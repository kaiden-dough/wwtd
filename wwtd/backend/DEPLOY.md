# Google OAuth and blue-green deployment

## Current rollout (October 12, 2026)

- Production frontend: https://wwtd.vercel.app (Google-first release).
- Blue rollback deployment: `9paWAmpCz4R87ccNGPvTtsxdMqsi` (commit `0c8686f`).
- Blue API: https://wwtd-api.onrender.com.
- Green frontend: https://wwtd-git-codex-wwtd-google-green-kaiden-doughs-projects.vercel.app/.
- Green API: https://wwtd-api-green.onrender.com.
- Green source branch: `codex/wwtd-google-green`.
- Render green service: `srv-db6jujdg1s2s739krrbg` in My Workspace.

Vercel production branch tracking is `codex/wwtd-google-green`, matching the
green Render service. Production deployments are staged for manual promotion.
The branch-specific build selects `AUTH_MODE=hybrid` and the green API; new
accounts use Google, while existing players can choose "Migrate an existing
account", log in with their password, and use Account > Link Google account.
Linking preserves profile IDs and all associated game records. An unused,
automatically created Google profile can be remapped after proving both
credentials; a Google profile with game history cannot be silently merged.

The Supabase site URL is https://wwtd.vercel.app/ and the redirect allowlist
contains both the production and exact green branch URLs. Green has the shared
database and JWT secret configured. Its start command refuses to run without
both values. Verify `/health` reports `color=green`, `auth_mode=hybrid`.
Retain hybrid mode until existing players have linked their own Google accounts.

To swap frontend traffic, promote the tested green Vercel deployment. The
promoted artifact already points to green API. Restore the prior production
Vercel deployment to roll back; it points to blue API. Keep both APIs running
through the observation period. No DNS changes or database reset are required.


## Two frontend releases

Leave the deployed blue frontend and its backend unchanged. Build a separate
Vercel preview using `AUTH_MODE=google`, the WWTD Supabase settings, and the green
API URL. The production build script defaults to `AUTH_MODE=password`, so Google
must be selected explicitly. For local builds from `wwtd/frontend`:

```sh
flutter build web --release --dart-define-from-file=auth.blue.json --dart-define=API_BASE_URL=https://BLUE_API
flutter build web --release --dart-define-from-file=auth.green.json --dart-define=API_BASE_URL=https://GREEN_API
```

Keep the green preview private until Google login, reload and logout work.
Promote the tested green Vercel deployment when ready; restore the prior blue
Vercel deployment to roll back. These are independent frontend releases.
Game data and accounts are preserved. The additive `google_identities` table
maps Supabase IDs to existing profile IDs. No database reset is needed or performed.
For existing players, first use a hybrid green preview (`AUTH_MODE=hybrid` on
both frontend and API), sign in with the existing password, and choose Link
Google account in Account. Complete Google login in the same browser. After
players have linked, use the Google-only green build for cutover.

WWTD now supports Supabase Auth Google sessions alongside legacy password sessions.
Supabase owns Google login, session persistence and refresh. The API verifies Google
access tokens against the configured Supabase `/auth/v1/user` endpoint on requests.
No service-role key or Google client secret belongs in the Flutter build.

## Configure Supabase and Google

Use a dedicated WWTD Supabase project. In Google Cloud create a Web OAuth client,
configure its consent screen and add test users if it is in testing mode. Set its
redirect URI to `https://PROJECT.supabase.co/auth/v1/callback`. Enable Google in
Supabase Authentication > Providers and enter the Google client ID and secret.
In Supabase URL Configuration, set the production frontend Site URL and allow
both production and the exact green preview frontend callback URLs.

Backend environment: `DATABASE_URL` (shared Supabase Postgres), `JWT_SECRET`
(shared strong secret for existing sessions), `SUPABASE_URL`,
`SUPABASE_PUBLISHABLE_KEY`, `CORS_ORIGINS` (production and green frontend origins),
`AUTH_MODE` and `DEPLOYMENT_COLOR`.

Flutter/Vercel build environment: `API_BASE_URL`, `SUPABASE_URL`,
`SUPABASE_PUBLISHABLE_KEY`, `AUTH_MODE=hybrid`. The build script passes these as
Dart defines. Google-only UI uses `AUTH_MODE=google`. For native apps also set
`AUTH_REDIRECT_URL`, configure platform deep links and allow the redirect in
Supabase before enabling Google login on that platform.

## Blue-green API on Docker

This matches FOMO's Docker/Nginx topology. It requires a Docker host and a TLS
reverse proxy that forwards the stable public API URL to localhost port 8080.
It does not provision a host, change DNS or deploy to Render automatically.

1. Copy `wwtd/deploy/config.env.example` to `wwtd/deploy/.env` and fill the values.
2. Run from the repository root:

```sh
docker compose --env-file wwtd/deploy/.env -f wwtd/deploy/compose.yaml build blue green
docker compose --env-file wwtd/deploy/.env -f wwtd/deploy/compose.yaml up -d
```

Blue starts with password auth; green starts with Google auth. Both use the same
database and JWT secret. Local diagnostic ports are 8081 (blue), 8082 (green),
and 8080 (stable proxy). Keep release images immutable for later rollouts: set
`BLUE_IMAGE` and `GREEN_IMAGE` to distinct versioned images and use `up --no-build`.
Never rebuild the active slot during a release.

3. Build a green frontend preview pointing at the green API's TLS preview URL.
   Test Google sign-in, refresh, logout, password login, rooms, bets and balances.
   Google users are keyed by Supabase user ID; existing password accounts are
   preserved. Matching existing emails return 409 rather than silently merging.
   Account linking requires both the existing password session and the verified
   Google session; link existing players in hybrid mode before retiring passwords.
4. Switch the stable API after preview checks:

```sh
python wwtd/deploy/switch.py green
```

The switch checks database readiness, color and auth mode, validates Nginx,
reloads it and verifies proxy routing. Failed route verification restores the
previous configuration. Promote the tested frontend preview in Vercel after
switching the API; keep its API URL set to the stable endpoint for production.
5. Roll back with `python wwtd/deploy/switch.py blue` and restore the prior Vercel
   frontend deployment. Keep blue running throughout the observation period.

Rollback to password-only blue cannot serve Google sessions. Google users must
sign in again after green is restored. If uninterrupted Google sessions during
future rollback are required, first promote a hybrid release into both slots.
Do not set green to Google-only until existing-account migration is complete.

## Existing Render hosting

Keep Render as blue while creating a separate green service from this revision,
with the same database and JWT secret, `AUTH_MODE=hybrid`,
`DEPLOYMENT_COLOR=green` and both Supabase settings. Test through a Vercel preview.
A stable gateway/domain must route to either Render service for a backend traffic
switch; the Docker switch script manages only its local Nginx gateway. Disable
auto-deploy on the active service during rollout. The hosted frontend promotion
switches between API URLs; the local Nginx script is not used on Render.

Only additive database changes are compatible with two live releases. Existing
startup migrations predate this change; run and review them on a database copy,
then execute migrations once before starting concurrent slots. This auth change adds only `google_identities`, with RLS enabled in the Supabase
migration; existing columns and game records are preserved. Never roll back shared database data as part
of an application traffic switch.

Supabase reference: https://supabase.com/docs/reference/dart/auth-signinwithoauth
