# EGS Quizit Arena

A standalone quiz draw and scoring app for EGS. It keeps the question draw, answer timer, pounce register, score paddles, live standings, and presentation screen together. It is separate from the earlier scoring website.

## Run the quiz

1. Open the website and sign in with the quiz administrator account.
2. Open **Admin controls** and select a round. Questions are selected from the entire round bank; no difficulty levels are used for now.
3. Reveal a question by entering the tag on a physical chit, or use the animated wheel to draw an unused question.
4. The revealed question shows its owner. Regular marks can only be awarded to that team. For a pounce, register the team while the timer is running, then enter the judge’s paper-check result. The question’s own team cannot pounce. Pounce is unavailable in the final round.
5. Use Presentation mode on the operator laptop and duplicate the laptop display to the projector.

The defaults follow the supplied rules: 6 quiz rounds plus a final round, 10 seconds per question, correct +10, regular incorrect 0, pounce incorrect −5, and final incorrect −5. Authorized administrators can edit the scoring values, timer length, final round, and team list before or during the quiz.

## Question bank

Use **Admin controls** for the question bank, scoring controls, themes, round selection, and presentation launch. **Stats** shows the leaderboard, totals, team-by-round matrix, answer accuracy, and pounce trends. Add questions one at a time, import a combined CSV/JSON bank, browse by round, or download an export. Tags must be unique within a round. Each round supports up to 10,000 questions. Older imports with a `difficulty` column remain accepted, but that value is ignored.

The shared project is seeded with 6,000 questions (1,000 per round). The imported Current Affairs archive is labeled with `CUR-REV-*` tags and should be reviewed before use because it is not a live current-affairs feed. See [QUESTION_BANK_SOURCES.md](QUESTION_BANK_SOURCES.md) for attribution, licensing, and review notes.

## Shared Supabase setup

The app is connected to the new EGSQuizIt Supabase project (`xikglhqvmsvywmenvywl`). Its URL and **publishable** key are already in `supabase-config.js`. Never put a service-role or secret key in this public website. The database tables, row-level security, Realtime publication, default scoring state, and 6,000 starter questions have been applied to that project.

The base migration is `supabase/migrations/20261018010000_question_draw_shared_arena.sql`; `supabase/migrations/20261018103000_seed_minimum_question_bank.sql` fills each round to 1,000 questions. These create separate `quizit_*` tables, leave the old `quiz_state` table alone, enable row-level security, and seed the question bank and default scoring state. Question text, draw history, teams, scoring rules, and scores sync through Supabase Realtime. Answer keys are stored in a separate admin-only table.

Create the first administrator user in Supabase Dashboard → Authentication → Users → Add user. Use the email and password the quiz operator will sign in with. Then open SQL Editor and grant that user the `admin` app-metadata role. Replace the example email below with the administrator’s sign-in email and run this once:

```sql
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
where email = 'quiz-admin@example.com';
```

The app checks `app_metadata.role`; it does not accept a user-editable profile field as authorization. Sign in to the arena with that account to draw questions, score, change teams, or edit the bank. Keep public sign-ups disabled unless you have a separate reason to allow them. Other visitors can view the shared question and scores but cannot draw, score, or edit the bank.

The app uses shared Supabase data when opened from a hosted site or `localhost`. A `file://` tab may block browser authentication and Realtime; use the hosted GitHub Pages URL when operating across devices. The Supabase session is persisted by the browser on that site and device; sign in separately on any other device.

## Deploy

The live site is [egsquizit.github.io/EGSQuizIt](https://egsquizit.github.io/EGSQuizIt/). The app is published from the root of the `EGSQuizIt` GitHub repository. Because this is a static site, it does not need a server of its own; Supabase supplies authentication, shared data, and Realtime updates.

## Question import format

The included `question-bank-template.csv` uses this header:

```csv
round,tag,question,answer,mediaUrl,source
```

Allowed round names are Science, Sports, General Knowledge, History, Current Affairs, and Music. The difficulty field is not required.
