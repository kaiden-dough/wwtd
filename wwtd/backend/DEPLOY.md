# Deploy wwtd (Render + Supabase + Vercel)

## Architecture

- **Supabase** — PostgreSQL database only (not Supabase Auth; app uses email OTP + JWT).
- **Render** — FastAPI backend (`wwtd/backend`).
- **Vercel** — Flutter web (`flutter build web`).

---

## 1. Supabase (database)

1. Create a project at [supabase.com](https://supabase.com).
2. **Project Settings → Database**:
   - Save the **database password** (shown once at project creation).
3. **Connect → ORMs** or **Connection string → URI**:
   - For **Render**, prefer **Transaction pooler** (port **6543**, host contains `pooler.supabase.com`).
   - Example shape:
     ```
     postgresql://postgres.[project-ref]:[PASSWORD]@aws-0-[region].pooler.supabase.com:6543/postgres
     ```
4. You do **not** need to create tables manually. On first API start, the app runs `create_all` and builds tables from models.

### Optional: migrate existing local SQLite data

Export/import manually or use a one-off script; there is no automatic SQLite → Postgres migrator in this repo. For a new deploy, an empty Supabase DB is fine.

---

## 2. Render (API)

1. Push repo to GitHub.
2. **New → Blueprint** (or Web Service) → repo root, set **Root Directory** to `wwtd/backend`.
3. **Environment variables**:

| Variable | Notes |
|----------|--------|
| `DATABASE_URL` | Full Supabase URI (see above) |
| `JWT_SECRET` | Long random string |
| `SMTP_*` | Gmail app password or SendGrid, etc. |
| `SMTP_FROM` | Sender address |
| `EXPOSE_DEV_OTP` | `false` in production |
| `CORS_ORIGINS` | Your Vercel URL, e.g. `https://your-app.vercel.app` |

4. Deploy. Check `https://YOUR-SERVICE.onrender.com/health` → `{"status":"ok"}`.

### Local API against Supabase

In `wwtd/backend/.env`:

```env
DATABASE_URL=postgresql://postgres.[ref]:[password]@....pooler.supabase.com:6543/postgres
JWT_SECRET=dev-secret
EXPOSE_DEV_OTP=true
```

```bash
cd wwtd/backend
pip install -r requirements.txt
python -m uvicorn app.main:app --reload --port 8000
```

Leave `DATABASE_URL` unset to keep using `data/wwtd.db` locally.

---

## 3. Vercel (Flutter web)

Build with your Render API URL:

```bash
cd wwtd/frontend
flutter build web --release --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
```

Deploy the `build/web` folder (see root README or add CI). Set the same URL in Vercel env if you build on Vercel.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `could not connect to server` | Check password, IP allowlist (Supabase allows all by default), use pooler URL on Render |
| `No module named 'psycopg'` | `pip install -r requirements.txt` includes `psycopg[binary]` |
| CORS errors from Vercel | Set `CORS_ORIGINS` to exact origin, no trailing slash |
| Login codes not emailed | Configure SMTP; set `EXPOSE_DEV_OTP=false` only after SMTP works |
