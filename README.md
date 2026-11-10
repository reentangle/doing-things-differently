# amongstudio research

The public website is hosted on GitHub Pages. Supabase stores the responses, editable wording and private admin services. No research responses or secret keys belong in this repository.

## website

- Public survey: `https://research.amongstudio.net/economicsofdoingthingsdifferently/`
- Private admin: the same address followed by `admin/`
- Review demo: the same address followed by `demo/`

The admin username and password stay the same. Sign in again after the hosting move. The admin session is kept only in the current browser tab, expires after 12 hours and is revoked on sign-out. Response access, CSV export, recoverable deletion, contact access and text editing require a valid server-checked session.

## GitHub Pages setup

1. Open this repository's Settings → Pages.
2. Choose **Deploy from a branch**.
3. Select **main** and **/docs**, then save.
4. Test the temporary GitHub Pages URL before moving the domain.
5. Add `research.amongstudio.net` as the custom domain in Pages.
6. In Squarespace DNS, point only the `research` CNAME to `reentangle.github.io`. Keep all other domain and email records unchanged.
7. Wait for GitHub's DNS and certificate checks, then enable **Enforce HTTPS**.

The temporary project URL is `https://reentangle.github.io/doing-things-differently/`. All assets work under that project prefix and at the final custom-domain root. GitHub adds `docs/CNAME` when the custom domain is configured; preserve that file.

## editing wording

Use **edit website text** in admin, preview the desktop/phone view, then publish. The public page fetches the latest wording before the participant can answer, so text edits do not need a GitHub rebuild. Each publication retains an immutable questionnaire version; historical responses and returned maps keep their original wording.

## editing code

The project uses plain HTML, CSS and JavaScript with no dependency installation.

1. Edit templates and browser scripts in `src/`, or images in `assets/`.
2. Run `node scripts/build.mjs`.
3. Run `node scripts/test.mjs`.
4. Commit the source changes **and the regenerated docs folder**, then push to main.
5. GitHub Pages publishes `docs/` automatically.

For a local preview, run `node scripts/preview.mjs`, then open the URL it prints. The preview uses the real Supabase database, so clearly label any synthetic responses and remove them through admin after checking them. The separate `/demo/` page never submits data.

## private backend

The Supabase Edge Function is `research-admin` in project `lfkfidiedchroabujbqs`. Its source is under `supabase/functions/research-admin/`. It uses Supabase's server-provided service-role key; that key is never sent to the browser or stored here. Deploy this function when its server code changes, including the generated `shared.js`. It authenticates requests itself using opaque expiring sessions, so platform JWT verification is disabled for this function only.

`supabase/github-backend.sql` records the one-time migration already applied to the connected database. **Do not rerun it.** Admin password hashes are encrypted in Supabase Vault. The completed credential migration no longer depends on the previous Sites server. All admin bridge functions are restricted to the service role; anonymous users cannot invoke them or read the private session/response tables.

Anonymous submission, reference-code return, consented shared maps and conversation opt-in still use the same restricted public RPCs as before. Coordinates, questionnaire questions, consent and one-year retention remain unchanged by the hosting move. The legacy setup scripts from the first prototype have been removed; their history remains available in Git.

## rollback

Keep the previous Sites deployment available until the new domain has been checked. If needed, restore the former `research` CNAME target from the DNS change record. Data remains in the same Supabase database throughout. Do not delete or re-create the response table.
