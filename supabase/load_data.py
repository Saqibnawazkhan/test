"""
Mirror the reference dataset from local SQLite (taxnet.db) into Supabase Postgres.
Loads via fast COPY. Skips graph_edges (regenerable) + app tables (already in Supabase).
Run:  python supabase/load_data.py
"""
import os, sqlite3, sys, time
import psycopg

HERE = os.path.dirname(__file__)
SQLITE = os.path.join(HERE, "..", "backend", "taxnet.db")
PG = dict(host="aws-1-ap-southeast-2.pooler.supabase.com", port=5432,
          user="postgres.zfzluirxexbefunbuyxf", password="Shah@330333",
          dbname="postgres", sslmode="require", connect_timeout=30)

SKIP = {"graph_edges", "correction_requests", "sqlite_sequence"}

def pgtype(t):
    t = (t or "").upper()
    if "INT" in t:
        return "bigint"
    if "REAL" in t or "FLOA" in t or "DOUB" in t or "NUM" in t:
        return "double precision"
    return "text"

def main():
    sq = sqlite3.connect(SQLITE)
    sq.row_factory = sqlite3.Row
    pg = psycopg.connect(**PG, autocommit=True)
    tables = [r[0] for r in sq.execute("select name from sqlite_master where type='table'") if r[0] not in SKIP]
    print("Tables to mirror:", tables)
    total = 0
    for t in tables:
        info = sq.execute(f"PRAGMA table_info({t})").fetchall()
        cols = [c["name"] for c in info]
        defs = ", ".join(f'"{c["name"]}" {pgtype(c["type"])}' for c in info)
        pg.execute(f'drop table if exists "{t}" cascade')
        pg.execute(f'create table "{t}" ({defs})')
        n = sq.execute(f"select count(*) from {t}").fetchone()[0]
        t0 = time.time()
        collist = ",".join(f'"{c}"' for c in cols)
        with pg.cursor().copy(f'COPY "{t}" ({collist}) FROM STDIN') as cp:
            for row in sq.execute(f"select {collist} from {t}"):
                cp.write_row(tuple(row))
        total += n
        print(f"  {t:18s} {n:>8,} rows  ({time.time()-t0:.0f}s)")
    # indexes the API filters on
    print("Indexing…")
    for stmt in [
        'create index if not exists ix_veh on vehicles(owner_cnic)',
        'create index if not exists ix_prop on properties(owner_cnic)',
        'create index if not exists ix_elec on electricity(customer_cnic)',
        'create index if not exists ix_gas on gas(customer_cnic)',
        'create index if not exists ix_stk on stocks(holder_cnic)',
        'create index if not exists ix_trv on travel(cnic)',
        'create index if not exists ix_bank on bank_accounts(customer_cnic)',
        'create index if not exists ix_dir on directorships(person_cnic)',
        'create index if not exists ix_zone on deviation_scores(zone)',
        'create index if not exists ix_score on deviation_scores(deviation_score desc)',
        'create index if not exists ix_pdist on persons(district)',
        'create unique index if not exists ux_persons on persons(cnic)',
        'create unique index if not exists ux_scores on deviation_scores(cnic)',
    ]:
        try:
            pg.execute(stmt)
        except Exception as e:
            print("  idx skip:", str(e)[:60])
    size = pg.execute("select pg_size_pretty(pg_database_size(current_database()))").fetchone()[0]
    print(f"\nDONE — {total:,} rows mirrored. DB size: {size}")
    sq.close(); pg.close()

if __name__ == "__main__":
    main()
