# Question bank sources

The starter bank contains 6,000 questions: 1,000 in each of Science, Sports, General Knowledge, History, Current Affairs, and Music. It retains the original 120 EGS starter questions and adds a selected set from [OpenTriviaQA](https://github.com/uberspot/OpenTriviaQA), licensed under [Creative Commons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/).

Imported content and answers are attributed to OpenTriviaQA and its contributors. The source category files are:

- [Science and Technology](https://github.com/uberspot/OpenTriviaQA/blob/master/categories/science-technology)
- [Sports](https://github.com/uberspot/OpenTriviaQA/blob/master/categories/sports)
- [General](https://github.com/uberspot/OpenTriviaQA/blob/master/categories/general)
- [History](https://github.com/uberspot/OpenTriviaQA/blob/master/categories/history)
- [Newest archive](https://github.com/uberspot/OpenTriviaQA/blob/master/categories/newest)
- [Music](https://github.com/uberspot/OpenTriviaQA/blob/master/categories/music)

## Current Affairs review label

OpenTriviaQA's `newest` category is a static archive, not a live current-affairs feed. Imported entries in that round are tagged `CUR-REV-*` to make review visible in the physical chit and in the bank. Review those entries for relevance, accuracy, age-appropriateness, and suitability before using them in a live event. Replace dated or off-topic entries with school-vetted questions. The other imported question tags use their round prefix and sequence number.

The bank builder is `scripts/build_question_bank.py`. It filters explicit unsuitable terms and lyric-completion questions, keeps the existing seed questions, and produces both the browser bank and the Supabase seed migration. The resulting set is selected from the cited source; it has not been independently fact-checked question by question.
