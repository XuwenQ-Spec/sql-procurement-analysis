
-- 08 异常核查映射
-- 将采购异常与财务审计核查程序关联

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

    -- 采购订单与发票金额差异
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

    -- 采购订单与收货数量差异
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
),

audit_mapping AS (

    SELECT
        '采购订单与发票金额差异' AS exception_type,
        '核实采购交易金额及发票金额的准确性' AS audit_objective,
        '采购合同、采购订单、发票、价格变更单、收货单、付款凭证'
            AS required_documents,
        '核对合同约定价格、订单数量、发票金额及价格变更记录'
            AS audit_procedure,
        '价格调整、折扣、退货、税额口径差异或发票金额不完整'
            AS possible_causes_to_verify,
        '采购成本计量及应付账款准确性'
            AS risk_focus

    UNION ALL

    SELECT
        '采购订单与收货数量差异',
        '核实采购订单数量与实际收货数量的一致性',
        '采购合同、采购订单、送货单、收货单、入库单、退货单',
        '核对订单数量、累计收货数量及后续收货和退货记录',
        '分批交货、尚未交货、退货、订单变更或收货记录遗漏',
        '存货数量、采购截止及应付账款完整性'
)

SELECT
    e.*,
    a.audit_objective,
    a.required_documents,
    a.audit_procedure,
    a.possible_causes_to_verify,
    a.risk_focus

FROM exception_details e
LEFT JOIN audit_mapping a
    ON e.exception_type = a.exception_type

ORDER BY e.exception_type, e.po_id;
