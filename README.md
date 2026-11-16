# Messaging Console

Send SMS and WhatsApp messages through your Twilio account, from a simple web page.

Works on **Windows**, **macOS** and **Linux**. Nothing is installed on your system, and no admin
rights or password are needed.

## 1. Download and set up (once)

**Windows:** open **PowerShell** (Start menu, type "PowerShell") and paste:

```powershell
irm https://raw.githubusercontent.com/manikorimilli/messaging-console/main/get.ps1 | iex
```

**macOS / Linux:** open **Terminal** and paste:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/manikorimilli/messaging-console/main/get.sh || wget -qO- https://raw.githubusercontent.com/manikorimilli/messaging-console/main/get.sh)"
```

It downloads the app into a `messaging-console` folder and sets everything up, including Java and
Node.js if your computer doesn't have them. Takes about 2 to 4 minutes the first time.

## 2. Start

**Windows:** open the `messaging-console` folder and double-click **`run.cmd`**. Or in PowerShell:

```powershell
cd messaging-console
.\run.cmd
```

**macOS / Linux:**

```bash
cd messaging-console
./run.sh
```

When you see **Ready**, open **http://localhost:5173**.

Press `Ctrl + C` to stop. Next time, only step 2 is needed.

## 3. Add your Twilio account

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

## 4. Send a message

Open **Send Message**, choose the provider, enter the phone number with country code
(e.g. `+919876543210`), type the message, and click **Send Message**. For WhatsApp no message
is needed: your approved template's text is sent.

A green **Accepted by provider** card means Twilio took the message.

## If something goes wrong

| You see | Do this |
|---|---|
| `Permission denied` when running a script (macOS / Linux) | Run `chmod +x init.sh run.sh` once. |
| `Run ./init.sh first` / `Run setup first` | Run the step 1 command again from the folder that contains `messaging-console`. |
| `Port 8080 is in use` or `Port 5173 is in use` | Another copy is still running. Stop it, or start on other ports: `SERVER_PORT=9090 CLIENT_PORT=3000 ./run.sh` (Windows: `$env:SERVER_PORT=9090; $env:CLIENT_PORT=3000; .\run.ps1`) |
| `Authentication Error` when sending | A value was copied wrong. On **Providers**, click **...** next to the provider, choose **Edit**, and paste it again. |
| Twilio error `21608` | Your Twilio trial can only send to numbers verified in the Twilio Console. |
| Anything else | Look in the `logs/` folder: `server.log` and `client.log`. |

## Good to know

- Your registered providers, with their keys, are saved in `server/db.json` on this computer only.
  Don't share that file.
- API documentation: **http://localhost:8080/swagger-ui.html** while the app is running.
- More detail: [how it works](docs/how-it-works.md), [server setup](docs/setup-server.md),
  [client setup](docs/setup-client.md), [client reference](docs/client-reference.md).
