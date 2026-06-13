# TaxNet AI — Web App

React + Vite web app that mirrors the TaxNet AI mobile app (FBR admin command center **and** the citizen portal), wired to the same FastAPI backend.

## Run locally

```bash
npm install
npm run dev          # http://localhost:5173
```

The app reads the backend URL from `VITE_API_URL` (see `.env`). Default: `http://localhost:8000`.
Start the backend first:

```bash
cd ../backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Demo logins
- **FBR / Admin:** username `admin`, password `admin123`
- **Citizen:** CNIC `42101-1354046-5` (any CNIC that exists in the graph)

## Deploy on Vercel

1. Push this folder to GitHub.
2. Import the repo in Vercel — it auto-detects Vite (build `npm run build`, output `dist`).
3. Set an env var **`VITE_API_URL`** to your **public** backend URL (the deployed site can't reach `localhost`).
   - Host the FastAPI backend somewhere public (Render / Railway / a VM). CORS is already `*`.
4. `vercel.json` already rewrites all routes to `index.html` for client-side routing.

## Structure
- `src/lib/api.js` — API client (mirrors the Flutter `Api` class)
- `src/lib/store.jsx` — theme (dark/light) + language (EN/اردو RTL) + auth
- `src/pages/admin/*` — FBR command center
- `src/pages/citizen/*` — citizen portal
- `src/components/*` — shared UI, icons, AI assistant drawer
- `legacy/` — the original single-file prototype (reference only)
