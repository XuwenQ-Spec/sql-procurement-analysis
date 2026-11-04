from pathlib import Path
import sqlite3, csv
ROOT=Path(__file__).resolve().parent
OUT=ROOT/'outputs'
OUT.mkdir(exist_ok=True)
con=sqlite3.connect(ROOT/'procurement_analysis.db')
try:
    for sql_file in sorted((ROOT/'sql').glob('*.sql')):
        cur=con.execute(sql_file.read_text(encoding='utf-8'))
        rows=cur.fetchall()
        with (OUT/(sql_file.stem+'.csv')).open('w',newline='',encoding='utf-8-sig') as f:
            w=csv.writer(f); w.writerow([c[0] for c in cur.description]); w.writerows(rows)
        print(f'{sql_file.name}: {len(rows)} rows')
finally:
    con.close()
