# Smile AI — AI administrator for dental clinic booking

Cross-platform mobile app (Flutter + Bloc) where a patient books a dentist by writing one
sentence, e.g. *"my tooth hurts, tomorrow after lunch"*. The server's AI assistant picks the
right doctor, finds free slots and shows them as tappable cards; one tap creates the appointment.

| Requirement | How it is met |
|---|---|
| Cross-platform mobile app (Flutter) | `app/` — Android, iOS and Web from one codebase |
| Mobile communicates with server | REST API in `server/` (FastAPI). Auth, doctors, appointments and AI chat all go over HTTP + JSON with a Bearer token |
| Pushed on GitHub | This repository, with CI (`.github/workflows/ci.yml`) running server tests, `flutter analyze`, `flutter test` and a web build |
| State management (Bloc) | `flutter_bloc`: `AuthBloc`, `ChatBloc`, `AppointmentsBloc`, `DoctorsBloc` |

## Features

- Register / login, session kept between launches (token in `shared_preferences`)
- **AI chat**: describe the problem and preferred time → slot cards → tap to book → confirmation card
- Two assistant modes, shown as a badge in the app bar:
  - **AI** — any OpenAI-compatible LLM with tool calling (`find_slots`, `book_appointment`, `list_my_appointments`)
  - **Offline** — built-in Russian/English keyword parser (specialty, date, part of day). Used when no API key is set or the LLM fails, so the demo always works
- My appointments: list, pull-to-refresh, cancel with confirmation, badge counter in the nav bar
- Doctors: list of specialists, "Book via AI" opens the chat with a prepared request
- Server rules: Mon–Sat 09:00–18:00, one-hour slots, no double booking, no past times

## Architecture

```
app/lib
├── main.dart                 # providers + AuthGate (login vs home)
├── core/                     # ApiClient (http), config, date formatters
├── data/                     # models + repositories (AuthRepository, ClinicRepository)
├── bloc/                     # events, states, blocs
└── ui/                       # screens + widgets

server/app
├── main.py                   # FastAPI endpoints
├── auth.py                   # PBKDF2 passwords, bearer tokens
├── scheduling.py             # slots and booking rules
├── assistant.py              # LLM tool calling + offline fallback
└── db.py                     # SQLite schema and seed doctors
```

Data flow: `UI → Event → Bloc → Repository → ApiClient → REST API → SQLite / LLM` and back as a new `State`.

## API

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/register` | – | `{name, email, password}` → `{token, user}` |
| POST | `/auth/login` | – | `{email, password}` → `{token, user}` |
| GET | `/me` | ✓ | Current user |
| GET | `/doctors` | – | List of doctors |
| GET | `/doctors/{id}/slots` | – | Free slots of a doctor |
| GET | `/appointments` | ✓ | My upcoming appointments |
| POST | `/appointments` | ✓ | `{doctor_id, start: "YYYY-MM-DDTHH:MM"}` |
| DELETE | `/appointments/{id}` | ✓ | Cancel |
| POST | `/chat` | ✓ | `{message, history}` → `{reply, slots, appointment, mode}` |

Interactive docs: http://localhost:8000/docs

## Run

### 1. Server

```bash
cd server
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Optional AI mode: copy `.env.example` to `.env` and set `LLM_API_KEY`
(works with OpenAI, OpenRouter, Groq, Gemini OpenAI-compatible endpoint — set `LLM_BASE_URL` and `LLM_MODEL`).

Tests: `python -m pytest -q`

### 2. App

```bash
cd app
flutter create . --project-name ai_clinic   # first time only: generates android/ios/web folders
flutter pub get
flutter run
```

Server address used by the app:
- Android emulator → `http://10.0.2.2:8000` (default)
- iOS simulator / web → `http://localhost:8000` (default)
- Real phone → `flutter run --dart-define=API_URL=http://<your-PC-IP>:8000` (phone and PC on the same Wi-Fi)

Tests: `flutter test`

## Demo script (2 minutes)

1. Register → the assistant greets you by name.
2. Type *"Болит зуб, завтра после обеда"* → therapist slots after 13:00 appear as cards.
3. Tap a slot → confirmation card, "My appointments" badge shows 1.
4. Open **Doctors** → "Book via AI" on the orthodontist → chat finds orthodontist slots.
5. Open **My appointments** → cancel one.
