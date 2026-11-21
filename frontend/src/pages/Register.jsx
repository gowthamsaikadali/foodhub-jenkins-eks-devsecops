import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import ErrorMessage from '../components/ErrorMessage';
import FormField from '../components/FormField';
import { useAuth } from '../context/AuthContext';
import { getErrorMessage } from '../services/api';
import { validateEmail, validateForm, validatePassword, validatePhone, validateRequired } from '../utils/validators';

export default function Register() {
  const { register } = useAuth();
  const navigate = useNavigate();
  const [values, setValues] = useState({ fullName: '', email: '', password: '', confirm: '', phone: '' });
  const [errors, setErrors] = useState({});
  const [serverError, setServerError] = useState('');
  const [busy, setBusy] = useState(false);

  const change = (e) => setValues({ ...values, [e.target.name]: e.target.value });

  const submit = async (e) => {
    e.preventDefault();
    const v = validateForm(values, {
      fullName: validateRequired('Full name'),
      email: validateEmail,
      password: validatePassword,
      confirm: (c, all) => (c === all.password ? '' : 'Passwords do not match'),
      phone: validatePhone,
    });
    setErrors(v);
    if (Object.keys(v).length) return;
    setBusy(true);
    setServerError('');
    try {
      await register({ fullName: values.fullName, email: values.email, password: values.password, phone: values.phone });
      navigate('/', { replace: true });
    } catch (err) {
      setServerError(getErrorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <form className="form-card" onSubmit={submit} noValidate>
      <h2>Create your account</h2>
      <ErrorMessage message={serverError} />
      <FormField label="Full name" name="fullName" error={errors.fullName}>
        <input id="fullName" name="fullName" autoComplete="name" value={values.fullName} onChange={change} />
      </FormField>
      <FormField label="Email" name="email" error={errors.email}>
        <input id="email" name="email" type="email" autoComplete="email" value={values.email} onChange={change} />
      </FormField>
      <FormField label="Phone (optional)" name="phone" error={errors.phone}>
        <input id="phone" name="phone" type="tel" autoComplete="tel" value={values.phone} onChange={change} />
      </FormField>
      <FormField label="Password" name="password" error={errors.password} hint="At least 8 characters with a letter and a digit">
        <input id="password" name="password" type="password" autoComplete="new-password" value={values.password} onChange={change} />
      </FormField>
      <FormField label="Confirm password" name="confirm" error={errors.confirm}>
        <input id="confirm" name="confirm" type="password" autoComplete="new-password" value={values.confirm} onChange={change} />
      </FormField>
      <button className="btn btn-block" disabled={busy}>{busy ? 'Creating account...' : 'Sign up'}</button>
      <p className="muted" style={{ marginTop: '1rem' }}>Already registered? <Link to="/login">Log in</Link></p>
    </form>
  );
}
