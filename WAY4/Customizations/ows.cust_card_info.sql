CREATE OR REPLACE PROCEDURE OWS."CUST_CARD_INFO" (CardInfoID in dtype. RecordID %Type) is
  p_latest_contract_number VARCHAR2(64);
  p_latest_contract_id     NUMBER;
  p_card_name              VARCHAR2(32);
  p_production_event       VARCHAR2(32);
  p_production_type        VARCHAR2(1);
  p_event                  VARCHAR2(1);
  p_prev_card              NUMBER;
  p_acnt_contract__oid     NUMBER;
  p_check_source_ref_id    NUMBER;
begin

  BEGIN
    ows.stnd.PROCESS_MESSAGE('I', 'CUST_CARD_INFO: Begin');
    SELECT MAX(cc.contract_number), MAX(cc.id)
      INTO p_latest_contract_number, p_latest_contract_id
      FROM ows.card_info ci
      JOIN ows.acnt_contract cc
        ON ci.acnt_contract__oid = cc.id
       AND cc.base_relation IS NULL
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
                                 p_prev_card || ' acnt_contract__oid=' ||
                                 p_acnt_contract__oid);
        ows.contract_parm.SET_CONTRACT_PARM(p_acnt_contract__oid,
                                            'LATEST_CONTRACT_NUMBER',
                                            p_latest_contract_number);
      END LOOP;
    
      SELECT ci.card_name,
             ci.production_event,
             ci.production_type,
             ci.event,
             NVL(ci.prev_card, 0)
        INTO p_card_name,
             p_production_event,
             p_production_type,
             p_event,
             p_prev_card
        FROM ows.card_info ci
       WHERE ci.id = CardInfoID;
    
      IF p_event = 'R' AND p_production_type IN ('3', '9') THEN
        ows.contract_parm.SET_CONTRACT_PARM(p_latest_contract_id,
                                            'LAST_PRODUCTION_DATE',
                                            TO_CHAR(SYSDATE, 'yyyymmdd'));
      
        ows.contract_parm.SET_CONTRACT_PARM(p_latest_contract_id,
                                            'LAST_PRODUCTION_TYPE',
                                            'RENEW');
      ELSIF p_event = 'O' AND p_production_type IN ('3', '9') THEN
        IF p_prev_card <> 0 THEN
          ows.contract_parm.SET_CONTRACT_PARM(p_latest_contract_id,
                                              'LAST_PRODUCTION_DATE',
                                              TO_CHAR(SYSDATE, 'yyyymmdd'));
        
          ows.contract_parm.SET_CONTRACT_PARM(p_latest_contract_id,
                                              'LAST_PRODUCTION_TYPE',
                                              'REPLACE');
        END IF;
      END IF;
    
--      SELECT COUNT(*)
--        INTO p_check_source_ref_id
--        FROM oms.oms_card_pin_delivery
--       WHERE source_ref_id = CardInfoID;
--    
--      IF p_check_source_ref_id > 0 THEN
--        DELETE oms.oms_card_pin_delivery WHERE source_ref_id = CardInfoID;
--      END IF;
--    
--      IF p_production_type = '3' THEN
--      
--        INSERT INTO oms.oms_card_pin_delivery
--          (card_number,
--           card_name,
--           production_event,
--           production_date,
--           source_table,
--           source_ref_id,
--           delivery_type,
--           delivery_status,
--           delivery_date)
--        VALUES
--          (p_latest_contract_number,
--           p_card_name,
--           p_production_event,
--           SYSDATE,
--           'CARD_INFO',
--           CardInfoID,
--           'CARD',
--           '8964',
--           SYSDATE);
--      
--        INSERT INTO oms.oms_card_pin_delivery
--          (card_number,
--           card_name,
--           production_event,
--           production_date,
--           source_table,
--           source_ref_id,
--           delivery_type,
--           delivery_status,
--           delivery_date)
--        VALUES
--          (p_latest_contract_number,
--           p_card_name,
--           p_production_event,
--           SYSDATE,
--           'CARD_INFO',
--           CardInfoID,
--           'PIN',
--           '8964',
--           SYSDATE);
--      ELSIF p_production_type = '9' THEN
--      
--        INSERT INTO oms.oms_card_pin_delivery
--          (card_number,
--           card_name,
--           production_event,
--           production_date,
--           source_table,
--           source_ref_id,
--           delivery_type,
--           delivery_status,
--           delivery_date)
--        VALUES
--          (p_latest_contract_number,
--           p_card_name,
--           p_production_event,
--           SYSDATE,
--           'CARD_INFO',
--           CardInfoID,
--           'CARD',
--           '8964',
--           SYSDATE);
--      ELSIF p_production_type = '0' THEN
--        INSERT INTO oms.oms_card_pin_delivery
--          (card_number,
--           card_name,
--           production_event,
--           production_date,
--           source_table,
--           source_ref_id,
--           delivery_type,
--           delivery_status,
--           delivery_date)
--        VALUES
--          (p_latest_contract_number,
--           p_card_name,
--           p_production_event,
--           SYSDATE,
--           'CARD_INFO',
--           CardInfoID,
--           'PIN',
--           '8964',
--           SYSDATE);
--      END IF;
    
    END IF;
    ows.stnd.PROCESS_MESSAGE('I', 'CUST_CARD_INFO: End.');
  EXCEPTION
    WHEN OTHERS THEN
      ows.stnd.PROCESS_MESSAGE('E', 'CUST_CARD_INFO: Error!');
      NULL;
  END;

  return;
end;
