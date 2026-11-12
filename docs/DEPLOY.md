# Running Smile AI in the cloud

Locally the server runs on your computer, so the app works only while that computer is on and
in the same network. In the cloud the server gets a permanent `https://` address, and the app is
installed once and keeps working:

| Device | How it is installed |
|---|---|
| Android | one APK file from the repository's Releases page |
| iPhone | the web app: open the link in Safari, then Share > Add to Home Screen |
| Computer | the same web link |

The setup below uses free plans. Limits were checked in November 2026; verify them on the
providers' pricing pages before you rely on them.

| Part | Provider | Free plan, in short |
|---|---|---|
| Server | [Render](https://render.com) web service | Sleeps after 15 minutes without requests and needs about a minute to wake up; 750 free hours a month |
| Database | [Neon](https://neon.com) PostgreSQL | No time limit; 1 GB of storage; 100 compute hours a month; pauses after 5 idle minutes and resumes on the next query |
| App files | GitHub Releases and GitHub Pages | Free for a public repository |

Render also has a free PostgreSQL, but it expires 30 days after creation, so the data would be
lost. That is why the database lives on Neon.

What the sleep means for users: the first request after a quiet period waits for the server.
The app shows "Connecting to the server…" during that time. A paid Render instance does not
sleep; that is the first upgrade to make for a real launch.

## 1. Database (about 2 minutes)

1. Open [neon.com](https://neon.com), sign up with GitHub.
2. Create a project: name `smile-ai`, region **AWS Europe (Frankfurt)**.
3. Press **Connect** and copy the connection string. It starts with `postgresql://`.

The string contains the database password. Paste it only into Render in the next step; do not
put it into the repository, chats or screenshots.

## 2. Server (about 5 minutes)

1. Open the one-click link
   <https://render.com/deploy?repo=https://github.com/Asilovvv/ai-clinic-booking> and sign in
   with GitHub. Render reads `render.yaml` and shows one service, `smile-ai-api`.
   The same from the dashboard: **New > Blueprint**, then pick the repository.
2. Paste the connection string into `DATABASE_URL` and start the deploy.
3. Wait for the first deploy to finish. Render builds `server/Dockerfile`.
4. Copy the service address from the top of its page, for example
   `https://smile-ai-api.onrender.com`, and open `<address>/health`. It must answer
   `{"status":"ok"}`. `<address>/docs` shows the whole API.

Render may ask a new account for a bank card to verify it. The Blueprint uses only the free
plan. Neon shows a pooled connection string by default; the server works with it.

On the first start the server creates its tables and the demo data: twelve businesses, a demo
client and a demo owner.

## 3. Tell the app where the server is

In the GitHub repository:

1. **Settings > Pages > Source: GitHub Actions**. This is needed once, for the web app.
2. Optional: **Settings > Secrets and variables > Actions > Variables > New repository
   variable**, name `API_URL`, value is the address from step 2. With it the address does not
   have to be typed at every release.

## 4. Build and publish the app

**Actions > Release > Run workflow**: a version such as `v3.0.0`, and your server address in
`api_url`. The workflow checks that the server answers, then:

- builds the Android APK with the server address inside and attaches it to a new Release;
- builds the web app and publishes it at `https://<user>.github.io/ai-clinic-booking/`.

## Installing

- **Android**: open the Releases page on the phone, download `smile-ai-v3.0.0.apk`, allow the
  installation, open the app.
- **iPhone**: open the web address in Safari, press Share, then **Add to Home Screen**. The icon
  opens the app full screen. No Mac, cable or Xcode is needed, and nothing expires.
- **Demo accounts**: the sign-in screen has two buttons, "Client" and "Owner".

## Updating

- **Server**: Render redeploys it after every push to the `main` branch.
- **App**: run **Release** again with a new version. Android users install the new APK over the
  old one; the web app updates by itself.
- **Another server address**: the sign-in screen has a "Server" line. Tap it and type the new
  address, the installed app does not have to be rebuilt.

## Before a real launch

Set these in Render, on the service's **Environment** page:

- `SEED_DEMO=0` starts with an empty catalog, without demo businesses and demo accounts. It
  only has an effect on an empty database.
- `LLM_API_KEY` (and optionally `LLM_BASE_URL`, `LLM_MODEL`) turns on the language-model mode of
  the assistant. Without it the built-in assistant answers.

Also worth doing: move the Render service to a paid instance so it does not sleep, check how
far back Neon can restore the database on your plan, and add your own domain in Render.
Publishing in Google Play and the App Store needs developer accounts in both stores and a
release signing key for Android; the code does not have to change.

## Another host

Nothing in the server is tied to Render. Any host that runs a container and gives a PostgreSQL
address will do: build `server/Dockerfile`, set `DATABASE_URL`, and pass the port in `PORT`.

```bash
docker build -t smile-ai-server server
docker run -p 8000:8000 -e DATABASE_URL=postgresql://user:password@host/dbname smile-ai-server
```

Without `DATABASE_URL` the container keeps its data in a SQLite file inside itself, which is
fine for a quick try and lost on restart.
