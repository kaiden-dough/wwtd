# What Would They Do? (WWTD)

A social prediction game where friends make picks about what people will do, track results, and compete on room leaderboards using in-app points.

**[Open the app](https://wwtd.vercel.app/)**

## Features

- Sign in with Google through Supabase Auth.
- Create rooms about an individual or a group of people.
- Invite friends using a join code or room link.
- Create yes/no questions, make picks, and track room balances.
- Close picking at question expiry and let room moderators resolve or undo results.
- View pick history and room leaderboards.

## Stack

| Component | Technology |
| --- | --- |
| Frontend | Flutter / Dart, Provider |
| API | Python, FastAPI, SQLAlchemy |
| Authentication | Google OAuth through Supabase Auth |
| Database | Supabase PostgreSQL in production; SQLite for local development |
| Hosting | Vercel frontend and Render API |

The frontend sends its Supabase access token to the API. The API verifies the session with Supabase and looks up the associated player profile. Production uses Google-only authentication; password login and account migration are disabled.

## Repository layout

```text
wwtd/
├── backend/
│   ├── app/                 # API routes, authentication, models, and game logic
│   ├── migrations/          # Database migration SQL
│   ├── tests/               # Backend authentication tests
│   ├── .env.example         # Backend configuration template
│   ├── requirements.txt
│   └── DEPLOY.md            # Deployment and rollback instructions
├── frontend/
│   ├── lib/                 # Flutter screens, state, services, and models
│   ├── pubspec.yaml
│   ├── vercel.json
│   └── vercel-build.sh
└── deploy/                  # Docker Compose and Nginx blue/green tooling
```

The application lives inside the nested `wwtd/` directory, relative to this README.

## Run locally

You need Python 3.12, a Flutter SDK that includes Dart 3.11.1 or newer, and Chrome. Google login also requires a Supabase project with the Google provider configured.

The commands below use PowerShell and start from the repository root.

### 1. Start the API

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
cd wwtd/backend
python -m pip install -r requirements.txt
Copy-Item .env.example .env
```

Edit `wwtd/backend/.env` with your own values:

```dotenv
AUTH_MODE=google
DEPLOYMENT_COLOR=local
JWT_SECRET=replace-with-a-long-random-secret
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
CORS_ORIGINS=http://localhost:3000
```

Leave `DATABASE_URL` unset to use SQLite at `wwtd/backend/data/wwtd.db`. To use PostgreSQL instead, set `DATABASE_URL` to your database connection string. The API creates its tables and runs startup migrations when it starts, so use a development database for local work.

```powershell
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

- API documentation: <http://127.0.0.1:8000/docs>
- Database health check: <http://127.0.0.1:8000/health>
- Authentication configuration: <http://127.0.0.1:8000/api/auth/config>

### 2. Start the frontend

In a second terminal, from the repository root:

```powershell
cd wwtd/frontend
flutter pub get
```

Create `wwtd/frontend/auth.local.json` using the same Supabase project as the API:

```json
{
  "API_BASE_URL": "http://127.0.0.1:8000",
  "AUTH_MODE": "google",
  "SUPABASE_URL": "https://YOUR_PROJECT_REF.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "YOUR_PUBLISHABLE_KEY"
}
```

```powershell
flutter run -d chrome --web-port 3000 --dart-define-from-file=auth.local.json
```

Allow `http://localhost:3000/` as an authentication redirect in your development Supabase project. Configure the Google OAuth client with the callback URL supplied by Supabase. The web app returns to its current URL after Google sign-in.

Frontend configuration is compiled into the app. Restart or rebuild after changing Dart defines. Only the Supabase URL and **publishable key** belong in frontend configuration; keep database passwords, Google client secrets, and server secrets on the backend or in the provider dashboard. Backend `.env` files are ignored by Git.

For isolated local development without Google, set `AUTH_MODE=password` in the backend `.env` and run Flutter with `--dart-define=AUTH_MODE=password` instead of the Google configuration file. This enables the local username/password flow; it does not match production authentication.

## Checks and builds

With the Python virtual environment active, run backend tests from `wwtd/backend`:

```powershell
python -m unittest discover -s tests -v
```

From `wwtd/frontend`:

```powershell
flutter analyze
flutter build web --release --dart-define-from-file=auth.local.json
```

Use your deployed API URL in the configuration file when building a hosted frontend. Flutter writes the web build to `wwtd/frontend/build/web`.

## Deployment

The hosted setup uses Vercel for Flutter web, Render for FastAPI, and Supabase for PostgreSQL and Google authentication. The release branch is `codex/wwtd-google-green`; its Vercel build script selects Google-only auth and the green API. Vercel production builds are staged for manual promotion.

Blue and green API services share the database. Promoting a frontend changes which API it calls; restoring a previous frontend deployment switches back to that deployment's API. Application rollback does not restore deleted database records.

See [the deployment guide](wwtd/backend/DEPLOY.md) for environment variables, hosted service URLs, and rollback details. The Docker/Nginx tooling in `wwtd/deploy/` is a separate local blue/green setup.
