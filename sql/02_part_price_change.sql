-- 同类零部件采购单价变化
WITH price_history AS (
 SELECT po.part_code,p.part_name,po.po_id,po.order_date,s.supplier_name,po.unit_price,
 LAG(po.unit_price) OVER (PARTITION BY po.part_code ORDER BY po.order_date) AS previous_unit_price
 FROM purchase_orders po JOIN parts p ON p.part_code=po.part_code
 JOIN suppliers s ON s.supplier_id=po.supplier_id
)
SELECT part_code,part_name,po_id,order_date,supplier_name,ROUND(unit_price,2) AS unit_price,
 ROUND(previous_unit_price,2) AS previous_unit_price,
 CASE WHEN previous_unit_price IS NULL THEN NULL
 ELSE ROUND((unit_price-previous_unit_price)*100.0/previous_unit_price,2) END AS price_change_pct
FROM price_history ORDER BY part_code,order_date;
