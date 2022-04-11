CREATE OR REPLACE PROCEDURE OWS."CUST_EVNT_POST" (EventID    in dtype. RecordID %Type,
                                           EventCode  in dtype. Name %Type,
                                           ContractID in dtype. RecordID %Type) is
  p_value_code    VARCHAR2(2);
  p_status_log_id number;
  p_event_id      number;
  p_late_count    number;
  p_err_msg       varchar2(16000);
  p_result        varchar2(1000);
begin
  if EventCode = 'DELQ_CHANGE_RATES' then
    instl_tools.CLOSE_CONTRACT_PLANS(ContractID);
  end if;

  if EventCode = 'CHANGE_YEARLY_2_MONTHLY_FEE' then
    SELECT LPAD(TO_CHAR(TO_NUMBER(TO_CHAR(cc.date_open, 'dd')) - 1), 2, '0')
      INTO p_value_code
      FROM ows.acnt_contract cc
     WHERE id = ContractID;
    ows.decr.SET_CS_BY_CODE(ContractID,
                            null,
                            null,
                            'CARD_MONTHLY_FEE_DATE',
                            p_value_code,
                            'Change 2 Monthly Fee',
                            null,
                            null,
                            p_status_log_id,
                            p_event_id,
                            p_err_msg);
  
    ows.stnd.PROCESS_MESSAGE('I',
                             'CUST_EVNT_POST ' || ContractID ||
                             ' Change yearly to month');
    p_result := ows.api.PUT_EVENT(ows.api.get_event_type('CHARGE_MONTHLY_FEE_1ST',
                                                         ContractID,
                                                         'N'),
                                  ContractID,
                                  NULL,
                                  ows.glob.ldate(),
                                  'Charge monthly fee in the first');
  end if;

  if EventCode = 'ACTIVATE_CARD' then
    IF ows.contract_parm.GET_CONTRACT_ID_PARM(ContractID,
                                              '',
                                              'FIRST_ACTIVATION_DATE') IS NULL THEN
      ows.contract_parm.SET_CONTRACT_PARM(ContractID,
                                          'FIRST_ACTIVATION_DATE',
                                          TO_CHAR(SYSDATE, 'yyyymmdd'));
    END IF;
    ows.contract_parm.SET_CONTRACT_PARM(ContractID,
                                        'LAST_ACTIVATION_DATE',
                                        TO_CHAR(SYSDATE, 'yyyymmdd'));
  end if;

  if EventCode = 'LATE_PAYMENT' then
    p_late_count := ows.contract_parm.GET_CONTRACT_ID_PARM(ContractID,
                                                           '',
                                                           'LATE_COUNT');
    ows.contract_parm.SET_CONTRACT_PARM(ContractID,
                                        'LATE_COUNT',
                                        NVL(p_late_count, 0) + 1);
  end if;

  if EventCode = 'ClOSE_TRANS_PREV_CARD' then
    update ows.card_info ci
       set ci.trans_status = 'C'
     where ci.acnt_contract__oid = ContractID
       and ci.status = 'C'
       and ci.trans_status <> 'C';
    ows.stnd.PROCESS_MESSAGE('I',
                             ContractID || ' is closed trans of prev cards');
  end if;

  return;
end;
