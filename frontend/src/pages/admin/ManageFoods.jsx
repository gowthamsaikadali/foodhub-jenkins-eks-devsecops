import { useEffect, useState } from 'react';
import EmptyState from '../../components/EmptyState';
import ErrorMessage from '../../components/ErrorMessage';
import FormField from '../../components/FormField';
import Loader from '../../components/Loader';
import { useToast } from '../../context/ToastContext';
import useFetch from '../../hooks/useFetch';
import { adminService } from '../../services/adminService';
import { getErrorMessage } from '../../services/api';
import { catalogService } from '../../services/catalogService';
import { formatINR } from '../../utils/format';
import { validateForm, validatePrice, validateRequired } from '../../utils/validators';

const EMPTY = { name: '', description: '', price: '', imageUrl: '', categoryId: '', available: true };

export default function ManageFoods() {
  const toast = useToast();
  const restaurants = useFetch(() => adminService.restaurants());
  const categories = useFetch(() => catalogService.categories());
  const [restaurantId, setRestaurantId] = useState('');
  const foods = useFetch(() => (restaurantId ? adminService.foods(restaurantId) : Promise.resolve([])), [restaurantId]);

  const [editingId, setEditingId] = useState(null);
  const [values, setValues] = useState(EMPTY);
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState('');
  const [busy, setBusy] = useState(false);
  const [newCategory, setNewCategory] = useState('');

  useEffect(() => {
    if (!restaurantId && restaurants.data?.length) setRestaurantId(String(restaurants.data[0].id));
  }, [restaurants.data, restaurantId]);

  const open = (f) => {
    setErrors({});
    setFormError('');
    if (f) {
      setEditingId(f.id);
      setValues({ name: f.name, description: f.description || '', price: String(f.price), imageUrl: f.imageUrl || '', categoryId: f.categoryId ? String(f.categoryId) : '', available: f.available });
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
    const v = validateForm(values, { name: validateRequired('Name'), price: validatePrice });
    setErrors(v);
    if (Object.keys(v).length) return;
    setBusy(true);
    setFormError('');
    const payload = {
      restaurantId: Number(restaurantId),
      categoryId: values.categoryId ? Number(values.categoryId) : null,
      name: values.name, description: values.description, price: values.price, imageUrl: values.imageUrl, available: values.available,
    };
    try {
      if (editingId) await adminService.updateFood(editingId, payload);
      else await adminService.createFood(payload);
      toast.success('Food item saved');
      setEditingId(null);
      foods.reload();
    } catch (err) {
      setFormError(getErrorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const remove = async (f) => {
    if (!window.confirm(`Delete "${f.name}"?`)) return;
    try {
      await adminService.deleteFood(f.id);
      toast.success('Food item deleted');
      foods.reload();
    } catch (err) {
      toast.error(getErrorMessage(err));
    }
  };

  const addCategory = async (e) => {
    e.preventDefault();
    if (!newCategory.trim()) return;
    try {
      await adminService.createCategory({ name: newCategory.trim() });
      setNewCategory('');
      toast.success('Category added');
      categories.reload();
    } catch (err) {
      toast.error(getErrorMessage(err));
    }
  };

  const removeCategory = async (c) => {
    if (!window.confirm(`Delete category "${c.name}"? Foods keep existing but become uncategorised.`)) return;
    try {
      await adminService.deleteCategory(c.id);
      categories.reload();
      foods.reload(true);
    } catch (err) {
      toast.error(getErrorMessage(err));
    }
  };

  if (restaurants.loading) return <Loader />;
  if (restaurants.error) return <ErrorMessage message={restaurants.error} onRetry={restaurants.reload} />;
  if (!restaurants.data.length) return <EmptyState title="Create a restaurant first">Foods belong to a restaurant.</EmptyState>;

  return (
    <>
      <div className="row-between">
        <h1>Foods</h1>
        <div className="actions">
          <select style={{ width: 'auto' }} value={restaurantId} onChange={(e) => { setRestaurantId(e.target.value); setEditingId(null); }} aria-label="Restaurant">
            {restaurants.data.map((r) => <option key={r.id} value={r.id}>{r.name}</option>)}
          </select>
          <button className="btn" onClick={() => open(null)}>+ New food</button>
        </div>
      </div>

      <div className="summary" style={{ margin: '1rem 0' }}>
        <strong>Categories:</strong>{' '}
        {(categories.data || []).map((c) => (
          <span className="chip" key={c.id} style={{ marginRight: '.4rem' }}>{c.name} <button aria-label={`Delete ${c.name}`} onClick={() => removeCategory(c)} style={{ border: 0, background: 'none', cursor: 'pointer' }}>×</button></span>
        ))}
        <form onSubmit={addCategory} style={{ display: 'flex', gap: '.5rem', marginTop: '.5rem', maxWidth: 360 }}>
          <input value={newCategory} onChange={(e) => setNewCategory(e.target.value)} placeholder="New category" aria-label="New category" />
          <button className="btn btn-small">Add</button>
        </form>
      </div>

      {editingId !== null && (
        <form className="summary" onSubmit={submit} noValidate style={{ marginBottom: '1rem' }}>
          <h3>{editingId ? 'Edit food' : 'New food'}</h3>
          <ErrorMessage message={formError} />
          <div className="form-grid">
            <FormField label="Name" name="name" error={errors.name}><input id="name" name="name" value={values.name} onChange={change} /></FormField>
            <FormField label="Price (INR)" name="price" error={errors.price}><input id="price" name="price" inputMode="decimal" value={values.price} onChange={change} /></FormField>
            <FormField label="Category" name="categoryId">
              <select id="categoryId" name="categoryId" value={values.categoryId} onChange={change}>
                <option value="">None</option>
                {(categories.data || []).map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
            </FormField>
            <FormField label="Image URL" name="imageUrl"><input id="imageUrl" name="imageUrl" value={values.imageUrl} onChange={change} /></FormField>
          </div>
          <FormField label="Description" name="description"><textarea id="description" name="description" rows={2} value={values.description} onChange={change} /></FormField>
          <label><input type="checkbox" name="available" checked={values.available} onChange={change} style={{ width: 'auto' }} /> Available</label>
          <div className="actions" style={{ marginTop: '1rem' }}>
            <button className="btn" disabled={busy}>{busy ? 'Saving...' : 'Save'}</button>
            <button type="button" className="btn btn-outline" onClick={() => setEditingId(null)}>Cancel</button>
          </div>
        </form>
      )}

      {foods.loading && <Loader />}
      <ErrorMessage message={foods.error} onRetry={foods.reload} />
      {foods.data && foods.data.length === 0 && <EmptyState title="No food items yet" />}
      {foods.data && foods.data.length > 0 && (
        <div className="table-wrap">
          <table>
            <thead><tr><th>Name</th><th>Category</th><th>Price</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              {foods.data.map((f) => (
                <tr key={f.id}>
                  <td><strong>{f.name}</strong></td><td>{f.categoryName || '—'}</td><td>{formatINR(f.price)}</td>
                  <td><span className={`badge ${f.available ? 'badge-success' : 'badge-failed'}`}>{f.available ? 'Available' : 'Hidden'}</span></td>
                  <td><div className="actions">
                    <button className="btn btn-small btn-outline" onClick={() => open(f)}>Edit</button>
                    <button className="btn btn-small btn-danger" onClick={() => remove(f)}>Delete</button>
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
