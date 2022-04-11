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
  TargetAmnt dtypt.Money       %Type;
  TransCode  dtypt.TransCode   %Type;

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
  
  
  --Begin Merchant Monthly Fee--
  TargetAmnt := 0;
  stnd.process_message (stnd.trace, 'Entering CUST_FEE_BASE');
  stnd.process_message (stnd.trace, 'ContractID: '||ContractID||',SettlAmount: '||SettlAmount||', ServiceID: '||ServiceID);
  
  select t.trans_code into TransCode
  from trans_subtype st, trans_type t
  where st.trans_type__oid = t.id
  and st.id = CurrMtr.Trans_Subtype;
  ows.stnd.PROCESS_MESSAGE('I', 'TransCode: ' || TransCode);
  
  IF TransCode = 'MMF'
   then 
    select hy.balance into TargetAmnt
    from ACNT_BALANCE_HISTORY hy
    where hy.id = (select max(h.id) from ACNT_BALANCE_HISTORY h
                                    where h.acnt_contract__oid = ContractID
                                    and h.balance_type = (select min(b.id) from balance_type b where b.code = 'MONTHLY_TURN'));
    ows.stnd.PROCESS_MESSAGE('I', 'TargetAmnt: ' || TargetAmnt);
    return TargetAmnt;
  end IF;   
  EXCEPTION WHEN NO_DATA_FOUND THEN return TargetAmnt;
  --End Merchant Monthly Fee--
  
  
  RETURN 0;
end;
