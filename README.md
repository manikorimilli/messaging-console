# Messaging Console

Register SMS or WhatsApp providers (Twilio, or any provider with an HTTP API) and send
messages through them.

## Get the code

```bash
git clone https://github.com/manikorimilli/messaging-console.git
cd messaging-console
```

Or on GitHub click **Code > Download ZIP** and unzip it.

## Run Messaging Console locally: Windows

Open a cmd terminal and go to the repository root folder, then:

1. Run `.\init.cmd` to install the prerequisites (Java 21, Node.js, Git) and set up the project.
2. Run `.\run-messaging-console.cmd` to build and start the server and the client.

## Run Messaging Console locally: macOS / Linux

Open a terminal and go to the repository root folder, then:

1. Run `./init.sh` to set up the prerequisites (Java 21, Node.js) and the project.
2. Run `./run-messaging-console.sh` to build and start the server and the client.

## Use it

Open http://localhost:5173/ and use the Messaging Console.

| | URL |
|---|---|
| Messaging Console (web portal) | http://localhost:5173/ |
| Server API (base URL) | http://localhost:8080/api/v1 |
| API documentation (Swagger) | http://localhost:8080/swagger-ui.html |
| Server health check | http://localhost:8080/actuator/health |

## Register a provider

Before you can send messages, register a provider. Follow the step-by-step guide for the channel
you need.

### SMS

**[Set up Twilio SMS](docs/providers/sms/README.md)**

### WhatsApp

**[Set up Twilio WhatsApp](docs/providers/whatsapp/README.md)**

## Options

Both run scripts take the same options, for example `--port 9090`, `--mock` or `--no-build`.
Add `--help` to see them all. `Ctrl + C` stops the server and the client.
