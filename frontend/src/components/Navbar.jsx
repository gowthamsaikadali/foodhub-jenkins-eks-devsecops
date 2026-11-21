import { useState } from 'react';
import { Link, NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useCart } from '../context/CartContext';

export default function Navbar() {
  const { isAuthenticated, isAdmin, user, logout } = useAuth();
  const { count } = useCart();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);

  const close = () => setOpen(false);
  const handleLogout = () => {
    logout();
    close();
    navigate('/');
  };

  return (
    <header className="navbar">
      <div className="container nav-inner">
        <Link to="/" className="brand" onClick={close}>🍽️ FoodHub</Link>
        <button className="nav-toggle" aria-label="Toggle menu" aria-expanded={open} onClick={() => setOpen(!open)}>☰</button>
        <nav className={`nav-links ${open ? 'open' : ''}`}>
          <NavLink to="/" end onClick={close}>Home</NavLink>
          <NavLink to="/restaurants" onClick={close}>Restaurants</NavLink>
          <NavLink to="/menu" onClick={close}>Food</NavLink>
          {isAuthenticated && !isAdmin && (
            <>
              <NavLink to="/orders" onClick={close}>My orders</NavLink>
              <NavLink to="/cart" onClick={close}>Cart{count > 0 && <span className="cart-count">{count}</span>}</NavLink>
              <NavLink to="/profile" onClick={close}>{user?.fullName?.split(' ')[0] || 'Profile'}</NavLink>
            </>
          )}
          {isAdmin && <NavLink to="/admin" onClick={close}>Admin</NavLink>}
          {isAuthenticated ? (
            <button className="btn btn-small btn-outline" onClick={handleLogout}>Log out</button>
          ) : (
            <>
              <NavLink to="/login" onClick={close}>Log in</NavLink>
              <Link to="/register" className="btn btn-small" onClick={close}>Sign up</Link>
            </>
          )}
        </nav>
      </div>
    </header>
  );
}
