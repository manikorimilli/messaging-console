export const MASKED_VALUE = '****';
export const AUTH_TYPES = ['basic', 'bearer', 'header', 'none'];
export const BODY_FORMATS = ['form', 'json'];

// A provider sends on one channel ("channel": "SMS"). Older responses used a
// "channels" list; its first entry is read as the channel.
export function providerChannel(provider) {
  const value = provider?.channel ?? (Array.isArray(provider?.channels) ? provider.channels[0] : undefined);
  return typeof value === 'string' ? value.toUpperCase() : undefined;
}

export const supportsSms = (provider) => providerChannel(provider) === 'SMS';

// Shown in the provider picker, e.g. "TWILIO (SMS)". The same account can later
// be registered again for another channel, which the channel tells apart.
export const providerLabel = (provider) => {
  const channel = providerChannel(provider);
  return channel ? `${provider.id} (${channel})` : provider?.id ?? '';
};

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
