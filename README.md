# the economics of doing things differently

A tiny static website: choose a point, describe your job, submit. Plain HTML, CSS and JavaScript. No installation, build process, login or analytics.

**Supabase setup is complete for this copy (28 October 2026).** The database table and restricted submission function are installed, and `config.js` contains your project URL and public publishable key. A real anonymous API submission was saved and checked in the database; the synthetic test row was then removed. Public reads and direct table writes were denied, and invalid coordinates, blank jobs and honeypot submissions were rejected. GitHub Pages publication is still your next step. Start at section 2 below.

The database setup instructions in section 1 are retained for reference or for a new project. Do not rerun `setup.sql` on the already configured project.

## 1. Set up Supabase (already completed)

1. Create an account at https://supabase.com and create a new project. Use a new project for this experiment. Keep your database password private.
2. Open **SQL Editor**, create a new query, paste all of `setup.sql`, and click **Run**. Run this setup once. It creates the `responses` table and the `submit_response` function, enables Row Level Security, and restricts public access.
3. In the project's **Connect** dialog, copy the **Project URL**. Under **Settings → API Keys**, copy a **publishable** key beginning `sb_publishable_`.
4. Open `config.js` in a text editor. Paste the URL and publishable key between the empty quotes. Remove any trailing `/` from the URL. Save the file.
5. Keep the **Data API** enabled and the `public` schema exposed (the normal project defaults). No Supabase Auth setup is needed.

The publishable key is intentionally public, including in GitHub. Never use a database password, `sb_secret_` key or `service_role` key in these files. This implementation uses the publishable key in the `apikey` header; it does not send that key as a Bearer token.

Official references: [API keys](https://supabase.com/docs/guides/getting-started/api-keys), [database functions](https://supabase.com/docs/guides/database/functions).

## 2. Upload to GitHub

1. Sign in at https://github.com. Click **New repository**.
2. Name it, for example, `doing-things-differently`. Choose **Public**, add a README so the repository starts with a `main` branch, and create it. A public repository is the simplest GitHub Pages option.
3. Click **Add file → Upload files**. Upload `index.html`, your edited `config.js`, `README.md`, `setup.sql`, `verify.sql` and `.nojekyll` directly to the repository root. Replace the initial README when prompted. Do not upload the enclosing folder or ZIP.
4. Click **Commit changes**. If your file picker hides `.nojekyll`, you can create it through **Add file → Create new file**, with the name `.nojekyll` and empty contents. The simple files also work without it.

The SQL files contain setup instructions, not credentials or research results. Never upload exported responses to this public repository.

## 3. Enable GitHub Pages

1. In the repository, open **Settings → Pages**.
2. Under **Build and deployment**, choose **Deploy from a branch**.
3. Select **main** and **/(root)**, then **Save**.
4. Wait for deployment. This page will show a link like `https://YOUR-USERNAME.github.io/doing-things-differently/`. Open it.
5. If deployment fails, check the repository's **Actions** tab. The repository root must contain a file named exactly `index.html`.

To make changes later, edit the files on GitHub and commit. Pages redeploys automatically. No custom domain or server is required. [Official GitHub Pages instructions](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).

## 4. Prove a submission was saved

1. Open your Pages URL (or open `index.html` locally after configuration).
2. Click near the top-right of the graph. Enter a distinctive temporary job such as `TEST-2026-10-28-A`. Click **submit**.
3. Only a successful Supabase response produces **Saved. Thank you.**
4. In Supabase's **SQL Editor**, paste `verify.sql` and click **Run**. The first result should show your test job, its server timestamp, and x/y near 100. Bottom-left is x=0, y=0; the centre is 50,50. Values have up to two decimal places.
5. The second result checks permissions. Expected values are listed in the file. Public direct reading, inserting, updating and deleting must all be false; anonymous function execution must be true.
6. Remove just your test row in Supabase's Table Editor when finished. Do not delete real responses.

Also test on your phone: tap a point, tap a different point, enter a job and submit. There should be one movable dot and one saved row. Keyboard users can Tab to the graph and press an arrow to start at 50,50, then use arrows to move by 1 or Shift+arrows by 10.

For an additional real API privacy check, open your site's browser developer console and run:

```js
fetch(EXPERIMENT_CONFIG.supabaseUrl + '/rest/v1/responses?select=*', {
  headers: { apikey: EXPERIMENT_CONFIG.supabasePublishableKey }
}).then(async r => console.log(r.status, await r.text()));
```

Expected: permission denied (normally HTTP 401 or 403), with no response data. If it returns rows, stop collecting data and recheck database grants and policies.

If saving fails, check that `setup.sql` ran successfully, the URL and publishable key belong to the same project, and the project and Data API are active. Your browser's Network panel shows the actual failed request. A connection failure can happen after the database has saved: check for the row before retrying. The page does not automatically retry requests.

## Export CSV (owner only)

In Supabase's SQL Editor, run:

```sql
select id, created_at, x, y, job
from public.responses
order by created_at, id;
```

Use the query results' **Export/Download CSV** control. Keep the CSV private. Do not build a public download endpoint. Job text is untrusted input: when opening a CSV in a spreadsheet, import `job` as text to avoid interpreting entries beginning with `=`, `+`, `-` or `@` as formulas.

## What is stored and protected

- `x`: fundamental difference, 0 = reproduction, 50 = reform, 100 = transformation.
- `y`: material security, 0 = precarious, 50 = liveable, 100 = secure.
- `job`: trimmed text, 1–160 characters.
- A generated row ID and server timestamp.

The application does not collect names, emails, accounts, visitor IDs or IP addresses. Free text may still identify a person; participants should avoid identifying details. GitHub and Supabase may retain ordinary infrastructure/request logs, including network information. This does not promise infrastructure-level anonymity.

Row Level Security is enabled with **no public table policies**, which means default deny. Direct table and sequence privileges are also revoked from `PUBLIC`, `anon` and `authenticated`. The only public entry point is an insert-only `SECURITY DEFINER` function, owned by the setup administrator, with an empty search path, qualified object references, input validation and no returned records. Only `anon` has permission to call it. The security review returned two expected notices: [RLS enabled with no policies](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) and [an anonymous-callable security-definer function](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable). Both are intentional here: direct access is denied and the function only accepts validated submissions. Do not grant table access to resolve these notices.

## Basic spam protection

There is a hidden honeypot field checked by the database function, a 160-character job limit, coordinate validation, protection against double clicks, and a browser-local 30-second cooldown after a successful submission. Local storage holds only the last successful submission time, not the response.

The database also enforces an experiment-wide maximum of **60 submissions in a rolling minute**. An advisory transaction lock prevents concurrent submissions from bypassing it; a simultaneous request may be asked to retry. Change `60` in the function if the experiment needs a different limit, and use `CREATE OR REPLACE FUNCTION` when updating an existing function.

This is basic deterrence, not bot-proofing or one-response-per-person enforcement. Browser checks and the honeypot can be bypassed. An attacker can consume the global allowance. Strong per-IP limits or a verified CAPTCHA would require additional server-side infrastructure, deliberately omitted here to keep the project small. The public key is not a spam secret.

## Files

- `index.html`: the entire interface, styles and application code.
- `config.js`: the two public configuration values.
- `setup.sql`: database and permission setup.
- `verify.sql`: owner-only inspection and permission checks.
- `.nojekyll`: tells Pages to serve static files directly.

No Supabase SDK or other dependencies are loaded. The browser makes one HTTPS request per submission.
