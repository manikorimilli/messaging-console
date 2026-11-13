// The only module pages import for data. It builds the exact request bodies
// from the backend contract and hands them to either the mock or the real API.
import { config } from '../config.js';
import { toBackendPlaceholders } from '../utils/providerParams.js';
import * as mockApi from './mockApi.js';
import * as realApi from './realApi.js';

export { ApiError } from './ApiError.js';

const impl = config.useMockApi ? mockApi : realApi;

// Every send names its provider; the backend has no default one.
export function buildSmsRequest({ provider, to, body }) {
  return { type: 'SMS', provider, to, body };
}

export const api = {
  listProviders: () => impl.listProviders(),
  getProvider: (id) => impl.getProvider(id),
  // Saved configs always use the backend's {{name}} form: see toBackendPlaceholders.
  registerProvider: (cfg) => impl.registerProvider(toBackendPlaceholders(cfg)),
  updateProvider: (id, cfg) => impl.updateProvider(id, toBackendPlaceholders(cfg)),
  // The backend has no PATCH: enabling or disabling sends the full config.
  // Masked secrets (****) in the fetched config tell the backend to keep the stored values.
  async setProviderEnabled(id, enabled) {
    const current = await impl.getProvider(id);
    return impl.updateProvider(id, { ...current, enabled });
  },
  deleteProvider: (id) => impl.deleteProvider(id),
  sendSms: (input) => impl.sendSms(buildSmsRequest(input)),
};

