import { Navigate, Route, Routes } from 'react-router-dom';
import ProtectedRoute from './components/ProtectedRoute';
import AdminLayout from './layouts/AdminLayout';
import CustomerLayout from './layouts/CustomerLayout';

import Cart from './pages/Cart';
import Checkout from './pages/Checkout';
import FoodMenu from './pages/FoodMenu';
import Home from './pages/Home';
import Login from './pages/Login';
import MyOrders from './pages/MyOrders';
import NotFound from './pages/NotFound';
import OrderConfirmation from './pages/OrderConfirmation';
import OrderTracking from './pages/OrderTracking';
import Profile from './pages/Profile';
import Register from './pages/Register';
import RestaurantDetails from './pages/RestaurantDetails';
import Restaurants from './pages/Restaurants';

import AdminDashboard from './pages/admin/AdminDashboard';
import AdminLogin from './pages/admin/AdminLogin';
import ManageCustomers from './pages/admin/ManageCustomers';
import ManageFoods from './pages/admin/ManageFoods';
import ManageOrders from './pages/admin/ManageOrders';
import ManageRestaurants from './pages/admin/ManageRestaurants';

export default function App() {
  return (
    <Routes>
      <Route path="/admin/login" element={<AdminLogin />} />

      <Route element={<ProtectedRoute role="admin" />}>
        <Route element={<AdminLayout />}>
          <Route path="/admin" element={<AdminDashboard />} />
          <Route path="/admin/restaurants" element={<ManageRestaurants />} />
          <Route path="/admin/foods" element={<ManageFoods />} />
          <Route path="/admin/orders" element={<ManageOrders />} />
          <Route path="/admin/customers" element={<ManageCustomers />} />
        </Route>
      </Route>

      <Route element={<CustomerLayout />}>
        <Route path="/" element={<Home />} />
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route path="/restaurants" element={<Restaurants />} />
        <Route path="/restaurants/:id" element={<RestaurantDetails />} />
        <Route path="/menu" element={<FoodMenu />} />

        <Route element={<ProtectedRoute role="customer" />}>
          <Route path="/cart" element={<Cart />} />
          <Route path="/checkout" element={<Checkout />} />
          <Route path="/order-confirmation/:id" element={<OrderConfirmation />} />
          <Route path="/orders" element={<MyOrders />} />
          <Route path="/orders/:id" element={<OrderTracking />} />
          <Route path="/profile" element={<Profile />} />
        </Route>

        <Route path="/home" element={<Navigate to="/" replace />} />
        <Route path="*" element={<NotFound />} />
      </Route>
    </Routes>
  );
}
