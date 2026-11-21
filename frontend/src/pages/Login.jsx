import { useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import ErrorMessage from '../components/ErrorMessage';
import FormField from '../components/FormField';
import { useAuth } from '../context/AuthContext';
import { getErrorMessage } from '../services/api';
import { validateEmail, validateForm, validateRequired } from '../utils/validators';

export default function Login() {
  const { login, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [values, setValues] = useState({ email: '', password: '' });
  const [errors, setErrors] = useState({});
  const [serverError, setServerError] = useState('');
  const [busy, setBusy] = useState(false);

  const change = (e) => setValues({ ...values, [e.target.name]: e.target.value });

  const submit = async (e) => {
    e.preventDefault();
    const v = validateForm(values, { email: validateEmail, password: validateRequired('Password') });
    setErrors(v);
    if (Object.keys(v).length) return;
    setBusy(true);
    setServerError('');
    try {
      const user = await login(values.email, values.password);
      if (user.roles.includes('ROLE_ADMIN')) {
        // admins use the admin portal; keep this page customer-only
        logout();
        setServerError('Administrators must sign in from the admin login page.');
        return;
      }
      navigate(location.state?.from || '/', { replace: true });
    } catch (err) {
      setServerError(getErrorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <form className="form-card" onSubmit={submit} noValidate>
      <h2>Welcome back</h2>
      <ErrorMessage message={serverError} />
      <FormField label="Email" name="email" error={errors.email}>
        <input id="email" name="email" type="email" autoComplete="email" value={values.email} onChange={change} />
      </FormField>
      <FormField label="Password" name="password" error={errors.password}>
        <input id="password" name="password" type="password" autoComplete="current-password" value={values.password} onChange={change} />
      </FormField>
      <button className="btn btn-block" disabled={busy}>{busy ? 'Signing in...' : 'Log in'}</button>
      <p className="muted" style={{ marginTop: '1rem' }}>New here? <Link to="/register">Create an account</Link></p>
    </form>
  );
}
