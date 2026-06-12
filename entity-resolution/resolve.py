"""
Entity Resolution pipeline  —  Step 2
=====================================
Links fragmented identity 'mentions' across all 10 person-bearing silos into
canonical persons, despite missing/typo'd CNICs and Urdu/English name variants.

Method (unsupervised, rule + fuzzy, scalable to ~1.4M mentions via union-find):
  R1  exact CNIC            -> strong block
  R2  shared phone + name   -> reinforce
  R3  shared address + name -> recovers MISSING/typo'd CNIC cases
  R4  fuzzy name within city block (light) -> catches no-cnic, no-address tails

Evaluation: pairwise precision / recall / F1 vs 12_er_ground_truth.csv
(overall, on the HARD subset = records lacking a clean usable CNIC, and per silo).

Run:  python resolve.py
Out:  ./output/resolved_entities.csv  +  ./output/er_report.txt
"""
import csv, os, sys, re
from collections import defaultdict, Counter

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

try:                                   # fast fuzzy if available, else stdlib
    from rapidfuzz.fuzz import ratio as _r
    sim = lambda a, b: _r(a, b) / 100.0
except Exception:
    from difflib import SequenceMatcher
    sim = lambda a, b: SequenceMatcher(None, a, b).ratio()

DATA = os.path.join(os.path.dirname(__file__), "..", "data-generator", "output_full")
OUT = os.path.join(os.path.dirname(__file__), "output")
os.makedirs(OUT, exist_ok=True)
load = lambda f: list(csv.DictReader(open(os.path.join(DATA, f), encoding="utf-8-sig")))

# (source, file, key_col, cnic_col, name_col, addr_col, phone_col)
SILOS = [
    ("NADRA", "01_nadra.csv", "cnic", "cnic", "name_en", "present_address", "mobile"),
    ("FBR", "02_fbr.csv", "cnic", "cnic", "taxpayer_name", "", ""),
    ("VEH", "03_excise_vehicles.csv", "reg_number", "owner_cnic", "owner_name", "owner_present_address", ""),
    ("ELE", "04_electricity.csv", "consumer_id", "customer_cnic", "customer_name", "service_address", ""),
    ("GAS", "05_gas.csv", "consumer_no", "customer_cnic", "customer_name", "service_address", ""),
    ("LND", "06_land.csv", "fard_registry_no", "owner_cnic", "owner_name", "", ""),
    ("STK", "07_stocks.csv", "cdc_investor_account", "holder_cnic", "holder_name", "", ""),
    ("TRV", "08_travel.csv", "passport_no", "cnic", "full_name", "", ""),
    ("BNK", "09_banking.csv", "iban", "customer_cnic", "customer_name", "customer_address", "mobile"),
    ("DIR", "11_secp_directorships.csv", None, "person_cnic", "person_name", "", ""),
]

HONORIFIC = {"mohammad": "muhammad", "mohammed": "muhammad", "muhammed": "muhammad",
             "mohd": "muhammad", "md": "muhammad", "m": "muhammad", "mr": "", "mrs": ""}

def norm_name(s):
    s = s.lower().replace(".", " ")
    toks = [HONORIFIC.get(t, t) for t in re.split(r"\s+", s) if t]
    toks = [t for t in toks if t]
    return " ".join(toks)

def norm_addr(s):
    return re.sub(r"[^a-z0-9]+", " ", s.lower()).strip()

def norm_cnic(s):
    d = re.sub(r"\D", "", s)
    return d if len(d) == 13 else ""

def norm_phone(s):
    d = re.sub(r"\D", "", s)
    return d if len(d) == 11 else ""

# ---------------------------------------------------------------------------
# Load ground truth + mentions
# ---------------------------------------------------------------------------
print("Loading ground truth…")
gt = {}                                # (source, record_key) -> true identity cnic
for r in load("12_er_ground_truth.csv"):
    gt[(r["source"], r["record_key"])] = r["true_identity_cnic"]

print("Loading mentions…")
mentions = []                          # list of dicts
seen_passport = set()
for src, fn, kcol, ccol, ncol, acol, pcol in SILOS:
    for r in load(fn):
        if src == "TRV":               # collapse to one mention per traveller
            if r["passport_no"] in seen_passport:
                continue
            seen_passport.add(r["passport_no"])
        key = r[kcol] if kcol else (r["company_ntn"] + "|" + r["person_cnic"])
        mentions.append({
            "mid": f"{src}:{key}", "src": src,
            "cnic": norm_cnic(r[ccol]) if ccol else "",
            "raw_cnic": r[ccol] if ccol else "",
            "name": norm_name(r[ncol]),
            "addr": norm_addr(r[acol]) if acol else "",
            "phone": norm_phone(r[pcol]) if pcol else "",
            "truth": gt.get((src, key), ""),
        })
N = len(mentions)
print(f"  {N:,} mentions loaded")

# ---------------------------------------------------------------------------
# Union-Find
# ---------------------------------------------------------------------------
parent = list(range(N))
def find(x):
    while parent[x] != x:
        parent[x] = parent[parent[x]]
        x = parent[x]
    return x
def union(a, b):
    ra, rb = find(a), find(b)
    if ra != rb:
        parent[ra] = rb

def block_union(key_fn, gate=None, gate_thr=0.0):
    """Group mentions by key_fn; union within group (optionally gated by name sim)."""
    blocks = defaultdict(list)
    for i, m in enumerate(mentions):
        k = key_fn(m)
        if k:
            blocks[k].append(i)
    unions = 0
    for idxs in blocks.values():
        if len(idxs) < 2:
            continue
        if gate is None:
            base = idxs[0]
            for j in idxs[1:]:
                union(base, j); unions += 1
        else:                          # union pairs passing the name-sim gate
            if len(idxs) > 200:        # guard against O(n^2) on huge blocks
                continue
            for a in range(len(idxs)):
                for b in range(a + 1, len(idxs)):
                    ca, cb = mentions[idxs[a]]["cnic"], mentions[idxs[b]]["cnic"]
                    if ca and cb and ca != cb:     # never merge distinct CNICs (authoritative)
                        continue
                    if sim(mentions[idxs[a]][gate], mentions[idxs[b]][gate]) >= gate_thr:
                        union(idxs[a], idxs[b]); unions += 1
    return unions

print("R1 exact CNIC…");      print("   unions:", block_union(lambda m: m["cnic"]))
print("R2 phone + name…");    print("   unions:", block_union(lambda m: m["phone"], gate="name", gate_thr=0.55))
print("R3 address + name…");  print("   unions:", block_union(lambda m: m["addr"], gate="name", gate_thr=0.60))

# R4 safe tail: a CNIC-less record links to a cnic-bearing cluster ONLY if its
# normalized name is UNIQUE among resolved clusters (avoids merging same-named people).
print("R4 unique-name (cnic-less tails)…")
name_clusters = defaultdict(set)
for i, m in enumerate(mentions):
    if m["cnic"] and m["name"]:
        name_clusters[m["name"]].add(find(i))
r4 = 0
for i, m in enumerate(mentions):
    if not m["cnic"] and m["name"]:
        cl = name_clusters.get(m["name"])
        if cl and len(cl) == 1:
            union(i, next(iter(cl))); r4 += 1
print("   unions:", r4)

# ---------------------------------------------------------------------------
# Components -> canonical person ids
# ---------------------------------------------------------------------------
comp = {}
for i in range(N):
    comp.setdefault(find(i), len(comp))
pred = [comp[find(i)] for i in range(N)]
print(f"\nResolved into {len(comp):,} canonical entities (truth has "
      f"{len(set(m['truth'] for m in mentions if m['truth'])):,} identities).")

# ---------------------------------------------------------------------------
# Pairwise precision / recall / F1  (contingency-table method, O(n))
# ---------------------------------------------------------------------------
def pairs(c): return c * (c - 1) // 2
def pairwise_metrics(idx_subset):
    pred_sizes = Counter(pred[i] for i in idx_subset)
    truth_sizes = Counter(mentions[i]["truth"] for i in idx_subset)
    cell = Counter((pred[i], mentions[i]["truth"]) for i in idx_subset)
    tp = sum(pairs(c) for c in cell.values())
    pred_pairs = sum(pairs(c) for c in pred_sizes.values())
    truth_pairs = sum(pairs(c) for c in truth_sizes.values())
    P = tp / pred_pairs if pred_pairs else 1.0
    R = tp / truth_pairs if truth_pairs else 1.0
    F = 2 * P * R / (P + R) if (P + R) else 0.0
    return P, R, F

# only evaluate mentions whose truth is a PERSON (exclude COMPANY: entities)
person_idx = [i for i in range(N) if mentions[i]["truth"] and not mentions[i]["truth"].startswith("COMPANY:")]
# HARD subset: records whose own CNIC is blank or does NOT equal their true identity (typo/missing)
hard_idx = [i for i in person_idx
            if mentions[i]["cnic"] != re.sub(r"\D", "", mentions[i]["truth"])]

Po, Ro, Fo = pairwise_metrics(person_idx)
Ph, Rh, Fh = pairwise_metrics(hard_idx)

report = []
def line(s=""):
    report.append(s); print(s)

line("\n" + "=" * 64)
line("ENTITY RESOLUTION — EVALUATION")
line("=" * 64)
line(f"Mentions: {N:,}  |  Canonical entities: {len(comp):,}")
line(f"Person mentions evaluated: {len(person_idx):,}")
line(f"HARD subset (missing/typo CNIC): {len(hard_idx):,} "
     f"({100*len(hard_idx)/len(person_idx):.1f}% of persons)")
line("")
line(f"{'Set':<26}{'Precision':>11}{'Recall':>10}{'F1':>9}")
line("-" * 56)
line(f"{'OVERALL (all persons)':<26}{Po:>11.4f}{Ro:>10.4f}{Fo:>9.4f}")
line(f"{'HARD (no clean CNIC)':<26}{Ph:>11.4f}{Rh:>10.4f}{Fh:>9.4f}")

# baseline: CNIC-join only (no fuzzy/address recovery)
base_pred = {}
bp = []
for i, m in enumerate(mentions):
    k = m["cnic"] if m["cnic"] else f"_solo{i}"
    base_pred.setdefault(k, len(base_pred))
    bp.append(base_pred[k])
def pairwise_with(predarr, idx_subset):
    ps = Counter(predarr[i] for i in idx_subset)
    ts = Counter(mentions[i]["truth"] for i in idx_subset)
    cell = Counter((predarr[i], mentions[i]["truth"]) for i in idx_subset)
    tp = sum(pairs(c) for c in cell.values())
    pp = sum(pairs(c) for c in ps.values()); tpр = sum(pairs(c) for c in ts.values())
    P = tp / pp if pp else 1.0; R = tp / tpр if tpр else 1.0
    return P, R, (2*P*R/(P+R) if P+R else 0)
bP, bR, bF = pairwise_with(bp, person_idx)
line("")
line(f"{'BASELINE CNIC-join only':<26}{bP:>11.4f}{bR:>10.4f}{bF:>9.4f}")
line(f"  -> ER lifts recall {bR:.3f} -> {Ro:.3f}  (+{100*(Ro-bR):.1f} pts)")

with open(os.path.join(OUT, "er_report.txt"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(report))

# write resolved mapping
with open(os.path.join(OUT, "resolved_entities.csv"), "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh); w.writerow(["mid", "source", "person_id", "true_identity_cnic"])
    for i, m in enumerate(mentions):
        w.writerow([m["mid"], m["src"], pred[i], m["truth"]])
print("\nWrote output/resolved_entities.csv and output/er_report.txt")
