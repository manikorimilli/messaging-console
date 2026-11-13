import { describe, expect, it } from 'vitest';
import { overviewRedirect } from '../utils/routes.js';

describe('hidden overview route', () => {
  it('redirects the /overview path to the hash route', () => {
    expect(overviewRedirect('/overview', '')).toBe('/#/overview');
    expect(overviewRedirect('/overview/', '')).toBe('/#/overview');
  });

  it('leaves every other address alone', () => {
    expect(overviewRedirect('/', '#/providers')).toBeNull();
    expect(overviewRedirect('/', '#/overview')).toBeNull();
    expect(overviewRedirect('/overview', '#/providers')).toBeNull();
  });
});
