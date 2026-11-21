import { useEffect, useState } from 'react';
import EmptyState from '../../components/EmptyState';
import ErrorMessage from '../../components/ErrorMessage';
import Loader from '../../components/Loader';
import StatusBadge from '../../components/StatusBadge';
import { useToast } from '../../context/ToastContext';
import useFetch from '../../hooks/useFetch';
import { adminService } from '../../services/adminService';
import { getErrorMessage } from '../../services/api';
import { formatDateTime, formatINR } from '../../utils/format';

const ACTION_LABEL = {
  CONFIRMED: 'Accept', REJECTED: 'Reject', PREPARING: 'Start preparing', READY: 'Mark ready', DELIVERED: 'Mark delivered', CANCELLED: 'Cancel',
};
const DANGER = new Set(['REJECTED', 'CANCELLED']);

export default function ManageOrders() {
  const toast = useToast();
  const { data, loading, error, reload } = useFetch(() => adminService.orders());
  const [filter, setFilter] = useState('ACTIVE');
  const [busyId, setBusyId] = useState(null);

  // new orders show up without a manual refresh
  useEffect(() => {
    const t = setInterval(() => reload(true), 15000);
    return () => clearInterval(t);
  }, [reload]);

  const change = async (order, status) => {
    if (DANGER.has(status) && !window.confirm(`${ACTION_LABEL[status]} order #${order.id}?`)) return;
    setBusyId(order.id);
    try {
      await adminService.updateOrderStatus(order.id, status);
      toast.success(`Order #${order.id} updated`);
      reload(true);
    } catch (err) {
      toast.error(getErrorMessage(err));
    } finally {
      setBusyId(null);
    }
  };

  if (loading) return <Loader />;
  if (error) return <ErrorMessage message={error} onRetry={reload} />;

  const isFinal = (s) => ['DELIVERED', 'CANCELLED', 'REJECTED'].includes(s);
  const list = data.filter((o) => (filter === 'ALL' ? true : filter === 'ACTIVE' ? !isFinal(o.status) : isFinal(o.status)));

  return (
    <>
      <div className="row-between">
        <h1>Orders</h1>
        <select style={{ width: 'auto' }} value={filter} onChange={(e) => setFilter(e.target.value)} aria-label="Filter orders">
          <option value="ACTIVE">Active</option><option value="DONE">Finished</option><option value="ALL">All</option>
        </select>
      </div>
      {list.length === 0 && <EmptyState title="No orders here" />}
      {list.length > 0 && (
        <div className="table-wrap" style={{ marginTop: '1rem' }}>
          <table>
            <thead><tr><th>#</th><th>Customer</th><th>Items</th><th>Total</th><th>Payment</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              {list.map((o) => (
                <tr key={o.id}>
                  <td>{o.id}<br /><small className="muted">{formatDateTime(o.createdAt)}</small></td>
                  <td>{o.customerName}<br /><small className="muted">{o.deliveryAddress}</small></td>
                  <td>{o.items.map((i) => <div key={`${o.id}-${i.foodName}`}>{i.quantity} × {i.foodName}</div>)}{o.notes && <small className="muted">Note: {o.notes}</small>}</td>
                  <td>{formatINR(o.totalAmount)}</td>
                  <td>{o.payment ? <StatusBadge status={o.payment.status} /> : '—'}<br /><small className="muted">{o.payment?.method.replaceAll('_', ' ').toLowerCase()}</small></td>
                  <td><StatusBadge status={o.status} /></td>
                  <td><div className="actions">
                    {o.nextStatuses.map((s) => (
                      <button key={s} className={`btn btn-small ${DANGER.has(s) ? 'btn-danger' : s === 'CONFIRMED' ? 'btn-ok' : ''}`} disabled={busyId === o.id} onClick={() => change(o, s)}>
                        {ACTION_LABEL[s] || s}
                      </button>
                    ))}
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
