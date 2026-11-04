
-- 06 Data Quality Checks
-- Procurement Data Quality Review

WITH quality_checks AS (

    -- 1. 采购订单缺失供应商
    SELECT
        '采购订单缺失供应商' AS check_name,
        COUNT(*) AS issue_count
    FROM purchase_orders po
    LEFT JOIN suppliers s
        ON po.supplier_id = s.supplier_id
    WHERE s.supplier_id IS NULL

    UNION ALL

    -- 2. 采购订单缺失零部件
    SELECT
        '采购订单缺失零部件',
        COUNT(*)
    FROM purchase_orders po
    LEFT JOIN parts p
        ON po.part_code = p.part_code
    WHERE p.part_code IS NULL

    UNION ALL

    -- 3. 收货记录找不到采购订单
    SELECT
        '收货记录缺失采购订单',
        COUNT(*)
    FROM receipts r
    LEFT JOIN purchase_orders po
        ON r.po_id = po.po_id
    WHERE po.po_id IS NULL

    UNION ALL

    -- 4. 发票找不到采购订单
    SELECT
        '发票缺失采购订单',
        COUNT(*)
    FROM invoices i
    LEFT JOIN purchase_orders po
        ON i.po_id = po.po_id
    WHERE po.po_id IS NULL

    UNION ALL

    -- 5. 付款记录找不到发票
    SELECT
        '付款记录缺失发票',
        COUNT(*)
    FROM payments p
    LEFT JOIN invoices i
        ON p.invoice_id = i.invoice_id
    WHERE i.invoice_id IS NULL

    UNION ALL

    -- 6. 采购数量或单价异常
    SELECT
        '采购数量或单价异常',
        COUNT(*)
    FROM purchase_orders
    WHERE order_qty <= 0 OR unit_price < 0

    UNION ALL

    -- 7. 累计收货数量超过订单数量
    SELECT
        '累计收货数量超过订单数量',
        COUNT(*)
    FROM (
        SELECT po.po_id
        FROM purchase_orders po
        JOIN receipts r
            ON po.po_id = r.po_id
        GROUP BY po.po_id, po.order_qty
        HAVING SUM(r.received_qty) > po.order_qty
    )

    UNION ALL

    -- 8. 发票或付款金额为负数
    SELECT
        '发票或付款金额为负数',
        (SELECT COUNT(*) FROM invoices
         WHERE invoice_amount < 0)
        +
        (SELECT COUNT(*) FROM payments
         WHERE payment_amount < 0)

    UNION ALL

    -- 9. 收货日期早于采购订单日期
    SELECT
        '收货日期早于订单日期',
        COUNT(*)
    FROM receipts r
    JOIN purchase_orders po
        ON r.po_id = po.po_id
    WHERE r.receipt_date < po.order_date

    UNION ALL

    -- 10. 发票日期早于采购订单日期
    SELECT
        '发票日期早于订单日期',
        COUNT(*)
    FROM invoices i
    JOIN purchase_orders po
        ON i.po_id = po.po_id
    WHERE i.invoice_date < po.order_date

    UNION ALL

    -- 11. 付款日期早于发票日期
    SELECT
        '付款日期早于发票日期',
        COUNT(*)
    FROM payments p
    JOIN invoices i
        ON p.invoice_id = i.invoice_id
    WHERE p.payment_date < i.invoice_date

UNION ALL

-- 12. 采购订单与累计收货数量存在差异
SELECT
    '采购订单与累计收货数量存在差异',
    COUNT(*)
FROM (
    SELECT po.po_id
    FROM purchase_orders po
    LEFT JOIN receipts r
        ON po.po_id = r.po_id
    GROUP BY po.po_id, po.order_qty
    HAVING COALESCE(SUM(r.received_qty), 0) <> po.order_qty
)

UNION ALL

-- 13. 采购订单与发票累计金额存在差异
SELECT
    '采购订单与发票累计金额存在差异',
    COUNT(*)
FROM (
    SELECT po.po_id
    FROM purchase_orders po
    LEFT JOIN (
        SELECT po_id, SUM(invoice_amount) AS total_invoice_amount
        FROM invoices
        GROUP BY po_id
    ) inv
        ON po.po_id = inv.po_id
    WHERE ABS(
    po.order_qty * po.unit_price
    - COALESCE(inv.total_invoice_amount, 0)
) > 0.01
)

)

SELECT
    check_name,
    issue_count,
    CASE
        WHEN issue_count = 0 THEN '通过'
        ELSE '需复核'
    END AS check_result
FROM quality_checks
ORDER BY check_name;
