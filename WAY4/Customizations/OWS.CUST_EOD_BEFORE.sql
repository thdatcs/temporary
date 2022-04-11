create or replace procedure ows.CUST_EOD_BEFORE(
                                            /**
                                                                                                                                                                                                                                                                                                                                    Actions performed before standard CDU
                                                                                                                                    
                                                                                                                                                                                                                                                                                                                                    @param Acnt Contract record which CDU is starting for
                                                                                                                                                                                                                                                                                                                                    @param Regime Mode which CDU was run in ('S' - start of day - morning, 'E' - end of day, evening)
                                                                                                                                                                                                                                                                                                                                    @param DueDate The date being opened
                                                                                                                                                                                                                                                                                                                                    @param BankDate Current bank date. On Evening CDU it's the date being closed, on Morning CDU it's the date being opened
                                                                                                                                                                                                                                                                                                                                    */Acnt     in acnt_contract %rowtype,
                                            Regime   in dtype. Tag %Type,
                                            DueDate  in dtype. CurrentDate %Type,
                                            BankDate in dtype. CurrentDate %Type) is

  p_ovl_amount           number;
  p_result               VARCHAR2(2000);
  p_min_payment_rate_id  number;
  p_auto_convert_inst_id number;
  p_status_log_id        number;
  p_event_id             number;
  p_err_msg              varchar2(16000);
  p_inst_unbilled_amount number;
  p_login_id             NUMBER;
  p_new_plan_id          NUMBER;
  p_ret_code             NUMBER;
  p_ret_msg              VARCHAR2(4000);
  p_inst_scheme_id       number;
begin
  begin
    /*
        IF Acnt.Pcat = 'C' AND Acnt.Con_Cat = 'C' AND Acnt.Ccat = 'P' AND
           Acnt.Base_Relation IS NULL AND Acnt.Production_Status = 'R' THEN
          BEGIN
            IF Acnt.Card_Expire || TO_CHAR(Acnt.Date_Open, 'DD') <=
               TO_CHAR(BankDate, 'YYMMDD') AND Acnt.Contr_Status <> 175 THEN
              p_result := ows.api.put_event(ows.api.get_event_type('CARD_EXPIRED',
                                                                   Acnt.Id,
                                                                   'N'),
                                            Acnt.Id,
                                            NULL,
                                            ows.glob.ldate(),
                                            'Card Expired');
              ows.stnd.process_message('I',
                                       Acnt.Id ||
                                       ' - CARD_EXPIRED - Event ID: ' ||
                                       p_result);
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              ows.stnd.process_message('E',
                                       Acnt.Contract_Number ||
                                       ' - CARD_EXPIRED');
          END;
        END IF;
    */
  
    IF Acnt.Pcat = 'C' AND Acnt.Con_Cat = 'A' AND Acnt.Ccat = 'P' AND
       Acnt.Liab_Category = 'Y' THEN
      BEGIN
        SELECT NVL(MAX(available), 0)
          INTO p_ovl_amount
          FROM ows.acnt_balance
         WHERE acnt_contract__oid = Acnt.Id
           AND balance_type_code IN ('OVL');
      
        IF p_ovl_amount <> 0 THEN
          p_result := ows.api.put_event(ows.api.get_event_type('OVL_DAILY',
                                                               Acnt.Id,
                                                               'N'),
                                        Acnt.Id,
                                        NULL,
                                        ows.glob.ldate(),
                                        'OVL Daily');
          ows.stnd.process_message('I',
                                   Acnt.Id || '- OVL_DAILY - Event ID: ' ||
                                   p_result);
        END IF;
      
        --Update Classifier Min Payment Rate for Credit Card
        SELECT cs.id
          INTO p_min_payment_rate_id
          FROM ows.Cs_Status_Type cs
         WHERE cs.code = 'OCB_MIN_PAYMENT_RATE'
           AND cs.amnd_state = 'A';
      
        IF TO_CHAR(Acnt.Next_Billing_Date, 'yyyymm') = '202110' AND
           ows.decr.EFF_STATUS_VALUE_CODE(p_min_payment_rate_id,
                                          Acnt.Id,
                                          Acnt.Client__Id) <> 'MIN5' AND
           ows.decr.EFF_STATUS_VALUE_CODE(520, Acnt.Id, Acnt.Client__Id) = 'A' AND
           ows.decr.EFF_STATUS_VALUE_CODE(459, Acnt.Id, Acnt.Client__Id) BETWEEN 2 AND 5 THEN
          ows.decr.SET_CS_BY_CODE(Acnt.Id,
                                  null,
                                  null,
                                  'OCB_MIN_PAYMENT_RATE',
                                  'MIN5',
                                  'EOD - Keep MIN5',
                                  null,
                                  null,
                                  p_status_log_id,
                                  p_event_id,
                                  p_err_msg);
        END IF;
      
        IF ows.decr.EFF_STATUS_VALUE_CODE(p_min_payment_rate_id,
                                          Acnt.Id,
                                          Acnt.Client__Id) = 'MIN5' AND
           ows.decr.EFF_STATUS_VALUE_CODE(459, Acnt.Id, Acnt.Client__Id) < 2 THEN
          ows.decr.SET_CS_BY_CODE(Acnt.Id,
                                  null,
                                  null,
                                  'OCB_MIN_PAYMENT_RATE',
                                  'DEFAULT',
                                  'EOD - Change to DEFAULT',
                                  null,
                                  null,
                                  p_status_log_id,
                                  p_event_id,
                                  p_err_msg);
        END IF;
      
        --------------
        --Auto convert Installment
        SELECT cs.id
          INTO p_auto_convert_inst_id
          FROM ows.Cs_Status_Type cs
         WHERE cs.code = 'OCB_INST_AUTO_CONVERT'
           AND cs.amnd_state = 'A';
      
        IF Acnt.Contr_Status = 51 AND
           TRUNC(Acnt.Next_Billing_Date) < TRUNC(BankDate) AND
           ows.decr.EFF_STATUS_VALUE_CODE(p_auto_convert_inst_id,
                                          Acnt.Id,
                                          Acnt.Client__Id) = 'Y' THEN
          SELECT NVL(MAX(available), 0)
            INTO p_inst_unbilled_amount
            FROM ows.acnt_balance
           WHERE acnt_contract__oid = Acnt.Id
             AND balance_type_code IN ('INST_UNBILLED');
        
          IF p_inst_unbilled_amount <> 0 THEN
            IF ABS(p_inst_unbilled_amount) <= 1000000 THEN
              select id
                into p_inst_scheme_id
                from ows.inst_scheme
               where amnd_state = 'A'
                 and inst_scheme__oid is null
                 and code = 'IVC001_SP3';
            ELSE
              select id
                into p_inst_scheme_id
                from ows.inst_scheme
               where amnd_state = 'A'
                 and inst_scheme__oid is null
                 and code = 'IVC001_SP6';
            END IF;
            ows.stnd.process_message('I',
                                     Acnt.Contract_Number ||
                                     ' Prepare for instalment creation & activation');
            ows.instl.CREATE_INST_PLAN_FOR_BAL(Acnt.Id,
                                               'INST_UNBILLED',
                                               p_inst_scheme_id,
                                               null,
                                               null,
                                               null,
                                               null,
                                               null,
                                               null,
                                               null,
                                               null,
                                               null,
                                               null,
                                               null,
                                               null,
                                               p_new_plan_id,
                                               p_ret_code,
                                               p_ret_msg);
            ows.stnd.process_message('I',
                                     Acnt.Contract_Number ||
                                     ' Create instalment: Plan ID: ' ||
                                     p_new_plan_id || '#RC: ' || p_ret_code);
            IF p_ret_code = 0 THEN
              SELECT NVL(MAX(id), 0)
                INTO p_login_id
                FROM OWS.login_history
               WHERE computer_name = 'OMS_INST:' || Acnt.Id
                 AND service_code = 'INST'
                 AND logout_time IS NULL;
            
              IF p_login_id = 0 THEN
                INSERT INTO ows.login_history
                  (computer_name, login_time, service_code)
                VALUES
                  ('OMS_INST:' || Acnt.Id, current_timestamp, 'INST')
                RETURNING id INTO p_login_id;
                INSERT INTO ows.local_constants (id) values (p_login_id);
              END IF;
              ows.stnd.ConnectionID := p_login_id;
              UPDATE ows.local_constants
                 SET doc = p_new_plan_id
               WHERE id = p_login_id;
              ows.instl.ACTIVATE_PLAN(p_new_plan_id,
                                      ows.glob.LDATE(),
                                      null,
                                      null,
                                      p_ret_code,
                                      p_ret_msg);
              ows.stnd.process_message('I',
                                       Acnt.Contract_Number ||
                                       ' Activate instalment: Plan ID: ' ||
                                       p_new_plan_id || '#RC: ' ||
                                       p_ret_code);
            
            END IF;
          END IF;
        END IF;
        ------------------
      EXCEPTION
        WHEN OTHERS THEN
          ows.stnd.process_message('E',
                                   Acnt.Contract_Number || ' - EOD BEFORE');
      END;
    END IF;
  exception
    when others then
      null;
  end;
  return;
end CUST_EOD_BEFORE;
