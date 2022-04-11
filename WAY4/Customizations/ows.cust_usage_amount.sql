create or replace function ows.CUST_USAGE_AMOUNT(BaseAmount dtypt. Money %Type,
                                                 BaseCurr   dtypt. CurrencyCode %Type,
                                                 CContract  acnt_contract %RowType,
                                                 UsageTmpl  usage_templ_appr %RowType,
                                                 CDoc       doc %RowType)

  return dtypt. Money %Type IS
  /* Returned Amount must be in UsageTmpl.curr */
begin
  if UsageTmpl.USAGE_CODE = '403_AMOUNT_FITTING_INCREASE' and
     UsageTmpl.PREDEF_CONDITION = 'AMOUNT_FITTING' then
    return BaseAmount * -1;
  end if;
  return null;
end;
