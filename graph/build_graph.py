"""
Knowledge Graph construction  —  Step 3
=======================================
Turns the resolved silos into a heterogeneous knowledge graph:

  NODES:  Person, Company, Vehicle, Property, BankAccount, Securities
  EDGES:  OWNS, HOLDS, HAS_ACCOUNT, DIRECTOR_OF, FAMILY_OF

Person nodes carry aggregated financial features (declared income, asset values,
bills, travel, balances) — the inputs the GNN + rule layer will score in Step 4.

Outputs:
  ./output/kg_nodes.csv , kg_edges.csv   (unified — feeds analysis + PyTorch Geometric)
  ./neo4j/*.csv  +  load.cypher          (load into Neo4j Aura when connected)
  prints graph stats + benami/shell/ring traversal demos

Run:  python build_graph.py
"""
import csv, os, sys
from collections import defaultdict, Counter

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

DATA = os.path.join(os.path.dirname(__file__), "..", "data-generator", "output_full")
OUT = os.path.join(os.path.dirname(__file__), "output")
NEO = os.path.join(os.path.dirname(__file__), "neo4j")
os.makedirs(OUT, exist_ok=True); os.makedirs(NEO, exist_ok=True)
load = lambda f: list(csv.DictReader(open(os.path.join(DATA, f), encoding="utf-8-sig")))
fnum = lambda x: float(x) if str(x).strip() not in ("", "None") else 0.0

print("Loading silos…")
nadra = load("01_nadra.csv")
fbr = {r["cnic"]: r for r in load("02_fbr.csv")}
veh = load("03_excise_vehicles.csv")
elec = load("04_electricity.csv")
gas = load("05_gas.csv")
land = load("06_land.csv")
stk = load("07_stocks.csv")
trv = load("08_travel.csv")
bnk = load("09_banking.csv")
comp = load("10_secp_companies.csv")
dirs = load("11_secp_directorships.csv")
labels = {r["cnic"]: r for r in load("00_LABELS_ground_truth.csv")}

# ---------------------------------------------------------------------------
# Person nodes + aggregate financial features
# ---------------------------------------------------------------------------
print("Building Person nodes + features…")
P = {}
for r in nadra:
    c = r["cnic"]
    f = fbr.get(c)
    P[c] = {
        "name": r["name_en"], "gender": r["gender"], "district": r["place_of_birth"],
        "family_tree_id": r["family_tree_id"], "father_husband": r["father_husband_name"],
        "declared_income": fnum(f["declared_income"]) if f else 0.0,
        "tax_paid": fnum(f["tax_paid"]) if f else 0.0,
        "is_filer": 1 if (f and f["filer_status"] == "Filer") else 0,
        "n_vehicles": 0, "vehicle_value": 0.0, "n_properties": 0, "property_value": 0.0,
        "bank_balance": 0.0, "bank_turnover": 0.0, "elec_bill": 0.0, "gas_bill": 0.0,
        "stock_value": 0.0, "dividend": 0.0, "travel_spend": 0.0, "travel_trips": 0,
        "n_directorships": 0,
    }

def padd(cnic, field, val, count=None):
    if cnic in P:
        P[cnic][field] += val
        if count:
            P[cnic][count] += 1

# ---------------------------------------------------------------------------
# Asset nodes + edges
# ---------------------------------------------------------------------------
nodes = defaultdict(dict)     # type -> {id: props}
edges = []                    # (src_type, src_id, TYPE, dst_type, dst_id, props)
for c, p in P.items():
    nodes["Person"][c] = p
for c in comp:
    nodes["Company"][c["company_ntn"]] = {"name": c["company_name"],
        "business": c["principal_business"], "capital": fnum(c["paid_up_capital"])}

def owner_ref(cnic, ntn):
    if ntn.strip():
        return "Company", ntn
    return "Person", cnic

print("Vehicles…")
for v in veh:
    vid = v["reg_number"]
    nodes["Vehicle"][vid] = {"make": v["make"], "model": v["model"],
        "cc": int(v["engine_cc"]), "value": fnum(v["vehicle_value"])}
    st, sid = owner_ref(v["owner_cnic"], v["owner_company_ntn"])
    edges.append((st, sid, "OWNS", "Vehicle", vid, {}))
    if st == "Person":
        padd(sid, "vehicle_value", fnum(v["vehicle_value"]), "n_vehicles")

print("Property (co-ownership merged by khewat/khasra/mauza/district)…")
for r in land:
    pid = f"{r['khewat_no']}|{r['khasra_no']}|{r['mauza']}|{r['district']}"
    nd = nodes["Property"].get(pid)
    if not nd:
        nodes["Property"][pid] = {"type": r["property_type"], "district": r["district"],
            "market_value": fnum(r["market_value"]), "owners": 0}
    nodes["Property"][pid]["owners"] += 1
    st, sid = owner_ref(r["owner_cnic"], r["owner_company_ntn"])
    edges.append((st, sid, "OWNS", "Property", pid, {}))
    if st == "Person":
        padd(sid, "property_value", fnum(r["market_value"]), "n_properties")

print("Bank accounts…")
for r in bnk:
    aid = r["iban"]
    nodes["BankAccount"][aid] = {"bank": r["bank_name"], "balance": fnum(r["account_balance"])}
    edges.append(("Person", r["customer_cnic"], "HAS_ACCOUNT", "BankAccount", aid, {}))
    padd(r["customer_cnic"], "bank_balance", fnum(r["account_balance"]))
    padd(r["customer_cnic"], "bank_turnover", fnum(r["annual_turnover"]))

print("Securities…")
for r in stk:
    sidd = r["cdc_investor_account"]
    nodes["Securities"][sidd] = {"scrip": r["scrip_symbol"], "value": fnum(r["market_value"])}
    if r["holder_cnic"].strip():
        edges.append(("Person", r["holder_cnic"], "HOLDS", "Securities", sidd, {}))
        padd(r["holder_cnic"], "stock_value", fnum(r["market_value"]))
        padd(r["holder_cnic"], "dividend", fnum(r["dividend_income"]))
    else:                                  # company-held (shell)
        # find company by matching uin/ntn
        edges.append(("Company", r["uin"], "HOLDS", "Securities", sidd, {}))

print("Directorships…")
for r in dirs:
    edges.append(("Person", r["person_cnic"], "DIRECTOR_OF", "Company", r["company_ntn"],
                  {"pct": r["shareholding_percent"], "role": r["role"]}))
    padd(r["person_cnic"], "n_directorships", 1)

print("Utilities + travel -> Person features…")
for r in elec:
    padd(r["customer_cnic"], "elec_bill", fnum(r["bill_amount"]))
for r in gas:
    padd(r["customer_cnic"], "gas_bill", fnum(r["bill_amount"]))
for r in trv:
    padd(r["cnic"], "travel_spend", fnum(r["ticket_cost"]), "travel_trips")

print("FAMILY_OF edges (from NADRA family_tree_id)…")
fam = defaultdict(list)
for c, p in P.items():
    fam[p["family_tree_id"]].append(c)
fam_edges = 0
for members in fam.values():
    if 2 <= len(members) <= 8:             # skip pathological huge groups
        for a in range(len(members)):
            for b in range(a + 1, len(members)):
                edges.append(("Person", members[a], "FAMILY_OF", "Person", members[b], {}))
                fam_edges += 1

# ---------------------------------------------------------------------------
# Write unified node/edge CSVs (feeds analysis + PyTorch Geometric in Step 4)
# ---------------------------------------------------------------------------
print("Writing unified graph CSVs…")
PFEATS = ["declared_income", "tax_paid", "is_filer", "n_vehicles", "vehicle_value",
          "n_properties", "property_value", "bank_balance", "bank_turnover", "elec_bill",
          "gas_bill", "stock_value", "dividend", "travel_spend", "travel_trips", "n_directorships"]
# consistent ID prefixes for BOTH nodes and edges (Property = "Pr" so it never collides with Person "P")
PREF = {"Person": "P", "Company": "C", "Vehicle": "V", "Property": "Pr",
        "BankAccount": "B", "Securities": "S"}
ASSET_VALUE = {"Company": "capital", "Vehicle": "value", "Property": "market_value",
               "BankAccount": "balance", "Securities": "value"}
with open(os.path.join(OUT, "kg_nodes.csv"), "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh)
    w.writerow(["node_id", "type"] + PFEATS + ["value", "name"])
    for c, p in nodes["Person"].items():
        pv = p["vehicle_value"] + p["property_value"] + p["stock_value"] + p["bank_balance"]
        w.writerow([f"P:{c}", "Person"] + [p[k] for k in PFEATS] + [pv, p["name"]])
    for t in ["Company", "Vehicle", "Property", "BankAccount", "Securities"]:
        for nid, nd in nodes[t].items():
            w.writerow([f"{PREF[t]}:{nid}", t] + [0] * len(PFEATS)
                       + [nd.get(ASSET_VALUE[t], 0), nd.get("name", nd.get("make", ""))])
with open(os.path.join(OUT, "kg_edges.csv"), "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh)
    w.writerow(["src", "type", "dst"])
    for st, sid, typ, dt, did, _ in edges:
        w.writerow([f"{PREF[st]}:{sid}", typ, f"{PREF[dt]}:{did}"])

# ---------------------------------------------------------------------------
# Neo4j load artifacts (CSV + Cypher) for Aura
# ---------------------------------------------------------------------------
def wnodes(fname, type_, cols):
    with open(os.path.join(NEO, fname), "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh); w.writerow(cols)
        for nid, nd in nodes[type_].items():
            w.writerow([nid] + [nd.get(c, "") for c in cols[1:]])
wnodes("persons.csv", "Person", ["cnic"] + PFEATS + ["name", "district"])
wnodes("companies.csv", "Company", ["ntn", "name", "business", "capital"])
wnodes("vehicles.csv", "Vehicle", ["reg", "make", "model", "cc", "value"])
wnodes("properties.csv", "Property", ["pid", "type", "district", "market_value", "owners"])
wnodes("accounts.csv", "BankAccount", ["iban", "bank", "balance"])
wnodes("securities.csv", "Securities", ["cdc", "scrip", "value"])
with open(os.path.join(NEO, "edges.csv"), "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh); w.writerow(["src", "src_type", "rel", "dst", "dst_type"])
    for st, sid, typ, dt, did, _ in edges:
        w.writerow([sid, st, typ, did, dt])
with open(os.path.join(NEO, "load.cypher"), "w", encoding="utf-8") as fh:
    fh.write("""// Neo4j Aura load script — run after `:auto USING PERIODIC COMMIT` style imports
// Place the CSVs in the import folder (or use Aura's Data Importer).
CREATE CONSTRAINT IF NOT EXISTS FOR (p:Person)  REQUIRE p.cnic IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (c:Company) REQUIRE c.ntn  IS UNIQUE;

LOAD CSV WITH HEADERS FROM 'file:///persons.csv' AS r
CREATE (:Person {cnic:r.cnic, name:r.name, district:r.district,
  declared_income:toFloat(r.declared_income), bank_balance:toFloat(r.bank_balance),
  vehicle_value:toFloat(r.vehicle_value), property_value:toFloat(r.property_value)});
LOAD CSV WITH HEADERS FROM 'file:///companies.csv' AS r
CREATE (:Company {ntn:r.ntn, name:r.name, business:r.business});
LOAD CSV WITH HEADERS FROM 'file:///vehicles.csv' AS r
CREATE (:Vehicle {reg:r.reg, make:r.make, model:r.model, value:toFloat(r.value)});
LOAD CSV WITH HEADERS FROM 'file:///properties.csv' AS r
CREATE (:Property {pid:r.pid, type:r.type, market_value:toFloat(r.market_value)});

// Relationships (match the unified edges.csv; route by src_type/dst_type/rel)
LOAD CSV WITH HEADERS FROM 'file:///edges.csv' AS r
CALL apoc.do.case([
  r.rel='OWNS' AND r.src_type='Person',  'MATCH (a:Person{cnic:$s}),(b) WHERE b.reg=$d OR b.pid=$d MERGE (a)-[:OWNS]->(b)',
  r.rel='DIRECTOR_OF', 'MATCH (a:Person{cnic:$s}),(c:Company{ntn:$d}) MERGE (a)-[:DIRECTOR_OF]->(c)',
  r.rel='FAMILY_OF',   'MATCH (a:Person{cnic:$s}),(b:Person{cnic:$d}) MERGE (a)-[:FAMILY_OF]->(b)'
], '', {s:r.src, d:r.dst}) YIELD value RETURN count(*);
""")

# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------
n_nodes = sum(len(nodes[t]) for t in nodes)
print("\n" + "=" * 60)
print("KNOWLEDGE GRAPH BUILT")
print("=" * 60)
print(f"Nodes: {n_nodes:,}")
for t in nodes:
    print(f"   {t:<12} {len(nodes[t]):>9,}")
print(f"Edges: {len(edges):,}")
ec = Counter(e[2] for e in edges)
for t, n in ec.items():
    print(f"   {t:<12} {n:>9,}")

# adjacency for demo traversals
print("\nBuilding adjacency for demos…")
out_adj = defaultdict(list)   # (type,id) -> [(rel,(type,id))]
in_adj = defaultdict(list)
for st, sid, typ, dt, did, pr in edges:
    out_adj[(st, sid)].append((typ, (dt, did)))
    in_adj[(dt, did)].append((typ, (st, sid)))

print("\n--- DEMO 1: BENAMI (man hides luxury cars under family) ---")
for c, lab in labels.items():
    if lab["archetype"] == "benami" and lab["true_wealth_level"] == "ultra":
        fronts = [(rel, n) for rel, n in out_adj[("Person", c)] if rel == "FAMILY_OF"]
        cars = []
        for _, (t, fid) in fronts:
            for rel, (vt, vid) in out_adj[(t, fid)]:
                if rel == "OWNS" and vt == "Vehicle":
                    cars.append((fid, nodes["Vehicle"][vid]))
        if len(cars) >= 2:
            print(f"Person {P[c]['name']} ({c}) declared PKR {int(P[c]['declared_income']):,}, "
                  f"own vehicles: {P[c]['n_vehicles']}")
            for fid, v in cars[:4]:
                print(f"   FAMILY_OF -> {P[fid]['name']} OWNS {v['make']} {v['model']} (PKR {int(v['value']):,})")
            break

print("\n--- DEMO 2: SHELL (assets via company directorship) ---")
for c, lab in labels.items():
    if lab["archetype"] == "shell":
        comps = [n for rel, n in out_adj[("Person", c)] if rel == "DIRECTOR_OF"]
        for (_, ntn) in comps:
            assets = [(vt, vid) for rel, (vt, vid) in out_adj[("Company", ntn)] if rel in ("OWNS", "HOLDS")]
            if assets:
                print(f"Person {P[c]['name']} ({c}) declared PKR {int(P[c]['declared_income']):,}")
                print(f"   DIRECTOR_OF -> Company {nodes['Company'][ntn]['name']} ({ntn})")
                for vt, vid in assets[:4]:
                    nd = nodes[vt][vid]
                    print(f"      Company OWNS {vt}: {nd.get('make', nd.get('type',''))} "
                          f"(PKR {int(nd.get('value', nd.get('market_value',0))):,})")
                break
        else:
            continue
        break

print("\n--- DEMO 3: RING (co-owned property clique) ---")
for pid, nd in nodes["Property"].items():
    if nd["owners"] >= 3:
        owners = [n for rel, n in in_adj[("Property", pid)] if rel == "OWNS"]
        persons = [oid for (ot, oid) in owners if ot == "Person"]
        if len(persons) >= 3:
            print(f"Property {pid.split('|')[0]} ({nd['type']}, {nd['district']}, "
                  f"PKR {int(nd['market_value']):,}) co-owned by {len(persons)} people:")
            for oid in persons[:5]:
                lab = labels.get(oid, {})
                print(f"   {P[oid]['name']} ({oid}) declared PKR {int(P[oid]['declared_income']):,} "
                      f"[{lab.get('true_compliance_band','?')}]")
            break

print("\nOutputs: output/kg_nodes.csv, output/kg_edges.csv, neo4j/*.csv, neo4j/load.cypher")
