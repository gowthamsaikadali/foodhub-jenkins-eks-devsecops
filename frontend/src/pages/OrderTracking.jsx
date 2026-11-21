import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import ErrorMessage from '../components/ErrorMessage';
import Loader from '../components/Loader';
import StatusBadge from '../components/StatusBadge';
import { useToast } from '../context/ToastContext';
import useFetch from '../hooks/useFetch';
import { getErrorMessage } from '../services/api';
import { orderService } from '../services/orderService';
import { STATUS_LABEL, STATUS_STEPS, formatDateTime, formatINR } from '../utils/format';

export default function OrderTracking() {
  const { id } = useParams();
  const toast = useToast();
  const { data: o, setData, loading, error, reload } = useFetch(() => orderService.get(id), [id]);
  const [busy, setBusy] = useState(false);

  // Refresh every 10 seconds until the order reaches a final state.
  const isFinal = o && ['DELIVERED', 'CANCELLED', 'REJECTED'].includes(o.status);
  useEffect(() => {
    if (!o || isFinal) return undefined;
    const t = setInterval(() => reload(true), 10000);
    return () => clearInterval(t);
  }, [o, isFinal, reload]);

  const act = async (fn, okMessage) => {
    setBusy(true);
    try {
      await fn();
      setData(await orderService.get(id));
      toast.success(okMessage);
    } catch (err) {
      toast.error(getErrorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  if (loading) return <Loader />;
  if (error) return <ErrorMessage message={error} onRetry={reload} />;

  const reached = STATUS_STEPS.indexOf(o.status);
  const stopped = o.status === 'CANCELLED' || o.status === 'REJECTED';
  const needsPayment = o.payment?.method === 'SIMULATED_ONLINE' && o.payment.status !== 'SUCCESS' && !stopped;

  return (
    <>
      <Link to="/orders">← My orders</Link>
      <div className="summary" style={{ marginTop: '1rem' }}>
        <div className="row-between"><h1>Order #{o.id}</h1><StatusBadge status={o.status} /></div>
        <p className="muted">{o.restaurantName} · placed {formatDateTime(o.createdAt)}</p>

        {stopped ? (
          <div className="alert alert-error">This order was {STATUS_LABEL[o.status].toLowerCase()}.</div>
        ) : (
          <div className="steps" aria-label="Order progress">
            {STATUS_STEPS.map((s, i) => <div key={s} className={`step ${i <= reached ? 'done' : ''}`}>{STATUS_LABEL[s]}</div>)}
          </div>
        )}

        <h3>Items</h3>
        {o.items.map((i) => <div className="summary-row" key={`${i.foodItemId}-${i.foodName}`}><span>{i.quantity} × {i.foodName}</span><span>{formatINR(i.lineTotal)}</span></div>)}
        <div className="summary-row"><span>Delivery fee</span><span>{formatINR(o.deliveryFee)}</span></div>
        <div className="summary-row"><span>Tax</span><span>{formatINR(o.tax)}</span></div>
        <div className="summary-row total"><span>Total</span><span>{formatINR(o.totalAmount)}</span></div>

        <p>Deliver to: {o.deliveryAddress}</p>
        {o.payment && <p>Payment: {o.payment.method.replaceAll('_', ' ').toLowerCase()} · <StatusBadge status={o.payment.status} />{o.payment.transactionRef && ` · ${o.payment.transactionRef}`}</p>}

        <div className="actions">
          {needsPayment && <button className="btn" disabled={busy} onClick={() => act(() => orderService.pay(o.id, false), 'Payment successful')}>Pay now (simulated)</button>}
          {o.status === 'PLACED' && <button className="btn btn-danger" disabled={busy} onClick={() => act(() => orderService.cancel(o.id), 'Order cancelled')}>Cancel order</button>}
        </div>
      </div>
    </>
  );
}
