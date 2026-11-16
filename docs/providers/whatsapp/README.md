# Register Twilio WhatsApp

Template: [twilio-whatsapp.json](twilio-whatsapp.json)

This sends an **approved WhatsApp template** (WhatsApp only lets a business start a conversation
with one). You need four values from your Twilio account. Then you paste the template into the
Messaging Console and fill them in.

## 1. Get your values from Twilio

Sign in at **https://console.twilio.com**.

> Twilio sometimes moves menus. If a menu name doesn't match, type it into the **search bar** at
> the top of the Console.

### Account SID and Auth Token

On the Console home page, scroll down to the **Account Info** box. Click **Show** next to the
Auth Token.

![Account Info box with the Auth Token shown](images/01-account-info.png)

| Box in the app | Where in Twilio | Looks like |
|---|---|---|
| `account-sid` | **Account SID** | `AC` + 32 letters and numbers |
| `auth-token` | **Auth Token** | 32 letters and numbers |

### WhatsApp sender number

Open **Messaging > Senders > WhatsApp senders** and copy your sender number.

![WhatsApp senders page](images/02-whatsapp-senders.png)

| Box in the app | Where in Twilio | Looks like |
|---|---|---|
| `from` | The WhatsApp sender number | `+15551234567` |

Write it with `+` and the country code. Don't add `whatsapp:`; the app adds it.

### Template ID

1. Open **Messaging > Content Template Builder**.
2. Find your template. Its **SID** is in the first column.
3. Check that its WhatsApp status is **Approved**. A new template needs WhatsApp approval first,
   which usually takes from a few minutes up to one day.

![Content Template Builder with an approved template](images/03-content-template-builder.png)

| Box in the app | Where in Twilio | Looks like |
|---|---|---|
| `content-sid` | Template **SID** | `HX` + 32 letters and numbers |

## 2. Register the provider in the Messaging Console

1. Open http://localhost:5173, go to **Providers** and click **Register provider**.

   ![Providers page with the Register provider button](images/04-providers-page.png)

2. Paste the whole content of [twilio-whatsapp.json](twilio-whatsapp.json).
3. Fill in the four boxes that appear: `account-sid`, `auth-token`, `from`, `content-sid`.

   ![Register provider form with the four boxes filled in](images/05-register-form.png)

4. Click **Validate**, then **Register provider**.

## 3. Send a test WhatsApp message

Open **Send Message**, choose **TWILIO_WHATSAPP (WHATSAPP)** and enter the phone number with
country code (e.g. `+919876543210`). No message text is needed: the approved template's text is
sent. Click **Send Message**.

![Send Message page with an accepted result](images/06-send-message.png)

A green **Accepted by provider** card means Twilio took the message.

## If something goes wrong

| You see | Do this |
|---|---|
| `Authentication Error` | `account-sid` or `auth-token` was copied wrong. On **Providers**, click **...** next to the provider, choose **Edit**, and paste it again. |
| WhatsApp error `63007` | `from` is not a WhatsApp sender on your account. |
| WhatsApp error `63015` | Twilio sandbox only: the recipient must first send your sandbox's `join <code>` message. |
| Template error | Check that the template's WhatsApp status is **Approved** and `content-sid` starts with `HX`. |

Keep these values private. Anyone who has them can send messages on your account.
