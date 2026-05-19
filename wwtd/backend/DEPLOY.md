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
| `SMTP_FROM` | Same as or authorized sender | Optional (local SMTP) |
| `SMTP_USE_TLS` | `true` | Optional |
| `BREVO_API_KEY` | From [brevo.com](https://www.brevo.com) → SMTP & API → API keys | **Yes on Render free tier** |
| `EMAIL_FROM` | `What Would They Do <you@gmail.com>` (must be verified in Brevo) | Yes |
| `EXPOSE_DEV_OTP` | `false` after email works | Yes in production |

**Render free tier blocks outbound SMTP** (ports 587/465). Use **Brevo** (HTTPS API, below) — not Gmail SMTP on Render free.
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

You need the **Render URL** from step 2.5 (no trailing slash).

### 3.0 Git auto-deploy (recommended)

Connect GitHub so every push to `main` rebuilds and deploys the Flutter web app.

1. Push this repo to GitHub (if you have not already).
2. Open [vercel.com/new](https://vercel.com/new) → **Import Git Repository** → authorize GitHub → select your repo.
3. **Configure Project**:

   | Setting | Value |
   |---------|--------|
   | **Root Directory** | `wwtd/frontend` (Edit → set before deploy) |
   | **Framework Preset** | Other |
   | **Build Command** | (leave empty — uses `vercel.json`) |
   | **Output Directory** | (leave empty — uses `vercel.json`) |

4. **Environment Variables** (add before first deploy):

   | Name | Value | Environments |
   |------|--------|----------------|
   | `API_BASE_URL` | `https://YOUR-SERVICE.onrender.com` (no trailing slash) | Production, Preview, Development |

5. Click **Deploy**. The first build installs Flutter on Vercel’s builder (~3–6 minutes). Later deploys are faster.
6. After deploy, note your URL (e.g. `https://kaidendo.vercel.app`) for step 4 (`CORS_ORIGINS`).

**Already have a Vercel project (CLI / drag-and-drop)?**

1. [vercel.com/dashboard](https://vercel.com/dashboard) → your project → **Settings** → **Git** → **Connect Git Repository**.
2. Pick the same repo and branch (`main`).
3. Confirm **Root Directory** = `wwtd/frontend` under **Settings → General**.
4. Add `API_BASE_URL` under **Settings → Environment Variables** if missing.
5. **Deployments** → **Redeploy** (or push a commit).

**Preview deploys:** Each PR gets a preview URL. Add those origins to Render `CORS_ORIGINS` if you test login on previews:

```text
https://kaidendo.vercel.app,https://your-project-*.vercel.app
```

(Render does not support wildcards in `CORS_ORIGINS`; list specific preview URLs or use `*` only while testing.)

---

### 3.1 Build the web app locally (optional)

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

### 3.4 Manual static deploy (no Git)

Drag-and-drop only: build locally (step 3.1), then upload the **contents** of `build/web` at [vercel.com/new](https://vercel.com/new). No auto-deploy on push. Prefer **3.0** for Git integration.

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
DATABASE_URL=<your-supabase-pooler-uri>
JWT_SECRET=dev-secret
RESEND_API_KEY=<optional-for-local>
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
| Login code never arrives | SMTP blocked on Render free | Use `BREVO_API_KEY` + verified sender (see below) |
| `Network is unreachable` on send-code | Render blocks port 587 | Resend or paid Render plan |
| Render cold start slow | Free tier | Wait 30–60s or upgrade |
| Empty Supabase tables | API never started successfully | Check Render logs during first deploy |
| App works locally, not Vercel | Built without `dart-define` | Rebuild with `API_BASE_URL` |

---

## Email on Render (Brevo — full setup)

### Why Brevo (and not Gmail SMTP on Render)

| Method | Render free tier |
|--------|------------------|
| Gmail `SMTP_HOST` + port 587 | Blocked → `Network is unreachable` |
| **Brevo API** (HTTPS) | Works |

Brevo’s free plan is enough for login codes (~300 emails/day). You **do not** need to buy a website domain if you verify a **Gmail address** as the sender.

---

### Part A — Create a Brevo account

1. Go to [https://www.brevo.com](https://www.brevo.com) → **Sign up free**.
2. Confirm your own email (Brevo account email).
3. Complete the short onboarding (company name can be personal / “WWTD”).

You land on the Brevo dashboard.

---

### Part B — Verify a sender (who emails are “from”)

This is the address users see as the sender. It **must** be verified before Brevo will send.

1. In the left menu: **Settings** (gear) → **Senders, domains, IPs** → tab **Senders**.
   - Or: **Transactional** → **Settings** → **Senders**.
2. Click **Add a sender** (or **Create a new sender**).
3. Fill in:
   - **From name:** `What Would They Do` (or `WWTD`)
   - **From email:** your Gmail, e.g. `kaiden12345do@gmail.com`
4. Submit. Brevo emails that Gmail inbox a **verification link**.
5. Open Gmail → click the link → sender status becomes **Verified** (green).

**Important:**

- `EMAIL_FROM` on Render must use **this exact verified email**.
- You can verify multiple senders later; one Gmail is enough to start.
- If verification email doesn’t arrive, check spam or use Brevo’s “Resend verification”.

You do **not** need to add a custom domain in Brevo for basic use. Domain setup is optional later for branding (`noreply@yourdomain.com`).

---

### Part C — Create an API key

The wwtd API sends mail via Brevo’s HTTP API, not SMTP.

1. Left menu: **SMTP & API** → **API keys**  
   (sometimes under **Settings → SMTP & API**).
2. **Generate a new API key**.
3. **Name:** `wwtd-render-production` (anything you’ll recognize).
4. **Permissions:** choose **Send emails only** / restricted to sending — **not** full account access unless you need it for the dashboard.
5. **Create** → copy the key immediately. It looks like:

   ```text
   xkeysib-abc123def456...
   ```

6. Store it in a password manager. You won’t see the full key again.

---

### Part D — Configure Render

1. [dashboard.render.com](https://dashboard.render.com) → your **wwtd-api** Web Service.
2. **Environment** → add or update:

| Key | Value | Notes |
|-----|--------|--------|
| `BREVO_API_KEY` | `xkeysib-...` | Paste full API key, no quotes |
| `EMAIL_FROM` | `What Would They Do <kaiden12345do@gmail.com>` | Name + **verified** Gmail; angle brackets required for name format |
| `EXPOSE_DEV_OTP` | `false` | Set `true` only while debugging without email |

**`EMAIL_FROM` formats that work:**

```text
What Would They Do <you@gmail.com>
WWTD <you@gmail.com>
you@gmail.com
```

**Optional:** you can remove these on Render (they don’t work on free tier):

- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM`
- `RESEND_API_KEY` (unless you still use Resend)

3. **Save Changes** → Render redeploys (wait until status is **Live**).

---

### Part E — Deploy the Brevo code (if not already)

Your repo must include `app/email_service.py` with `_send_via_brevo`. If you haven’t pushed yet:

```powershell
cd c:\Users\kaide\wwtd
git add wwtd/backend
git commit -m "Add Brevo for login emails"
git push
```

Wait for Render deploy to finish after push.

---

### Part F — Test end-to-end

1. Open `https://kaidendo.vercel.app` (or your Vercel URL).
2. Enter an email to log in with → **Send code**.
3. Success in the app: **“Check your email for the 6-digit code.”** (not “use dev code below”).
4. Check inbox + **spam** for subject **“Your wwtd login code”**.
5. Enter the 6-digit code → choose display name if prompted → you’re in.

**Parallel checks:**

- **Brevo dashboard** → **Transactional** → **Email** (or **Logs**) → you should see the send as **Delivered** or **Sent**.
- **Render** → **Logs** → look for `Login code sent via Brevo to ...` (no `Brevo failed` traceback).

**Quick API test** (replace URL and email):

```powershell
curl -X POST https://YOUR-SERVICE.onrender.com/api/auth/send-code `
  -H "Content-Type: application/json" `
  -d '{"email":"you@gmail.com"}'
```

Response should mention checking email, not only dev code.

---

### Part G — Local development with Brevo (optional)

In `wwtd/backend/.env` (never commit this file):

```env
BREVO_API_KEY=xkeysib-your-key
EMAIL_FROM=What Would They Do <you@gmail.com>
EXPOSE_DEV_OTP=false
JWT_SECRET=local-dev
```

```powershell
cd wwtd\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --port 8000
```

Flutter local: `flutter run -d chrome` (defaults API to `http://127.0.0.1:8000`).

---

### Brevo troubleshooting

| What you see | What to do |
|--------------|------------|
| App says “use dev code below” | `BREVO_API_KEY` missing on Render, or old code not deployed; set `EXPOSE_DEV_OTP=true` temporarily |
| Render log: `Brevo failed (401)` | Wrong or revoked API key — generate a new one |
| Render log: `Brevo failed (400)` + sender message | Sender not verified — finish Part B; `EMAIL_FROM` must match verified email exactly |
| Render log: `Invalid EMAIL_FROM` | Fix format: `Name <email@domain.com>` or plain `email@domain.com` |
| Brevo shows “Sent” but no inbox | Spam folder; Gmail “Promotions”; wait 1–2 minutes |
| `Network is unreachable` still | App is still using SMTP, not Brevo — remove `SMTP_HOST` or ensure `BREVO_API_KEY` is set and code is deployed |
| Hit daily limit | Free tier cap — wait 24h or upgrade Brevo plan |
| Only works for your email | Some new Brevo accounts are restricted until account is reviewed — check Brevo notifications |

### Brevo vs buying a domain

| Approach | Cost | Send to any user email? |
|----------|------|-------------------------|
| Verified Gmail sender | Free | Yes (typical for wwtd) |
| Verified custom domain in Brevo | ~$10/yr domain | Yes, looks more professional (`noreply@kaidendo.com`) |

For wwtd with friends, **verified Gmail is enough**.

---

### Security checklist

- Never commit `BREVO_API_KEY` to GitHub (only in Render env + local `.env`).
- Use a **send-only** API key permission.
- Rotate the key if it leaks: Brevo → delete old key → new key → update Render.

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
