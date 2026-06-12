"""
GNN Explainer  —  Step 5 (E3: which graph neighbours drove the flag)
====================================================================
Gradient × input saliency over the trained heterogeneous GNN. For a flagged
person it attributes the anomaly score to the specific 1-2 hop neighbours
(family members, owned/hidden assets, directed companies) that caused it —
turning the black-box GNN score into graph evidence for the audit trail.

Fast (one backward pass) -> usable on-demand per person in the API.
Run:  python explain.py            (demos a benami + a shell case)
      python explain.py <CNIC>     (explain a specific person)
"""
import csv, os, sys, math
from collections import defaultdict, deque
import numpy as np
import torch
import torch.nn.functional as F
from torch.nn import Linear
from torch_geometric.data import HeteroData
from torch_geometric.nn import HeteroConv, SAGEConv
import torch_geometric.transforms as T

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HERE = os.path.dirname(__file__)
GRAPH = os.path.join(HERE, "..", "graph", "output")
DATA = os.path.join(HERE, "..", "data-generator", "output_full")
dev = torch.device("cuda" if torch.cuda.is_available() else "cpu")

PREF2TYPE = {"P": "Person", "C": "Company", "V": "Vehicle", "Pr": "Property",
             "B": "BankAccount", "S": "Securities"}
PFEATS = ["declared_income", "tax_paid", "is_filer", "n_vehicles", "vehicle_value",
          "n_properties", "property_value", "bank_balance", "bank_turnover", "elec_bill",
          "gas_bill", "stock_value", "dividend", "travel_spend", "travel_trips", "n_directorships"]
MON = {"declared_income", "tax_paid", "vehicle_value", "property_value", "bank_balance",
       "bank_turnover", "elec_bill", "gas_bill", "stock_value", "dividend", "travel_spend"}

# ---- load nodes (features + descriptions) --------------------------------
idx = {t: {} for t in PREF2TYPE.values()}
feats = {t: [] for t in PREF2TYPE.values()}
desc = {}                                            # node_id -> (type, label, value)
person_ids = []
with open(os.path.join(GRAPH, "kg_nodes.csv"), encoding="utf-8") as fh:
    for r in csv.DictReader(fh):
        t, nid = r["type"], r["node_id"]
        idx[t][nid] = len(feats[t])
        desc[nid] = (t, r["name"], float(r["value"]))
        if t == "Person":
            feats[t].append([math.log1p(float(r[k])) if k in MON else float(r[k]) for k in PFEATS])
            person_ids.append(nid[2:])
        else:
            feats[t].append([math.log1p(float(r["value"]))])
pidx = {c: i for i, c in enumerate(person_ids)}

data = HeteroData()
for t in PREF2TYPE.values():
    x = np.asarray(feats[t], dtype=np.float32)
    mu, sd = x.mean(0, keepdims=True), x.std(0, keepdims=True) + 1e-6
    data[t].x = torch.tensor((x - mu) / sd, dtype=torch.float)

# ---- load edges + string adjacency (for neighbourhood walk) --------------
ebuf = {}
adj = defaultdict(list)                              # node_id -> [(rel, neighbour_id)]
with open(os.path.join(GRAPH, "kg_edges.csv"), encoding="utf-8") as fh:
    for r in csv.DictReader(fh):
        s, rel, d = r["src"], r["type"], r["dst"]
        st, dt = PREF2TYPE[s.split(":", 1)[0]], PREF2TYPE[d.split(":", 1)[0]]
        si, di = idx[st].get(s), idx[dt].get(d)
        if si is None or di is None:
            continue
        ebuf.setdefault((st, rel, dt), ([], []))
        ebuf[(st, rel, dt)][0].append(si); ebuf[(st, rel, dt)][1].append(di)
        adj[s].append((rel, d)); adj[d].append((rel, s))
for (st, rel, dt), (ss, dd) in ebuf.items():
    data[st, rel, dt].edge_index = torch.tensor([ss, dd], dtype=torch.long)
data = T.ToUndirected(merge=False)(data)

# ---- model + weights -----------------------------------------------------
class HGNN(torch.nn.Module):
    def __init__(self, edge_types, hidden=64, out=2):
        super().__init__()
        self.c1 = HeteroConv({et: SAGEConv((-1, -1), hidden) for et in edge_types}, aggr="sum")
        self.c2 = HeteroConv({et: SAGEConv((-1, -1), hidden) for et in edge_types}, aggr="sum")
        self.lin = Linear(hidden, out)
    def forward(self, x_dict, eidx):
        h = self.c1(x_dict, eidx); h = {k: F.relu(v) for k, v in h.items()}
        h = self.c2(h, eidx)
        return self.lin(h["Person"])

model = HGNN(data.edge_types).to(dev)
data = data.to(dev)
# lazy params need a forward to materialise before loading weights
with torch.no_grad():
    model(data.x_dict, data.edge_index_dict)
model.load_state_dict(torch.load(os.path.join(HERE, "output", "model.pt"), map_location=dev))
model.eval()

def short(nid):
    t, label, val = desc[nid]
    if t == "Person":
        return f"Person {label}"
    if t == "Company":
        return f"Company {label}"
    money = f" PKR {int(val):,}" if val else ""
    return f"{t} {label}{money}"

def explain(cnic, topk=6):
    if cnic not in pidx:
        print("Unknown CNIC"); return
    p = pidx[cnic]
    # one backward pass: saliency of the anomaly logit w.r.t. every node's features
    xg = {t: data[t].x.clone().requires_grad_(True) for t in data.node_types}
    logits = model(xg, data.edge_index_dict)
    prob = F.softmax(logits, 1)[p, 1]
    margin = logits[p, 1] - logits[p, 0]            # pre-softmax target (not saturated)
    model.zero_grad()
    margin.backward()
    sal = {t: (xg[t] * xg[t].grad).sum(1).detach().cpu().numpy() for t in xg}   # signed contribution

    # 2-hop neighbourhood of p, remembering hop distance + first relation
    start = f"P:{cnic}"
    seen = {start: (0, None)}; q = deque([start])
    while q:
        cur = q.popleft(); d0, _ = seen[cur]
        if d0 >= 2:
            continue
        for rel, nb in adj[cur]:
            if nb not in seen:
                seen[nb] = (d0 + 1, rel if d0 == 0 else seen[cur][1])
                q.append(nb)
    scored = []
    for nid, (hop, rel) in seen.items():
        if hop == 0:
            continue
        t = desc[nid][0]; li = idx[t][nid]
        scored.append((float(sal[t][li]), hop, rel, nid))
    scored.sort(reverse=True)

    print(f"\nGNN flag explanation for Person {desc[start][1]} ({cnic})")
    print(f"   anomaly probability: {float(prob):.3f}")
    print("   top graph evidence driving the score:")
    for s, hop, rel, nid in scored[:topk]:
        if s <= 0:
            break
        via = f"{rel}" + ("" if hop == 1 else f" → (2-hop)")
        print(f"     +{s:6.3f}  [{via}]  {short(nid)}")

# ---- CLI / demos ---------------------------------------------------------
labels = {r["cnic"]: r for r in csv.DictReader(open(os.path.join(DATA, "00_LABELS_ground_truth.csv"), encoding="utf-8-sig"))}
if len(sys.argv) > 1:
    explain(sys.argv[1])
else:
    # pick a benami principal and a shell principal that the model scores high
    with torch.no_grad():
        prob_all = F.softmax(model(data.x_dict, data.edge_index_dict), 1)[:, 1].cpu().numpy()
    def top_of(arch):
        cands = [(prob_all[pidx[c]], c) for c, l in labels.items()
                 if l["archetype"] == arch and l["is_front"] != "1" and c in pidx]
        return max(cands)[1] if cands else None
    print("=" * 64); print("DEMO — GNNExplainer evidence"); print("=" * 64)
    for arch in ["benami", "shell", "ring"]:
        c = top_of(arch)
        if c:
            print(f"\n### {arch.upper()} case")
            explain(c)
