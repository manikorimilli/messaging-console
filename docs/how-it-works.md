# Messaging Console: how it works

One REST API that sends SMS or WhatsApp messages through any provider you register. There are no built-in providers:
each provider (Twilio, Vonage, ...) is a JSON definition registered through the API and kept in
`db.json`. Adding a provider needs no code change; that is what the **extensible provider** does.

## Endpoints

| Method | Path | What it does |
|---|---|---|
| `GET` | `/api/v1/providers` | List registered providers, secrets shown as `****` |
| `GET` | `/api/v1/providers/{id}` | One provider |
| `POST` | `/api/v1/providers` | Register a provider (201) |
| `PUT` | `/api/v1/providers/{id}` | Replace a provider; a variable sent as `****` keeps its saved value |
| `DELETE` | `/api/v1/providers/{id}` | Unregister a provider (204) |
| `POST` | `/api/v1/messages` | Send one message (202) |
| `GET` | `/actuator/health` | Health check |
| `GET` | `/swagger-ui.html` | API documentation |

## A provider definition

Ready-to-fill examples: `docs/providers/twilio-sms.json` and `docs/providers/twilio-whatsapp.json`.

| Field | Meaning |
|---|---|
| `id` | Name used when sending, e.g. `TWILIO`. Stored in upper case. |
| `display-name` | Name shown in messages, e.g. `Twilio` |
| `channel` | The one channel it sends on: `SMS` or `WHATSAPP`. The same account on another channel is registered again. |
| `enabled` | Only enabled providers can send |
| `variables` | Keys and settings, e.g. `api-key`, `from`. Every one needs a value when enabled. |
| `request` | Method, URL, authentication (`basic`, `bearer`, `header`, `none`) and body (`json` or `form`) |
| `response` | How to read the reply: success statuses, JSONPath to the message id, status and error, and which errors mean "try later" |

### Placeholders

Templates in `request` use placeholders, filled in for each message:

| Placeholder | Filled with |
|---|---|
| `{{name}}` or `{name}` | The value of `variables.name` |
| `{{to}}` or `{uaap.message.to}` | The recipient, e.g. `+910000000001` |
| `{{to_digits}}` or `{uaap.message.to_digits}` | The recipient without `+` |
| `{{text}}`, `{uaap.message.text}` or `{uaap.message.template}` | The message |

Recipient and message values are not allowed in the URL. `${...}` is never a placeholder.

### WhatsApp

Register a `WHATSAPP` provider the same way as an `SMS` one. WhatsApp numbers carry a
`whatsapp:` scheme on the wire; add it in the field templates, not in `variables`.

WhatsApp only lets a business start a conversation with an approved **template**. Twilio sends
one as `ContentSid` (the template's id, `HX...`, fixed per provider) and `ContentVariables` (the
template's values as one JSON object, filled per message). `docs/providers/twilio-whatsapp.json`
does this:

```json
"fields": {
  "To": "whatsapp:{{uaap.to}}",
  "From": "whatsapp:{{from}}",
  "ContentSid": "{{content-sid}}",
  "ContentVariables": "{{uaap.text}}"
}
```

- **Message `body`:** the template's values as JSON, e.g. `{"1":"12/1","2":"3pm"}`. The console
  asks for JSON when a provider has a `ContentVariables` field.
- **Ready to try:** `from` is Twilio's WhatsApp sandbox number and `content-sid` is Twilio's sample
  "appointment reminder" template (`{{1}}` a date, `{{2}}` a time). In the sandbox, the
  recipient must first send your sandbox's `join <code>` message to that number.
- **Your own sender:** set `from` to your approved WhatsApp sender and `content-sid` to your
  approved template. Register one provider per template.
- **A template with no variables:** remove the `ContentVariables` field. The console then
  needs no message text.
- **Free text instead of a template:** replace `ContentSid` and `ContentVariables` with
  `"Body": "{{uaap.text}}"`. This only reaches a recipient within 24 hours of their last
  message to you (WhatsApp's "session" window).

## Sending one message

```
POST /api/v1/messages
{ "type": "SMS", "provider": "TWILIO_SMS", "to": "+910000000001", "body": "Hello" }
```

1. `MessageController` checks the request: every field is required, `to` must be E.164, `body`
   at most 1600 characters.
2. `ProviderRegistry` finds the provider. It must be registered, enabled and on the request's
   channel.
3. `ExtensibleProvider` fills the placeholders, calls the provider's API, and reads the reply with
   the definition's `response` rules.
4. `MessageService` returns `202 ACCEPTED` with the provider's message id, or an error.

`ACCEPTED` means the provider took the message, not that the phone received it.

## Errors

Every error is an RFC 9457 problem with a `code`:

| Code | HTTP | When |
|---|---|---|
| `VALIDATION_FAILED` | 400 | The request or provider definition is invalid; `errors` or `problems` lists why |
| `UNSUPPORTED_PROVIDER` | 400 | The named provider is not registered |
| `UNSUPPORTED_MESSAGE_TYPE` | 400 | The provider is on another channel |
| `PROVIDER_NOT_FOUND` | 404 | No provider with that id (provider endpoints) |
| `PROVIDER_ALREADY_EXISTS` | 409 | Registering an id that is taken |
| `PROVIDER_UNAVAILABLE` | 503 | Provider disabled, unreachable, or answered "try later" |
| `PROVIDER_REJECTED` | 502 | The provider refused the message; `providerErrorCode` has its code |
| `PROVIDER_TIMEOUT` | 504 | No reply in time; the message may or may not have been sent |
| `INTERNAL_ERROR` | 500 | Anything unexpected; details are only in the log |

## Code map

```
controller/   ProviderController, MessageController       HTTP in and out
service/      ProviderRegistry                             registered providers; register, update, unregister, pick
              MessageService                               one send; turns network failures into errors
provider/     MessageProvider, OutboundMessage, ProviderResult   what sending needs
  extensible/ ExtensibleProvider                           calls a provider's API from its definition
              ExtensibleProviderDefinition                 the definition's shape (request, auth, body, response)
              DescriptionValidator                         checks a definition before it is saved
              TemplateFiller                               fills the placeholders
              ResponseReader                               reads the reply: success, id, errors, retry
              GsmCharset                                   tells plain SMS text from Unicode (GSM-7)
  store/      ProviderStore                                reads and writes db.json safely
dto/          request and response shapes
exception/    ErrorCode, MessagingException, GlobalExceptionHandler
```

## Storage and settings

- **`db.json`** holds registered providers with their real keys. It is git-ignored. On a server,
  point `MESSAGING_DBFILE` at storage that survives redeploys.
- **`application.properties`** holds the HTTP timeouts (2 s connect, 10 s read), the `db.json`
  location and the health check. A `.env` file can set any of them for local runs.
- Logs never contain message text; phone numbers are masked, e.g. `+91******0001`.
