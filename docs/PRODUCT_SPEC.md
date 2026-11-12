# Smile AI — product specification (v3)

This is the brief the product is built from. It turns the mid-term demo (one chat that books
a dentist) into a two-sided booking product that can run as a real service.

## 1. Product in one paragraph

Smile AI is a booking marketplace for local service businesses in one city. **Clients** find a
place, or simply write or say what they need ("haircut tomorrow morning"), and the AI
administrator offers free time and books it. **Business owners** register their business in a
minute, get an AI administrator that takes bookings around the clock, and see their schedule,
clients and revenue in the same app.

## 2. Roles

| Role | Gets | Main screens |
|---|---|---|
| Client | catalog, AI chat (text and voice), classic booking flow, own bookings, reviews | Explore, Assistant, Bookings, Profile |
| Owner | business profile, services and staff, day schedule, manual bookings, statistics | Today, Bookings, Services, Business |

The role is chosen at registration. One owner account manages one business.

## 3. Niches

Ten categories, each with a template of typical services (name, duration, price) and search
keywords: dental, medical centre, barbershop, beauty salon, massage and spa, fitness,
car service, car wash, tutors and courses, vet clinic. A new niche is one entry in
`server/app/catalog.py`.

## 4. Domain model

- **User**: name, email, password hash, role (`customer` or `owner`), phone.
- **Business**: owner, category, name, description, address, phone, opening hours,
  working days, active flag.
- **Specialist**: a person or a resource (a wash bay) of a business.
- **Service**: name, duration (30-minute steps), price, keywords, the specialists who perform it.
- **Appointment**: business, service, specialist, client (an account or a name and phone
  entered by the owner), start, end, price and duration snapshots, status
  (`booked`, `completed`, `no_show`, `cancelled`), source (`chat`, `app`, `owner`), note.
- **Review**: one per finished appointment: rating 1–5 and a comment.

## 5. Rules

- Time grid is 30 minutes. A slot is free when it lies inside the business hours on a working
  day, starts in the future and does not overlap another active appointment of the specialist.
- A client cannot hold two overlapping appointments.
- "Any specialist" picks the first free specialist who performs the service.
- Cancelling keeps the record (status `cancelled`) so history and statistics stay correct.
- A review is allowed once, after the appointment time has passed.
- Owners can only see and change their own business.

## 6. AI administrator

Input: free text, optionally a category filter, a business (chat opened from its page) or a
specialist. Output: a reply, slot cards, and the booking it created or changed.

Two interchangeable engines behind one endpoint:

1. **LLM mode** — any OpenAI-compatible model with tool calling
   (`search_services`, `find_slots`, `book_appointment`, `reschedule_appointment`,
   `cancel_appointment`, `list_my_appointments`, `business_info`).
2. **Offline mode** — data-driven matcher used when no key is configured or the model fails.
   It scores every service by keyword stems of the service, the business name and the niche,
   parses dates and times in Russian and English, and understands booking, rescheduling,
   cancelling, "my bookings", price and address questions.

Because matching reads services from the database, a service an owner adds is bookable by
chat immediately.

Cancelling and moving never act on a guess. If the message names a service, a place, a
specialist or a niche the client has no booking for, or several bookings fit, the assistant
lists the bookings and asks which one is meant. In a chat opened from a business page it
shows and changes only the bookings made in that business.

## 7. Client features

- Explore: search, niche filter, business cards with rating, address and starting price.
- Business page: services with price and duration, specialists, reviews, opening hours.
- Booking: service → specialist (or any) → day → time → confirmation.
- Assistant: text or voice, slot cards from several businesses, reschedule and cancel by chat.
- Bookings: upcoming and history, cancel, reschedule, rate a finished visit.
- Settings: theme, language (Russian, Kyrgyz, English), server address.

## 8. Owner features

- Setup: pick a niche, enter name, address and hours; typical services are added from the template.
- Today: bookings and revenue today, last 7 days, share of bookings taken by the AI, rating,
  load, a bar chart by day, top services, today's schedule.
- Bookings: any day, statuses (complete, no-show, cancel), manual booking for a walk-in or a call.
- Services and staff: add, edit, remove; choose who performs each service.
- Business: profile, hours, working days, "accept bookings" switch.

## 9. Technology

- **App**: Flutter (Android, iOS, Web), `flutter_bloc` for state, a thin HTTP client,
  repositories per area. The server address is built in at build time (`API_URL`) and can be
  changed in the app, so one installed build keeps working when the server moves.
- **Server**: FastAPI, SQLAlchemy Core. SQLite for local runs and tests, PostgreSQL in the
  cloud (`DATABASE_URL`). Bearer tokens, PBKDF2 password hashes.
- **Quality gates** (GitHub Actions): server tests on SQLite and PostgreSQL, `flutter analyze`,
  bloc tests, an end-to-end test of the app's data layer against a live server, web, Android
  and iOS builds, screenshots rendered from the real screens.

## 10. Out of scope for this version

Online payments, SMS and push reminders, several businesses per owner, staff accounts,
per-specialist working hours, store publication. Each is a natural next step and none of
them changes the model above.
