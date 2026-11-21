import { useEffect, useState } from 'react';
import ErrorMessage from '../components/ErrorMessage';
import FormField from '../components/FormField';
import Loader from '../components/Loader';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../context/ToastContext';
import { getErrorMessage } from '../services/api';
import { authService } from '../services/authService';
import { validateForm, validatePhone, validateRequired } from '../utils/validators';

export default function Profile() {
  const { updateUser } = useAuth();
  const toast = useToast();
  const [values, setValues] = useState(null);
  const [email, setEmail] = useState('');
  const [errors, setErrors] = useState({});
  const [serverError, setServerError] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    authService.me()
      .then((p) => { setEmail(p.email); setValues({ fullName: p.fullName, phone: p.phone || '', address: p.address || '' }); })
      .catch((err) => setServerError(getErrorMessage(err)));
  }, []);

  if (!values) return serverError ? <ErrorMessage message={serverError} /> : <Loader />;

  const change = (e) => setValues({ ...values, [e.target.name]: e.target.value });

  const submit = async (e) => {
    e.preventDefault();
    const v = validateForm(values, { fullName: validateRequired('Full name'), phone: validatePhone });
    setErrors(v);
    if (Object.keys(v).length) return;
    setBusy(true);
    setServerError('');
    try {
      updateUser(await authService.updateProfile(values));
      toast.success('Profile updated');
    } catch (err) {
      setServerError(getErrorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <form className="form-card" onSubmit={submit} noValidate>
      <h2>My profile</h2>
      <ErrorMessage message={serverError} />
      <FormField label="Email" name="email" hint="Email cannot be changed"><input id="email" value={email} disabled /></FormField>
      <FormField label="Full name" name="fullName" error={errors.fullName}><input id="fullName" name="fullName" value={values.fullName} onChange={change} /></FormField>
      <FormField label="Phone" name="phone" error={errors.phone}><input id="phone" name="phone" type="tel" value={values.phone} onChange={change} /></FormField>
      <FormField label="Default delivery address" name="address"><textarea id="address" name="address" rows={3} maxLength={300} value={values.address} onChange={change} /></FormField>
      <button className="btn btn-block" disabled={busy}>{busy ? 'Saving...' : 'Save changes'}</button>
    </form>
  );
}
