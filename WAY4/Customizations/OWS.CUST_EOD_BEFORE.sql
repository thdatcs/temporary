create or replace procedure ows.CUST_EOD_BEFORE(
/**
Actions performed before standard CDU

@param Acnt Contract record which CDU is starting for
@param Regime Mode which CDU was run in ('S' - start of day - morning, 'E' - end of day, evening)
@param DueDate The date being opened
@param BankDate Current bank date. On Evening CDU it's the date being closed, on Morning CDU it's the date being opened
*/
  Acnt      in acnt_contract   %rowtype,
  Regime    in dtype. Tag         %Type,
  DueDate   in dtype. CurrentDate %Type,
  BankDate  in dtype. CurrentDate %Type
) is

p_ovl_amount number;
p_result VARCHAR2(2000);
begin
  begin
    IF Acnt.Pcat = 'C' AND Acnt.Con_Cat = 'C' AND Acnt.Ccat = 'P' AND Acnt.Base_Relation IS NULL THEN
      BEGIN
        IF Acnt.Card_Expire || TO_CHAR(Acnt.Date_Open, 'DD') <= TO_CHAR(BankDate, 'YYMMDD') AND Acnt.Contr_Status<>175 THEN
          p_result := ows.api.put_event(ows.api.get_event_type('CARD_EXPIRED', Acnt.Id, 'N'), Acnt.Id, NULL, ows.glob.ldate(), 'Card Expired');
          ows.stnd.process_message ('I', Acnt.Id || ' - CARD_EXPIRED - Event ID: ' || p_result);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          ows.stnd.process_message ('E', Acnt.Contract_Number || ' - CARD_EXPIRED');
      END;
    END IF;
    
    IF Acnt.Pcat = 'C' AND Acnt.Con_Cat = 'A' AND Acnt.Ccat = 'P' AND Acnt.Liab_Category = 'Y' THEN
      BEGIN
        SELECT NVL(MAX(available), 0) INTO p_ovl_amount
        FROM ows.acnt_balance
        WHERE acnt_contract__oid=Acnt.Id 
          AND balance_type_code IN ('OVL');
        
        IF p_ovl_amount<>0 THEN
          p_result := ows.api.put_event(ows.api.get_event_type('OVL_DAILY', Acnt.Id, 'N'), Acnt.Id, NULL, ows.glob.ldate(), 'OVL Daily');
          ows.stnd.process_message ('I', Acnt.Id || '- OVL_DAILY - Event ID: ' || p_result);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          ows.stnd.process_message ('E', Acnt.Contract_Number || ' - OVL_DAILY');
      END;
    END IF;
  exception
    when others then
      null;
  end;
  return;
end CUST_EOD_BEFORE;
