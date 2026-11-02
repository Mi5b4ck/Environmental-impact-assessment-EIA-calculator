# EIA Impact Assessor

A web app for environmental impact assessment. Users define their own impacts, score each one against the A–G evaluation matrix, and the significance score is calculated as:

**H = A × B × C × D × E × F × G**

| Band | Score |
|---|---|
| Low | H < 25 |
| Medium | 25 – 200 |
| High | H > 200 |

High impacts call for control or mitigation measures.

## Features

- Sign in with a 6-digit email code (no passwords)
- Shared records: everyone signed in can view all assessments; only the author can edit or delete theirs
- Project phase for each impact: commissioning, operation, decommissioning
- Residual risk after mitigation, with before-and-after comparison
- Risk heatmap (magnitude × severity), significance chart and evaluation matrix
- Dashboard across all assessments, and a side-by-side compare view
- Review status: Draft, Under review, Approved
- Photo and file evidence for each impact
- Change history with a trend line
- PDF report and CSV export
- Light and dark themes; works on phones, tablets and computers

## Files

| File | What it is |
|---|---|
| `index.html` | The app, connected to Supabase for shared records and sign-in |
| `supabase-setup.sql` | Creates the database tables, access rules and evidence storage |
| `offline.html` | A standalone copy that saves in the browser only, with backup and import |

## Scoring criteria

| | Criterion | Scores |
|---|---|---|
| A | Quantity / Magnitude | 1–5 |
| B | Occurrence / Frequency | 1–5 |
| C | Duration | 1–3 |
| D | Scale / Severity | 1–5 |
| E | Legislation | 1–2 |
| F | Controls & Detection | 1–4 |
| G | Preventive Mechanism | 1–5 |

The full option list for each criterion is in the app under **Scoring guide**.

## Setup

1. **Create a Supabase project** at [supabase.com](https://supabase.com).
2. **Build the database.** In the SQL Editor, paste the contents of `supabase-setup.sql` and run it.
3. **Send codes instead of links.** Under Authentication → Email Templates → Magic Link, put `{{ .Token }}` in the email body, for example `Your sign-in code is {{ .Token }}`.
4. **Connect an email service.** Supabase's built-in email only reaches your own team and sends 2 emails an hour. Add SMTP details from a provider such as Brevo or Resend under Authentication → SMTP.
5. **Add your project keys.** In `index.html`, near the top, set `SUPABASE_URL` to your Project URL and `SUPABASE_KEY` to your **publishable** key (starts with `sb_publishable_`). Never use the secret key here.
6. **Publish with GitHub Pages.** In this repository go to Settings → Pages, choose **Deploy from a branch**, select `main` and `/ (root)`, and save. The app will be live at `https://<your-username>.github.io/<repository-name>/`.

The publishable key is safe in a public page: the row-level security rules in `supabase-setup.sql` decide who can read and change data.

## Access rules

- Signed-in users can read every assessment and everyone's display name.
- Users can only create, edit and delete their own assessments.
- Evidence files upload into a folder named after the uploader, and only the uploader can delete them. The evidence bucket is public, so anyone with a file's link can open it.
- To make the app invite-only, turn off new sign-ups under Authentication and invite users from Authentication → Users.
