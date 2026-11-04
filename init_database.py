
import csv
import sqlite3
import shutil
import os
from pathlib import Path
from datetime import datetime

# 项目根目录
ROOT = Path(__file__).resolve().parent
DATA_DIR = ROOT / "data"

# 数据库文件
DB_PATH = ROOT / "procurement_analysis.db"
TEMP_DB = ROOT / "procurement_analysis_build.tmp.db"

# 六张数据表的结构
TABLES = [
    {
        "name": "suppliers",
        "file": "suppliers.csv",
        "expected_rows": 5,
        "columns": [
            ("supplier_id", "TEXT"),
            ("supplier_name", "TEXT"),
            ("category", "TEXT"),
            ("region", "TEXT"),
            ("status", "TEXT"),
        ],
        "primary_key": "supplier_id",
    },
    {
        "name": "parts",
        "file": "parts.csv",
        "expected_rows": 4,
        "columns": [
            ("part_code", "TEXT"),
            ("part_name", "TEXT"),
        ],
        "primary_key": "part_code",
    },
    {
        "name": "purchase_orders",
        "file": "purchase_orders.csv",
        "expected_rows": 10,
        "columns": [
            ("po_id", "TEXT"),
            ("supplier_id", "TEXT"),
            ("part_code", "TEXT"),
            ("order_date", "TEXT"),
            ("order_qty", "INTEGER"),
            ("unit_price", "REAL"),
            ("status", "TEXT"),
        ],
        "primary_key": "po_id",
    },
    {
        "name": "receipts",
        "file": "receipts.csv",
        "expected_rows": 10,
        "columns": [
            ("receipt_id", "TEXT"),
            ("po_id", "TEXT"),
            ("receipt_date", "TEXT"),
            ("received_qty", "INTEGER"),
        ],
        "primary_key": "receipt_id",
    },
    {
        "name": "invoices",
        "file": "invoices.csv",
        "expected_rows": 10,
        "columns": [
            ("invoice_id", "TEXT"),
            ("po_id", "TEXT"),
            ("invoice_date", "TEXT"),
            ("invoice_amount", "REAL"),
        ],
        "primary_key": "invoice_id",
    },
    {
        "name": "payments",
        "file": "payments.csv",
        "expected_rows": 10,
        "columns": [
            ("payment_id", "TEXT"),
            ("invoice_id", "TEXT"),
            ("payment_date", "TEXT"),
            ("payment_amount", "REAL"),
        ],
        "primary_key": "payment_id",
    },
]


def convert_value(value, data_type):
    """根据字段类型转换 CSV 数据。"""
    if value is None or value.strip() == "":
        return None

    value = value.strip()

    if data_type == "INTEGER":
        return int(value)

    if data_type == "REAL":
        return float(value)

    return value


def main():
    if not DATA_DIR.exists():
        raise FileNotFoundError("找不到 data 文件夹。")

    if TEMP_DB.exists():
        TEMP_DB.unlink()

    try:
        conn = sqlite3.connect(TEMP_DB)

        try:
            for table in TABLES:
                csv_path = DATA_DIR / table["file"]
                columns = table["columns"]

                if not csv_path.exists():
                    raise FileNotFoundError(
                        f"找不到文件：{csv_path}"
                    )

                # 创建数据表
                definitions = []

                for name, data_type in columns:
                    definition = f'"{name}" {data_type}'

                    if name == table["primary_key"]:
                        definition += " PRIMARY KEY"

                    definitions.append(definition)

                create_sql = (
                    f'CREATE TABLE "{table["name"]}" '
                    f'({", ".join(definitions)})'
                )

                conn.execute(create_sql)

                # 读取 CSV
                with csv_path.open(
                    "r",
                    newline="",
                    encoding="utf-8-sig"
                ) as f:

                    reader = csv.DictReader(f)
                    expected_headers = [
                        col[0] for col in columns
                    ]

                    if reader.fieldnames != expected_headers:
                        raise ValueError(
                            f"{table['file']} 字段名称不匹配："
                            f"{reader.fieldnames}"
                        )

                    rows = []

                    for line_no, row in enumerate(reader, start=2):
                        try:
                            values = tuple(
                                convert_value(row[name], data_type)
                                for name, data_type in columns
                            )
                        except (ValueError, AttributeError) as e:
                            raise ValueError(
                                f"{table['file']} 第 {line_no} 行数据错误：{e}"
                            )

                        rows.append(values)

                # 导入 SQLite
                column_names = ", ".join(
                    f'"{col[0]}"' for col in columns
                )

                placeholders = ", ".join(
                    "?" for _ in columns
                )

                insert_sql = (
                    f'INSERT INTO "{table["name"]}" '
                    f'({column_names}) VALUES ({placeholders})'
                )

                conn.executemany(insert_sql, rows)

                # 检查记录数量
                actual_rows = conn.execute(
                    f'SELECT COUNT(*) FROM "{table["name"]}"'
                ).fetchone()[0]

                if actual_rows != table["expected_rows"]:
                    raise ValueError(
                        f"{table['name']} 记录数不符："
                        f"预期 {table['expected_rows']}，"
                        f"实际 {actual_rows}"
                    )

                print(
                    f"[OK] {table['name']}: "
                    f"{actual_rows} rows imported"
                )

            conn.commit()

        finally:
            conn.close()

        # 新数据库构建成功后，才备份并替换原数据库
        if DB_PATH.exists():
            backup_path = ROOT / "procurement_analysis_original_backup.db"

            if backup_path.exists():
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                backup_path = ROOT / (
                    f"procurement_analysis_backup_{timestamp}.db"
                )

            shutil.copy2(DB_PATH, backup_path)
            print(f"[BACKUP] Original database saved: {backup_path.name}")

        os.replace(TEMP_DB, DB_PATH)

        print("\nSUCCESS: SQLite database rebuilt successfully!")
        print(f"Database: {DB_PATH.name}")

    except Exception:
        if TEMP_DB.exists():
            TEMP_DB.unlink()
        raise


if __name__ == "__main__":
    main()
