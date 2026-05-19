# Full deploy guide: Supabase → Render → Vercel

Deploy in this order. Each step depends on the previous one.

| Order | Service   | What it runs                          |
|-------|-----------|----------------------------------------|
| 0     | GitHub    | Source code                            |
| 1     | Supabase  | PostgreSQL database                    |
| 2     | Render    | FastAPI backend (`wwtd/backend`)       |
| 3     | Vercel    | Flutter web app (`wwtd/frontend`)      |
| 4     | Render    | Update `CORS_ORIGINS` (one env tweak)  |

Supabase is **database only**. Login uses your API (email OTP + JWT), not Supabase Auth.

---

## 0. Prerequisites

- GitHub account; repo pushed (e.g. `github.com/you/wwtd`).
- [Supabase](https://supabase.com), [Render](https://render.com), [Vercel](https://vercel.com) accounts.
- Flutter SDK installed locally (for building web).
- SMTP for production login emails (Gmail App Password is fine).

Repo layout Render/Vercel care about:

```
wwtd/
  backend/     ← Render root directory
  frontend/    ← Vercel project root
```

---

## 1. Supabase (database) — do this first

### 1.1 Create project

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard) → **New project**.
2. Pick organization, **name** (e.g. `wwtd`), **database password** (save in a password manager).
3. Choose a **region** close to your Render region (e.g. US West if Render is Oregon).
4. Wait until the project status is **Healthy**.

### 1.2 Get connection string

1. Open the project → **Connect** (top) or **Project Settings → Database**.
2. Under **Connection string**, choose **URI**.
3. Select **Transaction pooler** (recommended for Render):
   - Mode: **Transaction**
   - Port: **6543**
   - Host contains `pooler.supabase.com`
4. Copy the URI. Replace `[YOUR-PASSWORD]` with your database password.

Example (yours will differ):

```text
postgresql://postgres.abcdefghijklmnop:[YOUR-PASSWORD]@aws-0-us-west-1.pooler.supabase.com:6543/postgres
```

5. Store it securely — this is `DATABASE_URL` for Render.

You do **not** need to:

- Enable Supabase Auth
- Run SQL migrations manually
- Create tables in the Table Editor (the API creates them on first boot)

### 1.3 Optional: verify in Supabase SQL Editor

After the API has deployed once (step 2), you can open **Table Editor** and see `profiles`, `rooms`, `questions`, `bets`, etc.

---

## 2. Render (backend API) — Web Service (no Blueprint)

### 2.1 Connect GitHub

1. [dashboard.render.com](https://dashboard.render.com) → **New +** → **Web Service**.
2. **Build and deploy from a Git repository** → connect GitHub if needed → select your `wwtd` repo.
3. Click **Connect**.

### 2.2 Service settings

Fill in exactly:

| Field | Value |
|-------|--------|
| **Name** | `wwtd-api` (or any name; becomes part of the URL) |
| **Region** | Same region as Supabase if possible (e.g. Oregon) |
| **Branch** | `main` (or your default branch) |
| **Root Directory** | `wwtd/backend` |
| **Runtime** | `Python 3` |
| **Build Command** | `pip install -r requirements.txt` |
| **Start Command** | `uvicorn app.main:app --host 0.0.0.0 --port $PORT` |
| **Instance Type** | Free (sleeps when idle) or Starter |

Leave **Docker** off. Do not use Blueprint for this setup.

**Python version:** Add env var `PYTHON_VERSION` = `3.12.8` (or rely on `runtime.txt` in `wwtd/backend`). Do **not** use 3.14 — some packages lack wheels yet.

### 2.3 Environment variables

Scroll to **Environment Variables** → **Add Environment Variable** for each:

| Key | Value | Required |
|-----|--------|----------|
| `DATABASE_URL` | Supabase Transaction pooler URI (step 1.2) | Yes |
| `JWT_SECRET` | Random 32+ chars, e.g. `openssl rand -hex 32` | Yes |
| `SMTP_HOST` | `smtp.gmail.com` (or your provider) | Yes for email login |
| `SMTP_PORT` | `587` | Yes |
| `SMTP_USER` | Your SMTP login email | Yes |
| `SMTP_PASSWORD` | App password / API key | Yes |
| `SMTP_FROM` | Same as or authorized sender | Yes |
| `SMTP_USE_TLS` | `true` | Yes |
| `EXPOSE_DEV_OTP` | `false` | Yes in production |
| `CORS_ORIGINS` | `*` temporarily, then your Vercel URL (step 4) | Yes |

Do **not** set `SQLITE_PATH` when using Supabase.

### 2.4 Create and deploy

1. Click **Create Web Service** (bottom).
2. First deploy starts automatically. Open the **Logs** tab.
3. Wait until you see something like `Uvicorn running on http://0.0.0.0:10000`.
4. At the top, copy your service URL, e.g. `https://wwtd-api.onrender.com` (no trailing slash).

### 2.5 Verify health

In a browser or terminal:

```text
https://YOUR-SERVICE.onrender.com/health
```

Expected: `{"status":"ok"}`

If deploy fails:

- **Database connection error** → wrong password, wrong URI, or use pooler port **6543**.
- **Build OK but “Exited with status 1”** → open **Logs** (runtime, not build). Usually `DATABASE_URL` wrong or password needs [URL encoding](https://supabase.com/docs/guides/database/postgres/connection-strings) if it contains `@`, `#`, `/`, etc.
- **Module not found** → **Root Directory** must be `wwtd/backend`.
- **Build failed** → open Logs → Build; confirm `requirements.txt` exists in that folder.
- Set **`PYTHON_VERSION`** = `3.12.8` in Environment (avoid 3.14 unless build already works).

### 2.6 Smoke-test login (optional)

With `EXPOSE_DEV_OTP=true` temporarily you can test without SMTP; set back to `false` after email works.

```bash
curl -X POST https://YOUR-SERVICE.onrender.com/api/auth/send-code \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com"}'
```

---

## 3. Vercel (Flutter web) — after Render works

You need the **Render URL** from step 2.5 (no trailing slash). Vercel does not include Flutter — build on your PC, then upload `build/web`.

### 3.1 Build the web app

```powershell
cd wwtd\frontend
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
```

Replace `YOUR-SERVICE` with your real Render hostname. Output: `wwtd\frontend\build\web\`

Optional local test:

```powershell
cd build\web
python -m http.server 8080
```

Open `http://localhost:8080` → F12 → Network → confirm requests go to your Render URL.

### 3.2 Deploy with Vercel CLI (recommended)

1. Install Node.js if needed, then:

   ```powershell
   npm install -g vercel
   ```

2. Log in and deploy the **built** folder:

   ```powershell
   cd wwtd\frontend\build\web
   vercel login
   vercel
   ```

3. First run asks:
   - Link to existing project? **N**
   - Project name? e.g. `wwtd`
   - Directory? **./** (current `build/web`)
4. Production deploy:

   ```powershell
   vercel --prod
   ```

5. CLI prints your live URL, e.g. `https://wwtd.vercel.app` — save it for step 4.

### 3.3 Redeploy after API or code changes

Any time you change the Render URL or frontend code:

```powershell
cd wwtd\frontend
flutter build web --release --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
cd build\web
vercel --prod
```

### 3.4 Alternative: Vercel dashboard (import repo)

If you prefer the UI without CLI:

1. Build locally (step 3.1) first — required.
2. [vercel.com/new](https://vercel.com/new) → add project → **Deploy** by dragging the **contents** of `build/web` into [vercel.com/drop](https://vercel.com/new) (static deploy), **or** use CLI as above (simpler for updates).

Do not point Vercel’s build at `flutter build` unless you add your own CI — the default Vercel builder has no Flutter SDK.

---

## 4. Lock down CORS on Render — last

Until now `CORS_ORIGINS` was probably `*`. Lock it to your Vercel site only.

1. [dashboard.render.com](https://dashboard.render.com) → open **wwtd-api** (your Web Service).
2. **Environment** → edit `CORS_ORIGINS`.
3. Set to your **exact** Vercel URL (no trailing slash):

   ```text
   https://wwtd.vercel.app
   ```

   Multiple sites: comma-separated, no spaces:

   ```text
   https://wwtd.vercel.app,https://wwtd-git-main-you.vercel.app
   ```

4. **Save Changes**. Render redeploys automatically (1–2 min).

### 4.1 Final test

1. Open your Vercel URL in a private/incognito window.
2. Sign in with email → code (check email or SMTP).
3. Choose display name (new users).
4. Create or join a room → add a question → place a bet.
5. Supabase → **Table Editor** → confirm rows in `profiles`, `rooms`, `questions`.

### 4.2 Later deploys

| Change | What to do |
|--------|------------|
| Backend code | Push to GitHub → Render auto-deploys |
| Env var on Render | Edit Environment → Save (redeploys) |
| Frontend code | Rebuild Flutter + `vercel --prod` from `build/web` |
| New Vercel preview URL | Add that origin to `CORS_ORIGINS` if you use preview deploys |

---

## Order diagram

```
GitHub push
    ↓
Supabase (create DB, copy DATABASE_URL)
    ↓
Render (DATABASE_URL + JWT + SMTP, deploy API, /health OK)
    ↓
Vercel (flutter build web with API_BASE_URL=Render, deploy)
    ↓
Render (CORS_ORIGINS = Vercel URL, redeploy)
    ↓
Done
```

---

## Environment cheat sheet

### Render (`wwtd/backend`)

```env
DATABASE_URL=postgresql://postgres.[ref]:[password]@[region].pooler.supabase.com:6543/postgres
JWT_SECRET=<random>
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=you@gmail.com
SMTP_PASSWORD=<app-password>
SMTP_FROM=you@gmail.com
SMTP_USE_TLS=true
EXPOSE_DEV_OTP=false
CORS_ORIGINS=https://your-app.vercel.app
```

### Local backend testing Supabase

`wwtd/backend/.env` (never commit):

```env
DATABASE_URL=postgresql://postgres.axffuusaaathvketrgzf:WhatWouldTheyDo@aws-1-us-west-1.pooler.supabase.com:6543/postgres
JWT_SECRET=dev-secret
EXPOSE_DEV_OTP=true
```

```powershell
cd wwtd/backend
.\.venv\Scripts\pip.exe install -r requirements.txt
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --port 8000
```

### Flutter build (any platform)

```powershell
flutter build web --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|----------------|-----|
| `/health` 502 / crash on start | Bad `DATABASE_URL` | Pooler URI, correct password, URL-encode special chars in password |
| CORS error in browser | Wrong `CORS_ORIGINS` | Exact Vercel URL, redeploy Render |
| “Cannot reach API” on web | Wrong `API_BASE_URL` at build time | Rebuild Flutter with correct Render URL |
| Login code never arrives | SMTP | Gmail App Password, `SMTP_FROM` matches user |
| Render cold start slow | Free tier | Wait 30–60s or upgrade |
| Empty Supabase tables | API never started successfully | Check Render logs during first deploy |
| App works locally, not Vercel | Built without `dart-define` | Rebuild with `API_BASE_URL` |

---

## What you are NOT using

- **Supabase Auth** — app uses `/api/auth/send-code` and `/api/auth/verify-code`.
- **Supabase Edge Functions** — not required.
- **Render Disk / SQLite** — use `DATABASE_URL` only in production.

---

## Custom domain (optional)

1. **Vercel** → Project → Domains → add `app.yourdomain.com`.
2. **Render** → Settings → Custom Domain → `api.yourdomain.com`.
3. Update `API_BASE_URL` in Flutter build to `https://api.yourdomain.com`.
4. Update `CORS_ORIGINS` to `https://app.yourdomain.com`.
