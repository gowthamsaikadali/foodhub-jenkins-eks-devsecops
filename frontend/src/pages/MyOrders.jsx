import { Link } from 'react-router-dom';
import EmptyState from '../components/EmptyState';
import ErrorMessage from '../components/ErrorMessage';
import Loader from '../components/Loader';
import OrderCard from '../components/OrderCard';
import useFetch from '../hooks/useFetch';
import { orderService } from '../services/orderService';

export default function MyOrders() {
  const { data, loading, error, reload } = useFetch(() => orderService.mine());
  return (
    <>
      <h1>My orders</h1>
      {loading && <Loader />}
      <ErrorMessage message={error} onRetry={reload} />
      {data && data.length === 0 && <EmptyState title="No orders yet"><Link to="/restaurants" className="btn">Order something tasty</Link></EmptyState>}
      {data && <div className="grid">{data.map((o) => <OrderCard key={o.id} order={o} />)}</div>}
    </>
  );
}
