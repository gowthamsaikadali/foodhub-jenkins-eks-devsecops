import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import EmptyState from '../components/EmptyState';
import ErrorMessage from '../components/ErrorMessage';
import Loader from '../components/Loader';
import { useCart } from '../context/CartContext';
import { useToast } from '../context/ToastContext';
import { getErrorMessage } from '../services/api';
import { formatINR } from '../utils/format';

export default function Cart() {
  const { cart, loading, setQuantity, remove, clear } = useCart();
  const toast = useToast();
  const navigate = useNavigate();
  const [error, setError] = useState('');

  const act = async (fn) => {
    setError('');
    try {
      await fn();
    } catch (err) {
      setError(getErrorMessage(err));
      toast.error(getErrorMessage(err));
    }
  };

  if (loading) return <Loader />;
  if (cart.items.length === 0) {
    return <EmptyState title="Your cart is empty"><Link to="/restaurants" className="btn">Browse restaurants</Link></EmptyState>;
  }
  const hasUnavailable = cart.items.some((i) => !i.available);

  return (
    <>
      <div className="row-between">
        <h1>Your cart</h1>
        <button className="btn btn-small btn-outline" onClick={() => act(clear)}>Clear cart</button>
      </div>
      <p className="muted">Ordering from <strong>{cart.restaurantName}</strong></p>
      <ErrorMessage message={error} />
      <div className="two-col">
        <div className="card"><div className="card-body">
          {cart.items.map((i) => (
            <div className="cart-line" key={i.foodItemId}>
              <img src={i.imageUrl || 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=200'} alt={i.name} />
              <div>
                <strong>{i.name}</strong>
                <div className="muted">{formatINR(i.unitPrice)} each{!i.available && ' · no longer available'}</div>
                <div className="qty">
                  <button aria-label={`Decrease ${i.name}`} disabled={i.quantity <= 1} onClick={() => act(() => setQuantity(i.foodItemId, i.quantity - 1))}>−</button>
                  <span>{i.quantity}</span>
                  <button aria-label={`Increase ${i.name}`} disabled={i.quantity >= 50} onClick={() => act(() => setQuantity(i.foodItemId, i.quantity + 1))}>+</button>
                  <button className="btn btn-small btn-outline" onClick={() => act(() => remove(i.foodItemId))}>Remove</button>
                </div>
              </div>
              <strong>{formatINR(i.lineTotal)}</strong>
            </div>
          ))}
        </div></div>
        <aside className="summary">
          <h3>Summary</h3>
          <div className="summary-row"><span>Subtotal</span><strong>{formatINR(cart.subtotal)}</strong></div>
          <p className="muted">Delivery fee and taxes are calculated by the server when you place the order.</p>
          {hasUnavailable && <p className="error-text">Remove unavailable items to continue.</p>}
          <button className="btn btn-block" disabled={hasUnavailable} onClick={() => navigate('/checkout')}>Proceed to checkout</button>
        </aside>
      </div>
    </>
  );
}
