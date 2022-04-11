create or replace procedure CUST_EOD_AFTER(Acnt     in acnt_contract %rowtype,
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
  p_end_billing             number;
  p_backup_billing          number;
  p_previous_billing_date   date;
  p_issuing_number          varchar2(64);
  p_credit_limit            number;
  p_due_date                DATE;
  p_billing_date            DATE;
  p_total_balance           number;
  p_instalment_balance      number;
  p_due_amount              number;
  p_debit_amount            number;
  p_credit_amount           number;
  p_fee_amount              number;
  p_interest_amount         number;
  p_instalment_amount       number;
  p_instalment_creation     number;
  p_dlq_hist                VARCHAR2(1200);
  p_dlq_legacy              VARCHAR2(120);
  p_dlq_value               number;
  p_check_late              number;
  p_late_date               number;
  p_ovd_date                number;
  p_debt_level              number;
  p_debt_level_by_late_date number;
  p_status_log_id           number;
  p_event_id                number;
  p_err_msg                 varchar2(16000);
  p_previous_bank_date      date;
  p_principal_balance       number;
  p_interest                number;
  p_ovd_interest            number;
  p_late_payment_fee        number;
  p_ovd_late_payment_fee    number;
  p_credit_balance          number;
  p_provision_balance       number;
  p_product_category        varchar2(2);
  p_dispute                 number;
  p_principal_sale          number;
  p_principal_cash          number;
  p_principal_fee           number;
  p_principal_instalment    number;
  p_sale_interest           number;
  p_cash_interest           number;
  p_instalment_interest     number;
  p_banking_date            DATE;
  p_acnt_contract_id        NUMBER;
  p_issuing_status_code     VARCHAR2(10);

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
    /*
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
    */
    begin
      /*
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
                   
                   --sum(decode(substr(Acnt.Contract_Number,1,1), '2', 0, '5', 0, '8',0,
                   --              decode(acc.code, 'P',   acc.current_balance,
                   --                               0
                   --              )
                   --    )
                   --)
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
      */
      -- OCB --
      IF Acnt.Pcat = 'C' AND Acnt.Con_Cat = 'A' AND Acnt.Ccat = 'P' THEN
        IF Acnt.Liab_Category = 'Y' THEN
          p_dlq_value := TO_NUMBER(ows.decr.EFF_STATUS_VALUE_CODE(459,
                                                                  Acnt.Id,
                                                                  null)) - 1;
          IF p_dlq_value = 6 THEN
            SELECT COUNT(*)
              INTO p_check_late
              FROM ows.cs_status_log cssl
             WHERE cssl.status_type = 459
               AND cssl.status_value = 758
               AND cssl.status_value_prev = 757
               AND cssl.is_active = 'Y'
               AND TO_CHAR(cssl.bank_date, 'YYYYMMDD') >
                   TO_CHAR(acnt_api.ACNT_DUE_DATE(cssl.acnt_contract__oid) - 1,
                           'YYYYMMDD')
               AND cssl.acnt_contract__oid = Acnt.Id;
            IF p_check_late = 0 THEN
            
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
                 AND TO_CHAR(bl.finish_billing_date, 'YYYYMMDD') !=
                     '20180715'
               GROUP BY bl.acnt_contract__oid;
            
              -- From late day to billing date, dlq hist will be increased by 1 unit manually if previous dlq value equals current dlq value
              IF TO_CHAR(BankDate, 'YYYYMMDD') >
                 TO_CHAR(acnt_api.ACNT_DUE_DATE(acnt.id) - 1, 'YYYYMMDD') THEN
                p_dlq_hist := '6' || p_dlq_hist;
              END IF;
            
              IF p_dlq_legacy IS NOT NULL THEN
                p_dlq_hist := p_dlq_hist || p_dlq_legacy;
              END IF;
            
              ows.stnd.PROCESS_MESSAGE('I',
                                       Acnt.Contract_Number ||
                                       ' DLQ Hist = ' || p_dlq_hist);
              p_dlq_value := INSTR(p_dlq_hist, '5') + 4;
            END IF;
          END IF;
          ows.stnd.PROCESS_MESSAGE('I',
                                   Acnt.Contract_Number || ' DLQ Value = ' ||
                                   p_dlq_value);
          ows.contract_parm.SET_CONTRACT_PARM(Acnt.Id,
                                              'DLQ_VALUE',
                                              p_dlq_value);
          p_debt_level_by_late_date := 1;
          p_late_date               := 0;
          IF p_dlq_value >= 1 THEN
            IF TO_CHAR(BankDate, 'YYYYMMDD') >
               TO_CHAR(acnt_api.ACNT_DUE_DATE(acnt.id) - 1, 'YYYYMMDD') AND
               TO_CHAR(BankDate, 'YYYYMMDD') <=
               TO_CHAR(Acnt.Next_Billing_Date, 'YYYYMMDD') THEN
              p_late_date := BankDate -
                             (ADD_MONTHS(Acnt.Next_Billing_Date,
                                         -p_dlq_value) + 25);
            ELSE
              p_late_date := BankDate -
                             (ADD_MONTHS(Acnt.Last_Billing_Date - 1,
                                         -p_dlq_value) + 25);
            END IF;
            p_debt_level_by_late_date := CASE
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
          ows.stnd.PROCESS_MESSAGE('I',
                                   Acnt.Contract_Number || ' Late Date = ' ||
                                   p_late_date);
          ows.contract_parm.SET_CONTRACT_PARM(Acnt.Id,
                                              'LATE_DATE',
                                              p_late_date);
          ows.decr.SET_CS_BY_CODE(Acnt.id,
                                  null,
                                  null,
                                  'OCB_DEBT_LEVEL_BY_LATE_DATE',
                                  TO_CHAR(p_debt_level_by_late_date),
                                  'EOD',
                                  null,
                                  null,
                                  p_status_log_id,
                                  p_event_id,
                                  p_err_msg);
        
          p_debt_level := 1;
          p_ovd_date   := 0;
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
          ows.stnd.PROCESS_MESSAGE('I',
                                   Acnt.Contract_Number || ' OVD Date = ' ||
                                   p_ovd_date);
          ows.contract_parm.SET_CONTRACT_PARM(Acnt.Id,
                                              'OVD_DATE',
                                              p_ovd_date);
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
                  SELECT *
                    FROM oms.oms_billing
                   WHERE billing_date = p_previous_billing_date;
                DELETE oms.oms_billing
                 WHERE billing_date = p_previous_billing_date;
                COMMIT;
              EXCEPTION
                WHEN OTHERS THEN
                  NULL;
              END;
            END IF;
            /*
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
              JOIN ows.m_transaction mt
                ON entry.m_transaction__id = mt.id
             WHERE TO_CHAR(item.cycle_date_to, 'YYYYMMDD') =
                   TO_CHAR(Acnt.Last_Billing_Date - 1, 'YYYYMMDD')
               AND entry.acnt_contract__id = Acnt.Id
               AND entry.service_class IN ('T', 'A')
               AND entry.amount <> 0
               AND ((entry.service_class = 'T' AND
                    doc.trans_type NOT IN (7, 36565)) OR
                    (entry.service_class = 'A' AND
                    ows.acnt_api.TAG_VAL(doc.add_info, 'ORDER_ID') IS NULL AND
                    ows.acnt_api.TAG_VAL(NVL(mt.mtr_details, ' '),
                                          'ORDER_ID') IS NULL))
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
              JOIN ows.m_transaction mt
                ON entry.m_transaction__id = mt.id
             WHERE TO_CHAR(item.cycle_date_to, 'YYYYMMDD') =
                   TO_CHAR(Acnt.Last_Billing_Date - 1, 'YYYYMMDD')
               AND entry.acnt_contract__id = Acnt.Id
               AND entry.service_class IN ('T', 'A')
               AND entry.amount <> 0
               AND ((entry.service_class = 'T' AND
                    doc.trans_type NOT IN (20, 36565)) OR
                    (entry.service_class = 'A' AND
                    ows.acnt_api.TAG_VAL(doc.add_info, 'ORDER_ID') IS NULL AND
                    ows.acnt_api.TAG_VAL(NVL(mt.mtr_details, ' '),
                                          'ORDER_ID') IS NULL))
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
            
            SELECT SUM(amount)
              INTO p_instalment_creation
              FROM (SELECT entry.acnt_contract__id,
                           item.cycle_date_to,
                           entry.amount
                      FROM ows.entry entry
                      JOIN ows.item item
                        ON entry.item__id = item.id
                      JOIN ows.account account
                        ON item.account__oid = account.id
                      JOIN ows.doc doc
                        ON entry.doc_id = doc.id
                      JOIN ows.standing_order standing_order
                        ON ows.acnt_api.TAG_VAL(doc.add_info, 'ORDER_ID') =
                           standing_order.id
                       AND standing_order.amnd_state = 'A'
                    --JOIN ows.trans_type tt
                    --ON doc.trans_type = tt.id
                    --AND tt.amnd_state = 'A'
                    --JOIN ows.invoice_log invoice_log
                    --ON ows.acnt_api.TAG_VAL(doc.add_info, 'INV_ID') =
                    --invoice_log.id
                    --JOIN ows.doc original_doc
                    --ON invoice_log.doc_id = original_doc.id
                     WHERE TO_CHAR(item.cycle_date_to, 'YYYYMMDD') =
                           TO_CHAR(Acnt.Last_Billing_Date - 1, 'YYYYMMDD')
                       AND entry.acnt_contract__id = Acnt.Id
                       AND entry.service_class = 'T'
                       AND entry.amount > 0
                       AND standing_order.order_code = 'MANUAL_INSTALMENT'
                    UNION ALL
                    SELECT entry.acnt_contract__id,
                           item.cycle_date_to,
                           entry.amount
                      FROM ows.entry entry
                      JOIN ows.item item
                        ON entry.item__id = item.id
                      JOIN ows.account account
                        ON item.account__oid = account.id
                      JOIN ows.m_transaction mt
                        ON entry.m_transaction__id = mt.id
                      JOIN ows.standing_order standing_order
                        ON ows.acnt_api.TAG_VAL(mt.mtr_details, 'ORDER_ID') =
                           standing_order.id
                       AND standing_order.amnd_state = 'A'
                    --JOIN ows.trans_subtype tst
                    --ON mt.trans_subtype = tst.id
                    --AND tst.amnd_state = 'A'
                    --JOIN ows.invoice_log invoice_log
                    --ON ows.acnt_api.TAG_VAL(mt.mtr_details, 'INV_ID') =
                    --invoice_log.id
                    --JOIN ows.doc original_doc
                    --ON invoice_log.doc_id = original_doc.id
                     WHERE TO_CHAR(item.cycle_date_to, 'YYYYMMDD') =
                           TO_CHAR(Acnt.Last_Billing_Date - 1, 'YYYYMMDD')
                       AND entry.acnt_contract__id = Acnt.Id
                       AND entry.service_class = 'A'
                       AND entry.amount > 0
                       AND standing_order.order_code = 'MANUAL_INSTALMENT');
            
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
               instalment_creation,
               banking_date)
            VALUES
              (Acnt.Contract_Number,
               Acnt.Auth_Limit_Amount,
               p_instalment_balance,
               Acnt.Last_Billing_Date - 1,
               TO_DATE(ows.sy_convert.get_tag_value(Acnt.Ext_Data,
                                                    'DUE_DATE'),
                       'yyyy-MM-dd') - 1,
               Acnt.Total_Balance,
               p_due_amount,
               p_debit_amount,
               p_credit_amount,
               p_fee_amount,
               p_interest_amount,
               p_instalment_amount,
               p_instalment_creation,
               BankDate);
               */
            SELECT MIN(Acnt.contract_number) issuing_number
                   --, MIN(-ows.acnt_api.TAG_VAL(bl.bal_list, 'CR_LIMIT')) credit_limit
                  ,
                   MIN(Acnt.Auth_Limit_Amount) credit_limit,
                   NVL(MIN(inst.instalment_balance), 0) instalment_balance,
                   MIN(bl.finish_billing_date) billing_date,
                   MIN(bl.due_date - 1) due_date,
                   MIN(bl.total_balance) total_balance,
                   NVL(SUM(CASE
                             WHEN e.trans_code = 'RS_P_D' AND e.amount < 0 THEN
                              e.amount
                             ELSE
                              0
                           END),
                       0) due_amount,
                   NVL(SUM(CASE
                             WHEN ta.code IN ('POC_OS',
                                              'POC_GS',
                                              'POC_CS',
                                              'POC_OC',
                                              'POC_GC',
                                              'POC_CC',
                                              'POC_LPF',
                                              'POC_OSF',
                                              'POC_OCF',
                                              'POC_GSF',
                                              'POC_GCF',
                                              'POC_CSF',
                                              'POC_CCF',
                                              'POC_GSI',
                                              'POC_GCI',
                                              'POC_CSI',
                                              'POC_CCI') AND
                                  e.service_class IN ('T', 'A') AND
                                  e.trans_code NOT IN ('AL1', 'AL2', 'AL4') AND
                                  e.is_reversed is null AND
                                  ((e.request_cat in ('P', 'J') AND e.amount < 0) OR
                                  (e.request_cat = 'R' AND e.amount > 0)) THEN
                              e.amount
                             ELSE
                              0
                           END),
                       0) debit_amount,
                   NVL(SUM(CASE
                             WHEN ta.code = 'P' AND e.service_class IN ('T', 'A') AND
                                  e.amount > 0 THEN
                              e.amount
                             ELSE
                              0
                           END),
                       0) credit_amount,
                   NVL(SUM(e.fee_amount), 0) fee_amount,
                   NVL(SUM(CASE
                             WHEN e.service_class = 'I' AND e.amount <> 0 THEN
                              e.amount
                             ELSE
                              0
                           END),
                       0) interest_amount,
                   NVL(SUM(CASE
                             WHEN e.trans_code = 'AL1' AND e.amount < 0 THEN
                              e.amount
                             ELSE
                              0
                           END),
                       0) instalment_amount,
                   NVL(SUM(CASE
                             WHEN e.trans_code = 'IICACA' AND e.amount > 0 THEN
                              e.amount
                             ELSE
                              0
                           END),
                       0) instalment_creation,
                   MIN(BankDate) banking_date,
                   MIN(Acnt.Id) acnt_contract_id,
                   (SELECT code
                      FROM ows.contr_status
                     WHERE id = Acnt.Contr_Status
                       AND amnd_state = 'A') issuing_status_code
              INTO p_issuing_number,
                   p_credit_limit,
                   p_instalment_balance,
                   p_billing_date,
                   p_due_date,
                   p_total_balance,
                   p_due_amount,
                   p_debit_amount,
                   p_credit_amount,
                   p_fee_amount,
                   p_interest_amount,
                   p_instalment_amount,
                   p_instalment_creation,
                   p_banking_date,
                   p_acnt_contract_id,
                   p_issuing_status_code
              FROM ows.billing_log bl
            --JOIN ows.acnt_contract ic ON bl.acnt_contract__oid=ic.id AND ic.amnd_state='A' AND ic.liab_category='Y'
              LEFT JOIN ows.account a
                ON bl.acnt_contract__oid = a.acnt_contract__oid
              LEFT JOIN ows.item i
                ON i.account__oid = a.id
               AND bl.finish_billing_date = i.cycle_date_to
               AND i.currency = '704'
              LEFT JOIN ows.templ_approved ta
                ON i.templ_approved_id = ta.id
              LEFT JOIN ows.entry e
                ON i.id = e.item__id
              LEFT JOIN (SELECT a.acnt_contract__oid,
                                i.cycle_date_to,
                                SUM(i.ITEM_TOTAL + i.FEE_TOTAL) +
                                MIN(i.cycle_balance) instalment_balance
                           FROM ows.item i
                           JOIN ows.templ_approved ta
                             ON i.templ_approved_id = ta.id
                           JOIN ows.account a
                             ON i.account__oid = a.id
                          WHERE ta.code = 'L1'
                            AND i.cycle_date_to = Acnt.Last_Billing_Date - 1
                          GROUP by a.acnt_contract__oid, i.cycle_date_to) inst
                ON bl.acnt_contract__oid = inst.acnt_contract__oid
               AND bl.finish_billing_date = inst.cycle_date_to
             where 1 = 1
               AND bl.acnt_contract__oid = Acnt.Id
               AND bl.finish_billing_date = Acnt.Last_Billing_Date - 1
             GROUP BY bl.acnt_contract__oid, bl.finish_billing_date;
          
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
               instalment_creation,
               banking_date,
               acnt_contract_id,
               issuing_status_code)
            VALUES
              (p_issuing_number,
               p_credit_limit,
               p_instalment_balance,
               p_billing_date,
               p_due_date,
               p_total_balance,
               p_due_amount,
               p_debit_amount,
               p_credit_amount,
               p_fee_amount,
               p_interest_amount,
               p_instalment_amount,
               p_instalment_creation,
               p_banking_date,
               p_acnt_contract_id,
               p_issuing_status_code);
          
            IF Acnt.Branch = '0133' THEN
              INSERT INTO oms.oms_billing_comb
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
                 instalment_creation,
                 banking_date,
                 acnt_contract_id,
                 issuing_status_code)
              VALUES
                (p_issuing_number,
                 p_credit_limit,
                 p_instalment_balance,
                 p_billing_date,
                 p_due_date,
                 p_total_balance,
                 p_due_amount,
                 p_debit_amount,
                 p_credit_amount,
                 p_fee_amount,
                 p_interest_amount,
                 p_instalment_amount,
                 p_instalment_creation,
                 p_banking_date,
                 p_acnt_contract_id,
                 p_issuing_status_code);
            END IF;
          END IF;
        END IF;
        SELECT MAX(SUBSTR(ap.code, 1, 2))
          INTO p_product_category
          FROM ows.appl_product ap
         WHERE ap.internal_code = Acnt.product
           AND ap.amnd_state = 'A';
      
        IF p_product_category IN ('IC', 'IP') THEN
          SELECT MAX(local_date)
            INTO p_previous_bank_date
            FROM ows.ldate_log
           WHERE TO_CHAR(local_date, 'yyyymmdd') !=
                 TO_CHAR(BankDate, 'yyyymmdd');
        
          SELECT NVL(sum(case
                           when a.code in ('POC_NIC',
                                           'POC_OC',
                                           'POC_CC',
                                           'POC_GC',
                                           'POC_OVL_C',
                                           'OVD00C',
                                           'POC_NIS',
                                           'POC_OS',
                                           'POC_CS',
                                           'POC_GS',
                                           'POC_OVL_S',
                                           'OVD00S',
                                           'L2',
                                           'L4',
                                           'POC_OCF',
                                           'POC_GCF',
                                           'POC_CCF',
                                           'OVD00CF',
                                           'POC_OSF',
                                           'POC_GSF',
                                           'POC_CSF',
                                           'OVD00SF') then
                            a.current_balance
                           else
                            0
                         end),
                     0),
                 NVL(sum(case
                           when a.code IN ('L1') THEN
                            a.current_balance
                           else
                            0
                         end),
                     0),
                 NVL(sum(case
                           when a.code in ('POC_GCI',
                                           'POC_CCI',
                                           'POC_GSI',
                                           'POC_CSI',
                                           'Br1',
                                           '!l3',
                                           '-3') then
                           
                            a.current_balance
                           else
                            0
                         end),
                     0),
                 NVL(sum(case
                           when a.code in
                                ('OVD00SI', 'DEB00SI', 'OVD00CI', 'DEB00CI') then
                            a.current_balance
                           else
                            0
                         end),
                     0),
                 NVL(sum(case
                           when a.code = 'POC_LPF' then
                            a.current_balance
                           else
                            0
                         end),
                     0),
                 NVL(sum(case
                           when a.code = 'OVD_LPF' then
                            a.current_balance
                           else
                            0
                         end),
                     0),
                 NVL(sum(case
                           when a.code = 'P' then
                            a.current_balance
                           else
                            0
                         end),
                     0),
                 NVL(sum(case
                           when a.code = 'OVD_PVS2' then
                            a.current_balance
                           else
                            0
                         end),
                     0),
                 NVL(sum(case
                           when a.code = 'D' then
                            a.current_balance
                           else
                            0
                         end),
                     0),
                 NVL(sum(case
                           when a.code in ('POC_NIS',
                                           'POC_OS',
                                           'POC_CS',
                                           'POC_GS',
                                           'POC_OVL_S',
                                           'OVD00S',
                                           --'L2',
                                           'L4') then
                            a.current_balance
                           else
                            0
                         end),
                     0),
                 NVL(sum(case
                           when a.code in ('POC_NIC',
                                           'POC_OC',
                                           'POC_CC',
                                           'POC_GC',
                                           'POC_OVL_C',
                                           'OVD00C') then
                            a.current_balance
                           else
                            0
                         end),
                     0),
                 NVL(sum(case
                           when a.code in ('POC_OCF',
                                           'POC_GCF',
                                           'POC_CCF',
                                           'OVD00CF',
                                           'POC_OSF',
                                           'POC_GSF',
                                           'POC_CSF',
                                           'OVD00SF') then
                            a.current_balance
                           else
                            0
                         end),
                     0),
                 NVL(sum(case
                           when a.code in ('L2') then
                            a.current_balance
                           else
                            0
                         end),
                     0),
                 NVL(sum(case
                           when a.code in
                                ('POC_GSI', 'POC_CSI', 'OVD00SI', 'DEB00SI') then
                            a.current_balance
                           else
                            0
                         end),
                     0),
                 NVL(sum(case
                           when a.code in
                                ('POC_GCI', 'POC_CCI', 'OVD00CI', 'DEB00CI') then
                            a.current_balance
                           else
                            0
                         end),
                     0),
                 NVL(sum(case
                           when a.code in ('Br1', '!l3', '-3') then
                            a.current_balance
                           else
                            0
                         end),
                     0)
            INTO p_principal_balance,
                 p_instalment_balance,
                 p_interest,
                 p_ovd_interest,
                 p_late_payment_fee,
                 p_ovd_late_payment_fee,
                 p_credit_balance,
                 p_provision_balance,
                 p_dispute,
                 p_principal_sale,
                 p_principal_cash,
                 p_principal_fee,
                 p_principal_instalment,
                 p_sale_interest,
                 p_cash_interest,
                 p_instalment_interest
            FROM ows.account a
           WHERE a.acnt_contract__oid = Acnt.Id;
        
          INSERT INTO oms.oms_balance
            (issuing_number,
             principal_balance,
             instalment_balance,
             interest,
             ovd_interest,
             late_payment_fee,
             ovd_late_payment_fee,
             credit_balance,
             provision_balance,
             dlq_value,
             debt_level,
             debt_level_by_late_date,
             late_date,
             ovd_date,
             previous_banking_date,
             banking_date,
             total_balance,
             total_blocked,
             dispute,
             principal_sale,
             principal_cash,
             principal_fee,
             principal_instalment,
             sale_interest,
             cash_interest,
             instalment_interest)
          VALUES
            (Acnt.contract_number,
             p_principal_balance,
             p_instalment_balance,
             p_interest,
             p_ovd_interest,
             p_late_payment_fee,
             p_ovd_late_payment_fee,
             p_credit_balance,
             p_provision_balance,
             p_dlq_value,
             p_debt_level,
             p_debt_level_by_late_date,
             p_late_date,
             p_ovd_date,
             TRUNC(p_previous_bank_date),
             TRUNC(BankDate),
             Acnt.Total_Balance,
             Acnt.Total_Blocked,
             p_dispute,
             p_principal_sale,
             p_principal_cash,
             p_principal_fee,
             p_principal_instalment,
             p_sale_interest,
             p_cash_interest,
             p_instalment_interest);
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
