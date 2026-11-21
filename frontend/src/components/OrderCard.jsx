import { Link } from 'react-router-dom';
import { formatDateTime, formatINR } from '../utils/format';
import StatusBadge from './StatusBadge';

export default function OrderCard({ order }) {
  return (
    <div className="card order-card">
      <div className="card-body">
        <div className="row-between">
          <h3>Order #{order.id}</h3>
          <StatusBadge status={order.status} />
        </div>
        <p className="muted">{order.restaurantName} · {formatDateTime(order.createdAt)}</p>
        <p>{order.items.map((i) => `${i.quantity} × ${i.foodName}`).join(', ')}</p>
        <div className="row-between">
          <strong>{formatINR(order.totalAmount)}</strong>
          <Link className="btn btn-small btn-outline" to={`/orders/${order.id}`}>Track order</Link>
        </div>
      </div>
    </div>
  );
}
