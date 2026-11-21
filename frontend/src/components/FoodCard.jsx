import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useCart } from '../context/CartContext';
import { useToast } from '../context/ToastContext';
import { getErrorMessage } from '../services/api';
import { formatINR } from '../utils/format';

const FALLBACK = 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600';

export default function FoodCard({ food, showRestaurant = false }) {
  const { isAuthenticated, isAdmin } = useAuth();
  const { add } = useCart();
  const toast = useToast();
  const navigate = useNavigate();
  const [busy, setBusy] = useState(false);

  const handleAdd = async () => {
    if (!isAuthenticated) {
      navigate('/login', { state: { from: window.location.pathname } });
      return;
    }
    setBusy(true);
    try {
      await add(food.id, 1);
      toast.success(`${food.name} added to cart`);
    } catch (err) {
      toast.error(getErrorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="card food-card">
      <img src={food.imageUrl || FALLBACK} alt={food.name} loading="lazy"
           onError={(e) => { e.currentTarget.src = FALLBACK; }} />
      <div className="card-body">
        <h3>{food.name}</h3>
        {showRestaurant && <p className="muted">{food.restaurantName}</p>}
        {food.categoryName && <span className="chip">{food.categoryName}</span>}
        <p className="clamp">{food.description}</p>
        <div className="row-between">
          <strong>{formatINR(food.price)}</strong>
          {!isAdmin && (
            <button className="btn btn-small" onClick={handleAdd} disabled={busy}>
              {busy ? 'Adding...' : 'Add to cart'}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
