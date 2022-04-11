CREATE OR REPLACE PROCEDURE OWS."CUST_CARD_FROM_PROD"(cPlastic  in card_info %RowType,
                                                  cContract in acnt_contract %RowType,
                                                  IsCustom  out dtype. Tag %Type) is
  ErrMsg                dtype. ErrorMessage %Type;
  SchemeID              dtype.RecordID %Type;
  RetCode               dtype.Counter %Type;
  p_check_source_ref_id NUMBER;
  CURSOR c_contr_param IS
    SELECT code
      FROM ows.contr_parm
     WHERE is_ready = 'Y'
       AND amnd_state = 'A'
       and add_info LIKE '%OCB_RESET;%';
begin
  IsCustom := stnd.No; -- of way4

  BEGIN
    ows.stnd.PROCESS_MESSAGE('I',
                             'CUST_CARD_FROM_PROD: BEGIN ' || cPlastic.Id);
  
    -- Reset Contract Param                       
    FOR p_contr_param IN c_contr_param LOOP
      ows.contract_parm.SET_CONTRACT_PARM(cContract.Id,
                                          p_contr_param.code,
                                          '');
    END LOOP;
  
    -- Enroll 3D Secure
    IF cPlastic.Event = 'O' AND
       SUBSTR(cContract.Contract_Number, 1, 1) IN ('3', '4', '5') THEN
      TDA.ENROLL(cContract.id,
                 cContract.client__id,
                 'EXT_OTP',
                 NULL,
                 TRUNC(SYSDATE),
                 TO_DATE('01012100', 'DDMMYYYY'),
                 SchemeID,
                 RetCode,
                 ErrMsg);
      TDA.ENROLL(cContract.id,
                 cContract.client__id,
                 'TDS_ENROLL',
                 NULL,
                 TRUNC(SYSDATE),
                 TO_DATE('01012100', 'DDMMYYYY'),
                 SchemeID,
                 RetCode,
                 ErrMsg);
    END IF;
  
    -- Reset Usage for Soft Activation
    ows.usg.ZEROIZE_USAGE_COUNTERS(cContract.id,
                                   'SOFT_ACTIVATION_ECOM_LIMIT');
  
    -- Card/PIN Delivery Management
    SELECT COUNT(*)
      INTO p_check_source_ref_id
      FROM oms.oms_card_pin_delivery
     WHERE source_ref_id = cPlastic.id;
  
    IF p_check_source_ref_id > 0 THEN
      DELETE oms.oms_card_pin_delivery WHERE source_ref_id = cPlastic.id;
    END IF;
  
    IF cPlastic.production_type = '3' AND
       cPlastic.acnt_contract__oid IS NOT NULL AND
       cPlastic.Prod_Date IS NOT NULL THEN
    
      INSERT INTO oms.oms_card_pin_delivery
        (card_number,
         card_name,
         production_event,
         production_date,
         source_table,
         source_ref_id,
         delivery_type,
         delivery_status,
         delivery_date)
      VALUES
        (cContract.contract_number,
         cPlastic.card_name,
         cPlastic.production_event,
         cPlastic.prod_date,
         'CARD_INFO',
         cPlastic.id,
         'CARD',
         '8964',
         SYSDATE);
    
      INSERT INTO oms.oms_card_pin_delivery
        (card_number,
         card_name,
         production_event,
         production_date,
         source_table,
         source_ref_id,
         delivery_type,
         delivery_status,
         delivery_date)
      VALUES
        (cContract.contract_number,
         cPlastic.card_name,
         cPlastic.production_event,
         cPlastic.prod_date,
         'CARD_INFO',
         cPlastic.id,
         'PIN',
         '8964',
         SYSDATE);
    ELSIF cPlastic.production_type = '9' AND
          cPlastic.acnt_contract__oid IS NOT NULL AND
          cPlastic.Prod_Date IS NOT NULL THEN
    
      INSERT INTO oms.oms_card_pin_delivery
        (card_number,
         card_name,
         production_event,
         production_date,
         source_table,
         source_ref_id,
         delivery_type,
         delivery_status,
         delivery_date)
      VALUES
        (cContract.contract_number,
         cPlastic.card_name,
         cPlastic.production_event,
         cPlastic.prod_date,
         'CARD_INFO',
         cPlastic.id,
         'CARD',
         '8964',
         SYSDATE);
    ELSIF cPlastic.production_type = '0' AND
          cPlastic.acnt_contract__oid IS NOT NULL AND
          cPlastic.Prod_Date IS NOT NULL THEN
      INSERT INTO oms.oms_card_pin_delivery
        (card_number,
         card_name,
         production_event,
         production_date,
         source_table,
         source_ref_id,
         delivery_type,
         delivery_status,
         delivery_date)
      VALUES
        (cContract.contract_number,
         cPlastic.card_name,
         cPlastic.production_event,
         cPlastic.prod_date,
         'CARD_INFO',
         cPlastic.id,
         'PIN',
         '8964',
         SYSDATE);
    END IF;
  
    ows.stnd.PROCESS_MESSAGE('I', 'CUST_CARD_FROM_PROD: End.');
  EXCEPTION
    WHEN OTHERS THEN
      ows.stnd.PROCESS_MESSAGE('E', 'CUST_CARD_FROM_PROD: Error!');
      NULL;
  END;

end;
