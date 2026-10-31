# KampusLink

**Study smarter for your Algerian university exams.** KampusLink turns university modules into short, clear lessons,
smart flashcards, quizzes with explained answers, practice problems and timed mock exams. Offline-first, in Arabic,
French and English.

> KampusLink is a study tool. It does not replace lectures or teachers. It is independent and not affiliated with any university.

## Who it is for
- **L1 Sciences et Technologies**: the national common first year shared by all 22 ST specialities
  (Génie civil, Génie mécanique, Génie minier, Électrotechnique, Télécommunications, Hydrocarbures, and more).
- **L2 Génie minier** (pilot), with more specialities and years added continuously from the backend.

## What students get
- **Short lessons** (3 to 8 minutes) that go from intuition to the exam method, with explained diagrams and LaTeX maths
- **Flashcards with spaced repetition**: the app brings back what you are about to forget
- **Quizzes** with an explanation for every answer, including diagram-based questions
- **Carousels**: short puzzles and step-by-step stories that make hard ideas click
- **Practice problems** with progressive hints and full solutions
- **Timed mock exams** in the style of the real exams, with self-marking out of 20
- **A home feed** mixing what you know, what to review and what is new
- **Fully offline** after download; only your year and semester are shown
- **Arabic (RTL), French and English**, switchable at any time
- **Module chat**, report-a-mistake button, study reminders that respect "not now"

## How it works
| Layer | Technology |
|---|---|
| App | Flutter (Android first), Riverpod, go_router |
| Offline storage | Drift (SQLite); the app reads locally and syncs in the background |
| Rendering | flutter_math_fork (LaTeX), flutter_svg (themed diagrams), custom block renderer |
| Backend | Supabase (Postgres, Row Level Security, RPC functions), Cloudflare R2 / Workers |
| Content | JSON lessons produced and verified by a content pipeline, uploaded with an idempotent importer |

**Backend-driven by design:** specialities, years, semesters, modules, app settings and notification texts all come from
the database. Adding a new speciality or year needs no app release.

## Repository
```
lib/        app (shell, data + sync, renderer, features)
test/       unit and widget tests
docs/       backend contract, content format, plans, logs
AGENTS.md   rules for every contributor (read first)
```

## Development
```bash
flutter pub get
flutter analyze
flutter test
flutter run
```
The app only contains the public Supabase anon key. Never commit secrets.
Contributors: read `AGENTS.md` and `docs/BACKEND_CONTRACT.txt` before writing code.

## Status
Live on Google Play. Current content: Génie minier L2 (S3), with L1 Sciences et Technologies in production.

© KampusLink. All rights reserved.
