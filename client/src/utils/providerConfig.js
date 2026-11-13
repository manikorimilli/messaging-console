export const MASKED_VALUE = '****';
export const AUTH_TYPES = ['basic', 'bearer', 'header', 'none'];
export const BODY_FORMATS = ['form', 'json'];

// Channels the backend can send on. Keep in sync with the server's MessageType enum.
export const CHANNELS = ['SMS', 'WHATSAPP'];

// A provider sends on one channel ("channel": "SMS"). Older responses used a
// "channels" list; its first entry is read as the channel.
export function providerChannel(provider) {
  const value = provider?.channel ?? (Array.isArray(provider?.channels) ? provider.channels[0] : undefined);
  return typeof value === 'string' ? value.toUpperCase() : undefined;
}

// Whether a message can be sent through this provider: it is on a channel the
// backend supports. Replaces the old SMS-only "supportsSms" check.
export const canSend = (provider) => CHANNELS.includes(providerChannel(provider));

// Shown in the provider picker, e.g. "TWILIO (SMS)". The same account can later
// be registered again for another channel, which the channel tells apart.
export const providerLabel = (provider) => {
  const channel = providerChannel(provider);
  return channel ? `${provider.id} (${channel})` : provider?.id ?? '';
};

// True when a provider sends Twilio's WhatsApp Content Template fields: a fixed
// ContentSid and a ContentVariables value filled per message. For these, the
// message box holds the template's variables as JSON, not free text.
export function usesContentTemplate(provider) {
  const fields = provider?.request?.body?.fields;
  if (!fields || typeof fields !== 'object') return false;
  return Object.keys(fields).some((name) => name.toLowerCase() === 'contentvariables');
}

// Every placeholder spelling that is filled from the typed message.
const TEXT_PLACEHOLDERS = ['{{text}}', '{{uaap.text}}', '{{uaap.message.text}}', '{{uaap.message.template}}'];

// Whether this provider's request actually sends the typed message anywhere.
// A Content Template with no variables (e.g. Twilio's "Delivery Updates") has
// no text placeholder in its fields at all: ContentSid alone is enough, so the
// message box is not required.
export function needsMessageBody(provider) {
  const fields = provider?.request?.body?.fields;
  if (!fields || typeof fields !== 'object') return true;
  return Object.values(fields).some(
    (v) => typeof v === 'string' && TEXT_PLACEHOLDERS.some((placeholder) => v.includes(placeholder)),
  );
}

export const PROVIDER_EXAMPLE = {
  id: 'plivo',
  'display-name': 'Plivo',
  channel: 'SMS',
  enabled: true,
  variables: {
    'auth-id': 'MA123',
    'auth-token': 'your-token',
    from: '+10000000001',
  },
  request: {
    method: 'POST',
    url: 'https://api.plivo.com/v1/Account/{{auth-id}}/Message/',
    auth: { type: 'basic', username: '{{auth-id}}', password: '{{auth-token}}' },
    body: {
      format: 'json',
      fields: { src: '{{from}}', dst: '{{to_digits}}', text: '{{text}}' },
    },
  },
  response: {
    'id-path': '$.message_uuid[0]',
    error: { 'message-path': '$.error' },
  },
};
