-- 采购异常明细提取
-- 同时识别采购订单与发票金额差异、采购订单与收货数量差异

WITH invoice_summary AS (
    SELECT
        po_id,
        SUM(invoice_amount) AS total_invoice_amount
    FROM invoices
    GROUP BY po_id
),

receipt_summary AS (
    SELECT
        po_id,
        SUM(received_qty) AS total_received_qty
    FROM receipts
    GROUP BY po_id
),

exception_details AS (

    -- 1. 采购订单与发票金额差异
    SELECT
        '采购订单与发票金额差异' AS exception_type,
        po.po_id,
        s.supplier_id,
        s.supplier_name,
        po.part_code,
        pt.part_name,
        po.order_qty,
        COALESCE(r.total_received_qty, 0) AS received_qty,
        po.order_qty - COALESCE(r.total_received_qty, 0)
            AS qty_difference,
        ROUND(po.order_qty * po.unit_price, 2)
            AS order_amount,
        ROUND(COALESCE(i.total_invoice_amount, 0), 2)
            AS invoice_amount,
        ROUND(
            po.order_qty * po.unit_price
            - COALESCE(i.total_invoice_amount, 0), 2
        ) AS amount_difference

    FROM purchase_orders po
    LEFT JOIN suppliers s
        ON po.supplier_id = s.supplier_id
    LEFT JOIN parts pt
        ON po.part_code = pt.part_code
    LEFT JOIN invoice_summary i
        ON po.po_id = i.po_id
    LEFT JOIN receipt_summary r
        ON po.po_id = r.po_id

    WHERE ABS(
        po.order_qty * po.unit_price
        - COALESCE(i.total_invoice_amount, 0)
    ) > 0.01

    UNION ALL

    -- 2. 采购订单与收货数量差异
    SELECT
        '采购订单与收货数量差异',
        po.po_id,
        s.supplier_id,
        s.supplier_name,
        po.part_code,
        pt.part_name,
        po.order_qty,
        COALESCE(r.total_received_qty, 0),
        po.order_qty - COALESCE(r.total_received_qty, 0),
        NULL,
        NULL,
        NULL

    FROM purchase_orders po
    LEFT JOIN suppliers s
        ON po.supplier_id = s.supplier_id
    LEFT JOIN parts pt
        ON po.part_code = pt.part_code
    LEFT JOIN receipt_summary r
        ON po.po_id = r.po_id

    WHERE COALESCE(r.total_received_qty, 0) <> po.order_qty
)

SELECT *
FROM exception_details
ORDER BY exception_type, po_id;