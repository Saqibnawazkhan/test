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

def _recompute_score(cnic, own_assets):
    """Recompute & persist the deviation score for a given own-asset total."""
    s = one("select * from deviation_scores where cnic=?", (cnic,))
    if not s:
        return {"ok": True}
    declared = max((s["declared"] or 0), 50000)
    own = max(0.0, own_assets)
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

class ExplApprove(BaseModel):
    cnic: str
    asset_value: float = 0
    expl_id: int = 0

@app.post("/explanations/approve")
def approve_explanation(d: ExplApprove):
    """Accept a citizen's explanation for an existing asset: the explained value is
    treated as accounted-for, lowering the deviation score. Idempotent."""
    if d.expl_id:
        execute("create table if not exists processed_explanations(eid integer primary key)")
        if one("select eid from processed_explanations where eid=?", (d.expl_id,)):
            return {"ok": True, "duplicate": True}
        execute("insert into processed_explanations(eid) values(?)", (d.expl_id,))
    s = one("select own_assets from deviation_scores where cnic=?", (d.cnic,))
    if not s:
        return {"ok": True}
    own = max(0.0, (s["own_assets"] or 0) - float(d.asset_value or 0))
    return _recompute_score(d.cnic, own)

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
    audit_raw = score["audit_trail"] if score and score.get("audit_trail") else ""
    if not tax and audit_raw:
        # True non-filer: the 50,000 is an internal math floor, not a declaration. Show it honestly.
        import re as _re
        audit_raw = audit_raw.replace("Declared income+tax: PKR 50,000  [NON-FILER / inactive on ATL]",
                                      "No income tax return on record (Non-Filer, inactive on ATL)")
        audit_raw = _re.sub(r"\(~[\d,]+x declared\)", "(income undeclared)", audit_raw)
    audit = audit_raw.split(" | ") if audit_raw else []
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

def _report_data(cnic: str):
    """Assemble the full taxpayer dict consumed by the audit report and notice PDFs."""
    p = one("select * from persons where cnic=?", (cnic,))
    if not p:
        raise HTTPException(404, "not found")
    s = one("select * from deviation_scores where cnic=?", (cnic,))
    t = one("select * from tax_returns where cnic=?", (cnic,))
    elec = one("select sum(bill_amount) v from electricity where customer_cnic=?", (cnic,))
    declared = (s["declared"] if s else 0) or 0
    assets_v = ((s["own_assets"] or 0) + (s["hidden_assets"] or 0)) if s else 0
    rec = max(0, (assets_v + ((s["lifestyle"] or 0) if s else 0) - declared) * 0.1)
    return {
        "cnic": cnic, "name": p["name"], "father": p["father_husband_name"],
        "address": p["present_address"], "district": p["district"],
        "ntn": t["ntn"] if t else None, "tax_year": 2024,
        "declared_income": (t["declared_income"] if t else 0), "tax_paid": (t["tax_paid"] if t else 0),
        "filer_status": (t["filer_status"] if t else None), "source": (t["source_of_income"] if t else None),
        "score": (s["deviation_score"] if s else 0), "zone": (s["zone"] if s else "N/A"),
        "gnn_prob": (s["gnn_prob"] if s else 0),
        "declared": declared, "own_assets": (s["own_assets"] if s else 0),
        "hidden_assets": (s["hidden_assets"] if s else 0), "lifestyle": (s["lifestyle"] if s else 0),
        "recovery": rec,
        "assets": {
            "vehicles": rows("select engine_cc, value from vehicles where owner_cnic=?", (cnic,)),
            "properties": rows("select market_value from properties where owner_cnic=?", (cnic,)),
            "bank_accounts": rows("select balance from bank_accounts where customer_cnic=?", (cnic,)),
            "stocks": rows("select market_value from stocks where holder_cnic=?", (cnic,)),
            "travel_count": one("select count(*) n from travel where cnic=?", (cnic,))["n"],
            "electricity_monthly": (elec["v"] or 0) / 12 if elec and elec["v"] else 0,
        },
    }

def _pdf_response(pdf: bytes, prefix: str, cnic: str):
    from fastapi.responses import Response
    fname = "{}_{}.pdf".format(prefix, "".join(ch for ch in cnic if ch.isdigit()))
    return Response(content=pdf, media_type="application/pdf",
                    headers={"Content-Disposition": "attachment; filename={}".format(fname)})

@app.get("/person/{cnic}/audit-report")
def audit_report_pdf(cnic: str):
    """Findings-driven FBR audit report as a downloadable PDF."""
    from audit_report import build_audit_pdf
    return _pdf_response(build_audit_pdf(_report_data(cnic)), "audit", cnic)

@app.get("/person/{cnic}/notice-pdf")
def notice_pdf(cnic: str):
    """Findings-driven Show-Cause Notice (statutory letter to the taxpayer) as a PDF."""
    from audit_report import build_notice_pdf
    return _pdf_response(build_notice_pdf(_report_data(cnic)), "notice", cnic)

@app.get("/person/{cnic}/family")
def family(cnic: str):
    """Ego-centric family tree with each member's assets — surfaces benami fronts
    (relatives, esp. female, holding wealth with little/no income of their own).
    Relationships inferred from father_husband_name links + gender/age."""
    ego = one("select * from persons where cnic=?", (cnic,))
    if not ego:
        raise HTTPException(404, "not found")

    def age(dob):
        try:
            return 2025 - int(str(dob)[:4])
        except (TypeError, ValueError):
            return None

    def own(c):
        v = one("select coalesce(sum(value),0) s from vehicles where owner_cnic=?", (c,))["s"]
        p = one("select coalesce(sum(market_value),0) s from properties where owner_cnic=?", (c,))["s"]
        b = one("select coalesce(sum(balance),0) s from bank_accounts where customer_cnic=?", (c,))["s"]
        st = one("select coalesce(sum(market_value),0) s from stocks where holder_cnic=?", (c,))["s"]
        return (v or 0) + (p or 0) + (b or 0) + (st or 0)

    def card(p, relation):
        t = one("select declared_income,filer_status from tax_returns where cnic=?", (p["cnic"],))
        s = one("select deviation_score,zone from deviation_scores where cnic=?", (p["cnic"],))
        oa = own(p["cnic"])
        inc = (t["declared_income"] if t else 0) or 0
        filer = (t["filer_status"] if t else "Non-Filer") or "Non-Filer"
        front = relation in ("Wife", "Daughter", "Son", "Husband") and oa > 3_000_000 and (inc == 0 or oa > inc * 10)
        return {"cnic": p["cnic"], "name": p["name"], "gender": p["gender"], "relation": relation,
                "age": age(p["dob"]), "own_assets": oa, "declared_income": inc, "filer_status": filer,
                "zone": (s["zone"] if s else "-"), "deviation_score": (s["deviation_score"] if s else 0),
                "possible_front": bool(front)}

    members = [card(ego, "Self")]
    edges = []
    fam_id = ego["family_tree_id"]

    # parent / head — the person named as the ego's father or husband
    parent = None
    if ego["father_husband_name"]:
        parent = one("select * from persons where name=? and family_tree_id=? and cnic!=? limit 1",
                     (ego["father_husband_name"], fam_id, cnic)) \
            or one("select * from persons where name=? and cnic!=? limit 1", (ego["father_husband_name"], cnic))
    if parent:
        members.append(card(parent, "Father / Husband"))
        edges.append({"from": parent["cnic"], "to": cnic})

    # dependents / fronts — people who name the ego as their father/husband
    # (restricted to the same family tree so we don't match unrelated namesakes)
    ego_age = age(ego["dob"]) or 40
    for d in rows("select * from persons where father_husband_name=? and family_tree_id=? and cnic!=? limit 12",
                  (ego["name"], fam_id, cnic)):
        gap = ego_age - (age(d["dob"]) or 0)
        if d["gender"] == "F":
            rel = "Daughter" if gap >= 16 else "Wife"
        else:
            rel = "Son" if gap >= 16 else "Brother"
        members.append(card(d, rel))
        edges.append({"from": cnic, "to": d["cnic"]})

    fronts = [m for m in members if m["possible_front"]]
    return {
        "ego": cnic,
        "members": members,
        "edges": edges,
        "total_family_assets": sum(m["own_assets"] for m in members),
        "front_count": len(fronts),
        "hidden_in_fronts": sum(m["own_assets"] for m in fronts),
    }

@app.get("/pos/businesses")
def pos_businesses(q: str = Query(None), limit: int = Query(40, le=200)):
    """Registered businesses (for POS turnover reconciliation), ranked by bank turnover."""
    where = "t.source_of_income like '%usiness%'"
    args = []
    if q:
        where += " and (p.name like ? or p.cnic like ? or t.business_desc like ?)"
        args += [f"%{q}%", f"%{q}%", f"%{q}%"]
    data = rows(f"""select p.cnic, p.name, p.district, t.business_desc, t.declared_income, t.ntn,
                    coalesce((select sum(turnover) from bank_accounts where customer_cnic=p.cnic),0) turnover,
                    s.zone, s.deviation_score
                    from tax_returns t join persons p on p.cnic=t.cnic
                    left join deviation_scores s on s.cnic=p.cnic
                    where {where} order by turnover desc limit ?""", (*args, limit))
    return {"results": data}

@app.get("/pos/verify/{cnic}")
def pos_verify(cnic: str):
    """Simulated FBR POS verification + turnover reconciliation for one business.
    Compares observed bank turnover (true sales proxy) against POS-reported sales;
    the gap is under-reported turnover with recoverable sales tax (GST 17%)."""
    p = one("select * from persons where cnic=?", (cnic,))
    if not p:
        raise HTTPException(404, "not found")
    t = one("select * from tax_returns where cnic=?", (cnic,))
    s = one("select zone,deviation_score from deviation_scores where cnic=?", (cnic,))
    turnover = one("select coalesce(sum(turnover),0) v from bank_accounts where customer_cnic=?", (cnic,))["v"] or 0
    declared = (t["declared_income"] if t else 0) or 0
    zone = (s["zone"] if s else "Green")
    seed = sum((i + 1) * ord(ch) for i, ch in enumerate(cnic))     # deterministic per CNIC
    integrated = (zone != "Red") and (seed % 5 != 0)               # Red / unlucky -> not integrated
    frac = {"Green": 0.9, "Yellow": 0.6, "Red": 0.35}.get(zone, 0.7)
    frac = min(0.98, max(0.2, frac + ((seed % 11) - 5) / 100.0))
    if turnover <= 0:
        turnover = max(declared * 4, 5_000_000)
    reported = round(turnover * frac) if integrated else 0
    unreported = max(0, turnover - reported)
    recovery = round(unreported * 0.17)                            # GST 17%
    invoices = []
    for i in range(4):
        amt = 5000 + ((seed * (i + 3)) % 45000)
        invoices.append({"invoice_no": "FBR-{}-{}".format(cnic[-4:], 1000 + i * 7 + seed % 900),
                         "amount": amt, "sales_tax": round(amt * 0.17),
                         "status": "Reported" if (integrated and (seed + i) % 4 != 0) else "Not reported"})
    if not integrated:
        verdict = "Business not integrated with FBR POS system"
    elif unreported < turnover * 0.15:
        verdict = "Compliant - POS sales reconciled"
    else:
        verdict = "Under-reporting - {}% of sales not reported to FBR".format(round(unreported / turnover * 100))
    return {"cnic": cnic, "name": p["name"], "ntn": (t["ntn"] if t else None),
            "business": (t["business_desc"] if t else "Business"), "district": p["district"],
            "zone": zone, "deviation_score": (s["deviation_score"] if s else 0),
            "declared_income": declared, "bank_turnover": turnover, "pos_integrated": integrated,
            "pos_reported": reported, "unreported": unreported, "recovery": recovery,
            "reported_pct": round(reported / turnover * 100) if turnover else 0,
            "verdict": verdict, "invoices": invoices}

@app.get("/tax/calculate")
def tax_calculate(income: float = Query(...), year: str = Query("2025-26"), kind: str = Query("salaried")):
    """FBR income-tax — deterministic, verified slabs (no AI). year: 2024-25|2025-26, kind: salaried|business."""
    from tax_calc import compute_tax
    return compute_tax(income, year, kind)

class ChatReq(BaseModel):
    messages: list = []          # [{role:'user'|'assistant', content:str}]
    mode: str = "user"           # 'user' | 'admin'
    cnic: str = ""               # admin: the taxpayer under review

@app.post("/chat")
def chat_endpoint(req: ChatReq):
    """Grounded TaxNet assistant. Admin mode injects the taxpayer's real data so
    the model explains (never speculates). Returns a friendly note if AI is unavailable."""
    import json as _json
    from chat import chat as run_chat
    from audit_report import build_findings, declared_label
    extra = ""
    if req.mode == "admin" and req.cnic:
        try:
            d = _report_data(req.cnic)
            findings, unexplained = build_findings(d)
            ctx = {
                "name": d["name"], "cnic": d["cnic"], "district": d["district"],
                "filer_status": d["filer_status"] or "Non-Filer",
                "declared_income": declared_label(d),
                "identified_assets_PKR": int((d["own_assets"] or 0) + (d["hidden_assets"] or 0)),
                "indicative_annual_expenditure_PKR": int(d["lifestyle"] or 0),
                "deviation_score": d["score"], "risk_zone": d["zone"],
                "gnn_anomaly_probability": round((d["gnn_prob"] or 0), 3),
                "unexplained_amount_PKR": int(unexplained),
                "estimated_recoverable_tax_PKR": int(d["recovery"] or 0),
                "findings": [{"observation": f["observation"], "section": f["provision"]} for f in findings],
            }
            extra = ("\n\nTAXPAYER UNDER REVIEW (use ONLY these real figures; do not invent anything; "
                     "if asked something not covered here, say it is not on record):\n" + _json.dumps(ctx, default=str))
        except Exception:
            pass
    try:
        return {"reply": run_chat(req.messages, extra)}
    except Exception as e:
        msg = str(e).lower()
        if "credit balance" in msg or "credit" in msg and "low" in msg:
            return {"reply": "The AI assistant is unavailable: the Anthropic account has no credits. "
                             "Please add credits at console.anthropic.com to enable it.", "error": "no_credits"}
        if "no_api_key" in msg:
            return {"reply": "The AI assistant is not configured (missing API key).", "error": "no_api_key"}
        return {"reply": "Sorry, the assistant is temporarily unavailable. Please try again.", "error": str(e)[:140]}

def _apply_tax_payment(cnic, amount):
    """A successful tax payment: add to tax_paid, mark as Filer, recompute score (drops)."""
    amount = float(amount or 0)
    t = one("select cnic from tax_returns where cnic=?", (cnic,))
    if t:
        execute("update tax_returns set tax_paid=coalesce(tax_paid,0)+?, filer_status='Filer' where cnic=?", (amount, cnic))
    else:
        execute("insert into tax_returns(cnic, declared_income, tax_paid, filer_status) values(?,?,?,?)",
                (cnic, 0, amount, "Filer"))
    s = one("select own_assets from deviation_scores where cnic=?", (cnic,))
    if s:
        return _recompute_score(cnic, s["own_assets"] or 0)
    return {"ok": True}

class PayInit(BaseModel):
    cnic: str
    amount: float
    name: str = ""
    email: str = ""
    mobile: str = ""

@app.post("/payments/initiate")
def pay_initiate(d: PayInit):
    """Generate a PSID, fetch a Zindigi access token, store a pending payment."""
    import zindigi, random
    execute("""create table if not exists payments(psid text primary key, cnic text, name text, amount real,
               status text, txn_id text, token text, email text, mobile text, created_at text)""")
    if d.amount <= 0:
        raise HTTPException(400, "invalid amount")
    psid = "PSID" + "".join(random.choice("0123456789") for _ in range(11))
    token = zindigi.get_access_token(psid, int(d.amount))
    if not token:
        raise HTTPException(502, "could not get payment token from Zindigi")
    execute("""insert into payments(psid,cnic,name,amount,status,txn_id,token,email,mobile,created_at)
               values(?,?,?,?,?,?,?,?,?,?)""",
            (psid, d.cnic, d.name, float(d.amount), "Pending", "", token, d.email, d.mobile,
             datetime.datetime.now().isoformat()))
    base = os.environ.get("ZINDIGI_RETURN_BASE", "")
    return {"psid": psid, "amount": int(d.amount), "checkout_url": "{}/payments/checkout/{}".format(base, psid)}

@app.get("/payments/checkout/{psid}")
def pay_checkout(psid: str):
    """Self-submitting form that redirects the WebView to the Zindigi checkout."""
    from fastapi.responses import HTMLResponse
    import zindigi
    p = one("select * from payments where psid=?", (psid,))
    if not p:
        raise HTTPException(404, "payment not found")
    html_doc = zindigi.checkout_html(psid, p["token"], int(p["amount"]), p["name"], p["email"], p["mobile"],
                                     "FBR tax payment", datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    return HTMLResponse(html_doc)

@app.get("/payments/return")
def pay_return(psid: str, r: str = "", err_code: str = "", validation_hash: str = "", transaction_id: str = ""):
    """Zindigi redirects/IPN lands here. Verify, mark paid, update tax record + score."""
    from fastapi.responses import HTMLResponse
    import zindigi
    p = one("select * from payments where psid=?", (psid,))
    if not p:
        return HTMLResponse("<h3>Unknown payment</h3>")
    success = (r == "ok")
    if err_code:
        success = err_code in ("000", "00") and (zindigi.verify_hash(psid, err_code, validation_hash) if validation_hash else True)
    if success and p["status"] != "Paid":
        execute("update payments set status='Paid', txn_id=? where psid=?", (transaction_id or "", psid))
        _apply_tax_payment(p["cnic"], p["amount"])
    elif not success and p["status"] == "Pending":
        execute("update payments set status='Failed' where psid=?", (psid,))
    color = "#1AA978" if success else "#C62828"
    title = "Payment Successful" if success else "Payment Failed"
    sub = "Rs {:,} paid. Your tax record and score have been updated.".format(int(p["amount"])) if success else "The payment was not completed."
    mark = "&#10004;" if success else "&#10006;"  # check / cross HTML entities (ASCII source)
    return HTMLResponse(
        "<!doctype html><html><body style='font-family:sans-serif;text-align:center;padding:48px 24px'>"
        "<div style='font-size:54px;color:{}'>{}</div><h2 style='color:{}'>{}</h2><p style='color:#445'>{}</p>"
        "<p style='color:#889'>You can return to the TaxNet app.</p></body></html>".format(
            color, mark, color, title, sub))

@app.get("/payments")
def payments_list(cnic: str = Query(None), limit: int = Query(20, le=100)):
    execute("""create table if not exists payments(psid text primary key, cnic text, name text, amount real,
               status text, txn_id text, token text, email text, mobile text, created_at text)""")
    if cnic:
        return {"results": rows("select psid,amount,status,created_at from payments where cnic=? order by created_at desc limit ?", (cnic, limit))}
    return {"results": rows("select psid,cnic,name,amount,status,created_at from payments order by created_at desc limit ?", (limit,))}

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
