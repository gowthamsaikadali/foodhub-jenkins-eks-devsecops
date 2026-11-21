// Small, dependency-free form validators. They return an error string, or '' when the value is valid.
// The backend validates again; these only give faster feedback.

export const validateEmail = (v) => (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test((v || '').trim()) ? '' : 'Enter a valid email address');

export const validatePassword = (v) => {
  if (!v || v.length < 8) return 'Password must be at least 8 characters';
  if (v.length > 72) return 'Password must be at most 72 characters';
  if (!/[A-Za-z]/.test(v) || !/\d/.test(v)) return 'Password must contain a letter and a digit';
  return '';
};

export const validateRequired = (label) => (v) => ((v ?? '').toString().trim() ? '' : `${label} is required`);

export const validatePhone = (v) => (!v || /^[0-9+\- ]{7,20}$/.test(v) ? '' : 'Enter a valid phone number');

export const validatePrice = (v) => {
  const n = Number(v);
  if (v === '' || Number.isNaN(n)) return 'Enter a price';
  if (n < 0) return 'Price cannot be negative';
  if (!/^\d+(\.\d{1,2})?$/.test(String(v))) return 'Use at most 2 decimal places';
  return '';
};

/** Runs {field: validatorFn} against values and returns {field: message} for the failures only. */
export function validateForm(values, rules) {
  const errors = {};
  Object.entries(rules).forEach(([field, fn]) => {
    const msg = fn(values[field], values);
    if (msg) errors[field] = msg;
  });
  return errors;
}
