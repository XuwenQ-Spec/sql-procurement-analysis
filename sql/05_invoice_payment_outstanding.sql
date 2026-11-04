-- 发票与付款勾稽及未结清应付款提示
WITH payment_total AS (SELECT invoice_id,SUM(payment_amount) AS paid_amount FROM payments GROUP BY invoice_id)
SELECT i.invoice_id,i.po_id,ROUND(i.invoice_amount,2) AS invoice_amount,
 ROUND(COALESCE(p.paid_amount,0),2) AS paid_amount,
 ROUND(i.invoice_amount-COALESCE(p.paid_amount,0),2) AS outstanding_amount
FROM invoices i LEFT JOIN payment_total p ON p.invoice_id=i.invoice_id
WHERE i.invoice_amount-COALESCE(p.paid_amount,0)>0.01 ORDER BY i.invoice_id;
