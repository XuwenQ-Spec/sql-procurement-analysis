-- 供应商采购金额及采购集中度分析（模拟数据）
WITH supplier_spend AS (
 SELECT s.supplier_id, s.supplier_name, SUM(po.order_qty*po.unit_price) AS order_amount
 FROM suppliers s JOIN purchase_orders po ON po.supplier_id=s.supplier_id
 GROUP BY s.supplier_id, s.supplier_name
)
SELECT supplier_id, supplier_name, ROUND(order_amount,2) AS order_amount,
 ROUND(order_amount*100.0/SUM(order_amount) OVER (),2) AS spend_share_pct,
 DENSE_RANK() OVER (ORDER BY order_amount DESC) AS spend_rank
FROM supplier_spend ORDER BY order_amount DESC;
