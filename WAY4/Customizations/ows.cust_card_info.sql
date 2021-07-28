create or replace procedure ows.CUST_CARD_INFO(CardInfoID in dtype. RecordID %Type) is
  p_latest_contract_number VARCHAR2(64);
  p_prev_card              NUMBER;
  p_acnt_contract__oid     NUMBER;
begin

  BEGIN
    ows.stnd.PROCESS_MESSAGE('I', 'CUST_CARD_INFO: Begin');
    SELECT MAX(contract_number)
      INTO p_latest_contract_number
      FROM ows.card_info ci
      JOIN ows.acnt_contract ic
        ON ci.acnt_contract__oid = ic.id
       AND ic.base_relation IS NULL
     WHERE ci.id = CardInfoID;
  
    IF p_latest_contract_number IS NOT NULL THEN
      p_prev_card := CardInfoID;
      WHILE p_prev_card <> 0 LOOP
        SELECT NVL(ci.prev_card, 0), ci.acnt_contract__oid
          INTO p_prev_card, p_acnt_contract__oid
          FROM ows.card_info ci
         WHERE ci.id = p_prev_card
           AND ci.acnt_contract__oid IS NOT NULL;
        ows.stnd.PROCESS_MESSAGE('I',
                                 'CUST_CARD_INFO: Update prev_card=' ||
                                 p_prev_card || '&acnt_contract__oid=' ||
                                 p_acnt_contract__oid);
        ows.contract_parm.SET_CONTRACT_PARM(p_acnt_contract__oid,
                                            'LATEST_CONTRACT_NUMBER',
                                            p_latest_contract_number);
      END LOOP;
    END IF;
    ows.stnd.PROCESS_MESSAGE('I', 'CUST_CARD_INFO: End.');
  EXCEPTION
    WHEN OTHERS THEN
      ows.stnd.PROCESS_MESSAGE('E', 'CUST_CARD_INFO: Error!');
      NULL;
  END;

  return;
end;
