# Messaging Console

Send SMS and WhatsApp messages through your Twilio account, from a simple web page.

Works on **macOS** and **Linux**. On Windows, use [WSL](https://learn.microsoft.com/windows/wsl/install)
(Ubuntu) and run everything inside it.

## 1. Get the code

Open a terminal and run:

```bash
git clone https://github.com/manikorimilli/messaging-console.git
```

```bash
cd messaging-console
```

No `git`? Install it first: on Ubuntu `sudo apt install -y git`, on macOS run `git --version`
and click **Install**.

## 2. Set up (once)

```bash
./init.sh
```

This downloads everything the app needs, including Java and Node.js if your computer doesn't have
them. They go into this folder only; nothing is installed on your system and no password is
needed. Takes about 2 to 4 minutes the first time.

## 3. Start

```bash
./run.sh
```

When you see **Ready**, open **http://localhost:5173**.

Press `Ctrl + C` to stop.

## 4. Add your Twilio account

1. Open **Providers** and click **Register provider**.
2. Paste the content of one of these files:
   - [docs/providers/twilio-sms.json](docs/providers/twilio-sms.json) for SMS
   - [docs/providers/twilio-whatsapp.json](docs/providers/twilio-whatsapp.json) for WhatsApp
3. Fill in the boxes that appear with your values from the [Twilio Console](https://console.twilio.com):

   | Box | What to enter |
   |---|---|
   | `account-sid` | Your Account SID (starts with `AC`) |
   | `api-key`, `api-secret` | An API key and its secret (SMS only) |
   | `auth-token` | Your Auth Token (WhatsApp only) |
   | `from` | Your Twilio phone number, e.g. `+15551234567` |
   | `content-sid` | Your approved WhatsApp template id (starts with `HX`, WhatsApp only) |

4. Click **Validate**, then **Register provider**.

## 5. Send a message

Open **Send Message**, choose the provider, enter the phone number with country code
(e.g. `+919876543210`), type the message, and click **Send Message**. For WhatsApp no message
is needed: your approved template's text is sent.

A green **Accepted by provider** card means Twilio took the message.

## If something goes wrong

| You see | Do this |
|---|---|
| `Permission denied` when running a script | Run `chmod +x init.sh run.sh` once. |
| `Run ./init.sh first` | Run `./init.sh`, then `./run.sh`. |
| `Port 8080 is in use` or `Port 5173 is in use` | Another copy is still running. Stop it, or start on other ports: `SERVER_PORT=9090 CLIENT_PORT=3000 ./run.sh` |
| `Authentication Error` when sending | A value was copied wrong. On **Providers**, click **...** next to the provider, choose **Edit**, and paste it again. |
| Twilio error `21608` | Your Twilio trial can only send to numbers verified in the Twilio Console. |
| Anything else | Look in the `logs/` folder: `server.log` and `client.log`. |

## Good to know

- Your registered providers, with their keys, are saved in `server/db.json` on this computer only.
  Don't share that file.
- API documentation: **http://localhost:8080/swagger-ui.html** while the app is running.
- More detail: [how it works](docs/how-it-works.md), [server setup](docs/setup-server.md),
  [client setup](docs/setup-client.md), [client reference](docs/client-reference.md).
