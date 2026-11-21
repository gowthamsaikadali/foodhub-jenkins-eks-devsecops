import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import ErrorMessage from '../../components/ErrorMessage';
import FormField from '../../components/FormField';
import { useAuth } from '../../context/AuthContext';
import { getErrorMessage } from '../../services/api';
import { validateEmail, validateForm, validateRequired } from '../../utils/validators';

export default function AdminLogin() {
  const { login, logout } = useAuth();
  const navigate = useNavigate();
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
      if (!user.roles.includes('ROLE_ADMIN')) {
        logout();
        setServerError('This account is not an administrator.');
        return;
      }
      navigate('/admin', { replace: true });
    } catch (err) {
      setServerError(getErrorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="container page">
      <form className="form-card" onSubmit={submit} noValidate>
        <h2>🍽️ FoodHub Admin</h2>
        <p className="muted">Restaurant administrators only.</p>
        <ErrorMessage message={serverError} />
        <FormField label="Email" name="email" error={errors.email}>
          <input id="email" name="email" type="email" autoComplete="username" value={values.email} onChange={change} />
        </FormField>
        <FormField label="Password" name="password" error={errors.password}>
          <input id="password" name="password" type="password" autoComplete="current-password" value={values.password} onChange={change} />
        </FormField>
        <button className="btn btn-block" disabled={busy}>{busy ? 'Signing in...' : 'Sign in'}</button>
      </form>
    </div>
  );
}
