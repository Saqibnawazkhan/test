# National Tax Net — Graph AI for Broadening the Tax Net

Graph + GNN system that links fragmented Pakistani civic data, scores tax-compliance
deviation, and explains every flag. Hackathon Problem #2.

## Pipeline (all built & verified)
| Step | Folder | What |
|------|--------|------|
| 1. Synthetic data | `data-generator/` | 200k people, 14 silos, ground-truth labels. `validate.py` → 0 failures |
| 2. Entity Resolution | `entity-resolution/` | links records → canonical persons (F1 = 1.0) |
| 3. Knowledge Graph | `graph/` | 807k nodes / 878k edges; Neo4j export + unified CSVs |
| 4. Deviation Score | `scoring/` + `gnn/` | rule scorer + **GNN** (GraphSAGE, GPU) fused; AUC 0.93 |
| 5. GNN Explainer | `gnn/explain.py` | per-flag graph evidence (which neighbours drove it) |
| 6. Backend API | `backend/` | FastAPI over SQLite (Supabase-ready) |
| 7a. Mobile app | `flutter_app/` | Flutter — Admin + Citizen dashboards |
| 7b. Web app | _next_ | Next.js (uses cloud UI design) |

## Run it

### 1) Start the backend
```powershell
cd backend
python build_db.py                       # one-time: builds taxnet.db from CSVs + model outputs
python -m uvicorn main:app --host 0.0.0.0 --port 8000
# docs at http://localhost:8000/docs
```

### 2) Run the Flutter app
```powershell
cd flutter_app
flutter pub get
flutter run                              # on an Android emulator (Android Studio)
```
- **Android emulator** reaches the backend at `10.0.2.2:8000` (already the default).
- **Real device on Wi-Fi:** run the backend with `--host 0.0.0.0`, then
  `flutter run --dart-define=API_BASE=http://<your-laptop-LAN-ip>:8000`.

### Demo logins
- **Citizen:** enter a CNIC (default `42101-1354046-5` is a flagged benami case).
- **Admin:** tap "Enter as FBR Admin" → triage list, drill-down, GNN evidence, request inbox.

## Re-train / regenerate (optional)
```powershell
cd data-generator && python generate_full.py 200000 && python validate.py
cd ../entity-resolution && python resolve.py
cd ../graph && python build_graph.py
cd ../scoring && python score.py
cd ../gnn && python train_gnn.py          # uses GPU if available
cd ../backend && python build_db.py
```

## To move to Supabase later
Run `supabase/schema.sql` in your Supabase project, load the CSVs, then point the
backend at it via a `DATABASE_URL` env var (swap the SQLite layer in `backend/main.py`).
