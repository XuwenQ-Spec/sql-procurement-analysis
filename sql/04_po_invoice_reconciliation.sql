-- 采购订单金额与发票金额勾稽
WITH invoice_total AS (SELECT po_id,SUM(invoice_amount) AS invoice_amount FROM invoices GROUP BY po_id)
SELECT po.po_id,po.supplier_id,ROUND(po.order_qty*po.unit_price,2) AS order_amount,
 ROUND(COALESCE(i.invoice_amount,0),2) AS invoice_amount,
 ROUND(po.order_qty*po.unit_price-COALESCE(i.invoice_amount,0),2) AS difference
FROM purchase_orders po LEFT JOIN invoice_total i ON i.po_id=po.po_id
WHERE ABS(po.order_qty*po.unit_price-COALESCE(i.invoice_amount,0))>0.01 ORDER BY po.po_id;
