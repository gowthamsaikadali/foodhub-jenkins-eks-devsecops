import { describe, expect, it } from 'vitest';
import { validateEmail, validateForm, validatePassword, validatePrice } from './validators';

describe('validators', () => {
  it('validates email', () => {
    expect(validateEmail('a@b.com')).toBe('');
    expect(validateEmail('nope')).not.toBe('');
  });
  it('validates password rules', () => {
    expect(validatePassword('Passw0rd1')).toBe('');
    expect(validatePassword('short1')).not.toBe('');
    expect(validatePassword('onlyletters')).not.toBe('');
  });
  it('validates price', () => {
    expect(validatePrice('120.50')).toBe('');
    expect(validatePrice('-1')).not.toBe('');
    expect(validatePrice('1.234')).not.toBe('');
    expect(validatePrice('')).not.toBe('');
  });
  it('collects only failing fields', () => {
    const errors = validateForm({ email: 'x', password: 'Passw0rd1' }, { email: validateEmail, password: validatePassword });
    expect(Object.keys(errors)).toEqual(['email']);
  });
});
