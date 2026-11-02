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

- Sign in with email and password; no email service needed
- Shared records: everyone signed in can view all assessments; only the author can edit or delete theirs
- Project phase for each impact: commissioning, operation, decommissioning
- Residual risk after mitigation, with before-and-after comparison
- Risk heatmap (magnitude × severity), significance chart and evaluation matrix
- Analysis dashboard: filter by project, phase, category and status; headline figures and automatic key findings; charts you configure yourself (measure, grouping, split, chart type, scale), including Pareto, radar criteria fingerprint, heatmap and scatter; download each chart as PNG or CSV, or all charts as one PDF
- Side-by-side compare view
- Review status: Draft, Under review, Approved
- Photo and file evidence for each impact
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
3. **Turn off email confirmation.** Under Authentication → Sign In / Providers → Email, switch **Confirm email** off and save. The app then never needs to send emails, so no email service is required.
4. **Add your project keys.** In `index.html`, near the top, set `SUPABASE_URL` to your Project URL and `SUPABASE_KEY` to your **publishable** key (starts with `sb_publishable_`). Never use the secret key here.
5. **Publish with GitHub Pages.** In this repository go to Settings → Pages, choose **Deploy from a branch**, select `main` and `/ (root)`, and save. The app will be live at `https://<your-username>.github.io/<repository-name>/`.

The publishable key is safe in a public page: the row-level security rules in `supabase-setup.sql` decide who can read and change data.

## Access rules

- Signed-in users can read every assessment and everyone's display name.
- Users can only create, edit and delete their own assessments.
- Evidence files upload into a folder named after the uploader, and only the uploader can delete them. The evidence bucket is public, so anyone with a file's link can open it.
- To close registration once your team has joined, see **Managing users** below.

## Managing users

- People create their own account in the app. Anyone with the link can register, so share it only with your team, or switch off **Allow new users to sign up** under Authentication once everyone has joined.
- Signed-in users can change their display name and password under **Account**.
- Because no emails are sent, there is no "forgot password" email. To reset someone's password, run this in the Supabase SQL Editor, replacing the email and the new password:

```sql
update auth.users
set encrypted_password = crypt('NewPassword123', gen_salt('bf'))
where email = 'person@example.com';
```

Then tell them the new password and ask them to change it under **Account**.
