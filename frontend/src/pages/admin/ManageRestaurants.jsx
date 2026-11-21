import { useState } from 'react';
import EmptyState from '../../components/EmptyState';
import ErrorMessage from '../../components/ErrorMessage';
import FormField from '../../components/FormField';
import Loader from '../../components/Loader';
import { useToast } from '../../context/ToastContext';
import useFetch from '../../hooks/useFetch';
import { getErrorMessage } from '../../services/api';
import { adminService } from '../../services/adminService';
import { validateForm, validatePhone, validateRequired } from '../../utils/validators';

const EMPTY = { name: '', description: '', cuisine: '', address: '', city: '', phone: '', imageUrl: '', available: true };

export default function ManageRestaurants() {
  const toast = useToast();
  const { data, loading, error, reload } = useFetch(() => adminService.restaurants());
  const [editingId, setEditingId] = useState(null); // null = closed, 0 = new, n = editing id
  const [values, setValues] = useState(EMPTY);
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState('');
  const [busy, setBusy] = useState(false);

  const open = (r) => {
    setErrors({});
    setFormError('');
    if (r) {
      setEditingId(r.id);
      setValues({ ...EMPTY, ...r, description: r.description || '', cuisine: r.cuisine || '', phone: r.phone || '', imageUrl: r.imageUrl || '' });
    } else {
      setEditingId(0);
      setValues(EMPTY);
    }
  };

  const change = (e) => {
    const { name, type, checked, value } = e.target;
    setValues({ ...values, [name]: type === 'checkbox' ? checked : value });
  };

  const submit = async (e) => {
    e.preventDefault();
    const v = validateForm(values, { name: validateRequired('Name'), address: validateRequired('Address'), city: validateRequired('City'), phone: validatePhone });
    setErrors(v);
    if (Object.keys(v).length) return;
    setBusy(true);
    setFormError('');
    const payload = { name: values.name, description: values.description, cuisine: values.cuisine, address: values.address, city: values.city, phone: values.phone, imageUrl: values.imageUrl, available: values.available };
    try {
      if (editingId) await adminService.updateRestaurant(editingId, payload);
      else await adminService.createRestaurant(payload);
      toast.success('Restaurant saved');
      setEditingId(null);
      reload();
    } catch (err) {
      setFormError(getErrorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const remove = async (r) => {
    if (!window.confirm(`Delete "${r.name}" and its menu?`)) return;
    try {
      await adminService.deleteRestaurant(r.id);
      toast.success('Restaurant deleted');
      reload();
    } catch (err) {
      toast.error(getErrorMessage(err));
    }
  };

  const toggle = async (r) => {
    try {
      await adminService.updateRestaurant(r.id, { ...r, available: !r.available });
      reload(true);
    } catch (err) {
      toast.error(getErrorMessage(err));
    }
  };

  return (
    <>
      <div className="row-between"><h1>Restaurants</h1><button className="btn" onClick={() => open(null)}>+ New restaurant</button></div>

      {editingId !== null && (
        <form className="summary" onSubmit={submit} noValidate style={{ margin: '1rem 0' }}>
          <h3>{editingId ? 'Edit restaurant' : 'New restaurant'}</h3>
          <ErrorMessage message={formError} />
          <div className="form-grid">
            <FormField label="Name" name="name" error={errors.name}><input id="name" name="name" value={values.name} onChange={change} /></FormField>
            <FormField label="Cuisine" name="cuisine"><input id="cuisine" name="cuisine" value={values.cuisine} onChange={change} /></FormField>
            <FormField label="Address" name="address" error={errors.address}><input id="address" name="address" value={values.address} onChange={change} /></FormField>
            <FormField label="City" name="city" error={errors.city}><input id="city" name="city" value={values.city} onChange={change} /></FormField>
            <FormField label="Phone" name="phone" error={errors.phone}><input id="phone" name="phone" value={values.phone} onChange={change} /></FormField>
            <FormField label="Image URL" name="imageUrl"><input id="imageUrl" name="imageUrl" value={values.imageUrl} onChange={change} /></FormField>
          </div>
          <FormField label="Description" name="description"><textarea id="description" name="description" rows={3} value={values.description} onChange={change} /></FormField>
          <label><input type="checkbox" name="available" checked={values.available} onChange={change} style={{ width: 'auto' }} /> Open for orders</label>
          <div className="actions" style={{ marginTop: '1rem' }}>
            <button className="btn" disabled={busy}>{busy ? 'Saving...' : 'Save'}</button>
            <button type="button" className="btn btn-outline" onClick={() => setEditingId(null)}>Cancel</button>
          </div>
        </form>
      )}

      {loading && <Loader />}
      <ErrorMessage message={error} onRetry={reload} />
      {data && data.length === 0 && <EmptyState title="You have no restaurants yet">Create your first one.</EmptyState>}
      {data && data.length > 0 && (
        <div className="table-wrap" style={{ marginTop: '1rem' }}>
          <table>
            <thead><tr><th>Name</th><th>Cuisine</th><th>City</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              {data.map((r) => (
                <tr key={r.id}>
                  <td><strong>{r.name}</strong></td><td>{r.cuisine}</td><td>{r.city}</td>
                  <td><span className={`badge ${r.available ? 'badge-success' : 'badge-failed'}`}>{r.available ? 'Open' : 'Closed'}</span></td>
                  <td><div className="actions">
                    <button className="btn btn-small btn-outline" onClick={() => open(r)}>Edit</button>
                    <button className="btn btn-small btn-outline" onClick={() => toggle(r)}>{r.available ? 'Close' : 'Open'}</button>
                    <button className="btn btn-small btn-danger" onClick={() => remove(r)}>Delete</button>
                  </div></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}
