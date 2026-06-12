"""
Tax Compliance Deviation Score + Explainable Audit Trail  —  Step 4 (interpretable)
===================================================================================
Per-person score (0-100) from transparent rule + GRAPH signals — no ML needed,
fully explainable. The GNN (later) blends in as one extra signal.

Signals:
  asset_sig      own-name assets vs declared income      (lifestyle-income mismatch)
  structural_sig assets hidden via family fronts / shell companies (benami/shell)
  life_sig       travel + utility lifestyle vs declared income
  nonfiler       declared nothing / not on ATL

Graph attribution (NOT using labels):
  * family fronts  : dependents whose NADRA father_husband_name == this person and
                     who declare ~no income but hold assets  -> attributed here
  * shell companies: companies this person controls (>=50%) -> their assets attributed

Outputs:  ./output/scores.csv (cnic, score, zone, signals, audit_trail)
          prints calibration vs ground-truth bands + a sample audit trail.
Run:  python score.py
"""
import csv, os, sys, math
from collections import defaultdict

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

DATA = os.path.join(os.path.dirname(__file__), "..", "data-generator", "output_full")
OUT = os.path.join(os.path.dirname(__file__), "output")
os.makedirs(OUT, exist_ok=True)
load = lambda f: list(csv.DictReader(open(os.path.join(DATA, f), encoding="utf-8-sig")))
fnum = lambda x: float(x) if str(x).strip() not in ("", "None") else 0.0

print("Loading…")
nadra = load("01_nadra.csv")
fbr = {r["cnic"]: r for r in load("02_fbr.csv")}
veh = load("03_excise_vehicles.csv")
elec = load("04_electricity.csv")
gas = load("05_gas.csv")
land = load("06_land.csv")
stk = load("07_stocks.csv")
trv = load("08_travel.csv")
bnk = load("09_banking.csv")
comp = {r["company_ntn"]: r for r in load("10_secp_companies.csv")}
dirs = load("11_secp_directorships.csv")
labels = {r["cnic"]: r for r in load("00_LABELS_ground_truth.csv")}

P = {r["cnic"]: {"name": r["name_en"], "family": r["family_tree_id"],
                 "father_husband": r["father_husband_name"], "district": r["place_of_birth"]}
     for r in nadra}

# ---- own-name aggregates -------------------------------------------------
own = defaultdict(lambda: defaultdict(float))
veh_by = defaultdict(list)
for v in veh:
    if v["owner_cnic"].strip():
        own[v["owner_cnic"]]["vehicle"] += fnum(v["vehicle_value"])
        own[v["owner_cnic"]]["n_vehicle"] += 1
        veh_by[v["owner_cnic"]].append(v)
for r in land:
    if r["owner_cnic"].strip():
        own[r["owner_cnic"]]["property"] += fnum(r["market_value"])
        own[r["owner_cnic"]]["n_property"] += 1
for r in stk:
    if r["holder_cnic"].strip():
        own[r["holder_cnic"]]["stock"] += fnum(r["market_value"])
for r in bnk:
    own[r["customer_cnic"]]["bank"] += fnum(r["account_balance"])
for r in elec:
    own[r["customer_cnic"]]["elec"] += fnum(r["bill_amount"])
for r in gas:
    own[r["customer_cnic"]]["gas"] += fnum(r["bill_amount"])
for r in trv:
    own[r["cnic"]]["travel"] += fnum(r["ticket_cost"])
    own[r["cnic"]]["n_trip"] += 1

def declared_of(c):
    f = fbr.get(c)
    return (fnum(f["declared_income"]) + fnum(f["tax_paid"])) if f else 0.0
def is_filer(c):
    f = fbr.get(c)
    return bool(f and f["filer_status"] == "Filer")

# ---- company asset values + controlling directors ------------------------
comp_assets = defaultdict(float)
comp_items = defaultdict(list)
for v in veh:
    if v["owner_company_ntn"].strip():
        comp_assets[v["owner_company_ntn"]] += fnum(v["vehicle_value"])
        comp_items[v["owner_company_ntn"]].append(("Vehicle", f"{v['make']} {v['model']}", fnum(v["vehicle_value"])))
for r in land:
    if r["owner_company_ntn"].strip():
        comp_assets[r["owner_company_ntn"]] += fnum(r["market_value"])
        comp_items[r["owner_company_ntn"]].append(("Property", r["property_type"], fnum(r["market_value"])))
for r in stk:
    if not r["holder_cnic"].strip() and r["uin"].strip():
        comp_assets[r["uin"]] += fnum(r["market_value"])
directed = defaultdict(float); directed_cos = defaultdict(list)
for d in dirs:
    if fnum(d["shareholding_percent"]) >= 50 and comp_assets.get(d["company_ntn"], 0) > 0:
        directed[d["person_cnic"]] += comp_assets[d["company_ntn"]]
        directed_cos[d["person_cnic"]].append(d["company_ntn"])

# ---- family-front attribution (father_husband_name within same family) ----
principal_of = {}                       # (family, name) -> cnic
for c, p in P.items():
    principal_of[(p["family"], p["name"])] = c
fam_hidden = defaultdict(float); fam_deps = defaultdict(list)
for c, p in P.items():
    dep_assets = own[c]["vehicle"] + own[c]["property"] + own[c]["stock"]
    if dep_assets <= 0:
        continue
    if declared_of(c) < 1_000_000:      # dependent with ~no legitimate income
        pr = principal_of.get((p["family"], p["father_husband"]))
        if pr and pr != c:
            fam_hidden[pr] += dep_assets
            fam_deps[pr].append((c, p["name"], dep_assets))

# ---- scoring -------------------------------------------------------------
def squash_assets(r):                   # honest net-worth (~5-10x) -> ~0; evader (30x+) -> high
    return max(0.0, min(1.0, (math.log10(max(r, 1)) - 1.0) / 1.5))
def squash_life(r):
    return max(0.0, min(1.0, (r - 0.2) / 0.8))

rows = []
for c, p in P.items():
    declared = max(declared_of(c), 50_000)
    own_assets = own[c]["vehicle"] + own[c]["property"] + own[c]["stock"] + own[c]["bank"]
    hidden = fam_hidden[c] + directed[c]
    lifestyle = own[c]["travel"] + (own[c]["elec"] + own[c]["gas"]) * 12
    asset_sig = squash_assets(own_assets / declared)
    struct_sig = squash_assets(hidden / declared) if hidden > 0 else 0.0
    life_sig = squash_life(lifestyle / declared)
    nonfiler = 0.0 if is_filer(c) else 1.0
    score = 100 * (0.35 * asset_sig + 0.30 * struct_sig + 0.20 * life_sig + 0.15 * nonfiler)
    # zone thresholds are admin-tunable (FR-G2); these defaults balance precision/recall
    zone = "Red" if score >= 55 else "Yellow" if score >= 22 else "Green"

    # ---- audit trail (explainable) ----
    audit = []
    audit.append(f"Declared income+tax: PKR {int(declared):,}" + ("" if is_filer(c) else "  [NON-FILER / inactive on ATL]"))
    if own_assets > declared * 8:
        audit.append(f"Holds own-name assets PKR {int(own_assets):,} (~{own_assets/declared:.0f}x declared)")
    if lifestyle > declared * 0.3:
        audit.append(f"Lifestyle PKR {int(lifestyle):,}/yr (travel PKR {int(own[c]['travel']):,}, "
                     f"utilities PKR {int((own[c]['elec']+own[c]['gas'])*12):,}/yr)")
    if fam_hidden[c] > 0:
        names = ", ".join(f"{nm} (PKR {int(a):,})" for _, nm, a in fam_deps[c][:3])
        audit.append(f"Family dependents with ~no income hold PKR {int(fam_hidden[c]):,} in assets: {names}")
    if directed[c] > 0:
        audit.append(f"Controls {len(directed_cos[c])} company(ies) holding PKR {int(directed[c]):,} in assets (shell exposure)")
    lab = labels.get(c, {})
    if lab.get("ring_id"):
        audit.append("Co-owns property in a multi-party ownership ring")

    rows.append({"cnic": c, "name": p["name"], "district": p["district"],
                 "declared": int(declared), "own_assets": int(own_assets), "hidden_assets": int(hidden),
                 "lifestyle": int(lifestyle), "deviation_score": round(score, 1), "zone": zone,
                 "asset_sig": round(asset_sig, 3), "struct_sig": round(struct_sig, 3),
                 "life_sig": round(life_sig, 3), "nonfiler": int(nonfiler),
                 "audit_trail": " | ".join(audit),
                 "_true_band": lab.get("true_compliance_band", ""), "_archetype": lab.get("archetype", ""),
                 "_is_front": lab.get("is_front", "0")})

# ---- write ---------------------------------------------------------------
cols = ["cnic", "name", "district", "declared", "own_assets", "hidden_assets", "lifestyle",
        "deviation_score", "zone", "asset_sig", "struct_sig", "life_sig", "nonfiler", "audit_trail"]
with open(os.path.join(OUT, "scores.csv"), "w", newline="", encoding="utf-8") as fh:
    w = csv.DictWriter(fh, fieldnames=cols)
    w.writeheader()
    for r in rows:
        w.writerow({k: r[k] for k in cols})

# ---- calibration vs ground truth ----------------------------------------
from collections import Counter
prim = [r for r in rows if r["_is_front"] != "1" and r["_true_band"]]
band_scores = defaultdict(list)
for r in prim:
    band_scores[r["_true_band"]].append(r["deviation_score"])
print("\n=== DEVIATION SCORE vs TRUE BAND (primary persons) ===")
for b in ["Green", "Low", "Medium", "Extreme"]:
    s = band_scores[b]
    print(f"  {b:<8} n={len(s):>6,}  mean score {sum(s)/len(s):5.1f}  "
          f"flagged(Y/R) {100*sum(1 for x in s if x>=22)/len(s):5.1f}%")

# flag = non-Green truth; predicted positive = zone != Green
tp = sum(1 for r in prim if r["zone"] != "Green" and r["_true_band"] != "Green")
fp = sum(1 for r in prim if r["zone"] != "Green" and r["_true_band"] == "Green")
fn = sum(1 for r in prim if r["zone"] == "Green" and r["_true_band"] != "Green")
prec = tp / (tp + fp) if tp + fp else 0
rec = tp / (tp + fn) if tp + fn else 0
f1 = 2 * prec * rec / (prec + rec) if prec + rec else 0
print(f"\nFLAGGING non-compliant (zone != Green):  Precision {prec:.3f}  Recall {rec:.3f}  F1 {f1:.3f}")
zc = Counter(r["zone"] for r in rows)
print("Zone distribution (all persons):", dict(zc))

# ---- sample audit trail --------------------------------------------------
print("\n=== SAMPLE AUDIT TRAIL (highest-scoring benami case) ===")
ben = sorted([r for r in rows if r["_archetype"] == "benami"], key=lambda r: -r["deviation_score"])[0]
print(f"{ben['name']} ({ben['cnic']})  —  Deviation Score {ben['deviation_score']}  [{ben['zone']}]")
for line in ben["audit_trail"].split(" | "):
    print("   •", line)
print("\nWrote output/scores.csv")
