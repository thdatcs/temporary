create or replace function ows.CUST_INSTL_EFF_DATE(
  ContractID   in dtype. RecordID    %Type,
  InvoiceCode  in dtype. Name        %Type,
  PrevEffDate  in dtype. CurrentDate %Type,
  StartDate    in dtype. CurrentDate %Type,
  InstN        in dtype. Counter     %Type,
  BillingMode  in dtype. Name        %Type,
  ShiftN       in dtype. Counter     %Type
) return dtype. CurrentDate %Type
is
EffDate dtype. CurrentDate %Type;
NextBillingDate dtype. CurrentDate %Type;
begin
/*  if (glob.LDATEACNT(ContractID) <= to_date(to_char(glob.LDATEACNT(ContractID),'YYYY-MM')||'-24'))  then
     if (InstN=1) then
        EffDate:= to_date(to_char(glob.LDATEACNT(ContractID),'YYYY-MM')||'-24');
     else
        EffDate:= sy_convert.PLUS_MONTHS(nvl(StartDate, to_date(to_char(glob.LDATEACNT(ContractID),'YYYY-MM')||'-24')), InstN-1);
     end if;
  else
     EffDate:= sy_convert.PLUS_MONTHS(nvl(StartDate, to_date(to_char(glob.LDATEACNT(ContractID),'YYYY-MM')||'-24')), InstN);
  end if;

  return EffDate;
  --return sy_convert.PLUS_MONTHS(nvl(StartDate, glob.LDATEACNT(ContractID)), InstN);*/

SELECT ic.next_billing_date
    INTO NextBillingDate
    FROM ows.acnt_contract ic
   WHERE ic.id = ContractID;

  EffDate := sy_convert.PLUS_MONTHS(NextBillingDate + 1, InstN - 1);

  return EffDate;
end;
