"""
run_queries.py — executes every .sql file in sql/ against the generated
database and prints results. Also used as a smoke test: if a query errors
or returns zero rows, something is broken.
"""
from __future__ import annotations
import sqlite3
from pathlib import Path
import pandas as pd

DB_PATH = Path(__file__).parent.parent / "data" / "analytics.db"
SQL_DIR = Path(__file__).parent.parent / "sql"


def run_all() -> dict[str, pd.DataFrame]:
    if not DB_PATH.exists():
        raise FileNotFoundError("Run generate_data.py first to build the database.")

    conn = sqlite3.connect(DB_PATH)
    results = {}

    for sql_file in sorted(SQL_DIR.glob("*.sql")):
        raw_text = sql_file.read_text()
        # strip full-line comments first, then split into statements —
        # the previous approach checked if a whole multi-line statement
        # *started* with "--", which incorrectly dropped every statement
        # since each one opens with a comment header.
        code_lines = [
            line for line in raw_text.splitlines()
            if not line.strip().startswith("--")
        ]
        text = "\n".join(code_lines)
        statements = [s.strip() for s in text.split(";") if s.strip()]
        for i, stmt in enumerate(statements):
            try:
                df = pd.read_sql_query(stmt, conn)
                key = sql_file.stem if len(statements) == 1 else f"{sql_file.stem}_part{i+1}"
                results[key] = df
            except Exception as e:
                print(f"ERROR in {sql_file.name} (statement {i+1}): {e}")

    conn.close()
    return results


if __name__ == "__main__":
    results = run_all()
    for name, df in results.items():
        print(f"\n{'='*60}\n{name}  ({len(df)} rows)\n{'='*60}")
        print(df.head(10).to_string(index=False))
