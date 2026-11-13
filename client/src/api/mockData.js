// Sample providers for mock mode. Secret values here are fake and are
// never returned to the UI: the mock API masks them as "****", like the backend.
// Placeholders use {{name}}, the only form the backend fills. The console also
// accepts {name} and uaap.* names when registering and rewrites them to this form.
export const MOCK_PROVIDERS = [
  {
    id: 'TWILIO',
    'display-name': 'Twilio',
    channel: 'SMS',
    enabled: true,
    variables: {
      'account-sid': 'AC00000000000000000000000000000000',
      'auth-token': 'mock-twilio-token',
      from: '+10000000001',
    },
    request: {
      method: 'POST',
      url: 'https://api.twilio.com/2010-04-01/Accounts/{{account-sid}}/Messages.json',
      auth: { type: 'basic', username: '{{account-sid}}', password: '{{auth-token}}' },
      body: { format: 'form', fields: { To: '{{to}}', From: '{{from}}', Body: '{{text}}' } },
    },
    response: {
      'id-path': '$.sid',
      'status-path': '$.status',
      error: { 'message-path': '$.message', 'code-path': '$.code' },
    },
  },
  {
    id: 'VONAGE',
    'display-name': 'Vonage',
    channel: 'SMS',
    enabled: true,
    variables: {
      'api-key': 'mock-vonage-key',
      'api-secret': 'mock-vonage-secret',
      from: 'Innoridge',
    },
    request: {
      method: 'POST',
      url: 'https://rest.nexmo.com/sms/json',
      auth: { type: 'none' },
      body: {
        format: 'form',
        fields: {
          api_key: '{{api-key}}',
          api_secret: '{{api-secret}}',
          from: '{{from}}',
          to: '{{to_digits}}',
          text: '{{text}}',
        },
      },
    },
    response: {
      'id-path': '$.messages[0].message-id',
      'status-path': '$.messages[0].status',
      error: { 'message-path': '$.messages[0].error-text' },
    },
  },
  {
    id: 'MSG91',
    'display-name': 'MSG91',
    channel: 'SMS',
    enabled: true,
    variables: {
      'auth-key': 'mock-msg91-key',
      sender: 'INNRDG',
    },
    request: {
      method: 'POST',
      url: 'https://control.msg91.com/api/v5/flow/',
      auth: { type: 'header', name: 'authkey', value: '{{auth-key}}' },
      body: {
        format: 'json',
        fields: { sender: '{{sender}}', mobiles: '{{to_digits}}', message: '{{text}}' },
      },
    },
    response: { 'id-path': '$.request_id', error: { 'message-path': '$.message' } },
  },
  {
    id: 'TEXTLOCAL',
    'display-name': 'Textlocal',
    channel: 'SMS',
    enabled: false,
    variables: {
      'api-token': 'mock-textlocal-token',
      sender: 'TXTLCL',
    },
    request: {
      method: 'POST',
      url: 'https://api.textlocal.in/send/',
      auth: { type: 'bearer', token: '{{api-token}}' },
      body: { format: 'form', fields: { sender: '{{sender}}', numbers: '{{to_digits}}', message: '{{text}}' } },
    },
    response: { 'id-path': '$.messages[0].id', error: { 'message-path': '$.errors[0].message' } },
  },
];
