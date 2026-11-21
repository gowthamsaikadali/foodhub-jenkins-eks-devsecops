import ErrorMessage from '../../components/ErrorMessage';
import Loader from '../../components/Loader';
import useFetch from '../../hooks/useFetch';
import { adminService } from '../../services/adminService';
import { formatINR } from '../../utils/format';

export default function AdminDashboard() {
  const { data, loading, error, reload } = useFetch(() => adminService.dashboard());

  if (loading) return <Loader />;
  if (error) return <ErrorMessage message={error} onRetry={reload} />;

  const tiles = [
    ['Customers', data.totalCustomers, 'who ordered from you'],
    ['Restaurants', data.totalRestaurants, 'owned by you'],
    ['Food items', data.totalFoodItems, 'on your menus'],
    ['Total orders', data.totalOrders, ''],
    ['Pending orders', data.pendingOrders, 'placed to ready'],
    ['Completed orders', data.completedOrders, 'delivered'],
    ['Total order value', formatINR(data.totalOrderValue), 'excluding cancelled/rejected'],
  ];

  return (
    <>
      <div className="row-between"><h1>Dashboard</h1><button className="btn btn-small btn-outline" onClick={reload}>Refresh</button></div>
      <div className="stats">
        {tiles.map(([label, value, sub]) => (
          <div className="stat" key={label}>
            <div className="value">{value}</div>
            <div className="label">{label}</div>
            {sub && <small className="muted">{sub}</small>}
          </div>
        ))}
      </div>
    </>
  );
}
