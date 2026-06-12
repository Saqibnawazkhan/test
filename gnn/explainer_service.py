"""
Importable GNN explainer service — loads the graph + trained model ONCE (lazily)
and returns JSON-able per-person graph evidence. Used by the FastAPI backend.
"""
import csv, os, math
from collections import defaultdict, deque

HERE = os.path.dirname(__file__)
GRAPH = os.path.join(HERE, "..", "graph", "output")
PREF2TYPE = {"P": "Person", "C": "Company", "V": "Vehicle", "Pr": "Property",
             "B": "BankAccount", "S": "Securities"}
PFEATS = ["declared_income", "tax_paid", "is_filer", "n_vehicles", "vehicle_value",
          "n_properties", "property_value", "bank_balance", "bank_turnover", "elec_bill",
          "gas_bill", "stock_value", "dividend", "travel_spend", "travel_trips", "n_directorships"]
MON = {"declared_income", "tax_paid", "vehicle_value", "property_value", "bank_balance",
       "bank_turnover", "elec_bill", "gas_bill", "stock_value", "dividend", "travel_spend"}

_S = {}     # lazily-filled global state

def _init():
    if _S:
        return
    import numpy as np, torch, torch.nn.functional as F
    from torch.nn import Linear
    from torch_geometric.data import HeteroData
    from torch_geometric.nn import HeteroConv, SAGEConv
    import torch_geometric.transforms as T

    dev = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    idx = {t: {} for t in PREF2TYPE.values()}
    feats = {t: [] for t in PREF2TYPE.values()}
    desc, person_ids, adj = {}, [], defaultdict(list)
    for r in csv.DictReader(open(os.path.join(GRAPH, "kg_nodes.csv"), encoding="utf-8")):
        t, nid = r["type"], r["node_id"]
        idx[t][nid] = len(feats[t]); desc[nid] = (t, r["name"], float(r["value"]))
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
    ebuf = {}
    for r in csv.DictReader(open(os.path.join(GRAPH, "kg_edges.csv"), encoding="utf-8")):
        s, rel, d = r["src"], r["type"], r["dst"]
        st, dt = PREF2TYPE[s.split(":", 1)[0]], PREF2TYPE[d.split(":", 1)[0]]
        si, di = idx[st].get(s), idx[dt].get(d)
        if si is None or di is None:
            continue
        ebuf.setdefault((st, rel, dt), ([], [])); ebuf[(st, rel, dt)][0].append(si); ebuf[(st, rel, dt)][1].append(di)
        adj[s].append((rel, d)); adj[d].append((rel, s))
    for (st, rel, dt), (ss, dd) in ebuf.items():
        data[st, rel, dt].edge_index = torch.tensor([ss, dd], dtype=torch.long)
    data = T.ToUndirected(merge=False)(data)

    class HGNN(torch.nn.Module):
        def __init__(self, ets, hidden=64, out=2):
            super().__init__()
            self.c1 = HeteroConv({et: SAGEConv((-1, -1), hidden) for et in ets}, aggr="sum")
            self.c2 = HeteroConv({et: SAGEConv((-1, -1), hidden) for et in ets}, aggr="sum")
            self.lin = Linear(hidden, out)
        def forward(self, xd, ei):
            h = self.c1(xd, ei); h = {k: F.relu(v) for k, v in h.items()}
            return self.lin(self.c2(h, ei)["Person"])
    model = HGNN(data.edge_types).to(dev); data = data.to(dev)
    with torch.no_grad():
        model(data.x_dict, data.edge_index_dict)
    model.load_state_dict(torch.load(os.path.join(HERE, "output", "model.pt"), map_location=dev))
    model.eval()
    _S.update(torch=torch, F=F, dev=dev, data=data, model=model, idx=idx,
              desc=desc, adj=adj, pidx=pidx)

def explain(cnic, topk=6):
    _init()
    torch, F = _S["torch"], _S["F"]
    data, model, idx, desc, adj, pidx = (_S[k] for k in ["data", "model", "idx", "desc", "adj", "pidx"])
    if cnic not in pidx:
        return None
    p = pidx[cnic]
    xg = {t: data[t].x.clone().requires_grad_(True) for t in data.node_types}
    logits = model(xg, data.edge_index_dict)
    prob = float(F.softmax(logits, 1)[p, 1])
    margin = logits[p, 1] - logits[p, 0]
    model.zero_grad(); margin.backward()
    sal = {t: (xg[t] * xg[t].grad).sum(1).detach().cpu().numpy() for t in xg}

    start = f"P:{cnic}"; seen = {start: (0, None)}; q = deque([start])
    while q:
        cur = q.popleft(); d0, _ = seen[cur]
        if d0 >= 2:
            continue
        for rel, nb in adj[cur]:
            if nb not in seen:
                seen[nb] = (d0 + 1, rel if d0 == 0 else seen[cur][1]); q.append(nb)
    scored = []
    for nid, (hop, rel) in seen.items():
        if hop == 0:
            continue
        t = desc[nid][0]
        scored.append((float(sal[t][idx[t][nid]]), hop, rel, nid))
    scored.sort(reverse=True)
    evidence = []
    for s, hop, rel, nid in scored[:topk]:
        if s <= 0:
            break
        t, label, val = desc[nid]
        evidence.append({"contribution": round(s, 3), "relation": rel, "hop": hop,
                         "node_type": t, "label": label, "value": int(val)})
    return {"cnic": cnic, "anomaly_prob": round(prob, 3), "evidence": evidence}
