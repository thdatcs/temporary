create or replace procedure ows.CUST_ACNT_NUMBER(Acnt           in acnt_contract %RowType,
                                                 ContractNumber out dtype. Name %Type,
                                                 ErrMsg         out dtype. ErrorMessage %Type) is
  product_code varchar2(32);
  seq_nbr      varchar2(4);
  cif          varchar2(32);
  card_type    varchar2(1);
begin
  select a.code
    into product_code
    from appl_product a
   where a.internal_code = acnt.product
     and amnd_state = 'A';

  if substr(product_code, 3, 1) = 'L' then
    if substr(product_code, 2, 1) = 'D' then
      card_type := '1';
    elsif substr(product_code, 2, 1) = 'P' then
      card_type := '2';
    elsif substr(product_code, 2, 1) = 'C' then
      card_type := '3';
    end if;
  elsif substr(product_code, 3, 1) = 'M' then
    if substr(product_code, 2, 1) = 'D' then
      card_type := '4';
    elsif substr(product_code, 2, 1) = 'P' then
      card_type := '5';
    elsif substr(product_code, 2, 1) = 'C' then
      card_type := '6';
    end if;
  elsif substr(product_code, 3, 1) = 'J' then
    if substr(product_code, 2, 1) = 'D' then
      card_type := '7';
    elsif substr(product_code, 2, 1) = 'P' then
      card_type := '8';
    elsif substr(product_code, 2, 1) = 'C' then
      card_type := '9';
    end if;
  end if;

  select trim(k.client_number)
    into cif
    from client k
   where k.id = acnt.client__id
     and amnd_state = 'A';
  /*
  select max(substr(b.contract_number,length(cif)+6,4)) into seq_nbr --12
  from acnt_contract b
  where substr(b.contract_number,2,length(cif)+4) = trim(acnt.branch)||trim(cif);--10
  */
  select max(substr(b.contract_number, length(b.contract_number) - 3))
    into seq_nbr
    from ows.acnt_contract b
   where b.client__id = acnt.client__id
     and b.branch = acnt.branch
     and b.amnd_state = 'A'
     and b.con_cat = 'A'
     and instr(b.contract_number, 'L', 1) = 0;

  if seq_nbr is null then
    seq_nbr := '0001';
  else
    if seq_nbr is not null then
      seq_nbr := lpad(to_char(to_number(seq_nbr) + 1), 4, '0');
    end if;
  end if;

  if substr(product_code, 1, 1) = 'I' then
    ContractNumber := card_type || trim(acnt.branch) || trim(cif) ||
                      seq_nbr;
  end if;
exception
  when others then
    ErrMsg := SUBSTR(SQLERRM, 1, 100);
end;
