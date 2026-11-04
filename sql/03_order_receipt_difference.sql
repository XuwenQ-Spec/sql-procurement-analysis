-- 采购订单与实际收货数量差异
WITH received AS (SELECT po_id,SUM(received_qty) AS received_qty FROM receipts GROUP BY po_id)
SELECT po.po_id,po.supplier_id,po.part_code,po.order_qty,
 COALESCE(r.received_qty,0) AS received_qty,
 po.order_qty-COALESCE(r.received_qty,0) AS qty_difference
FROM purchase_orders po LEFT JOIN received r ON r.po_id=po.po_id
WHERE po.order_qty<>COALESCE(r.received_qty,0) ORDER BY po.po_id;
