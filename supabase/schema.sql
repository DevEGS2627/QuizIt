-- EGS Quizit question-draw shared arena. Separate from the legacy quiz_state table.
create table if not exists public.quizit_questions (
  id text primary key,
  round text not null check (round in ('Science','Sports','General Knowledge','History','Current Affairs','Music')),
  difficulty text not null,
  tag text not null,
  tag_key text not null,
  question text not null,
  media_url text not null default '',
  source text not null default '',
  created_at timestamptz not null default now(),
  unique (round, tag_key)
);

create table if not exists public.quizit_question_answers (
  question_id text primary key references public.quizit_questions(id) on delete cascade,
  answer text not null default ''
);

create table if not exists public.quizit_draws (
  id text primary key,
  round text not null,
  tag text not null,
  tag_key text not null,
  question_id text not null references public.quizit_questions(id) on delete restrict,
  difficulty text not null,
  method text not null,
  time timestamptz not null default now(),
  active boolean not null default true,
  reset_at timestamptz
);
create unique index if not exists quizit_one_active_draw_per_tag on public.quizit_draws(round,tag_key) where active;
create index if not exists quizit_draws_round_time_idx on public.quizit_draws(round,time desc);
create index if not exists quizit_draws_question_id_idx on public.quizit_draws(question_id);

create table if not exists public.quizit_live_state (
  id text primary key check (id = 'main'),
  state jsonb not null,
  updated_at timestamptz not null default now()
);

create or replace function public.quizit_is_admin()
returns boolean
language sql stable
set search_path = ''
as $$ select coalesce((auth.jwt()->'app_metadata'->>'role')='admin', false) $$;
revoke all on function public.quizit_is_admin() from public;
grant execute on function public.quizit_is_admin() to anon, authenticated;

alter table public.quizit_questions enable row level security;
alter table public.quizit_question_answers enable row level security;
alter table public.quizit_draws enable row level security;
alter table public.quizit_live_state enable row level security;

grant select on public.quizit_questions, public.quizit_draws, public.quizit_live_state to anon, authenticated;
grant insert, update, delete on public.quizit_questions, public.quizit_draws, public.quizit_live_state to authenticated;
grant select, insert, update, delete on public.quizit_question_answers to authenticated;

drop policy if exists quizit_questions_public_read on public.quizit_questions;
create policy quizit_questions_public_read on public.quizit_questions for select to anon, authenticated using (true);
drop policy if exists quizit_questions_admin_write on public.quizit_questions;
drop policy if exists quizit_questions_admin_insert on public.quizit_questions;
drop policy if exists quizit_questions_admin_update on public.quizit_questions;
drop policy if exists quizit_questions_admin_delete on public.quizit_questions;
create policy quizit_questions_admin_insert on public.quizit_questions for insert to authenticated with check ((select public.quizit_is_admin()));
create policy quizit_questions_admin_update on public.quizit_questions for update to authenticated using ((select public.quizit_is_admin())) with check ((select public.quizit_is_admin()));
create policy quizit_questions_admin_delete on public.quizit_questions for delete to authenticated using ((select public.quizit_is_admin()));

drop policy if exists quizit_answers_admin_only on public.quizit_question_answers;
create policy quizit_answers_admin_only on public.quizit_question_answers for all to authenticated using ((select public.quizit_is_admin())) with check ((select public.quizit_is_admin()));

drop policy if exists quizit_draws_public_read on public.quizit_draws;
create policy quizit_draws_public_read on public.quizit_draws for select to anon, authenticated using (true);
drop policy if exists quizit_draws_admin_write on public.quizit_draws;
drop policy if exists quizit_draws_admin_insert on public.quizit_draws;
drop policy if exists quizit_draws_admin_update on public.quizit_draws;
drop policy if exists quizit_draws_admin_delete on public.quizit_draws;
create policy quizit_draws_admin_insert on public.quizit_draws for insert to authenticated with check ((select public.quizit_is_admin()));
create policy quizit_draws_admin_update on public.quizit_draws for update to authenticated using ((select public.quizit_is_admin())) with check ((select public.quizit_is_admin()));
create policy quizit_draws_admin_delete on public.quizit_draws for delete to authenticated using ((select public.quizit_is_admin()));

drop policy if exists quizit_live_state_public_read on public.quizit_live_state;
create policy quizit_live_state_public_read on public.quizit_live_state for select to anon, authenticated using (true);
drop policy if exists quizit_live_state_admin_write on public.quizit_live_state;
drop policy if exists quizit_live_state_admin_insert on public.quizit_live_state;
drop policy if exists quizit_live_state_admin_update on public.quizit_live_state;
drop policy if exists quizit_live_state_admin_delete on public.quizit_live_state;
create policy quizit_live_state_admin_insert on public.quizit_live_state for insert to authenticated with check ((select public.quizit_is_admin()));
create policy quizit_live_state_admin_update on public.quizit_live_state for update to authenticated using ((select public.quizit_is_admin())) with check ((select public.quizit_is_admin()));
create policy quizit_live_state_admin_delete on public.quizit_live_state for delete to authenticated using ((select public.quizit_is_admin()));

insert into public.quizit_live_state(id,state) values ('main', jsonb_build_object(
  'teams',jsonb_build_array('Team 1','Team 2','Team 3','Team 4','Team 5','Team 6'),
  'rounds',jsonb_build_array('Science','Sports','General Knowledge','History','Current Affairs','Music','Final Round'),
  'finalRound',6,'correct',10,'pouncePenalty',5,'finalPenalty',5,'questionSeconds',10,
  'logos',jsonb_build_array(),'entries',jsonb_build_array(),
  'questionOrderMode','sequence','nextTeamIndex',0,
  'selectedRound','Science','difficultyMode','five','selectedDifficulty','foundation',
  'currentQuestion',null,'questionSessionId',''
)) on conflict(id) do nothing;

insert into public.quizit_questions(id,round,difficulty,tag,tag_key,question,media_url,source) values
('Science::sci-001', 'Science', 'foundation', 'SCI-001', 'sci-001', 'Which planet is known as the Red Planet?', '', ''),
('Science::sci-002', 'Science', 'easy', 'SCI-002', 'sci-002', 'What is the chemical symbol for gold?', '', ''),
('Science::sci-003', 'Science', 'intermediate', 'SCI-003', 'sci-003', 'Which gas do plants absorb during photosynthesis?', '', ''),
('Science::sci-004', 'Science', 'advanced', 'SCI-004', 'sci-004', 'What is the largest organ of the human body?', '', ''),
('Science::sci-005', 'Science', 'expert', 'SCI-005', 'sci-005', 'How many bones are there in an adult human body?', '', ''),
('Science::sci-006', 'Science', 'foundation', 'SCI-006', 'sci-006', 'What is the SI unit of force?', '', ''),
('Science::sci-007', 'Science', 'easy', 'SCI-007', 'sci-007', 'Which part of a plant cell contains chlorophyll?', '', ''),
('Science::sci-008', 'Science', 'intermediate', 'SCI-008', 'sci-008', 'At sea level, what is the boiling point of water in degrees Celsius?', '', ''),
('Science::sci-009', 'Science', 'advanced', 'SCI-009', 'sci-009', 'What is the closest star to Earth?', '', ''),
('Science::sci-010', 'Science', 'expert', 'SCI-010', 'sci-010', 'Which blood cells help the body fight infections?', '', ''),
('Science::sci-011', 'Science', 'foundation', 'SCI-011', 'sci-011', 'What is the process by which liquid water changes into water vapour?', '', ''),
('Science::sci-012', 'Science', 'easy', 'SCI-012', 'sci-012', 'Which planet has the most prominent ring system?', '', ''),
('Science::sci-013', 'Science', 'intermediate', 'SCI-013', 'sci-013', 'What is the pH of a neutral solution at room temperature?', '', ''),
('Science::sci-014', 'Science', 'advanced', 'SCI-014', 'sci-014', 'Which vitamin can the human body make when skin is exposed to sunlight?', '', ''),
('Science::sci-015', 'Science', 'expert', 'SCI-015', 'sci-015', 'What is the name of the force that pulls objects toward Earth?', '', ''),
('Science::sci-016', 'Science', 'foundation', 'SCI-016', 'sci-016', 'Which organ pumps blood around the human body?', '', ''),
('Science::sci-017', 'Science', 'easy', 'SCI-017', 'sci-017', 'What is the hardest naturally occurring substance?', '', ''),
('Science::sci-018', 'Science', 'intermediate', 'SCI-018', 'sci-018', 'What is the smallest unit of an element that retains its chemical properties?', '', ''),
('Science::sci-019', 'Science', 'advanced', 'SCI-019', 'sci-019', 'Which gas makes up most of Earth’s atmosphere?', '', ''),
('Science::sci-020', 'Science', 'expert', 'SCI-020', 'sci-020', 'What type of energy does a moving object possess?', '', ''),
('Sports::spt-001', 'Sports', 'foundation', 'SPT-001', 'spt-001', 'How many players from one team are on the court in a basketball game?', '', ''),
('Sports::spt-002', 'Sports', 'easy', 'SPT-002', 'spt-002', 'How many rings appear on the Olympic symbol?', '', ''),
('Sports::spt-003', 'Sports', 'intermediate', 'SPT-003', 'spt-003', 'In which sport is the term “love” used for a score of zero?', '', ''),
('Sports::spt-004', 'Sports', 'advanced', 'SPT-004', 'spt-004', 'How many players are on the field for one football (soccer) team at the start of a match?', '', ''),
('Sports::spt-005', 'Sports', 'expert', 'SPT-005', 'spt-005', 'Which country hosts the Wimbledon tennis championships?', '', ''),
('Sports::spt-006', 'Sports', 'foundation', 'SPT-006', 'spt-006', 'In cricket, how many runs are scored when the ball reaches the boundary without bouncing?', '', ''),
('Sports::spt-007', 'Sports', 'easy', 'SPT-007', 'spt-007', 'What is the name of the trophy awarded to the winner of the men’s FIFA World Cup?', '', ''),
('Sports::spt-008', 'Sports', 'intermediate', 'SPT-008', 'spt-008', 'Which sport uses a shuttlecock?', '', ''),
('Sports::spt-009', 'Sports', 'advanced', 'SPT-009', 'spt-009', 'How many squares are there on a standard chessboard?', '', ''),
('Sports::spt-010', 'Sports', 'expert', 'SPT-010', 'spt-010', 'In which sport would you perform a slam dunk?', '', ''),
('Sports::spt-011', 'Sports', 'foundation', 'SPT-011', 'spt-011', 'What is the maximum score with one dart in a standard game of darts?', '', ''),
('Sports::spt-012', 'Sports', 'easy', 'SPT-012', 'spt-012', 'Which track-and-field event combines running, jumping, and throwing across ten events?', '', ''),
('Sports::spt-013', 'Sports', 'intermediate', 'SPT-013', 'spt-013', 'How many players from one team are on court in indoor volleyball?', '', ''),
('Sports::spt-014', 'Sports', 'advanced', 'SPT-014', 'spt-014', 'What colour card sends a player off in association football?', '', ''),
('Sports::spt-015', 'Sports', 'expert', 'SPT-015', 'spt-015', 'Which sport is played at the Tour de France?', '', ''),
('Sports::spt-016', 'Sports', 'foundation', 'SPT-016', 'spt-016', 'How many minutes are in a regulation rugby union match, excluding added time?', '', ''),
('Sports::spt-017', 'Sports', 'easy', 'SPT-017', 'spt-017', 'Which Indian city is home to the Eden Gardens cricket stadium?', '', ''),
('Sports::spt-018', 'Sports', 'intermediate', 'SPT-018', 'spt-018', 'What is the central object hit back and forth in table tennis called?', '', ''),
('Sports::spt-019', 'Sports', 'advanced', 'SPT-019', 'spt-019', 'In which sport do competitors compete for the Ashes?', '', ''),
('Sports::spt-020', 'Sports', 'expert', 'SPT-020', 'spt-020', 'What is the name of the area from which a golfer starts each hole?', '', ''),
('General Knowledge::gkn-001', 'General Knowledge', 'foundation', 'GKN-001', 'gkn-001', 'What is the capital city of Japan?', '', ''),
('General Knowledge::gkn-002', 'General Knowledge', 'easy', 'GKN-002', 'gkn-002', 'Which is the largest ocean on Earth?', '', ''),
('General Knowledge::gkn-003', 'General Knowledge', 'intermediate', 'GKN-003', 'gkn-003', 'How many sides does a hexagon have?', '', ''),
('General Knowledge::gkn-004', 'General Knowledge', 'advanced', 'GKN-004', 'gkn-004', 'What is the currency of the United Kingdom?', '', ''),
('General Knowledge::gkn-005', 'General Knowledge', 'expert', 'GKN-005', 'gkn-005', 'Which language has the most native speakers worldwide?', '', ''),
('General Knowledge::gkn-006', 'General Knowledge', 'foundation', 'GKN-006', 'gkn-006', 'What is the largest mammal in the world?', '', ''),
('General Knowledge::gkn-007', 'General Knowledge', 'easy', 'GKN-007', 'gkn-007', 'How many days are there in a leap year?', '', ''),
('General Knowledge::gkn-008', 'General Knowledge', 'intermediate', 'GKN-008', 'gkn-008', 'Which is the smallest continent by land area?', '', ''),
('General Knowledge::gkn-009', 'General Knowledge', 'advanced', 'GKN-009', 'gkn-009', 'What is the name of the imaginary line at 0° latitude?', '', ''),
('General Knowledge::gkn-010', 'General Knowledge', 'expert', 'GKN-010', 'gkn-010', 'How many colours are traditionally named in a rainbow?', '', ''),
('General Knowledge::gkn-011', 'General Knowledge', 'foundation', 'GKN-011', 'gkn-011', 'Which is the largest hot desert in the world?', '', ''),
('General Knowledge::gkn-012', 'General Knowledge', 'easy', 'GKN-012', 'gkn-012', 'What is the capital of Australia?', '', ''),
('General Knowledge::gkn-013', 'General Knowledge', 'intermediate', 'GKN-013', 'gkn-013', 'What is the Roman numeral for 50?', '', ''),
('General Knowledge::gkn-014', 'General Knowledge', 'advanced', 'GKN-014', 'gkn-014', 'Which bird is commonly used as a symbol of peace?', '', ''),
('General Knowledge::gkn-015', 'General Knowledge', 'expert', 'GKN-015', 'gkn-015', 'What is the name of the ship on which Charles Darwin made his famous voyage?', '', ''),
('General Knowledge::gkn-016', 'General Knowledge', 'foundation', 'GKN-016', 'gkn-016', 'How many minutes are there in one hour?', '', ''),
('General Knowledge::gkn-017', 'General Knowledge', 'easy', 'GKN-017', 'gkn-017', 'Which instrument is used to measure temperature?', '', ''),
('General Knowledge::gkn-018', 'General Knowledge', 'intermediate', 'GKN-018', 'gkn-018', 'What is the official residence of the President of India called?', '', ''),
('General Knowledge::gkn-019', 'General Knowledge', 'advanced', 'GKN-019', 'gkn-019', 'Which country is famous for the ancient city of Petra?', '', ''),
('General Knowledge::gkn-020', 'General Knowledge', 'expert', 'GKN-020', 'gkn-020', 'What is the name for a word that has the opposite meaning of another word?', '', ''),
('History::his-001', 'History', 'foundation', 'HIS-001', 'his-001', 'In which year did India gain independence from British rule?', '', ''),
('History::his-002', 'History', 'easy', 'HIS-002', 'his-002', 'Who was the first person to walk on the Moon?', '', ''),
('History::his-003', 'History', 'intermediate', 'HIS-003', 'his-003', 'Which ancient civilisation built the pyramids at Giza?', '', ''),
('History::his-004', 'History', 'advanced', 'HIS-004', 'his-004', 'Who led the Salt March in India in 1930?', '', ''),
('History::his-005', 'History', 'expert', 'HIS-005', 'his-005', 'In which year did the First World War begin?', '', ''),
('History::his-006', 'History', 'foundation', 'HIS-006', 'his-006', 'Which Indian emperor issued edicts after the Kalinga War and embraced Buddhism?', '', ''),
('History::his-007', 'History', 'easy', 'HIS-007', 'his-007', 'Which wall divided Berlin from 1961 until 1989?', '', ''),
('History::his-008', 'History', 'intermediate', 'HIS-008', 'his-008', 'Who was the first Mughal emperor in India?', '', ''),
('History::his-009', 'History', 'advanced', 'HIS-009', 'his-009', 'Which civilisation built the city of Machu Picchu?', '', ''),
('History::his-010', 'History', 'expert', 'HIS-010', 'his-010', 'In which year was the United Nations founded?', '', ''),
('History::his-011', 'History', 'foundation', 'HIS-011', 'his-011', 'Who was the first President of the United States?', '', ''),
('History::his-012', 'History', 'easy', 'HIS-012', 'his-012', 'Which Indian movement began in 1942 with the slogan “Do or Die”?', '', ''),
('History::his-013', 'History', 'intermediate', 'HIS-013', 'his-013', 'Which famous passenger liner sank on its maiden voyage in 1912?', '', ''),
('History::his-014', 'History', 'advanced', 'HIS-014', 'his-014', 'Who was known as the Iron Man of India?', '', ''),
('History::his-015', 'History', 'expert', 'HIS-015', 'his-015', 'Which French heroine helped lead her country during the Hundred Years’ War?', '', ''),
('History::his-016', 'History', 'foundation', 'HIS-016', 'his-016', 'In which year did the French Revolution begin?', '', ''),
('History::his-017', 'History', 'easy', 'HIS-017', 'his-017', 'Who founded the Maurya Empire?', '', ''),
('History::his-018', 'History', 'intermediate', 'HIS-018', 'his-018', 'Which document, signed in 1215, limited the power of the English king?', '', ''),
('History::his-019', 'History', 'advanced', 'HIS-019', 'his-019', 'Who was the first woman to fly solo across the Atlantic Ocean?', '', ''),
('History::his-020', 'History', 'expert', 'HIS-020', 'his-020', 'Which ancient Indian university was located in present-day Bihar?', '', ''),
('Current Affairs::cur-001', 'Current Affairs', 'foundation', 'CUR-001', 'cur-001', 'Which country won the 2026 FIFA World Cup?', '', ''),
('Current Affairs::cur-002', 'Current Affairs', 'easy', 'CUR-002', 'cur-002', 'Which team did Spain defeat in the 2026 FIFA World Cup final?', '', ''),
('Current Affairs::cur-003', 'Current Affairs', 'intermediate', 'CUR-003', 'cur-003', 'Which three countries jointly hosted the 2026 FIFA World Cup?', '', ''),
('Current Affairs::cur-004', 'Current Affairs', 'advanced', 'CUR-004', 'cur-004', 'What was the score in the 2026 FIFA World Cup final, which Spain won after extra time?', '', ''),
('Current Affairs::cur-005', 'Current Affairs', 'expert', 'CUR-005', 'cur-005', 'What does the Indian space mission name SpaDeX stand for?', '', ''),
('Current Affairs::cur-006', 'Current Affairs', 'foundation', 'CUR-006', 'cur-006', 'Which Indian mission successfully demonstrated docking in orbit in January 2025?', '', ''),
('Current Affairs::cur-007', 'Current Affairs', 'easy', 'CUR-007', 'cur-007', 'Which two space agencies jointly developed the NISAR Earth-observation mission?', '', ''),
('Current Affairs::cur-008', 'Current Affairs', 'intermediate', 'CUR-008', 'cur-008', 'In which year was the United Nations International Year of Quantum Science and Technology observed?', '', ''),
('Current Affairs::cur-009', 'Current Affairs', 'advanced', 'CUR-009', 'cur-009', 'What was the United Nations International Year of Cooperatives?', '', ''),
('Current Affairs::cur-010', 'Current Affairs', 'expert', 'CUR-010', 'cur-010', 'Which three scientists received the 2025 Nobel Prize in Physics?', '', ''),
('Current Affairs::cur-011', 'Current Affairs', 'foundation', 'CUR-011', 'cur-011', 'Who received the 2025 Nobel Peace Prize?', '', ''),
('Current Affairs::cur-012', 'Current Affairs', 'easy', 'CUR-012', 'cur-012', 'Who received the 2025 Nobel Prize in Literature?', '', ''),
('Current Affairs::cur-013', 'Current Affairs', 'intermediate', 'CUR-013', 'cur-013', 'Which three scientists received the 2025 Nobel Prize in Chemistry?', '', ''),
('Current Affairs::cur-014', 'Current Affairs', 'advanced', 'CUR-014', 'cur-014', 'Who received the 2025 Nobel Prize in Economic Sciences for work on innovation-driven economic growth?', '', ''),
('Current Affairs::cur-015', 'Current Affairs', 'expert', 'CUR-015', 'cur-015', 'Which three researchers shared the 2025 Nobel Prize in Physiology or Medicine?', '', ''),
('Current Affairs::cur-016', 'Current Affairs', 'foundation', 'CUR-016', 'cur-016', 'Which city hosted Expo 2025?', '', ''),
('Current Affairs::cur-017', 'Current Affairs', 'easy', 'CUR-017', 'cur-017', 'Which Brazilian city hosted the 2025 United Nations Climate Change Conference, COP30?', '', ''),
('Current Affairs::cur-018', 'Current Affairs', 'intermediate', 'CUR-018', 'cur-018', 'Which country held the G20 presidency in 2025?', '', ''),
('Current Affairs::cur-019', 'Current Affairs', 'advanced', 'CUR-019', 'cur-019', 'Which country became the first African nation to hold the G20 presidency?', '', ''),
('Current Affairs::cur-020', 'Current Affairs', 'expert', 'CUR-020', 'cur-020', 'In which country was the 2025 UN Climate Change Conference (COP30) held?', '', ''),
('Music::mus-001', 'Music', 'foundation', 'MUS-001', 'mus-001', 'How many keys does a standard modern piano usually have?', '', ''),
('Music::mus-002', 'Music', 'easy', 'MUS-002', 'mus-002', 'Which family of instruments does the violin belong to?', '', ''),
('Music::mus-003', 'Music', 'intermediate', 'MUS-003', 'mus-003', 'What is the Italian musical term for playing loudly?', '', ''),
('Music::mus-004', 'Music', 'advanced', 'MUS-004', 'mus-004', 'How many lines are there on a standard musical staff?', '', ''),
('Music::mus-005', 'Music', 'expert', 'MUS-005', 'mus-005', 'Which instrument has black and white keys and is commonly used to play chords?', '', ''),
('Music::mus-006', 'Music', 'foundation', 'MUS-006', 'mus-006', 'What is the name of the symbol at the beginning of a staff that indicates pitch?', '', ''),
('Music::mus-007', 'Music', 'easy', 'MUS-007', 'mus-007', 'Which Indian percussion instrument is played as a pair of hand drums?', '', ''),
('Music::mus-008', 'Music', 'intermediate', 'MUS-008', 'mus-008', 'How many beats does a whole note receive in common time?', '', ''),
('Music::mus-009', 'Music', 'advanced', 'MUS-009', 'mus-009', 'Which instrument is played by blowing across a hole and is usually made of metal?', '', ''),
('Music::mus-010', 'Music', 'expert', 'MUS-010', 'mus-010', 'What is a group of singers performing together called?', '', ''),
('Music::mus-011', 'Music', 'foundation', 'MUS-011', 'mus-011', 'Which composer wrote the “Moonlight Sonata”?', '', ''),
('Music::mus-012', 'Music', 'easy', 'MUS-012', 'mus-012', 'What is the highest common adult female singing voice?', '', ''),
('Music::mus-013', 'Music', 'intermediate', 'MUS-013', 'mus-013', 'Which string instrument is usually held under the chin and played with a bow?', '', ''),
('Music::mus-014', 'Music', 'advanced', 'MUS-014', 'mus-014', 'What does the musical term “piano” mean in dynamics?', '', ''),
('Music::mus-015', 'Music', 'expert', 'MUS-015', 'mus-015', 'How many semitones are there in an octave in Western music?', '', ''),
('Music::mus-016', 'Music', 'foundation', 'MUS-016', 'mus-016', 'Which Indian string instrument is often associated with Ravi Shankar?', '', ''),
('Music::mus-017', 'Music', 'easy', 'MUS-017', 'mus-017', 'What is the person who leads an orchestra called?', '', ''),
('Music::mus-018', 'Music', 'intermediate', 'MUS-018', 'mus-018', 'Which instrument has a mouthpiece, valves, and a flared bell and belongs to the brass family?', '', ''),
('Music::mus-019', 'Music', 'advanced', 'MUS-019', 'mus-019', 'What is the speed of a piece of music called?', '', ''),
('Music::mus-020', 'Music', 'expert', 'MUS-020', 'mus-020', 'Which percussion instrument is made of a pair of small metal discs that are struck together?', '', '')
on conflict(round,tag_key) do nothing;
insert into public.quizit_question_answers(question_id,answer) values
('Science::sci-001', 'Mars'),
('Science::sci-002', 'Au'),
('Science::sci-003', 'Carbon dioxide'),
('Science::sci-004', 'The skin'),
('Science::sci-005', '206'),
('Science::sci-006', 'Newton'),
('Science::sci-007', 'Chloroplast'),
('Science::sci-008', '100°C'),
('Science::sci-009', 'The Sun'),
('Science::sci-010', 'White blood cells'),
('Science::sci-011', 'Evaporation'),
('Science::sci-012', 'Saturn'),
('Science::sci-013', '7'),
('Science::sci-014', 'Vitamin D'),
('Science::sci-015', 'Gravity'),
('Science::sci-016', 'The heart'),
('Science::sci-017', 'Diamond'),
('Science::sci-018', 'An atom'),
('Science::sci-019', 'Nitrogen'),
('Science::sci-020', 'Kinetic energy'),
('Sports::spt-001', '5'),
('Sports::spt-002', '5'),
('Sports::spt-003', 'Tennis'),
('Sports::spt-004', '11'),
('Sports::spt-005', 'The United Kingdom (England)'),
('Sports::spt-006', '6'),
('Sports::spt-007', 'The FIFA World Cup Trophy'),
('Sports::spt-008', 'Badminton'),
('Sports::spt-009', '64'),
('Sports::spt-010', 'Basketball'),
('Sports::spt-011', '60'),
('Sports::spt-012', 'Decathlon'),
('Sports::spt-013', '6'),
('Sports::spt-014', 'Red'),
('Sports::spt-015', 'Road cycling'),
('Sports::spt-016', '80'),
('Sports::spt-017', 'Kolkata'),
('Sports::spt-018', 'A ball'),
('Sports::spt-019', 'Cricket'),
('Sports::spt-020', 'The tee (teeing area)'),
('General Knowledge::gkn-001', 'Tokyo'),
('General Knowledge::gkn-002', 'The Pacific Ocean'),
('General Knowledge::gkn-003', '6'),
('General Knowledge::gkn-004', 'The pound sterling'),
('General Knowledge::gkn-005', 'Mandarin Chinese'),
('General Knowledge::gkn-006', 'The blue whale'),
('General Knowledge::gkn-007', '366'),
('General Knowledge::gkn-008', 'Australia'),
('General Knowledge::gkn-009', 'The Equator'),
('General Knowledge::gkn-010', '7'),
('General Knowledge::gkn-011', 'The Sahara'),
('General Knowledge::gkn-012', 'Canberra'),
('General Knowledge::gkn-013', 'L'),
('General Knowledge::gkn-014', 'A dove'),
('General Knowledge::gkn-015', 'HMS Beagle'),
('General Knowledge::gkn-016', '60'),
('General Knowledge::gkn-017', 'A thermometer'),
('General Knowledge::gkn-018', 'Rashtrapati Bhavan'),
('General Knowledge::gkn-019', 'Jordan'),
('General Knowledge::gkn-020', 'An antonym'),
('History::his-001', '1947'),
('History::his-002', 'Neil Armstrong'),
('History::his-003', 'The ancient Egyptians'),
('History::his-004', 'Mahatma Gandhi'),
('History::his-005', '1914'),
('History::his-006', 'Ashoka (Ashoka the Great)'),
('History::his-007', 'The Berlin Wall'),
('History::his-008', 'Babur'),
('History::his-009', 'The Inca civilisation'),
('History::his-010', '1945'),
('History::his-011', 'George Washington'),
('History::his-012', 'The Quit India Movement'),
('History::his-013', 'The RMS Titanic'),
('History::his-014', 'Sardar Vallabhbhai Patel'),
('History::his-015', 'Joan of Arc'),
('History::his-016', '1789'),
('History::his-017', 'Chandragupta Maurya'),
('History::his-018', 'Magna Carta'),
('History::his-019', 'Amelia Earhart'),
('History::his-020', 'Nalanda University'),
('Current Affairs::cur-001', 'Spain'),
('Current Affairs::cur-002', 'Argentina'),
('Current Affairs::cur-003', 'Canada, Mexico, and the United States'),
('Current Affairs::cur-004', 'Spain 1–0 Argentina'),
('Current Affairs::cur-005', 'Space Docking Experiment'),
('Current Affairs::cur-006', 'SpaDeX (Space Docking Experiment)'),
('Current Affairs::cur-007', 'NASA and ISRO'),
('Current Affairs::cur-008', '2025'),
('Current Affairs::cur-009', '2025'),
('Current Affairs::cur-010', 'John Clarke, Michel H. Devoret, and John M. Martinis'),
('Current Affairs::cur-011', 'Maria Corina Machado'),
('Current Affairs::cur-012', 'László Krasznahorkai'),
('Current Affairs::cur-013', 'Susumu Kitagawa, Richard Robson, and Omar M. Yaghi'),
('Current Affairs::cur-014', 'Joel Mokyr, Philippe Aghion, and Peter Howitt'),
('Current Affairs::cur-015', 'Mary E. Brunkow, Fred Ramsdell, and Shimon Sakaguchi'),
('Current Affairs::cur-016', 'Osaka, Japan'),
('Current Affairs::cur-017', 'Belém'),
('Current Affairs::cur-018', 'South Africa'),
('Current Affairs::cur-019', 'South Africa'),
('Current Affairs::cur-020', 'Brazil'),
('Music::mus-001', '88'),
('Music::mus-002', 'The string family'),
('Music::mus-003', 'Forte'),
('Music::mus-004', '5'),
('Music::mus-005', 'The piano'),
('Music::mus-006', 'A clef'),
('Music::mus-007', 'Tabla'),
('Music::mus-008', '4 beats'),
('Music::mus-009', 'The flute'),
('Music::mus-010', 'A choir'),
('Music::mus-011', 'Ludwig van Beethoven'),
('Music::mus-012', 'Soprano'),
('Music::mus-013', 'The violin'),
('Music::mus-014', 'Softly'),
('Music::mus-015', '12'),
('Music::mus-016', 'The sitar'),
('Music::mus-017', 'The conductor'),
('Music::mus-018', 'The trumpet'),
('Music::mus-019', 'Tempo'),
('Music::mus-020', 'Cymbals')
on conflict(question_id) do nothing;

do $$ begin
  if exists (select 1 from pg_publication where pubname='supabase_realtime') then
    if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='quizit_questions') then execute 'alter publication supabase_realtime add table public.quizit_questions'; end if;
    if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='quizit_question_answers') then execute 'alter publication supabase_realtime add table public.quizit_question_answers'; end if;
    if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='quizit_draws') then execute 'alter publication supabase_realtime add table public.quizit_draws'; end if;
    if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='quizit_live_state') then execute 'alter publication supabase_realtime add table public.quizit_live_state'; end if;
  end if;
end $$;
