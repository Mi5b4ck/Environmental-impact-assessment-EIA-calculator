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
- Live co-editing, like Canva: several people can edit the same assessment, even the same impact, at once; every change saves instantly and appears for everyone within a second
- Presence: see who's online, who's viewing an assessment, and who's editing which impact or field
- Canva-style sharing: the creator decides who can view and who can edit
- Roles: an owner, moderators and users, listed in one tap under People; only the owner can make someone a moderator
- Approval: only moderators can approve; approved projects are locked and listed in their own section on the home page
- Review comments: moderators pin comments to any part of a project; they appear on hover, and editors answer with Acknowledge or Reject and a note
- Several categories per impact (for example Air, Water and Soil & land), and several project phases: commissioning, operation, decommissioning
- Residual risk after mitigation, with before-and-after comparison
- Evaluation matrix and risk heatmap (magnitude × severity), each showing current scores, scores after mitigation, or both side by side with one shared switch; changed scores are highlighted
- Private analysis dashboard, saved to each user's account: filter by project, phase, category and status; headline figures and automatic key findings; charts you configure yourself (measure, grouping, split, chart type, scale), including Pareto, radar criteria fingerprint, heatmap and scatter; download each chart as PNG or CSV, or all charts as one PDF
- Compare two projects on current risk, risk after mitigation, or both; private and saved per user
- Review status: Draft, Under review, Approved
- Photo and file evidence for each impact
- PDF report (with the evaluation matrix before and after mitigation) and CSV export (with current and residual A–G scores)
- Light and dark themes; works on phones, tablets and computers

## Files

| File | What it is |
|---|---|
| `index.html` | The app, connected to Supabase for shared records and sign-in |
| `supabase-setup.sql` | Creates the database tables, access rules and evidence storage |
| `make-me-owner.sql` | Makes your account the app owner (run once, with your email) |
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

## Access and sharing

Sharing works like Canva. Each assessment shows who created it, who can edit it and who can view it.

| Role | Can view | Can edit content | Can share | Can delete |
|---|---|---|---|---|
| Creator | Yes | Yes | Yes | Yes |
| Editor (added with "Can edit") | Yes | Yes | No | No |
| Viewer (added with "Can view") | Yes | No | No | No |
| Everyone else | Depends on general access | Only if general access is "Can edit" | No | No |

The creator opens **Share** on the assessment. Every change there saves at once (the window shows "Saving…" then "Access saved"), so closing it never loses anything. From Share the creator can:

- tap the search box to list everyone in the app, or type any part of a name or email to narrow it, then tap a person (or press Enter) to add them as **Can edit** or **Can view**
- change or remove someone's access
- set **general access**: *Only people with access* (private), *Everyone in the app · Can view* (the default), or *Everyone in the app · Can edit*

These rules are enforced by the database, not just the screen. Editors can change an assessment's content but not its owner or sharing; only the creator can change sharing (through the `set_assessment_sharing` function) or delete it. The Share search uses `search_app_users`, which only signed-in users can call; it shows names and emails of people with an account, so everyone in the app can see each other's email in that list.

History has filters for **All**, **Created by me** and **Shared with me**.

Evidence files are stored in a public folder, so anyone with a file's direct link can open it, even if the assessment is private.

**Updating an existing project:** run `supabase-setup.sql` again in the SQL Editor. It is safe to re-run and adds the sharing, live co-editing, private workspace, roles, approval and review-comment pieces. Then run `make-me-owner.sql` once with your email. Existing assessments start as *Everyone in the app · Can view*, editable only by their creator.

## Roles and approval

| Role | Who | Can |
|---|---|---|
| Owner | You (set once with `make-me-owner.sql`) | Everything a moderator can, plus make people moderators or users |
| Moderator | People the owner promotes | See every project, approve or reopen projects, leave review comments |
| User | Everyone else | Create projects, share them, and set their own projects to Draft or Under review |

- Tap the **People** icon at the top to see everyone and their role. Only the owner sees role pickers.
- Only moderators can set **Approved**. An approved project is locked: nobody but a moderator can change it until a moderator reopens it (sets it back to Draft or Under review). The database records who approved it and when.
- Approved projects appear under **Approved projects** on the home page; the rest appear under **In progress**.
- These rules are enforced in the database (`app_roles`, `set_user_role`, `list_app_people` and the `assessments_review_guard` trigger), not just on screen.

## Review comments

- Moderators tap **Review** on a project to show a small **+** next to the title, each section (chart, heatmap, before and after, evaluation matrix, measures) and each impact. Tapping it opens a box to write a comment. Outside review mode the layout is unchanged.
- A comment shows as a small speech-bubble icon in that spot: yellow while open, green when acknowledged, red when rejected, with a number when there are several. Hovering shows the comment, which fades away when the pointer leaves; tapping keeps it open (on phones, tap).
- People who can edit the project answer with **Acknowledge** or **Reject**, with an optional note to the moderator. Moderators can reply and **Resolve** (remove) a comment.
- Project cards on the home page show how many comments are still open.
- Stored in `review_comments` and `review_replies`, visible only to people who can see the project and to moderators.

## Live co-editing

There is no Save button. Each change (one score, a name, a category, an attachment) is sent as a small operation to the `apply_assessment_patch` database function, which applies it to the latest version of the assessment while the row is locked. So:

- two people changing different impacts, or different fields of the same impact, never overwrite each other
- if two people change the very same field at the same moment, the later change wins, and both see the result within a second
- changes appear on everyone's screen as they're made, and each editor shows "Saving…" / "All changes saved"
- avatars show who's online, who's viewing an assessment, and which impact and field each person is editing

## Private workspace

Each person's dashboard (filters, charts, chart settings) and compare selection are saved to their own row in `user_settings`, which only they can read or change. They come back on any device after signing in. Charts are always drawn from the latest data the person is allowed to see.

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
