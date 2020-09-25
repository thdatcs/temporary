DECLARE
CURSOR debit_contracts IS
SELECT contract.id, contract.contract_number
FROM ows.acnt_contract contract
JOIN ows.appl_product product ON contract.product=product.internal_code
WHERE contract.amnd_state='A'
AND product.amnd_state='A'
AND product.code IN ('CDMEM04001', 'CDME004001')
AND ows.decr.EFF_STATUS_VALUE_CODE(605, contract.id, contract.client__id)='CTF12';

r_debit_contracts debit_contracts%ROWTYPE;

p_result VARCHAR2(2000);
BEGIN
  OPEN debit_contracts;
  LOOP
    FETCH debit_contracts INTO r_debit_contracts;
    EXIT WHEN debit_contracts%NOTFOUND;
    
    p_result := ows.api.put_event(ows.api.get_event_type('FREE_DOM_TRANS_FEE_IND', r_debit_contracts.id, 'N'), r_debit_contracts.id, NULL, ows.glob.ldate(), 'Reset Counter');   
    COMMIT;
  
    ows.stnd.process_message ('I', r_debit_contracts.contract_number || '-' || r_debit_contracts.id || '- Event ID: ' || p_result);
  END LOOP;
  CLOSE debit_contracts;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;