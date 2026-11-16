# Register Twilio SMS

Template: [twilio-sms.json](twilio-sms.json)

You need four values from your Twilio account. Then you paste the template into the Messaging
Console and fill them in.

## 1. Get your values from Twilio

Sign in at **https://console.twilio.com**.

> Twilio sometimes moves menus. If a menu name doesn't match, type it into the **search bar** at
> the top of the Console.

### Account SID and phone number

On the Console home page, scroll down to the **Account Info** box.

![Account Info box on the Twilio Console home page](images/01-account-info.png)

| Box in the app | Where in Twilio | Looks like |
|---|---|---|
| `account-sid` | **Account SID** | `AC` + 32 letters and numbers |
| `from` | **My Twilio phone number** | `+15551234567` |

If **My Twilio phone number** is not shown, open **Phone Numbers > Manage > Active numbers** and
copy the number with `+` and the country code, no spaces.

![Active numbers page](images/02-active-numbers.png)

### API key and secret

1. Open **API keys & tokens** (Account menu, top right).
2. Click **Create API key**, give it any name (e.g. `messaging-console`), keep type **Standard**,
   and click **Create**.

   ![Create API key form](images/03-create-api-key.png)

3. Copy both values right away. The secret is shown **only once**.

   ![New API key with its SID and secret](images/04-api-key-created.png)

| Box in the app | Where in Twilio | Looks like |
|---|---|---|
| `api-key` | **SID** of the new key | `SK` + 32 letters and numbers |
| `api-secret` | **Secret** of the new key | 32 letters and numbers |

## 2. Register the provider in the Messaging Console

1. Open http://localhost:5173, go to **Providers** and click **Register provider**.

   ![Providers page with the Register provider button](images/05-providers-page.png)

2. Paste the whole content of [twilio-sms.json](twilio-sms.json).
3. Fill in the four boxes that appear: `account-sid`, `api-key`, `api-secret`, `from`.

   ![Register provider form with the four boxes filled in](images/06-register-form.png)

4. Click **Validate**, then **Register provider**.

## 3. Send a test SMS

Open **Send Message**, choose **TWILIO (SMS)**, enter a phone number with country code
(e.g. `+919876543210`), type a message and click **Send Message**.

![Send Message page with an accepted result](images/07-send-message.png)

A green **Accepted by provider** card means Twilio took the message.

## If something goes wrong

| You see | Do this |
|---|---|
| `Authentication Error` | `api-key` or `api-secret` was copied wrong. On **Providers**, click **...** next to the provider, choose **Edit**, and paste it again. |
| Twilio error `21608` | A Twilio trial can only send to numbers verified in the Twilio Console. |
| Twilio error `21211` | The phone number is not valid. Use `+`, the country code and the number, no spaces. |

Keep these values private. Anyone who has them can send messages on your account.
