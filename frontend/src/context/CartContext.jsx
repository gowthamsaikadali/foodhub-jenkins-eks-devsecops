import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { cartService } from '../services/cartService';
import { useAuth } from './AuthContext';

const CartContext = createContext(null);
const EMPTY = { restaurantId: null, restaurantName: null, items: [], subtotal: 0 };

/** The cart lives on the server (so it follows the user across devices). This context just mirrors it. */
export function CartProvider({ children }) {
  const { isAuthenticated, isAdmin } = useAuth();
  const [cart, setCart] = useState(EMPTY);
  const [loading, setLoading] = useState(false);

  const refresh = useCallback(async () => {
    if (!isAuthenticated || isAdmin) {
      setCart(EMPTY);
      return;
    }
    setLoading(true);
    try {
      setCart(await cartService.get());
    } catch {
      setCart(EMPTY);
    } finally {
      setLoading(false);
    }
  }, [isAuthenticated, isAdmin]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const run = useCallback(async (fn) => {
    const next = await fn();
    setCart(next);
    return next;
  }, []);

  const value = useMemo(
    () => ({
      cart,
      loading,
      count: cart.items.reduce((n, i) => n + i.quantity, 0),
      refresh,
      add: (foodId, qty = 1) => run(() => cartService.add(foodId, qty)),
      setQuantity: (foodId, qty) => run(() => cartService.setQuantity(foodId, qty)),
      remove: (foodId) => run(() => cartService.remove(foodId)),
      clear: () => run(() => cartService.clear()),
    }),
    [cart, loading, refresh, run],
  );

  return <CartContext.Provider value={value}>{children}</CartContext.Provider>;
}

export const useCart = () => {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error('useCart must be used inside <CartProvider>');
  return ctx;
};
