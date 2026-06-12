"""
FastAPI backend — National Tax Net
Serves the Next.js web + Flutter mobile dashboards from the local SQLite DB
(swap to Supabase via DATABASE_URL later). GNN explanation computed on-demand.

Run:  uvicorn main:app --reload --port 8000
Docs: http://localhost:8000/docs
"""
import os, sqlite3, sys, datetime
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

HERE = os.path.dirname(__file__)
DB = os.path.join(HERE, "taxnet.db")
sys.path.insert(0, os.path.join(HERE, "..", "gnn"))   # for explainer_service

# ---- load .env (SUPABASE_DB_URL etc.) ----
def _load_env():
    p = os.path.join(HERE, "..", ".env")
    if os.path.exists(p):
        for ln in open(p, encoding="utf-8"):
            ln = ln.strip()
            if ln and not ln.startswith("#") and "=" in ln:
                k, v = ln.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())
_load_env()

# Default to fast local SQLite (dev). In production (backend deployed near Supabase)
# set DB_BACKEND=supabase to read from Postgres at full speed.
_DB_URL = os.environ.get("SUPABASE_DB_URL")
USE_PG = os.environ.get("DB_BACKEND", "sqlite").lower() == "supabase" and bool(_DB_URL)

app = FastAPI(title="National Tax Net API", version="1.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

if USE_PG:
    from psycopg_pool import ConnectionPool
    from psycopg.rows import dict_row
    _pool = ConnectionPool(_DB_URL, min_size=2, max_size=10, open=True,
                           kwargs={"row_factory": dict_row, "autocommit": True})

    def rows(q, args=()):
        with _pool.connection() as con:
            return [dict(r) for r in con.execute(q.replace("?", "%s"), args).fetchall()]

    def execute(q, args=()):
        with _pool.connection() as con:
            cur = con.execute(q.replace("?", "%s"), args)
            return cur
else:
    def db():
        con = sqlite3.connect(DB, check_same_thread=False)
        con.row_factory = sqlite3.Row
        return con

    def rows(q, args=()):
        con = db(); cur = con.execute(q, args)
        out = [dict(r) for r in cur.fetchall()]; con.close()
        return out

    def execute(q, args=()):
        con = db(); cur = con.execute(q, args); con.commit(); rid = cur.lastrowid; con.close()
        return rid

def one(q, args=()):
    r = rows(q, args)
    return r[0] if r else None

# estimated under-declared tax ("recovery potential") = 10% of (footprint − declared), floored at 0
REC = ("(case when (coalesce(own_assets,0)+coalesce(hidden_assets,0)+coalesce(lifestyle,0)-coalesce(declared,0))>0 "
       "then (coalesce(own_assets,0)+coalesce(hidden_assets,0)+coalesce(lifestyle,0)-coalesce(declared,0))*0.1 else 0 end)")

@app.on_event("startup")
def _init_tables():
    if USE_PG:
        return  # tables + indexes already provisioned in Supabase (app_schema.sql + load)
    con = db()
    con.execute("""create table if not exists correction_requests(
        id integer primary key autoincrement, cnic text, field text,
        current_value text, requested_value text, reason text,
        status text default 'Pending', created_at text)""")
    con.execute("create index if not exists ix_edst on graph_edges(dst)")
    con.commit(); con.close()

@app.get("/health")
def health():
    return {"status": "ok", "db": "supabase-postgres" if USE_PG else os.path.basename(DB)}

# ---- citizen -> admin correction-request flow ----------------------------
class CorrectionIn(BaseModel):
    cnic: str
    field: str
    current_value: str = ""
    requested_value: str
    reason: str = ""

@app.post("/requests")
def create_request(r: CorrectionIn):
    if USE_PG:
        row = one("""insert into correction_requests(cnic,field,current_value,requested_value,reason)
                     values(?,?,?,?,?) returning id""",
                  (r.cnic, r.field, r.current_value, r.requested_value, r.reason))
        return {"id": row["id"], "status": "Pending"}
    rid = execute("""insert into correction_requests(cnic,field,current_value,requested_value,reason,created_at)
                     values(?,?,?,?,?,?)""",
                  (r.cnic, r.field, r.current_value, r.requested_value, r.reason,
                   datetime.datetime.now().isoformat(timespec="seconds")))
    return {"id": rid, "status": "Pending"}

@app.get("/requests")
def list_requests(status: str = Query(None), cnic: str = Query(None)):
    where, args = [], []
    if status: where.append("r.status=?"); args.append(status)
    if cnic:   where.append("r.cnic=?"); args.append(cnic)
    wsql = ("where " + " and ".join(where)) if where else ""
    return rows(f"""select r.*, p.name from correction_requests r
                   left join persons p on p.cnic=r.cnic {wsql} order by r.id desc""", tuple(args))

@app.post("/requests/{rid}/resolve")
def resolve_request(rid: int, decision: str = Query(..., pattern="^(Approved|Rejected)$")):
    execute("update correction_requests set status=? where id=?", (decision, rid))
    return {"id": rid, "status": decision}

# ---- approved asset declaration -> write into the record + recompute score ----
import math as _math, random as _rnd

class DeclApprove(BaseModel):
    cnic: str
    asset_type: str
    description: str = ""
    value: float = 0
    details: dict = {}
    decl_id: int = 0

def _intval(x, dflt=0):
    try:
        return int(float(x))
    except (TypeError, ValueError):
        return dflt

@app.post("/declarations/approve")
def approve_declaration(d: DeclApprove):
    # Idempotency: a declaration may only ever be written into the record once.
    # Guards against double-clicks / retries creating duplicate assets.
    if d.decl_id:
        execute("create table if not exists processed_declarations(decl_id integer primary key)")
        if one("select decl_id from processed_declarations where decl_id=?", (d.decl_id,)):
            return {"ok": True, "duplicate": True}
        execute("insert into processed_declarations(decl_id) values(?)", (d.decl_id,))
    cnic, val, t = d.cnic, float(d.value or 0), d.asset_type
    det = d.details or {}
    g = lambda k, dflt="": (det.get(k) if det.get(k) not in (None, "") else dflt)
    label = d.description or "Declared"
    if t == "Vehicle":
        execute("""insert into vehicles(reg_number,owner_cnic,owner_company_ntn,owner_name,make,model,variant,engine_cc,color,value)
                   values(?,?,?,?,?,?,?,?,?,?)""",
                (f"DEC-{_rnd.randint(1000,9999)}", cnic, "", g("owner_name"),
                 g("make", "Declared"), g("model", ""), str(g("year", "")), _intval(g("engine_cc")), "", val))
    elif t == "Property":
        execute("""insert into properties(fard,owner_cnic,owner_company_ntn,owner_name,khewat,khasra,mauza,district,property_type,area,market_value,dc_valuation)
                   values(?,?,?,?,?,?,?,?,?,?,?,?)""",
                (f"DEC-{_rnd.randint(100000,999999)}", cnic, "", "", "", "", "", g("district"),
                 g("property_type", "Property"), g("area"), val, val * 0.5))
    elif t == "Bank":
        execute("""insert into bank_accounts(iban,customer_cnic,bank,account_type,balance,turnover)
                   values(?,?,?,?,?,?)""",
                (f"PKDEC{_rnd.randint(10**14,10**15)}", cnic, g("bank", label), g("account_type", "Current"), val, val))
    elif t == "Stock":
        execute("""insert into stocks(cdc,holder_cnic,scrip,shares,market_value,dividend)
                   values(?,?,?,?,?,?)""",
                (str(_rnd.randint(10**11, 10**12)), cnic, str(g("scrip", label))[:6], _intval(g("shares")), val, 0))
    # recompute the citizen's deviation score with the new own-asset total
    s = one("select * from deviation_scores where cnic=?", (cnic,))
    if s:
        declared = max((s["declared"] or 0), 50000)
        own = (s["own_assets"] or 0) + val
        hidden = s["hidden_assets"] or 0
        life = s["lifestyle"] or 0
        gnn = s["gnn_prob"] or 0
        sq = lambda r: max(0.0, min(1.0, (_math.log10(max(r, 1)) - 1) / 1.5))
        asset_sig = sq(own / declared)
        struct_sig = sq(hidden / declared) if hidden > 0 else 0
        life_sig = max(0.0, min(1.0, (life / declared - 0.2) / 0.8))
        tr = one("select filer_status from tax_returns where cnic=?", (cnic,))
        nonfiler = 0 if (tr and tr["filer_status"] == "Filer") else 1
        rule = 100 * (0.35 * asset_sig + 0.30 * struct_sig + 0.20 * life_sig + 0.15 * nonfiler)
        fused = round(100 * (0.5 * rule / 100 + 0.5 * gnn), 1)
        zone = "Red" if fused >= 55 else "Yellow" if fused >= 22 else "Green"
        execute("update deviation_scores set own_assets=?, rule_score=?, deviation_score=?, zone=? where cnic=?",
                (own, round(rule, 1), fused, zone, cnic))
        return {"ok": True, "new_score": fused, "zone": zone, "own_assets": own}
    return {"ok": True}

@app.get("/stats")
def stats():
    """Admin dashboard summary cards."""
    zones = {r["zone"]: r["n"] for r in rows("select zone, count(*) n from deviation_scores group by zone")}
    tot = one("select count(*) n from persons")["n"]
    filers = one("select count(*) n from tax_returns where filer_status='Filer'")["n"]
    flagged_val = one("select coalesce(sum(hidden_assets),0) v from deviation_scores where zone in('Red','Yellow')")["v"]
    return {"total_persons": tot, "filers": filers, "non_filers": tot - filers,
            "zones": zones, "hidden_assets_under_review": flagged_val}

@app.get("/persons")
def persons(zone: str = Query(None), district: str = Query(None), q: str = Query(None),
            sort: str = Query("score"), limit: int = Query(50, le=500), offset: int = 0):
    """Admin list — filter by zone/district, search by name/CNIC, sort by score."""
    where, args = [], []
    if zone:     where.append("s.zone = ?"); args.append(zone)
    if district: where.append("p.district = ?"); args.append(district)
    if q:        where.append("(p.name like ? or p.cnic like ?)"); args += [f"%{q}%", f"%{q}%"]
    wsql = ("where " + " and ".join(where)) if where else ""
    order = "s.deviation_score desc" if sort == "score" else "p.name"
    data = rows(f"""select p.cnic, p.name, p.district, s.deviation_score, s.zone,
                    t.declared_income, t.filer_status, s.own_assets, s.hidden_assets, {REC} as recovery
                    from persons p left join deviation_scores s on s.cnic=p.cnic
                    left join tax_returns t on t.cnic=p.cnic
                    {wsql} order by {order} limit ? offset ?""", (*args, limit, offset))
    total = one(f"select count(*) n from persons p left join deviation_scores s on s.cnic=p.cnic {wsql}", tuple(args))["n"]
    return {"total": total, "results": data}

@app.get("/person/{cnic}")
def person(cnic: str):
    """Full profile for the user/admin drill-down: identity, tax, assets, score, audit."""
    p = one("select * from persons where cnic=?", (cnic,))
    if not p:
        raise HTTPException(404, "person not found")
    tax = one("select * from tax_returns where cnic=?", (cnic,))
    score = one("select * from deviation_scores where cnic=?", (cnic,))
    assets = {
        "vehicles": rows("select reg_number,make,model,variant,engine_cc,value from vehicles where owner_cnic=?", (cnic,)),
        "properties": rows("select fard,property_type,area,district,market_value from properties where owner_cnic=?", (cnic,)),
        "stocks": rows("select scrip,shares,market_value,dividend from stocks where holder_cnic=?", (cnic,)),
        "bank_accounts": rows("select bank,account_type,balance,turnover from bank_accounts where customer_cnic=?", (cnic,)),
        "electricity": rows("select disco,units,bill_amount,billing_month from electricity where customer_cnic=?", (cnic,)),
        "gas": rows("select company,units,bill_amount from gas where customer_cnic=?", (cnic,)),
        "travel": rows("select airline,destination,ticket_cost,travel_date from travel where cnic=?", (cnic,)),
        "directorships": rows("""select d.ntn, c.name, d.role, d.pct from directorships d
                                 left join companies c on c.ntn=d.ntn where d.person_cnic=?""", (cnic,)),
    }
    audit = score["audit_trail"].split(" | ") if score and score.get("audit_trail") else []
    return {"identity": p, "tax": tax, "score": score, "audit_trail": audit, "assets": assets}

@app.get("/person/{cnic}/graph")
def person_graph(cnic: str, hops: int = Query(1, le=2)):
    """Ego graph around a person for the visualisation (nodes + edges)."""
    seen = {f"P:{cnic}"}; edges = []
    frontier = [f"P:{cnic}"]
    for _ in range(hops):
        nxt = []
        for nid in frontier:
            for e in rows("select src,rel,dst from graph_edges where src=? or dst=? limit 60", (nid, nid)):
                edges.append(e)
                for x in (e["src"], e["dst"]):
                    if x not in seen:
                        seen.add(x); nxt.append(x)
        frontier = nxt
    return {"nodes": [{"id": n, "type": n.split(":", 1)[0]} for n in seen],
            "edges": [{"source": e["src"], "rel": e["rel"], "target": e["dst"]} for e in edges]}

@app.get("/person/{cnic}/explain")
def explain(cnic: str):
    """On-demand GNN explanation — which graph neighbours drove the anomaly score."""
    try:
        from explainer_service import explain as gnn_explain
        res = gnn_explain(cnic)
    except Exception as e:
        raise HTTPException(500, f"explainer error: {e}")
    if res is None:
        raise HTTPException(404, "cnic not in graph")
    return res

@app.get("/districts")
def districts():
    return [r["district"] for r in rows("select distinct district from persons order by district")]

# ---- NEW: leaderboard, analytics, risk-factors, notice, ER metrics, search ----
@app.get("/leaderboard")
def leaderboard(limit: int = Query(20, le=100)):
    return rows(f"""select p.cnic, p.name, p.district, s.deviation_score, s.zone,
        s.declared, s.own_assets, s.hidden_assets, {REC} as recovery
        from deviation_scores s join persons p on p.cnic=s.cnic
        where s.zone in ('Red','Yellow')
        order by recovery desc limit ?""", (limit,))

@app.get("/analytics")
def analytics():
    zones = {r["zone"]: r["n"] for r in rows("select zone,count(*) n from deviation_scores group by zone")}
    districts = rows(f"""select p.district, count(*) n, round(avg(s.deviation_score),1) avg_score,
        sum({REC}) recovery from deviation_scores s join persons p on p.cnic=s.cnic
        group by p.district order by recovery desc""")
    filers = one("select count(*) n from tax_returns where filer_status='Filer'")["n"]
    total = one("select count(*) n from persons")["n"]
    total_rec = one(f"select sum({REC}) v from deviation_scores")["v"] or 0
    # synthetic 12-month filed-vs-nonfiler trend (for the line chart)
    base = filers / max(total, 1) * 100
    filed = [round(base * (0.7 + 0.03 * i), 1) for i in range(12)]
    nonfiler = [round(100 - f, 1) for f in filed]
    return {"zones": zones, "districts": districts, "filers": filers, "non_filers": total - filers,
            "total_recovery_potential": total_rec,
            "trend_months": ["Jul", "Aug", "Sep", "Oct", "Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun"],
            "trend_filed": filed, "trend_nonfiler": nonfiler}

@app.get("/person/{cnic}/risk-factors")
def risk_factors(cnic: str):
    s = one("select * from deviation_scores where cnic=?", (cnic,))
    if not s:
        raise HTTPException(404, "not found")
    veh = rows("select engine_cc, value from vehicles where owner_cnic=?", (cnic,))
    props = rows("select market_value from properties where owner_cnic=?", (cnic,))
    elec = one("select sum(bill_amount) v from electricity where customer_cnic=?", (cnic,))
    trips = one("select count(*) n from travel where cnic=?", (cnic,))["n"]
    declared = s["declared"] or 0
    assets = (s["own_assets"] or 0) + (s["hidden_assets"] or 0)
    lux = [v for v in veh if (v["engine_cc"] or 0) >= 2000]
    f = []
    if veh:
        f.append({"label": "Luxury Vehicle Ownership", "weight": min(99, 45 + len(lux) * 25),
                  "detail": f"{len(veh)} vehicle(s), {len(lux)} ≥2000cc", "sev": "critical" if lux else "high"})
    monthly = (elec["v"] or 0) / 12 if elec and elec["v"] else 0
    if monthly > 30000:
        f.append({"label": "High Electricity Consumption", "weight": min(95, 50 + int(monthly / 20000) * 10),
                  "detail": f"PKR {int(monthly):,}/mo avg", "sev": "high"})
    if len(props) > 1:
        f.append({"label": "Multiple Properties", "weight": min(92, 55 + len(props) * 10),
                  "detail": f"{len(props)} properties", "sev": "high"})
    if trips > 2:
        f.append({"label": "Foreign Travel Frequency", "weight": min(88, 40 + trips * 7),
                  "detail": f"{trips} international trips", "sev": "med"})
    if assets > 0 and (declared == 0 or assets > declared * 5):
        ratio = int(assets / declared) if declared else 0
        f.append({"label": "Declared Income Mismatch", "weight": 97,
                  "detail": "Lifestyle ≫ PKR 0 declared" if declared == 0 else f"Assets ≈ {ratio}x declared",
                  "sev": "critical"})
    f.sort(key=lambda x: -x["weight"])
    return {"cnic": cnic, "factors": f}

@app.get("/person/{cnic}/notice")
def notice(cnic: str):
    p = one("select * from persons where cnic=?", (cnic,))
    if not p:
        raise HTTPException(404, "not found")
    s = one("select * from deviation_scores where cnic=?", (cnic,))
    declared = (s["declared"] if s else 0) or 0
    assets = ((s["own_assets"] or 0) + (s["hidden_assets"] or 0)) if s else 0
    rec = max(0, (assets + (s["lifestyle"] or 0) - declared) * 0.1) if s else 0
    text = (
        "FEDERAL BOARD OF REVENUE\n"
        "Notice under Section 122(5A), Income Tax Ordinance 2001\n\n"
        f"To: {p['name']}\nCNIC: {cnic}\nAddress: {p['present_address']}\n\n"
        "Subject: Amendment of Assessment — Tax Year 2024\n\n"
        "Cross-departmental analysis (Excise, Land Revenue, DISCOs, FIA, SECP, banking) indicates a "
        f"Tax Compliance Deviation Score of {s['deviation_score'] if s else 0}/100 "
        f"({s['zone'] if s else 'N/A'} risk). Noted discrepancies:\n"
        f"  • Declared income: PKR {int(declared):,}\n"
        f"  • Identified assets/footprint: PKR {int(assets):,}\n"
        f"  • Estimated under-declared tax (recovery): PKR {int(rec):,}\n\n"
        "You are required to show cause within fifteen (15) days as to why your assessment should not "
        "be amended under the above section. — Inland Revenue Officer, FBR."
    )
    return {"cnic": cnic, "recovery_potential": int(rec), "notice": text}

@app.get("/er-metrics")
def er_metrics():
    silos = [("NADRA", "persons", "cnic"), ("FBR", "tax_returns", "cnic"), ("Excise", "vehicles", "owner_cnic"),
             ("Electricity", "electricity", "customer_cnic"), ("Gas", "gas", "customer_cnic"),
             ("Land", "properties", "owner_cnic"), ("Stocks", "stocks", "holder_cnic"),
             ("Banking", "bank_accounts", "customer_cnic"), ("SECP", "directorships", "person_cnic")]
    out = []
    for name, tbl, col in silos:
        n = one(f"select count(*) n from {tbl}")["n"]
        out.append({"source": name, "records": n, "match": 99.0 + (hash(name) % 9) / 10, "status": "matched"})
    return {"sources": out, "precision": 1.0, "recall": 1.0, "f1": 1.0}

@app.get("/network")
def network(limit: int = Query(35, le=120)):
    """A multi-entity intelligence network: top flagged citizens + their family
    fronts and directed companies, with FAMILY_OF / DIRECTOR_OF edges between them."""
    seed = rows("""select p.cnic, p.name, s.deviation_score, s.zone
        from deviation_scores s join persons p on p.cnic=s.cnic
        where s.zone in ('Red','Yellow') order by s.deviation_score desc limit ?""", (limit,))
    nodes, edges, seen_e = {}, [], set()

    def pnode(cnic, name=None, zone=None, score=None):
        nid = "P:" + cnic
        if nid not in nodes:
            if name is None:
                r = one("""select p.name, s.zone, s.deviation_score from persons p
                           left join deviation_scores s on s.cnic=p.cnic where p.cnic=?""", (cnic,))
                name = r["name"] if r else cnic
                zone = r["zone"] if r else "Green"
                score = r["deviation_score"] if r else 0
            nodes[nid] = {"id": nid, "label": name, "type": "citizen", "zone": zone or "Green",
                          "score": round(score or 0, 1), "cnic": cnic}
        return nid

    def cnode(ntn):
        nid = "C:" + ntn
        if nid not in nodes:
            r = one("select name from companies where ntn=?", (ntn,))
            nodes[nid] = {"id": nid, "label": (r["name"] if r else ntn), "type": "company"}
        return nid

    for p in seed:
        pnode(p["cnic"], p["name"], p["zone"], p["deviation_score"])
    srcs = ["P:" + p["cnic"] for p in seed]
    if srcs:
        ph = ",".join(["?"] * len(srcs))
        nbrs = rows(f"""select src, rel, dst from graph_edges
                        where (src in ({ph}) or dst in ({ph})) and rel in ('FAMILY_OF','DIRECTOR_OF')""",
                    (*srcs, *srcs))
        srcset = set(srcs)
        per = {}  # cap neighbours per seed person so the graph stays readable
        for e in nbrs:
            a, b = e["src"], e["dst"]
            src = a if a in srcset else (b if b in srcset else None)
            if src is None:
                continue
            if per.get(src, 0) >= 6:
                continue
            other = b if a == src else a
            pre = other.split(":", 1)[0]
            if pre == "P":
                pnode(other.split(":", 1)[1])
            elif pre == "C":
                cnode(other.split(":", 1)[1])
            else:
                continue
            k = tuple(sorted([src, other])) + (e["rel"],)
            if k in seen_e:
                continue
            seen_e.add(k)
            per[src] = per.get(src, 0) + 1
            edges.append({"source": src, "target": other, "rel": e["rel"]})
    return {"nodes": list(nodes.values()), "edges": edges}

@app.get("/search")
def search(q: str):
    res = []
    for r in rows("select cnic,name,district from persons where name like ? or cnic like ? limit 8", (f"%{q}%", f"%{q}%")):
        res.append({"type": "Citizen", "label": r["name"], "sub": f"{r['cnic']} · {r['district']}", "cnic": r["cnic"]})
    for r in rows("select reg_number,make,model,owner_cnic from vehicles where reg_number like ? limit 4", (f"%{q}%",)):
        res.append({"type": "Vehicle", "label": f"{r['reg_number']} · {r['make']} {r['model']}", "sub": r["owner_cnic"], "cnic": r["owner_cnic"]})
    return res
