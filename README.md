# Messaging Console

Register SMS providers (Twilio, Vonage, or any provider with an HTTP API) and send messages
through them.

| Folder | What it is | Runs at |
|---|---|---|
| `server/` | The API: Java 21, Spring Boot, Maven | `http://localhost:8080` |
| `client/` | The web console: React, Vite | `http://localhost:5173` |
| `docs/` | Guides and ready-to-fill provider files | |

## Quick start

You need **Java 21 or newer** and **Node.js 22.12 or newer**. Install steps for each system are in
[docs/setup-server.md](docs/setup-server.md) and [docs/setup-client.md](docs/setup-client.md).

1. Install the shortcuts and the client's packages (once):

   ```bash
   npm install
   ```

   ```bash
   npm run setup
   ```

2. Create the client's settings file and point it at the local server (once):

   ```bash
   cp client/.env.example client/.env
   ```

   In `client/.env`, set `VITE_USE_MOCK_API=false` and keep
   `DEV_PROXY_TARGET=http://localhost:8080`. (Set it to `true` to try the console without the server:
   everything is simulated in the browser, and it starts with no providers, so register one first.)

3. Start the server and the client together:

   ```bash
   npm run dev
   ```

   Logs from both appear in one terminal, labelled `[server]` and `[client]`. `Ctrl + C` stops
   both. The server takes a few seconds longer to start; if the console says it cannot reach the
   server, wait a moment and click **Refresh**.

4. Open `http://localhost:5173` and register a provider on the **Providers** page. Ready-made
   files are in [docs/providers/](docs/providers/): paste one and fill in your keys.

5. Open **Send Message**, choose the provider, and send a test message.

`npm run dev` is only a shortcut. The server is a plain Maven project and still runs on its own
with `cd server && ./mvnw spring-boot:run`, and the client with `cd client && npm run dev`.

## Other commands

| Command | What it does |
|---|---|
| `npm run dev:server` | Start only the server |
| `npm run dev:client` | Start only the client |
| `npm test` | Run the server tests, then the client tests |

## Documentation

| Guide | Read it for |
|---|---|
| [docs/how-it-works.md](docs/how-it-works.md) | Endpoints, the provider format and placeholders, error codes, a map of the code |
| [docs/setup-server.md](docs/setup-server.md) | Installing Java, running the server, registering a provider, sending with `curl` |
| [docs/setup-client.md](docs/setup-client.md) | Installing Node.js, running the console, mock or live data |
| [docs/client-reference.md](docs/client-reference.md) | Client settings, pages, mock test numbers, tests and build |

## Local files that are never committed

| File | What it holds |
|---|---|
| `server/db.json` | Registered providers, with their real keys |
| `server/.env`, `client/.env` | Local settings |
| `server/target/`, `client/node_modules/`, `client/dist/`, `node_modules/` | Build output and packages |
