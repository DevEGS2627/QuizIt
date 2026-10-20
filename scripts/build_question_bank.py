#!/usr/bin/env python3
"""Build the bundled EGS Quizit question bank from its cited source files.

The imported OpenTriviaQA material is licensed CC BY-SA 4.0. The original
120-question EGS seed bank is retained and each round is filled to 1,000.
"""

from __future__ import annotations

import json
import random
import re
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = "https://raw.githubusercontent.com/uberspot/OpenTriviaQA/master/categories"
SOURCE_PAGE = "https://github.com/uberspot/OpenTriviaQA/tree/master/categories"
ROUND_SOURCES = {
    "Science": ("SCI", "science-technology"),
    "Sports": ("SPT", "sports"),
    "General Knowledge": ("GKN", "general"),
    "History": ("HIS", "history"),
    "Current Affairs": ("CUR", "newest"),
    "Music": ("MUS", "music"),
}
TARGET_PER_ROUND = 1000
UNSUITABLE = re.compile(
    r"\b(?:porn(?:ography)?|masturbat\w*|orgasm\w*|genitals?|penis|vagina|"
    r"intercourse|prostitut\w*|rape|nigger|faggot|cunt|fuck(?:ing|ed)?|"
    r"shit(?:ty)?|asshole|blowjob|lyrics?)\b",
    re.IGNORECASE,
)
MUSIC_LYRIC_PROMPT = re.compile(
    r"\b(?:complete|finish|continue|next line|next words?|lyrics?|lyric)\b",
    re.IGNORECASE,
)


def request_text(url: str) -> str:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "EGS-Quizit-question-bank-builder/1.0"},
    )
    with urllib.request.urlopen(req, timeout=45) as response:
        return response.read().decode("iso-8859-1")


def parse_source(category: str) -> list[tuple[str, str]]:
    text = request_text(f"{SOURCE_ROOT}/{category}")
    result: list[tuple[str, str]] = []
    question_lines: list[str] = []
    answer = ""
    saw_answer = False

    def finish() -> None:
        nonlocal question_lines, answer, saw_answer
        question = "\n".join(part.strip() for part in question_lines if part.strip()).strip()
        answer_value = answer.strip()
        is_music_lyric = category == "music" and (
            "\n" in question or MUSIC_LYRIC_PROMPT.search(question)
        )
        if (
            12 <= len(question) <= 260
            and 1 <= len(answer_value) <= 120
            and not UNSUITABLE.search(question + " " + answer_value)
            and not is_music_lyric
        ):
            result.append((question, answer_value))
        question_lines = []
        answer = ""
        saw_answer = False

    for line in text.splitlines():
        if line.startswith("#Q "):
            finish()
            question_lines = [line[3:].strip()]
        elif not question_lines:
            continue
        elif line.startswith("^ "):
            answer = line[2:]
            saw_answer = True
        elif saw_answer:
            # The remaining lines are multiple-choice distractors.
            continue
        else:
            question_lines.append(line.strip())
    finish()
    return result


def question_key(question: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", question.casefold()).strip()


def sql_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def build() -> None:
    curated_path = ROOT / "question-bank" / "curated-seed.json"
    curated = json.loads(curated_path.read_text(encoding="utf-8"))
    questions = list(curated)
    added_questions: list[dict[str, str]] = []
    added_answers: list[dict[str, str]] = []

    for round_name, (prefix, category) in ROUND_SOURCES.items():
        existing = [q for q in questions if q["round"] == round_name]
        if len(existing) > TARGET_PER_ROUND:
            raise RuntimeError(f"{round_name} already exceeds the target bank size")
        needed = TARGET_PER_ROUND - len(existing)
        seen = {question_key(q["question"]) for q in existing}
        candidates: list[tuple[str, str]] = []
        for question, answer in parse_source(category):
            key = question_key(question)
            if not key or key in seen:
                continue
            seen.add(key)
            candidates.append((question, answer))

        if len(candidates) < needed:
            raise RuntimeError(
                f"{round_name}: only {len(candidates)} clean, unique source questions; "
                f"need {needed}"
            )

        random.Random(f"egs-quizit-{round_name}-20261018").shuffle(candidates)
        for number, (question, answer) in enumerate(candidates[:needed], start=len(existing) + 1):
            tag = f"{prefix}-REV-{number:04d}" if round_name == "Current Affairs" else f"{prefix}-{number:04d}"
            source = f"{SOURCE_PAGE}/{category}"
            row = {
                "round": round_name,
                "tag": tag,
                "question": question,
                "answer": answer,
                "source": source,
            }
            questions.append(row)
            added_questions.append(row)
            added_answers.append({"question_id": f"{round_name}::{tag.casefold()}", "answer": answer})

    bank_path = ROOT / "starter-bank.js"
    public_questions = [
        {key: value for key, value in question.items() if key != "answer"}
        for question in questions
    ]
    bank_path.write_text(
        "/* EGS curated seed plus the attributed CC BY-SA 4.0 question set. */\n"
        "window.EGS_STARTER_QUESTIONS = "
        + json.dumps(public_questions, ensure_ascii=False, separators=(",", ":"))
        + ";\n",
        encoding="utf-8",
    )

    migration_dir = ROOT / "supabase" / "migrations"
    migration_dir.mkdir(parents=True, exist_ok=True)
    rounds = list(ROUND_SOURCES)
    for index, round_name in enumerate(rounds, start=1):
        round_questions = [row for row in added_questions if row["round"] == round_name]
        round_answers = [row for row in added_answers if row["question_id"].startswith(f"{round_name}::")]
        question_values = []
        for row in round_questions:
            tag_key = row["tag"].casefold()
            question_values.append(
                "(" + ",".join(
                    [
                        sql_quote(f"{row['round']}::{tag_key}"),
                        sql_quote(row["round"]),
                        sql_quote("intermediate"),
                        sql_quote(row["tag"]),
                        sql_quote(tag_key),
                        sql_quote(row["question"]),
                        sql_quote(""),
                        sql_quote(row["source"]),
                    ]
                ) + ")"
            )
        answer_values = [
            "(" + sql_quote(row["question_id"]) + "," + sql_quote(row["answer"]) + ")"
            for row in round_answers
        ]
        sql = [
            f"-- Add {round_name} questions to 1,000 without overwriting live quiz data.",
            "-- Imported question content: OpenTriviaQA, CC BY-SA 4.0 (see QUESTION_BANK_SOURCES.md).",
            "begin;",
            "insert into public.quizit_questions(id,round,difficulty,tag,tag_key,question,media_url,source) values",
            ",\n".join(question_values) + "\non conflict(round,tag_key) do nothing;",
            "insert into public.quizit_question_answers(question_id,answer) values",
            ",\n".join(answer_values) + "\non conflict(question_id) do nothing;",
            "commit;",
        ]
        slug = re.sub(r"[^a-z0-9]+", "_", round_name.casefold()).strip("_")
        migration_path = migration_dir / f"2026101810300{index}_seed_{slug}_to_1000.sql"
        migration_path.write_text("\n".join(sql) + "\n", encoding="utf-8")

    counts = {round_name: sum(q["round"] == round_name for q in questions) for round_name in ROUND_SOURCES}
    if any(count != TARGET_PER_ROUND for count in counts.values()):
        raise RuntimeError(f"Unexpected per-round totals: {counts}")
    print(json.dumps({
        "counts": counts,
        "inserted": len(added_questions),
        "migrations": [str(migration_dir / f"2026101810300{i}_seed_{re.sub(r'[^a-z0-9]+', '_', name.casefold()).strip('_')}_to_1000.sql") for i, name in enumerate(rounds, start=1)],
    }))


if __name__ == "__main__":
    build()
