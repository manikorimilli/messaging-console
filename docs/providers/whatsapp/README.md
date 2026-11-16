# Set up Twilio WhatsApp

Three parts: copy four values from Twilio, register them in the Messaging Console, send a test
WhatsApp message.

| Value | Where you find it in Twilio | Looks like |
|---|---|---|
| `account-sid` | Home page, **Account SID** | `AC...` (34 characters) |
| `auth-token` | Home page, **Auth Token** | 32 characters |
| `from` | **Try out WhatsApp > Send a message**, **From** | `+15551234567` |
| `content-sid` | **Try out WhatsApp > Send a message > API**, `ContentSid=` | `HX...` (34 characters) |

Keep these values private. Anyone who has them can send messages on your account.

## Part 1: Get your values from Twilio

Sign in at **https://console.twilio.com**.

### Step 1. Copy the Account SID and Auth Token

On the **Home** page, copy the **Account SID** (`account-sid`) and the **Auth Token**
(`auth-token`) with the copy icon next to each.

![Twilio home page: Account SID and Auth Token](images/01-home-account-info.png)

### Step 2. Connect your phone to the WhatsApp test environment

On the same page, under **Try it out**, open **Send a WhatsApp message**.

1. **Select your tester:** choose your own phone number.
2. **Link your device:** open WhatsApp on that phone and send the code shown (for example
   `join twilio-trial`) to the number shown. Or scan the QR code.

This is needed once per phone on a Twilio trial. Only phones that did it can receive your
messages.

![Try out WhatsApp: connect to the testing environment](images/02-connect-sandbox.png)

### Step 3. Copy the From number

After your phone is connected, the **Send a message** tab opens. The **From** number is your
`from`. Copy it with the `+` and the country code, no spaces. Don't add `whatsapp:`; the app adds
it.

Under **Template**, choose the message you want to send (for example **Appointment Reminders**).

![Send a message tab with the From number and the template](images/03-from-number.png)

### Step 4. Copy the ContentSid

Click the **API** tab on the right. In the request, find `ContentSid=` and copy the value after it
(starts with `HX`, highlighted below). This is your `content-sid`.

The `ContentSid` belongs to the template you chose in Step 3. Choose another template and it
changes.

![API tab with the ContentSid highlighted](images/04-content-sid.png)

## Part 2: Register the provider in the Messaging Console

### Step 5. Paste the template

Open **http://localhost:5173**, go to **Providers** and click **Register provider**. Open
[twilio-whatsapp.json](twilio-whatsapp.json), copy all of it, and paste it into the box.

![Register provider with the WhatsApp template pasted](images/05-register-paste.png)

Four boxes appear below it: `account-sid`, `auth-token`, `from` and `content-sid`.

![Register provider form with the four empty boxes](images/06-register-empty.png)

### Step 6. Fill in your values and register

Paste the four values from Part 1. Click **Validate**. When it says **Configuration looks valid**,
click **Register provider**.

![Register provider form with the four values filled in](images/07-register-filled.png)

The provider now shows in the list as **TWILIO_WHATSAPP**, channel **WHATSAPP**, **Enabled**.

![Providers list with TWILIO_WHATSAPP enabled](images/08-provider-registered.png)

## Part 3: Send a test WhatsApp message

### Step 7. Send

Open **Send Message**:

1. **Provider:** choose **TWILIO_WHATSAPP (WHATSAPP)**.

   ![Provider list with TWILIO_WHATSAPP](images/09-choose-provider.png)

2. **Recipient phone number:** the phone you connected in Step 2, with `+` and the country code,
   e.g. `+919876543210`.
3. **Message:** nothing to type. The template's own text is sent.
4. Click **Send Message**.

![Send Message page filled in for WhatsApp](images/10-send-message.png)

A green **Accepted by provider** card means Twilio took the message. It arrives in WhatsApp on that
phone.

![Accepted by provider result](images/11-message-accepted.png)
