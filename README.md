# EGS Quizit Arena

A standalone quiz draw and scoring app for EGS. It keeps the question draw, answer timer, pounce register, score paddles, live standings, and presentation screen together. It is separate from the earlier scoring website.

## Run the quiz

1. Open the website and sign in with the quiz administrator account.
2. Select a round and difficulty.
3. Reveal a question by entering the tag on a physical chit, or use the animated wheel to draw an unused question.
4. The revealed question shows its owner. Regular marks can only be awarded to that team. For a pounce, register the team while the timer is running, then enter the judge’s paper-check result. The question’s own team cannot pounce. Pounce is unavailable in the final round.
5. Use Presentation mode on the operator laptop and duplicate the laptop display to the projector.

The defaults follow the supplied rules: 6 quiz rounds plus a final round, 10 seconds per question, correct +10, regular incorrect 0, pounce incorrect −5, and final incorrect −5. Authorized administrators can edit the scoring values, timer length, final round, and team list before or during the quiz.

## Question bank

Question management is on its own page at `?view=bank`. Use the **Question bank** button in the top bar. Add questions one at a time, import a combined CSV/JSON bank, browse by round, or download an export. Tags must be unique within a round. The bank supports up to 10,000 questions per round, split across either five levels of 2,000 or two levels of 5,000.

The shared project is seeded with 120 starter questions (20 per round). Add or import more through the question bank when you are ready.

## Shared Supabase setup

The app is connected to the new EGSQuizIt Supabase project (`xikglhqvmsvywmenvywl`). Its URL and **publishable** key are already in `supabase-config.js`. Never put a service-role or secret key in this public website. The database tables, row-level security, Realtime publication, default scoring state, and 120 starter questions have already been applied to that project.

The database migration is `supabase/migrations/20261018010000_question_draw_shared_arena.sql`. It creates separate `quizit_*` tables, leaves the old `quiz_state` table alone, enables row-level security, and seeds the starter questions and default scoring state. Question text, draw history, teams, scoring rules, and scores sync through Supabase Realtime. Answer keys are stored in a separate admin-only table.

Create the first administrator user in Supabase Dashboard → Authentication → Users → Add user. Use the email and password the quiz operator will sign in with. Then open SQL Editor and grant that user the `admin` app-metadata role. Replace the example email below with the administrator’s sign-in email and run this once:

```sql
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
where email = 'quiz-admin@example.com';
```

The app checks `app_metadata.role`; it does not accept a user-editable profile field as authorization. Sign in to the arena with that account to draw questions, score, change teams, or edit the bank. Keep public sign-ups disabled unless you have a separate reason to allow them. Other visitors can view the shared question and scores but cannot draw, score, or edit the bank.

The app uses shared Supabase data when opened from a hosted site or `localhost`. A `file://` tab may block browser authentication and Realtime; use the hosted GitHub Pages URL when operating across devices.

## Deploy

Publish the contents of this folder as the root of the `EGSQuizIt` GitHub repository, then enable GitHub Pages for the default branch. Because this is a static site, it does not need a server of its own; Supabase supplies authentication, shared data, and Realtime updates.

## Question import format

The included `question-bank-template.csv` uses this header:

```csv
round,difficulty,tag,question,answer,mediaUrl,source
```

Allowed round names are Science, Sports, General Knowledge, History, Current Affairs, and Music. Use the active difficulty names from the selected difficulty setup.
