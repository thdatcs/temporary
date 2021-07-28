create or replace procedure ows.CUST_PUT_ENTRY(
  Acnt    in acnt_contract    %RowType,
  Templ   in templ_approved   %RowType,
  Serv    in service_approved %RowType,
  CurrMtr in m_transaction    %RowType,
  Amount  in dtypt. Money        %Type
) is
p_issuing_number varchar2(64);
p_card_number varchar2(64);
p_product_category varchar2(1);
p_contract_category varchar2(1);
p_contract_number varchar2(64);
p_transaction_date date;
p_amount number(28, 10);
p_currency varchar2(3);
p_source_ref_id number;
p_check_instalment_fee_creation number;
p_instalment_tenor number;
begin
  --- OCB Customization ---
  BEGIN
    --- Statistic for Credit Payment/Prepaid Topup ---
    
    IF Templ.Account_Type = 6 AND Serv.Service_Class = 'T' THEN
      SELECT MAX(SUBSTR(ap.code, 2, 1)) INTO p_product_category
      FROM ows.appl_product ap
      WHERE ap.internal_code=Acnt.product AND ap.amnd_state='A';
      
      IF p_product_category NOT IN ('C', 'P') THEN
        RETURN;
      END IF;
      
      IF Acnt.CCat = 'P' AND Acnt.Con_Cat = 'C' THEN
        p_card_number:=Acnt.Contract_Number;
        
        SELECT MAX(issuing.contract_number) INTO p_issuing_number
        FROM ows.acnt_contract issuing
        WHERE issuing.id=Acnt.Acnt_Contract__Oid AND issuing.amnd_state='A';
      ELSIF Acnt.CCat = 'P' AND Acnt.Con_Cat = 'A' THEN
        p_issuing_number:=Acnt.Contract_Number;
      ELSE
        RETURN;
      END IF;
      
      SELECT d.trans_date, d.trans_amount, d.trans_curr INTO p_transaction_date, p_amount, p_currency
      FROM ows.doc d
      WHERE d.id=CurrMtr.Doc__Oid;
      
      INSERT INTO oms.oms_payment (transaction_date, issuing_number, card_number, amount, currency, source_table, source_ref_id, posting_date, settlement_amount)
        VALUES (p_transaction_date, p_issuing_number, p_card_number, p_amount, p_currency, 'DOC', CurrMtr.Doc__Oid, CurrMtr.Posting_Date, CurrMtr.Local_Amount);
      
      RETURN;
    END IF;
    
    --- END ---
    
    IF Serv.Fee_Direction <> 0 THEN
      --- Statistic for Fee ---
      IF Acnt.Contract_Number IN ('CLIENT_FEE_DR', 'CLIENT_FEE_CR') THEN
        SELECT tt.t_cat, d.target_number, d.trans_date, d.trans_amount, d.trans_curr INTO p_contract_category, p_contract_number, p_transaction_date, p_amount, p_currency
        FROM ows.doc d
             JOIN ows.trans_type tt ON d.trans_type=tt.id AND tt.amnd_state='A'
        WHERE d.id=CurrMtr.Doc__Oid;
        
        IF p_contract_category = 'C' THEN
          SELECT card.contract_number, issuing.contract_number INTO p_card_number, p_issuing_number
          FROM ows.acnt_contract issuing
               JOIN ows.acnt_contract card ON card.acnt_contract__oid=issuing.id
          WHERE card.contract_number=p_contract_number AND card.base_relation IS NULL AND issuing.amnd_state='A' AND card.amnd_state='A';
        ELSIF p_contract_category = 'A' THEN
          p_issuing_number:=p_contract_number;
        ELSE
          RETURN;
        END IF;
      
      INSERT INTO oms.oms_card_fee (transaction_date, service, issuing_number, card_number, amount, currency, settlement_amount, fee_direction, fee_amount, fee_currency, source_table, source_ref_id, posting_date)
        VALUES (p_transaction_date, Serv.Id, p_issuing_number, p_card_number, p_amount, p_currency, CurrMtr.Local_Amount, Serv.Fee_Direction, Amount, Serv.Fee_Curr, 'DOC', CurrMtr.Doc__Oid, CurrMtr.Posting_Date);
      END IF;
    
          --- Create custom event on Account level ---
    IF Acnt.contract_number NOT IN ('CLIENT_FEE_CR', 'CLIENT_FEE_DR') THEN
        SELECT COUNT(*)
          INTO p_check_instalment_fee_creation
          FROM ows.trans_subtype tst
          JOIN ows.trans_type tt
            ON tst.trans_type__oid = tt.id
         WHERE tst.id = CurrMtr.trans_subtype
           AND tt.amnd_state = 'A'
           AND tst.amnd_state = 'A'
           AND tt.trans_code = 'IFFC';
        IF p_check_instalment_fee_creation > 0 THEN
        
          SELECT ows.glob.GET_TAG_VALUE(d.add_info, 'INST_TENOR')
            INTO p_instalment_tenor
            FROM ows.doc d
           WHERE d.id = CurrMtr.doc__oid;
        
          IF CurrMtr.request_cat = 'P' THEN
            p_result := ows.api.PUT_EVENT(ows.api.get_event_type('INST_CREATION_FEE',
                                                                 Acnt.id,
                                                                 'N'),
                                          Acnt.id,
                                          CurrMtr.doc__oid,
                                          ows.glob.ldate(),
                                          'FEE=' || CurrMtr.t_fee_amount ||
                                          ';TENOR=' || p_instalment_tenor);
          ELSIF CurrMtr.request_cat = 'R' THEN
            p_result := ows.api.PUT_EVENT(ows.api.get_event_type('INST_CREATION_FEE_REV',
                                                                 Acnt.id,
                                                                 'N'),
                                          Acnt.id,
                                          CurrMtr.doc__oid,
                                          ows.glob.ldate(),
                                          'FEE=' || CurrMtr.t_fee_amount ||
                                          ';TENOR=' || p_instalment_tenor);
          END IF;
        END IF;
      END IF;
    END IF;
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;
end CUST_PUT_ENTRY;
