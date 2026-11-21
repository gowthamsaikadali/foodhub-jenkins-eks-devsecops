import { Link, useParams } from 'react-router-dom';
import ErrorMessage from '../components/ErrorMessage';
import Loader from '../components/Loader';
import StatusBadge from '../components/StatusBadge';
import useFetch from '../hooks/useFetch';
import { orderService } from '../services/orderService';
import { formatINR } from '../utils/format';

export default function OrderConfirmation() {
  const { id } = useParams();
  const { data: o, loading, error, reload } = useFetch(() => orderService.get(id), [id]);

  if (loading) return <Loader />;
  if (error) return <ErrorMessage message={error} onRetry={reload} />;

  return (
    <div className="form-card form-wide">
      <div className="alert alert-success">🎉 Thank you! Your order has been placed.</div>
      <div className="row-between"><h2>Order #{o.id}</h2><StatusBadge status={o.status} /></div>
      <p className="muted">{o.restaurantName} · deliver to {o.deliveryAddress}</p>
      {o.items.map((i) => (
        <div className="summary-row" key={`${i.foodItemId}-${i.foodName}`}><span>{i.quantity} × {i.foodName}</span><span>{formatINR(i.lineTotal)}</span></div>
      ))}
      <div className="summary-row"><span>Subtotal</span><span>{formatINR(o.subtotal)}</span></div>
      <div className="summary-row"><span>Delivery fee</span><span>{formatINR(o.deliveryFee)}</span></div>
      <div className="summary-row"><span>Tax</span><span>{formatINR(o.tax)}</span></div>
      <div className="summary-row total"><span>Total</span><span>{formatINR(o.totalAmount)}</span></div>
      {o.payment && (
        <p>Payment: {o.payment.method.replaceAll('_', ' ').toLowerCase()} · <StatusBadge status={o.payment.status} /></p>
      )}
      <div className="actions">
        <Link className="btn" to={`/orders/${o.id}`}>Track order</Link>
        <Link className="btn btn-outline" to="/restaurants">Order more</Link>
      </div>
    </div>
  );
}
