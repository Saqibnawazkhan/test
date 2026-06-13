# TaxNet AI — FastAPI serving image (stateless, reads Supabase Postgres).
# Place this at the ROOT of the backend repo (next to the backend/ folder),
# alongside requirements-serving.txt. Serves every endpoint except /explain
# (which needs the ML image — see handoff README).
FROM python:3.11-slim

WORKDIR /app
COPY requirements-serving.txt .
RUN pip install --no-cache-dir -r requirements-serving.txt

COPY backend/ ./backend/

# Read from Supabase Postgres instead of local SQLite (stateless container).
# Provide SUPABASE_DB_URL at runtime (NEVER bake it into the image):
#   docker run -e DB_BACKEND=supabase -e SUPABASE_DB_URL="postgresql://..." -p 8000:8000 taxnet-api
ENV DB_BACKEND=supabase

# Run from inside backend/ so the app's top-level imports (from tax_calc import,
# from chat import, import zindigi, …) resolve exactly as they do in local dev.
WORKDIR /app/backend
EXPOSE 8000
# Bind to Railway's assigned $PORT (falls back to 8000 locally).
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
