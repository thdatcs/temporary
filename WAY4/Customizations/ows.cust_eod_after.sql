create or replace procedure ows.CUST_EOD_AFTER(Acnt     in acnt_contract %rowtype,
                                               Regime   in dtype. Tag %Type,
                                               DueDate  in dtype. CurrentDate %Type,
                                               BankDate in dtype. CurrentDate %Type) is
  /*
   cursor get_data_billing is
           select ac.id, bl.total_balance
           from acnt_contract ac, billing_log bl
           where trunc(ac.last_billing_date) = trunc(bl.finish_billing_date)
           and ac.id = bl.acnt_contract__oid
           and ac.amnd_state = 'A'
           and ac.ccat <> 'A'
           and ac.pcat = 'C'
           and ac.con_cat = 'A'
           and ac.contr_status = '38'
           and trunc(ac.last_billing_date) = trunc(BankDate)
           and trunc(bl.finish_billing_date) = trunc(BankDate)
           and bl.total_balance < 0;
    lvs_sum_shadow number;
  */
  p_end_billing           number;
  p_backup_billing        number;
  p_previous_billing_date date;
  p_instalment_balance    number;
  p_due_amount            number;
  p_debit_amount          number;
  p_credit_amount         number;
  p_fee_amount            number;
  p_interest_amount       number;
  p_instalment_amount     number;
  p_instalment_creation   number;
  p_dlq_hist              VARCHAR2(1200);
  p_dlq_legacy            VARCHAR(120);
  p_dlq_value             number;
  p_late_date             number;
  p_ovd_date              number;
  p_debt_level            number;
  p_status_log_id         number;
  p_event_id              number;
  p_err_msg               varchar2(16000);
begin
  /*
  FOR enr_data_billing IN get_data_billing LOOP
       select nvl(sum(h.current_balance),0) into lvs_sum_shadow
       from account h
       where h.acnt_contract__oid = enr_data_billing.id
       and h.code in ('S_P_D','S_OVD00','S_OVD15','S_OVD30','S_OVD45','S_OVD60','S_OVD75','S_OVD90','S_OVD105','S_OVD120','S_OVD135','S_OVD150','S_OVD165');
  
       if abs(enr_data_billing.total_balance > lvs_sum_shadow then
            update account at
            set at.current_balance = abs(enr_data_billing.total_balance - lvs_sum_shadow
            where h.acnt_contract__oid = enr_data_billing.id
            and h.code = 'S_P_D';
       end if;
  end loop;
  */
  begin
    --IF acnt.contract_number = '6016819429700001' THEN --HUNGHG2 FIX 17/08/2020
    IF acnt.contract_number = '6016822962820001' THEN
      begin
        update ocb.nab_params np
           set np.flag =
               (select np1.flag
                  from ocb.nab_params np1
                 where np1.type_param = 'CURRENT_DATE')
         where np.type_param = 'PREVIOUS_DATE';
      
        update ocb.nab_params np
           set np.flag = to_char(BankDate, 'dd/mm/yyyy')
         where np.type_param = 'CURRENT_DATE';
      exception
        when others then
          null;
      end;
    END IF;
  
    begin
      --      if Acnt.Pcat = 'C' and Acnt.Con_Cat = 'A' and Acnt.Ccat = 'P' and substr(Acnt.Contract_Number,1,1) in ('2','5','3','6') then -- KIMKC change allowed prefix cards 26032018
      -- KIMKC add prefix '8' for JCB 23042018      
      if Acnt.Pcat = 'C' and Acnt.Con_Cat = 'A' and Acnt.Ccat = 'P' and
         substr(Acnt.Contract_Number, 1, 1) not in ('1', '4', '7') then
        --process for updating balance history
        delete from ocb.balance_history
         where trunc(business_date) = trunc(BankDate)
           and acnt_contract__oid = Acnt.id;
      
        insert into ocb.balance_history
          (business_date,
           acnt_contract__oid,
           cr_balance_cash,
           cr_balance_noncash,
           cr_balanace_fee,
           cr_balance_interest_in_s,
           cr_balance_interest_in_c,
           cr_balance_interest_ex_s,
           cr_balance_interest_ex_c,
           cr_balance_ins_waiting,
           cr_balance_ins_open,
           cr_balance_ins_ovd,
           total_balance,
           total_blocked,
           CH_balance,
           loyalty_score,
           ovd_pvs2,
           ovd_pvs9_fee,
           ovd_pvs9_int,
           cr_balance_fee_in,
           cr_balance_fee_ex)
          select trunc(BankDate),
                 Acnt.id,
                 nvl(sum(decode(substr(Acnt.Contract_Number, 1, 1),
                                '2',
                                0,
                                '5',
                                0,
                                '8',
                                0,
                                decode(acc.code,
                                       'POC_NIC',
                                       acc.current_balance,
                                       'POC_OC',
                                       acc.current_balance,
                                       'POC_CC',
                                       acc.current_balance,
                                       'POC_GC',
                                       acc.current_balance,
                                       'POC_OVL_C',
                                       acc.current_balance,
                                       'OVD00C',
                                       acc.current_balance,
                                       0))),
                     0) cr_balance_cash,
                 nvl(sum(decode(substr(Acnt.Contract_Number, 1, 1),
                                '2',
                                0,
                                '5',
                                0,
                                '8',
                                0,
                                decode(acc.code,
                                       'POC_NIS',
                                       acc.current_balance,
                                       'POC_OS',
                                       acc.current_balance,
                                       'POC_GS',
                                       acc.current_balance,
                                       'POC_CS',
                                       acc.current_balance,
                                       'POC_OVL',
                                       acc.current_balance,
                                       'POC_OVL_S',
                                       acc.current_balance,
                                       'OVD00S',
                                       acc.current_balance,
                                       0))),
                     0) cr_balance_noncash,
                 nvl(sum(decode(substr(Acnt.Contract_Number, 1, 1),
                                '2',
                                0,
                                '5',
                                0,
                                '8',
                                0,
                                decode(acc.code,
                                       'POC_OSF',
                                       acc.current_balance,
                                       'POC_OCF',
                                       acc.current_balance,
                                       'POC_GSF',
                                       acc.current_balance,
                                       'POC_GCF',
                                       acc.current_balance,
                                       'POC_CSF',
                                       acc.current_balance,
                                       'POC_CCF',
                                       acc.current_balance,
                                       'OVD00SF',
                                       acc.current_balance,
                                       'OVD00CF',
                                       acc.current_balance,
                                       0))),
                     0) cr_balanace_fee,
                 nvl(sum(decode(substr(Acnt.Contract_Number, 1, 1),
                                '2',
                                0,
                                '5',
                                0,
                                '8',
                                0,
                                decode(acc.code,
                                       'POC_GSI',
                                       acc.current_balance,
                                       'POC_CSI',
                                       acc.current_balance,
                                       0))),
                     0) cr_balance_interest_in_s,
                 nvl(sum(decode(substr(Acnt.Contract_Number, 1, 1),
                                '2',
                                0,
                                '5',
                                0,
                                '8',
                                0,
                                decode(acc.code,
                                       'POC_GCI',
                                       acc.current_balance,
                                       'POC_CCI',
                                       acc.current_balance,
                                       0))),
                     0) cr_balance_interest_in_c,
                 nvl(sum(decode(substr(Acnt.Contract_Number, 1, 1),
                                '2',
                                0,
                                '5',
                                0,
                                '8',
                                0,
                                decode(acc.code,
                                       'OVD00SI',
                                       acc.current_balance,
                                       'DEB00SI',
                                       acc.current_balance,
                                       0))),
                     0) cr_balance_interest_ex_s,
                 nvl(sum(decode(substr(Acnt.Contract_Number, 1, 1),
                                '2',
                                0,
                                '5',
                                0,
                                '8',
                                0,
                                decode(acc.code,
                                       'OVD00CI',
                                       acc.current_balance,
                                       'DEB00CI',
                                       acc.current_balance,
                                       0))),
                     0) cr_balance_interest_ex_c,
                 nvl(sum(decode(substr(Acnt.Contract_Number, 1, 1),
                                '2',
                                0,
                                '5',
                                0,
                                '8',
                                0,
                                decode(acc.code,
                                       'L1',
                                       acc.current_balance,
                                       'Br1',
                                       acc.current_balance,
                                       0))),
                     0) cr_balance_ins_waiting,
                 nvl(sum(decode(substr(Acnt.Contract_Number, 1, 1),
                                '2',
                                0,
                                '5',
                                0,
                                '8',
                                0,
                                decode(acc.code,
                                       'L2',
                                       acc.current_balance,
                                       '-3',
                                       acc.current_balance,
                                       0))),
                     0) cr_balance_ins_open,
                 nvl(sum(decode(substr(Acnt.Contract_Number, 1, 1),
                                '2',
                                0,
                                '5',
                                0,
                                '8',
                                0,
                                decode(acc.code,
                                       'L4',
                                       acc.current_balance,
                                       '!l3',
                                       acc.current_balance,
                                       0))),
                     0) cr_balance_ins_ovd,
                 Acnt.Total_Balance total_balance,
                 Acnt.Total_Blocked total_blocked,
                 /*
                 sum(decode(substr(Acnt.Contract_Number,1,1), '2', 0, '5', 0, '8',0,
                               decode(acc.code, 'P',   acc.current_balance,
                                                0
                               )
                     )
                 )*/
                 sum(decode(acc.code, 'P', acc.current_balance, 0)) CH_balance,
                 nvl(sum(decode(substr(Acnt.Contract_Number, 1, 1),
                                '2',
                                0,
                                '5',
                                0,
                                '8',
                                0,
                                decode(acc.code,
                                       'B1',
                                       acc.current_balance,
                                       0))),
                     0) Loyalty_Score,
                 nvl(sum(decode(substr(Acnt.Contract_Number, 1, 1),
                                '2',
                                0,
                                '5',
                                0,
                                '8',
                                0,
                                decode(acc.code,
                                       'OVD_PVS2',
                                       acc.current_balance,
                                       0))),
                     0) OVD_PVS2,
                 nvl(sum(decode(substr(Acnt.Contract_Number, 1, 1),
                                '2',
                                0,
                                '5',
                                0,
                                '8',
                                0,
                                decode(acc.code,
                                       'OVD_PVS9_1',
                                       acc.current_balance,
                                       0))),
                     0) OVD_PVS9_FEE,
                 nvl(sum(decode(substr(Acnt.Contract_Number, 1, 1),
                                '2',
                                0,
                                '5',
                                0,
                                '8',
                                0,
                                decode(acc.code,
                                       'OVD_PVS9_2',
                                       acc.current_balance,
                                       0))),
                     0) OVD_PVS9_INT,
                 nvl(sum(decode(substr(Acnt.Contract_Number, 1, 1),
                                '2',
                                0,
                                '5',
                                0,
                                '8',
                                0,
                                decode(acc.code,
                                       'POC_LPF',
                                       acc.current_balance,
                                       0))),
                     0) CR_BALANCE_FEE_IN,
                 nvl(sum(decode(substr(Acnt.Contract_Number, 1, 1),
                                '2',
                                0,
                                '5',
                                0,
                                '8',
                                0,
                                decode(acc.code,
                                       'OVD_LPF',
                                       acc.current_balance,
                                       0))),
                     0) CR_BALANCE_FEE_EX
            from ows.account acc
           where acc.acnt_contract__oid = Acnt.id;
      end if;
    
      -- OCB --
      IF Acnt.Pcat = 'C' AND Acnt.Con_Cat = 'A' AND Acnt.Ccat = 'P' AND
         Acnt.Liab_Category = 'Y' THEN
        p_dlq_value := TO_NUMBER(ows.decr.EFF_STATUS_VALUE_CODE(459,
                                                                Acnt.Id,
                                                                null)) - 1;
        IF p_dlq_value = 6 THEN
          SELECT MIN(ows.acnt_api.TAG_VAL(ic.ext_data, 'DLQ_LEGACY'))
            INTO p_dlq_legacy
            FROM ows.acnt_contract ic
           WHERE ic.id = Acnt.Id
             AND ic.amnd_state = 'A'
             AND ows.acnt_api.TAG_VAL(ic.ext_data, 'DLQ_LEGACY') IS NOT NULL;
        
          SELECT LISTAGG(SUBSTR(ows.acnt_api.TAG_VAL(bl.bal_list,
                                                     'DLQ_HIST'),
                                1,
                                1)) WITHIN GROUP(ORDER BY bl.finish_billing_date DESC)
            INTO p_dlq_hist
            FROM ows.billing_log bl
           WHERE bl.acnt_contract__oid = Acnt.Id
             AND bl.finish_billing_date != '15-JUL-2018'
           GROUP BY bl.acnt_contract__oid;
        
          -- From late day to billing date, dlq hist will be increased by 1 unit manually if previous dlq value equals current dlq value
          IF TO_CHAR(BankDate, 'YYYYMMDD') >
             TO_CHAR(acnt_api.ACNT_DUE_DATE(acnt.id) - 1, 'YYYYMMDD') AND
             TO_CHAR(BankDate, 'YYYYMMDD') <=
             TO_CHAR(Acnt.Next_Billing_Date, 'YYYYMMDD') AND
             p_dlq_value = SUBSTR(p_dlq_hist, 1, 1) THEN
            p_dlq_hist := '6' || p_dlq_hist;
          END IF;
        
          IF p_dlq_legacy IS NOT NULL THEN
            p_dlq_hist := p_dlq_hist || p_dlq_legacy;
          END IF;
          p_dlq_value := INSTR(p_dlq_hist, '5') + 4;
        END IF;
        ows.stnd.PROCESS_MESSAGE('I',
                                 Acnt.Contract_Number || ' DLQ Value = ' ||
                                 p_dlq_value);
        ows.contract_parm.SET_CONTRACT_PARM(Acnt.Id,
                                            'DLQ_VALUE',
                                            p_dlq_value);
        p_debt_level := 1;
        IF p_dlq_value >= 1 THEN
          IF TO_CHAR(BankDate, 'YYYYMMDD') >
             TO_CHAR(acnt_api.ACNT_DUE_DATE(acnt.id) - 1, 'YYYYMMDD') AND
             TO_CHAR(BankDate, 'YYYYMMDD') <=
             TO_CHAR(Acnt.Next_Billing_Date, 'YYYYMMDD') THEN
            p_late_date := BankDate -
                           (ADD_MONTHS(Acnt.Next_Billing_Date, -p_dlq_value) + 25);
          ELSE
            p_late_date := BankDate -
                           (ADD_MONTHS(Acnt.Last_Billing_Date - 1,
                                       -p_dlq_value) + 25);
          END IF;
          ows.stnd.PROCESS_MESSAGE('I',
                                   Acnt.Contract_Number || ' Late Date = ' ||
                                   p_late_date);
          ows.contract_parm.SET_CONTRACT_PARM(Acnt.Id,
                                              'LATE_DATE',
                                              p_late_date);
          p_debt_level := CASE
                            WHEN p_late_date < 10 THEN
                             1
                            WHEN p_late_date <= 90 THEN
                             2
                            WHEN p_late_date <= 180 THEN
                             3
                            WHEN p_late_date <= 360 THEN
                             4
                            ELSE
                             5
                          END;
        END IF;
        ows.decr.SET_CS_BY_CODE(Acnt.id,
                                null,
                                null,
                                'OCB_DEBT_LEVEL_BY_LATE_DATE',
                                TO_CHAR(p_debt_level),
                                'EOD',
                                null,
                                null,
                                p_status_log_id,
                                p_event_id,
                                p_err_msg);
      
        p_debt_level := 1;
        IF p_dlq_value >= 4 THEN
          IF TO_CHAR(BankDate, 'YYYYMMDD') >
             TO_CHAR(acnt_api.ACNT_DUE_DATE(acnt.id) - 1, 'YYYYMMDD') AND
             TO_CHAR(BankDate, 'YYYYMMDD') <=
             TO_CHAR(Acnt.Next_Billing_Date, 'YYYYMMDD') THEN
            p_ovd_date := BankDate -
                          (ADD_MONTHS(Acnt.Next_Billing_Date,
                                      -p_dlq_value + 4));
          ELSE
            p_ovd_date := BankDate -
                          (ADD_MONTHS(Acnt.Last_Billing_Date - 1,
                                      -p_dlq_value + 4));
          END IF;
          ows.stnd.PROCESS_MESSAGE('I',
                                   Acnt.Contract_Number || ' OVD Date = ' ||
                                   p_ovd_date);
          ows.contract_parm.SET_CONTRACT_PARM(Acnt.Id,
                                              'OVD_DATE',
                                              p_ovd_date);
        
          p_debt_level := CASE
                            WHEN p_ovd_date < 10 THEN
                             1
                            WHEN p_ovd_date <= 90 THEN
                             2
                            WHEN p_ovd_date <= 180 THEN
                             3
                            WHEN p_ovd_date <= 360 THEN
                             4
                            ELSE
                             5
                          END;
        END IF;
        ows.decr.SET_CS_BY_CODE(Acnt.id,
                                null,
                                null,
                                'OCB_DEBT_LEVEL',
                                TO_CHAR(p_debt_level),
                                'EOD',
                                null,
                                null,
                                p_status_log_id,
                                p_event_id,
                                p_err_msg);
      
        SELECT COUNT(*)
          INTO p_end_billing
          FROM ows.usage_action ua
          JOIN ows.event_type et
            ON ua.event_type = et.id
         WHERE ua.acnt_contract__id = Acnt.Id
           AND TO_CHAR(BankDate, 'YYYYMMDD') =
               TO_CHAR(ua.start_local_date, 'YYYYMMDD')
           AND et.code = 'END_BILLING'
           AND et.amnd_state = 'A';
        IF p_end_billing > 0 THEN
          SELECT COUNT(*), MIN(billing_date)
            INTO p_backup_billing, p_previous_billing_date
            FROM oms.oms_billing
           WHERE TO_CHAR(ADD_MONTHS(Acnt.Last_Billing_Date - 1, -1),
                         'YYYYMMDD') = TO_CHAR(billing_date, 'YYYYMMDD');
        
          IF p_backup_billing > 0 THEN
            BEGIN
              INSERT INTO oms.oms_billing_ind
              VALUES
                (p_previous_billing_date);
            
              INSERT INTO oms.oms_billing_hist
                SELECT * FROM oms.oms_billing;
              DELETE oms.oms_billing;
              COMMIT;
            EXCEPTION
              WHEN OTHERS THEN
                NULL;
            END;
          END IF;
        
          SELECT NVL(MAX(available), 0)
            INTO p_instalment_balance
            FROM ows.acnt_balance
           WHERE acnt_contract__oid = Acnt.Id
             AND balance_type_code IN ('INST_W');
        
          SELECT NVL(MAX(available), 0)
            INTO p_due_amount
            FROM ows.acnt_balance
           WHERE acnt_contract__oid = Acnt.Id
             AND balance_type_code IN ('DUE');
        
          SELECT NVL(SUM(entry.amount), 0)
            INTO p_debit_amount
            FROM ows.entry entry
            JOIN ows.item item
              ON entry.item__id = item.id
            JOIN ows.account account
              ON item.account__oid = account.id
            JOIN ows.doc doc
              ON entry.doc_id = doc.id
           WHERE TO_CHAR(item.cycle_date_to, 'YYYYMMDD') =
                 TO_CHAR(Acnt.Last_Billing_Date - 1, 'YYYYMMDD')
             AND entry.acnt_contract__id = Acnt.Id
             AND entry.service_class = 'T'
             AND entry.amount <> 0
             AND ows.sy_convert.GET_TAG_VALUE(doc.add_info, 'ORDER_ID') IS NULL
             AND account.code <> 'P';
        
          SELECT NVL(SUM(entry.amount), 0)
            INTO p_credit_amount
            FROM ows.entry entry
            JOIN ows.item item
              ON entry.item__id = item.id
            JOIN ows.account account
              ON item.account__oid = account.id
            JOIN ows.doc doc
              ON entry.doc_id = doc.id
           WHERE TO_CHAR(item.cycle_date_to, 'YYYYMMDD') =
                 TO_CHAR(Acnt.Last_Billing_Date - 1, 'YYYYMMDD')
             AND entry.acnt_contract__id = Acnt.Id
             AND entry.service_class = 'T'
             AND entry.amount <> 0
             AND ows.sy_convert.GET_TAG_VALUE(doc.add_info, 'ORDER_ID') IS NULL
             AND account.code = 'P';
        
          SELECT NVL(SUM(fee_amount), 0)
            INTO p_fee_amount
            FROM ows.entry entry
            JOIN ows.item item
              ON entry.item__id = item.id
           WHERE TO_CHAR(item.cycle_date_to, 'YYYYMMDD') =
                 TO_CHAR(Acnt.Last_Billing_Date - 1, 'YYYYMMDD')
             AND entry.acnt_contract__id = Acnt.Id
             AND entry.fee_amount <> 0
             AND item.currency = '704';
        
          SELECT NVL(SUM(amount), 0)
            INTO p_interest_amount
            FROM ows.entry entry
            JOIN ows.item item
              ON entry.item__id = item.id
           WHERE TO_CHAR(item.cycle_date_to, 'YYYYMMDD') =
                 TO_CHAR(Acnt.Last_Billing_Date - 1, 'YYYYMMDD')
             AND entry.acnt_contract__id = Acnt.Id
             AND entry.service_class = 'I';
        
          SELECT NVL(SUM(entry.amount), 0)
            INTO p_instalment_amount
            FROM ows.entry entry
            JOIN ows.item item
              ON entry.item__id = item.id
            JOIN ows.account account
              ON item.account__oid = account.id
            JOIN ows.doc doc
              ON entry.doc_id = doc.id
            JOIN ows.standing_order standing_order
              ON ows.sy_convert.GET_TAG_VALUE(doc.add_info, 'ORDER_ID') =
                 standing_order.id
             AND standing_order.amnd_state = 'A'
            JOIN ows.event_type event_type
              ON standing_order.event_type = event_type.id
             AND event_type.amnd_state = 'A'
           WHERE TO_CHAR(item.cycle_date_to, 'YYYYMMDD') =
                 TO_CHAR(Acnt.Last_Billing_Date - 1, 'YYYYMMDD')
             AND entry.acnt_contract__id = Acnt.Id
             AND entry.service_class = 'A'
             AND entry.amount < 0
             AND event_type.code IN
                 ('ISTL_PRCP_OPEN', 'ISTL_PRINCIPAL_CLOSE');
        
          SELECT NVL(SUM(entry.amount), 0)
            INTO p_instalment_creation
            FROM ows.entry entry
            JOIN ows.item item
              ON entry.item__id = item.id
            JOIN ows.account account
              ON item.account__oid = account.id
            JOIN ows.doc doc
              ON entry.doc_id = doc.id
            JOIN ows.standing_order standing_order
              ON ows.sy_convert.GET_TAG_VALUE(doc.add_info, 'ORDER_ID') =
                 standing_order.id
             AND standing_order.amnd_state = 'A'
          --JOIN ows.event_type event_type ON standing_order.event_type=event_type.id AND event_type.amnd_state='A'
           WHERE TO_CHAR(item.cycle_date_to, 'YYYYMMDD') =
                 TO_CHAR(Acnt.Last_Billing_Date - 1, 'YYYYMMDD')
             AND entry.acnt_contract__id = Acnt.Id
             AND entry.service_class = 'T'
             AND entry.amount > 0
             AND standing_order.order_code = 'MANUAL_INSTALMENT';
        
          INSERT INTO oms.oms_billing
            (issuing_number,
             credit_limit,
             instalment_balance,
             billing_date,
             due_date,
             total_balance,
             due_amount,
             debit_amount,
             credit_amount,
             fee_amount,
             interest_amount,
             instalment_amount,
             instalment_creation)
          VALUES
            (Acnt.Contract_Number,
             Acnt.Auth_Limit_Amount,
             p_instalment_balance,
             Acnt.Last_Billing_Date - 1,
             TO_DATE(ows.sy_convert.get_tag_value(Acnt.Ext_Data, 'DUE_DATE'),
                     'yyyy-MM-dd') - 1,
             Acnt.Total_Balance,
             p_due_amount,
             p_debit_amount,
             p_credit_amount,
             p_fee_amount,
             p_interest_amount,
             p_instalment_amount,
             p_instalment_creation);
        END IF;
      END IF;
    
    exception
      when others then
        null;
    end;
  exception
    when others then
      null;
  end;

  return;
end CUST_EOD_AFTER;
