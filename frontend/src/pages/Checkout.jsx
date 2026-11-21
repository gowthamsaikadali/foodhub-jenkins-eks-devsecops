import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import EmptyState from '../components/EmptyState';
import ErrorMessage from '../components/ErrorMessage';
import FormField from '../components/FormField';
import { useAuth } from '../context/AuthContext';
import { useCart } from '../context/CartContext';
import { getErrorMessage } from '../services/api';
import { authService } from '../services/authService';
import { orderService } from '../services/orderService';
import { formatINR } from '../utils/format';
import { validateForm, validateRequired } from '../utils/validators';

export default function Checkout() {
  const { cart, refresh } = useCart();
  const { user } = useAuth();
  const navigate = useNavigate();
  const [values, setValues] = useState({ deliveryAddress: '', notes: '', paymentMethod: 'CASH_ON_DELIVERY' });
  const [errors, setErrors] = useState({});
  const [serverError, setServerError] = useState('');
  const [busy, setBusy] = useState(false);

  // Pre-fill the address from the saved profile.
  useEffect(() => {
    authService.me().then((p) => p.address && setValues((v) => (v.deliveryAddress ? v : { ...v, deliveryAddress: p.address }))).catch(() => {});
  }, [user?.id]);

  if (cart.items.length === 0) {
    return <EmptyState title="Nothing to check out"><Link to="/restaurants" className="btn">Browse restaurants</Link></EmptyState>;
  }

  const change = (e) => setValues({ ...values, [e.target.name]: e.target.value });

  const submit = async (e) => {
    e.preventDefault();
    const v = validateForm(values, {
      deliveryAddress: (x) => validateRequired('Delivery address')(x) || (x.trim().length < 5 ? 'Address is too short' : ''),
    });
    setErrors(v);
    if (Object.keys(v).length) return;
    setBusy(true);
    setServerError('');
    try {
      // Only the address, notes and payment method are sent. The server calculates prices from the database.
      const order = await orderService.place(values);
      if (values.paymentMethod === 'SIMULATED_ONLINE') {
        try { await orderService.pay(order.id, false); } catch { /* the user can retry from the tracking page */ }
      }
      await refresh();
      navigate(`/order-confirmation/${order.id}`, { replace: true });
    } catch (err) {
      setServerError(getErrorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <h1>Checkout</h1>
      <div className="two-col">
        <form className="summary" onSubmit={submit} noValidate>
          <ErrorMessage message={serverError} />
          <FormField label="Delivery address" name="deliveryAddress" error={errors.deliveryAddress}>
            <textarea id="deliveryAddress" name="deliveryAddress" rows={3} value={values.deliveryAddress} onChange={change} />
          </FormField>
          <FormField label="Notes for the restaurant (optional)" name="notes">
            <input id="notes" name="notes" maxLength={500} value={values.notes} onChange={change} />
          </FormField>
          <h3>Payment method</h3>
          <label className="radio-row">
            <input type="radio" name="paymentMethod" value="CASH_ON_DELIVERY" checked={values.paymentMethod === 'CASH_ON_DELIVERY'} onChange={change} />
            Cash on delivery
          </label>
          <label className="radio-row">
            <input type="radio" name="paymentMethod" value="SIMULATED_ONLINE" checked={values.paymentMethod === 'SIMULATED_ONLINE'} onChange={change} />
            Online payment (simulated, no card needed)
          </label>
          <button className="btn btn-block" disabled={busy}>{busy ? 'Placing order...' : 'Place order'}</button>
        </form>
        <aside className="summary">
          <h3>{cart.restaurantName}</h3>
          {cart.items.map((i) => (
            <div className="summary-row" key={i.foodItemId}><span>{i.quantity} × {i.name}</span><span>{formatINR(i.lineTotal)}</span></div>
          ))}
          <div className="summary-row total"><span>Subtotal</span><span>{formatINR(cart.subtotal)}</span></div>
          <p className="muted">Delivery fee and tax are added by the server and shown on your confirmation.</p>
        </aside>
      </div>
    </>
  );
}
