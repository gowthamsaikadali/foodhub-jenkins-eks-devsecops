import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

/**
 * Guards a group of routes.
 *  - not logged in            -> go to the login page (and come back afterwards)
 *  - role="admin" and not admin -> go to the customer home
 *  - role="customer" and admin  -> go to the admin dashboard
 * NOTE: this only hides screens. The real security is in the backend, which re-checks every request.
 */
export default function ProtectedRoute({ role }) {
  const { isAuthenticated, isAdmin } = useAuth();
  const location = useLocation();

  if (!isAuthenticated) {
    const loginPath = role === 'admin' ? '/admin/login' : '/login';
    return <Navigate to={loginPath} replace state={{ from: location.pathname }} />;
  }
  if (role === 'admin' && !isAdmin) return <Navigate to="/" replace />;
  if (role === 'customer' && isAdmin) return <Navigate to="/admin" replace />;
  return <Outlet />;
}
