import { MASKED_VALUE } from './providerConfig.js';

// Parameters are the {name} or {{name}} placeholders inside a provider config.
// "${NAME}" environment placeholders are not parameters and are skipped.
const PLACEHOLDER = /(?<!\$)\{\{\s*([\w.-]+)\s*\}\}|(?<![${])\{([\w.-]+)\}(?!\})/g;

// The backend fills these three from each message: {{to}} and {{to_digits}}
// from the recipient, {{text}} from the message body.
export const BACKEND_BUILT_INS = ['to', 'to_digits', 'text'];

// uaap.* parameters are the same per-message values under the names the
// requirement uses. The backend only understands its built-ins, so saving a
// provider rewrites each uaap name to the built-in it stands for.
export const UAAP_PARAMETERS = {
  'uaap.message.to': 'to',
  'uaap.message.to_digits': 'to_digits',
  'uaap.message.text': 'text',
  'uaap.message.template': 'text',
  'uaap.to': 'to',
  'uaap.to_digits': 'to_digits',
  'uaap.text': 'text',
};

// The uaap name shown for each built-in, for providers saved in backend form.
const UAAP_NAME_FOR_BUILT_IN = { to: 'uaap.message.to', to_digits: 'uaap.message.to_digits', text: 'uaap.message.text' };

// What each built-in is filled from, in words.
const BUILT_IN_SOURCE = { to: 'recipient number', to_digits: 'recipient number without "+"', text: 'message' };

// The backend only recognises {{name}} with these characters in the name.
const BACKEND_NAME = /^[A-Za-z0-9_-]+$/;

const isUaap = (name) => name.startsWith('uaap.');

// Filled in when a message is sent, so nobody types them at registration.
export const isSendTimeParameter = (name) => isUaap(name) || BACKEND_BUILT_INS.includes(name);

const builtInFor = (name) => (BACKEND_BUILT_INS.includes(name) ? name : UAAP_PARAMETERS[name]);

// For a send-time parameter: its uaap name and what fills it, or null if unknown.
export function describeSendTimeParameter(name) {
  const builtIn = builtInFor(name);
  if (!builtIn) return null;
  return { uaap: isUaap(name) ? name : UAAP_NAME_FOR_BUILT_IN[builtIn], builtIn, source: BUILT_IN_SOURCE[builtIn] };
}

const isObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);

// Applies `fn` to every string in a JSON value, keeping its shape.
function mapStrings(value, fn) {
  if (typeof value === 'string') return fn(value);
  if (Array.isArray(value)) return value.map((item) => mapStrings(item, fn));
  if (isObject(value)) return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, mapStrings(v, fn)]));
  return value;
}

// Rewrites placeholders into the only form the backend fills: {name} becomes
// {{name}} and known uaap names become the built-in they stand for. Unknown uaap
// names are left alone for validation to report. "variables" holds raw values
// and is copied unchanged.
export function toBackendPlaceholders(cfg) {
  if (!isObject(cfg)) return cfg;
  const { variables, ...templates } = cfg;
  const rewritten = mapStrings(templates, (text) =>
    text.replace(PLACEHOLDER, (match, doubled, single) => {
      const name = doubled ?? single;
      if (isUaap(name)) return UAAP_PARAMETERS[name] ? `{{${UAAP_PARAMETERS[name]}}}` : match;
      return `{{${name}}}`;
    }),
  );
  return variables === undefined ? rewritten : { ...rewritten, variables };
}

// Placeholder problems the backend would reject at registration, or that would
// leave a placeholder unfilled when sending.
export function placeholderProblems(cfg) {
  if (!isObject(cfg)) return [];
  const problems = [];
  const { provider, sendTime } = detectParameters(cfg);
  for (const name of sendTime) {
    if (!describeSendTimeParameter(name)) {
      problems.push(`{${name}} is not a known uaap parameter. Use one of: ${Object.keys(UAAP_PARAMETERS).join(', ')}`);
    }
  }
  for (const name of provider) {
    if (!BACKEND_NAME.test(name)) problems.push(`{${name}} may contain only letters, digits, "_" and "-"`);
  }
  const url = cfg.request?.url;
  if (typeof url === 'string') {
    for (const name of collect(url, new Set())) {
      if (isSendTimeParameter(name)) problems.push(`request.url cannot use {${name}}. Message values are not allowed in the URL.`);
    }
  }
  if (isObject(cfg.variables)) {
    for (const name of BACKEND_BUILT_INS) {
      if (name in cfg.variables) problems.push(`variables.${name} clashes with the built-in {{${name}}}. Rename it.`);
    }
  }
  return problems;
}

function collect(value, found) {
  if (typeof value === 'string') {
    for (const match of value.matchAll(PLACEHOLDER)) found.add(match[1] ?? match[2]);
  } else if (Array.isArray(value)) {
    for (const item of value) collect(item, found);
  } else if (isObject(value)) {
    for (const item of Object.values(value)) collect(item, found);
  }
  return found;
}

// Every placeholder name in the config, in order of first appearance, split into
// the ones to ask for now and the ones filled at send time. "variables" holds
// raw values, not templates, so it is not scanned.
export function detectParameters(cfg) {
  if (!isObject(cfg)) return { provider: [], sendTime: [] };
  const { variables: _values, ...templates } = cfg;
  const names = [...collect(templates, new Set())];
  return {
    provider: names.filter((name) => !isSendTimeParameter(name)),
    sendTime: names.filter(isSendTimeParameter),
  };
}

// What a parameter box shows: only what was typed. Boxes never copy values from
// the pasted JSON, so a placeholder there can never pass as a filled-in value.
export const parameterValue = (name, values) => values[name] ?? '';

// True when the text is or contains a {name} or {{name}} placeholder.
export const hasPlaceholder = (text) => typeof text === 'string' && new RegExp(PLACEHOLDER.source).test(text);

// The problem with each parameter box, keyed by name: empty, or still a placeholder.
// Names in "kept" may stay empty: the server already holds their value.
export function parameterErrors(names, values, kept = new Set()) {
  const errors = {};
  for (const name of names) {
    const value = parameterValue(name, values).trim();
    if (!value) {
      if (!kept.has(name)) errors[name] = 'Enter a value';
    }
    else if (hasPlaceholder(value)) errors[name] = 'Enter the real value, not a placeholder';
  }
  return errors;
}

// Writes the entered parameter values into "variables", where the service looks
// them up. Blank entries are skipped so they never overwrite an existing value.
export function withParameterValues(cfg, values) {
  const entered = Object.entries(values).filter(([, value]) => value !== '');
  if (!isObject(cfg) || entered.length === 0) return cfg;
  const variables = isObject(cfg.variables) ? cfg.variables : {};
  return { ...cfg, variables: { ...variables, ...Object.fromEntries(entered) } };
}

// Editing a provider: the server returns stored secrets as "****". Those boxes
// start empty and may stay empty, which keeps the stored value.
export function keptParameters(cfg) {
  const variables = isObject(cfg) && isObject(cfg.variables) ? cfg.variables : {};
  return new Set(Object.keys(variables).filter((name) => variables[name] === MASKED_VALUE));
}

// Editing a provider: each box starts with the value saved in "variables" when it
// is shown in plain text. Masked, empty and placeholder values start empty.
export function initialParameterValues(cfg) {
  const variables = isObject(cfg) && isObject(cfg.variables) ? cfg.variables : {};
  const values = {};
  for (const name of detectParameters(cfg).provider) {
    const value = variables[name];
    if (typeof value === 'string' && value && value !== MASKED_VALUE && !hasPlaceholder(value)) values[name] = value;
  }
  return values;
}
