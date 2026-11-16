# Set up Twilio WhatsApp

You need five values from Twilio.

| Value | Where in Twilio |
|---|---|
| `account-sid` | Home page > **Account SID** |
| `api-key` | API key > **SID** |
| `api-secret` | API key > **Client secret** (shown only once) |
| `from` | Try out WhatsApp > **From** |
| `content-sid` | Try out WhatsApp > **API** tab > `ContentSid` |

## Part 1: Get your values from Twilio

Sign in at **https://console.twilio.com**.

### Step 1. Copy the Account SID

On the **Home** page, copy the **Account SID** (`account-sid`) with the copy icon next to it.

![Twilio home page: Account SID](images/01-home-account-info.png)

### Step 2. Get an API key and its Client secret

On the Home page click **API keys & auth tokens**, then **Create API key**. Enter any
name (for example `messaging-console`), set **Key type** to **Main**, and click **Next**.

![Create API key: name and key type Main](images/02a-create-api-key.png)

Copy both values now. **The Client secret is shown only once.**

- **SID** is your `api-key`
- **Client secret** is your `api-secret`

![Copy secret page with the SID and the Client secret](images/02b-copy-secret.png)

### Step 3. Connect your phone to the WhatsApp test environment

Go back to **Home**. Under **Try it out**, open **Send a WhatsApp message**.

1. **Select your tester:** choose your own phone number.
2. **Link your device:** open WhatsApp on that phone and send the code shown (for example
   `join twilio-trial`) to the number shown. Or scan the QR code.

This is needed once per phone on a Twilio trial. Only phones that did it can receive your
messages.

![Try out WhatsApp: connect to the testing environment](images/02-connect-sandbox.png)

### Step 4. Copy the From number

After your phone is connected, the **Send a message** tab opens. The **From** number is your
`from`. Copy it with the `+` and the country code, no spaces. Don't add `whatsapp:`; the app adds
it.

Under **Template**, choose the message you want to send (for example **Appointment Reminders**).

![Send a message tab with the From number and the template](images/03-from-number.png)

### Step 5. Copy the ContentSid

Click the **API** tab on the right. In the request, find `ContentSid=` and copy the value after it
(starts with `HX`, highlighted below). This is your `content-sid`. It is not a secret: it only
names the template.

The `ContentSid` belongs to the template you chose in Step 4. Choose another template and it
changes.

![API tab with the ContentSid highlighted](images/04-content-sid.png)

## Part 2: Register the provider in the Messaging Console

### Step 6. Paste the template

Open **http://localhost:5173**, go to **Providers** and click **Register provider**. Open
[twilio-whatsapp.json](twilio-whatsapp.json), copy all of it, and paste it into the box.

Five boxes appear below it: `account-sid`, `api-key`, `api-secret`, `from` and `content-sid`.

![Register provider with the WhatsApp template pasted and its five boxes](images/06-register-empty.png)

### Step 7. Fill in your values and register

Paste each value into its box. Click **Validate**, then **Register provider**.

The provider now shows in the list as **TWILIO_WHATSAPP**, channel **WHATSAPP**, **Enabled**.

![Providers list with TWILIO_WHATSAPP enabled](images/08-provider-registered.png)

## Part 3: Send a test WhatsApp message

### Step 8. Send

Open **Send Message**:

1. **Provider:** choose **TWILIO_WHATSAPP (WHATSAPP)**.

   ![Provider list with TWILIO_WHATSAPP](images/09-choose-provider.png)

2. **Recipient phone number:** the phone you connected in Step 3, with `+` and the country code,
   e.g. `+919876543210`.
3. **Message:** nothing to type. The template's own text is sent.
4. Click **Send Message**.

![Send Message page filled in for WhatsApp](images/10-send-message.png)

A green **Accepted by provider** card means Twilio took the message. It arrives in WhatsApp on that
phone.

![Accepted by provider result](images/11-message-accepted.png)
