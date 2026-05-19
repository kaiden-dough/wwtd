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

## 2. Render (backend API) — second

### 2.1 Create web service

**Option A — Blueprint (if `render.yaml` is in repo)**

1. Render Dashboard → **New +** → **Blueprint**.
2. Connect GitHub → select `wwtd` repo.
3. Render reads `wwtd/backend/render.yaml`. Confirm service name `wwtd-api`.
4. Set **Root Directory** to `wwtd/backend` if prompted.

**Option B — Manual web service**

1. **New +** → **Web Service** → connect repo.
2. Settings:
   - **Name:** `wwtd-api`
   - **Root Directory:** `wwtd/backend`
   - **Runtime:** Python 3
   - **Build Command:** `pip install -r requirements.txt`
   - **Start Command:** `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
   - **Instance type:** Free or Starter (free sleeps after inactivity).

### 2.2 Environment variables

In the service → **Environment** → add:

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

### 2.3 Deploy

1. **Save** env vars → **Manual Deploy** → **Deploy latest commit** (or push to `main`).
2. Watch **Logs** until you see Uvicorn running.
3. Open:

   `https://wwtd-api-xxxx.onrender.com/health`

   Expected: `{"status":"ok"}`

If deploy fails:

- **Database connection error** → wrong password, wrong URI, or use pooler port 6543.
- **Module not found** → check Root Directory is `wwtd/backend`.

### 2.4 Smoke-test API (optional)

With `EXPOSE_DEV_OTP=true` temporarily you can test login without SMTP; set back to `false` after SMTP works.

```bash
curl -X POST https://YOUR-SERVICE.onrender.com/api/auth/send-code \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com"}'
```

---

## 3. Vercel (Flutter web) — third

You need the **Render URL** from step 2 (no trailing slash).

### 3.1 Build locally (recommended first time)

```powershell
cd wwtd/frontend
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
```

Output: `wwtd/frontend/build/web/`

Test locally:

```powershell
cd build/web
python -m http.server 8080
```

Open `http://localhost:8080` — app should call Render API (check browser Network tab).

### 3.2 Deploy to Vercel

**Option A — Vercel CLI**

```powershell
npm i -g vercel
cd wwtd/frontend
# Build first with dart-define (Vercel does not include Flutter by default)
flutter build web --release --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
cd build/web
vercel --prod
```

**Option B — GitHub + Vercel dashboard (build Flutter in CI)**

Because Vercel’s default image has no Flutter, use a GitHub Action to build `build/web` and deploy, or build locally and deploy `build/web` as a static site.

**Option B2 — Vercel project pointing at prebuilt `build/web`**

1. [vercel.com/new](https://vercel.com/new) → Import Git repo.
2. **Root Directory:** `wwtd/frontend`
3. For a **static export** workflow, build on your machine, commit `build/web` (not ideal) OR use the Action below.

**Option C — Vercel with environment variable (if you add a Flutter build Action)**

Create `.github/workflows/deploy-web.yml` that runs `flutter build web --dart-define=API_BASE_URL=${{ secrets.API_BASE_URL }}` and deploys `build/web` with Vercel Action.

Minimal Vercel settings when deploying **only** the `build/web` folder:

- **Framework Preset:** Other
- **Output Directory:** `.` (if uploading `build/web` contents)

`vercel.json` in `wwtd/frontend` handles SPA routing.

### 3.3 Note your Vercel URL

After deploy: e.g. `https://wwtd.vercel.app` or `https://wwtd-yourteam.vercel.app`

---

## 4. Lock down CORS on Render — last

1. Render → `wwtd-api` → **Environment**.
2. Set `CORS_ORIGINS` to your **exact** Vercel origin (no trailing slash):

   ```text
   https://wwtd.vercel.app
   ```

   Multiple origins: comma-separated:

   ```text
   https://wwtd.vercel.app,https://www.yourdomain.com
   ```

3. **Save** → redeploy.

Reload the Vercel app → sign in → create/join room. Data lives in Supabase.

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
DATABASE_URL=<same as Render>
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
