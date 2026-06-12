"""
Heterogeneous GNN for graph anomaly (tax-evasion) detection  —  Step 4 (the GNN)
================================================================================
A 2-layer heterogeneous GraphSAGE over the knowledge graph. Message passing lets a
Person aggregate signal from FAMILY_OF relatives, OWNED assets, and DIRECTED
companies — so HIDDEN wealth (benami / shell / ring) propagates to the real owner
even though it isn't in that person's own-name features.

Semi-supervised: trained on a labelled split (non-Green vs Green), evaluated on a
held-out test set. Outputs per-person GNN anomaly probability, then FUSES it with
the interpretable rule score into the final Deviation Score.

Run (after torch+PyG installed):  python train_gnn.py
Out: ./output/gnn_scores.csv , ./output/fused_scores.csv , model.pt
"""
import csv, os, sys, math
import numpy as np
import torch
import torch.nn.functional as F
from torch.nn import Linear
from torch_geometric.data import HeteroData
from torch_geometric.nn import HeteroConv, SAGEConv
import torch_geometric.transforms as T
from sklearn.metrics import precision_recall_fscore_support, roc_auc_score

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass
torch.manual_seed(42); np.random.seed(42)

GRAPH = os.path.join(os.path.dirname(__file__), "..", "graph", "output")
DATA = os.path.join(os.path.dirname(__file__), "..", "data-generator", "output_full")
SCOR = os.path.join(os.path.dirname(__file__), "..", "scoring", "output")
OUT = os.path.join(os.path.dirname(__file__), "output")
os.makedirs(OUT, exist_ok=True)
dev = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print("Device:", dev, "|", torch.cuda.get_device_name(0) if torch.cuda.is_available() else "")

PREF2TYPE = {"P": "Person", "C": "Company", "V": "Vehicle", "Pr": "Property",
             "B": "BankAccount", "S": "Securities"}
PFEATS = ["declared_income", "tax_paid", "is_filer", "n_vehicles", "vehicle_value",
          "n_properties", "property_value", "bank_balance", "bank_turnover", "elec_bill",
          "gas_bill", "stock_value", "dividend", "travel_spend", "travel_trips", "n_directorships"]

# ---------------------------------------------------------------------------
# Load nodes -> per-type feature matrices + id->index maps
# ---------------------------------------------------------------------------
print("Loading nodes…")
idx = {t: {} for t in PREF2TYPE.values()}          # type -> {node_id: local_idx}
feats = {t: [] for t in PREF2TYPE.values()}
person_ids = []
MON = {"declared_income", "tax_paid", "vehicle_value", "property_value", "bank_balance",
       "bank_turnover", "elec_bill", "gas_bill", "stock_value", "dividend", "travel_spend"}
with open(os.path.join(GRAPH, "kg_nodes.csv"), encoding="utf-8") as fh:
    for r in csv.DictReader(fh):
        t = r["type"]; nid = r["node_id"]
        idx[t][nid] = len(feats[t])
        if t == "Person":
            row = [math.log1p(float(r[k])) if k in MON else float(r[k]) for k in PFEATS]
            feats[t].append(row)
            person_ids.append(nid[2:])             # strip "P:"
        else:
            feats[t].append([math.log1p(float(r["value"]))])

data = HeteroData()
for t in PREF2TYPE.values():
    x = np.asarray(feats[t], dtype=np.float32)
    if x.shape[0] == 0:
        continue
    # standardize columns
    mu, sd = x.mean(0, keepdims=True), x.std(0, keepdims=True) + 1e-6
    data[t].x = torch.tensor((x - mu) / sd, dtype=torch.float)
print("Node types:", {t: data[t].num_nodes for t in data.node_types})

# ---------------------------------------------------------------------------
# Load edges -> edge_index per (src_type, REL, dst_type)
# ---------------------------------------------------------------------------
print("Loading edges…")
ebuf = {}
with open(os.path.join(GRAPH, "kg_edges.csv"), encoding="utf-8") as fh:
    for r in csv.DictReader(fh):
        s, rel, d = r["src"], r["type"], r["dst"]
        st = PREF2TYPE[s.split(":", 1)[0]]; dt = PREF2TYPE[d.split(":", 1)[0]]
        si = idx[st].get(s); di = idx[dt].get(d)
        if si is None or di is None:
            continue
        ebuf.setdefault((st, rel, dt), ([], []))
        ebuf[(st, rel, dt)][0].append(si); ebuf[(st, rel, dt)][1].append(di)
for (st, rel, dt), (ss, dd) in ebuf.items():
    data[st, rel, dt].edge_index = torch.tensor([ss, dd], dtype=torch.long)
data = T.ToUndirected(merge=False)(data)           # add reverse edges for message flow
print("Edge types:", len(data.edge_types))

# ---------------------------------------------------------------------------
# Labels (binary: non-Green = 1) + train/val/test masks on Person
# ---------------------------------------------------------------------------
labels = {r["cnic"]: r for r in csv.DictReader(open(os.path.join(DATA, "00_LABELS_ground_truth.csv"), encoding="utf-8-sig"))}
y = np.zeros(len(person_ids), dtype=np.int64)
for i, c in enumerate(person_ids):
    lab = labels.get(c, {})
    y[i] = 0 if lab.get("true_compliance_band", "Green") == "Green" else 1
data["Person"].y = torch.tensor(y)
n = len(person_ids); perm = np.random.permutation(n)
tr, va = int(0.6 * n), int(0.8 * n)
mask = lambda ids: torch.zeros(n, dtype=torch.bool).index_fill_(0, torch.tensor(ids, dtype=torch.long), True)
train_m, val_m, test_m = mask(perm[:tr]), mask(perm[tr:va]), mask(perm[va:])
print(f"Persons {n:,} | positives {y.sum():,} ({100*y.mean():.1f}%) | train/val/test "
      f"{train_m.sum()}/{val_m.sum()}/{test_m.sum()}")

# ---------------------------------------------------------------------------
# Model
# ---------------------------------------------------------------------------
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
opt = torch.optim.Adam(model.parameters(), lr=0.01, weight_decay=5e-4)
w = torch.tensor([1.0, float((y == 0).sum()) / max(int((y == 1).sum()), 1)], dtype=torch.float, device=dev)

def run_eval(m):
    model.eval()
    with torch.no_grad():
        logits = model(data.x_dict, data.edge_index_dict)
        prob = F.softmax(logits, 1)[:, 1].cpu().numpy()
    yt = y[m.cpu().numpy()]; yp = prob[m.cpu().numpy()]
    p, r, f, _ = precision_recall_fscore_support(yt, (yp >= 0.5).astype(int), average="binary", zero_division=0)
    auc = roc_auc_score(yt, yp) if len(set(yt)) > 1 else 0.5
    return p, r, f, auc, prob

print("\nTraining…")
best = 0
for ep in range(1, 41):
    model.train(); opt.zero_grad()
    logits = model(data.x_dict, data.edge_index_dict)
    loss = F.cross_entropy(logits[train_m], data["Person"].y[train_m], weight=w)
    loss.backward(); opt.step()
    if ep % 5 == 0 or ep == 1:
        p, r, f, auc, _ = run_eval(val_m)
        print(f"  ep {ep:2d}  loss {loss.item():.3f}  val P {p:.3f} R {r:.3f} F1 {f:.3f} AUC {auc:.3f}")

# ---------------------------------------------------------------------------
# Final test metrics + outputs
# ---------------------------------------------------------------------------
p, r, f, auc, prob = run_eval(test_m)
print("\n=== GNN TEST PERFORMANCE (held-out) ===")
print(f"  Precision {p:.3f}  Recall {r:.3f}  F1 {f:.3f}  AUC {auc:.3f}")

with open(os.path.join(OUT, "gnn_scores.csv"), "w", newline="", encoding="utf-8") as fh:
    w_ = csv.writer(fh); w_.writerow(["cnic", "gnn_anomaly_prob"])
    for c, pr in zip(person_ids, prob):
        w_.writerow([c, round(float(pr), 4)])
torch.save(model.state_dict(), os.path.join(OUT, "model.pt"))

# ---- Fuse with the interpretable rule score ------------------------------
rule = {r["cnic"]: float(r["deviation_score"]) for r in csv.DictReader(open(os.path.join(SCOR, "scores.csv"), encoding="utf-8"))}
gnnp = {c: float(pr) for c, pr in zip(person_ids, prob)}
fused_rows, yt, yf = [], [], []
test_set = set(np.array(person_ids)[test_m.cpu().numpy()])
for c in person_ids:
    rs = rule.get(c, 0.0) / 100.0
    gs = gnnp.get(c, 0.0)
    fused = 100 * (0.5 * rs + 0.5 * gs)
    zone = "Red" if fused >= 55 else "Yellow" if fused >= 22 else "Green"
    fused_rows.append((c, round(fused, 1), zone, round(rule.get(c, 0), 1), round(gnnp.get(c, 0), 4)))
    if c in test_set:
        yt.append(0 if labels.get(c, {}).get("true_compliance_band", "Green") == "Green" else 1)
        yf.append(1 if fused >= 22 else 0)
with open(os.path.join(OUT, "fused_scores.csv"), "w", newline="", encoding="utf-8") as fh:
    w_ = csv.writer(fh); w_.writerow(["cnic", "fused_score", "zone", "rule_score", "gnn_prob"])
    w_.writerows(fused_rows)
fp_, fr_, ff_, _ = precision_recall_fscore_support(yt, yf, average="binary", zero_division=0)
print("\n=== FUSED (GNN + rule) on test set, flag = score>=22 ===")
print(f"  Precision {fp_:.3f}  Recall {fr_:.3f}  F1 {ff_:.3f}")
print("\nWrote output/gnn_scores.csv, output/fused_scores.csv, output/model.pt")
