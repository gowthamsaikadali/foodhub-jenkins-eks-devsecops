import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function AdminLayout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  return (
    <div className="admin-shell">
      <aside className="sidebar">
        <div className="brand">🍽️ FoodHub Admin</div>
        <nav>
          <NavLink to="/admin" end>Dashboard</NavLink>
          <NavLink to="/admin/restaurants">Restaurants</NavLink>
          <NavLink to="/admin/foods">Foods</NavLink>
          <NavLink to="/admin/orders">Orders</NavLink>
          <NavLink to="/admin/customers">Customers</NavLink>
        </nav>
        <div className="sidebar-footer">
          <small>{user?.email}</small>
          <button className="btn btn-small btn-outline" onClick={() => { logout(); navigate('/admin/login'); }}>
            Log out
          </button>
        </div>
      </aside>
      <main className="admin-main">
        <Outlet />
      </main>
    </div>
  );
}
