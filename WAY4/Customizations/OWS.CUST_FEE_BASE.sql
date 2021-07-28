create or replace function ows.CUST_FEE_BASE(ContractID  in dtype. RecordID %Type,
                                         SettlCurr   in dtypt. CurrencyCode %Type,
                                         SettlAmount in dtypt. Money %Type,
                                         AccCurr     in dtypt. CurrencyCode %Type,
                                         ServiceID   in dtype. RecordID %Type,
                                         FeeDsc      in dtype. Name %Type,
                                         CurrMtr     in m_transaction %rowtype)
  return dtypt. Money %Type IS
  p_check_dlq_level     NUMBER;
  p_check_merchant_name NUMBER;
begin
  ows.stnd.PROCESS_MESSAGE('I', 'Cust Fee Base ' || ContractID);
  IF AccCurr = '001' THEN
    ows.stnd.PROCESS_MESSAGE('I',
                             'ABC Cust Fee Base ' || ContractID || ' ' ||
                             CurrMtr.Local_Amount);
    SELECT COUNT(*)
      INTO p_check_dlq_level
      FROM ows.acnt_contract card
      JOIN ows.acnt_contract issuing
        ON card.acnt_contract__oid = issuing.id
     WHERE card.id = ContractID
       AND card.amnd_state = 'A'
       AND issuing.amnd_state = 'A'
       AND CAST(ows.decr.EFF_STATUS_VALUE_CODE((SELECT id
                                                 FROM ows.cs_status_type
                                                WHERE code = 'DLQ_LEVEL'
                                                  AND amnd_state = 'A'),
                                               issuing.id,
                                               NULL) AS NUMBER) > 1;
  
    IF p_check_dlq_level > 1 THEN
      ows.stnd.PROCESS_MESSAGE('I', 'Cust Fee Base: Check DLQ');
      RETURN 0;
    END IF;
  
    SELECT COUNT(*)
      INTO p_check_merchant_name
      FROM ows.sy_handbook
     WHERE group_code = 'OCB_LYP_EXC_MN_LIST'
       AND amnd_state = 'A'
       AND (SELECT UPPER(d.trans_details)
              FROM ows.doc d
             WHERE d.id = CurrMtr.Doc__Oid) LIKE '%' || FILTER || '%';
  
    IF p_check_merchant_name > 0 THEN
      ows.stnd.PROCESS_MESSAGE('I', 'Cust Fee Base: Check Merchant Name');
      RETURN 0;
    END IF;
  
    RETURN CurrMtr.Local_Amount;
  END IF;
  RETURN 0;
end;
