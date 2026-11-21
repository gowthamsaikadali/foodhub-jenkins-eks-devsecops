import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { authService } from '../services/authService';
import { TOKEN_KEY, USER_KEY } from '../services/api';

const AuthContext = createContext(null);

function readStoredUser() {
  try {
    return JSON.parse(localStorage.getItem(USER_KEY));
  } catch {
    return null;
  }
}

export function AuthProvider({ children }) {
  const [user, setUser] = useState(readStoredUser);

  const persist = useCallback((data) => {
    localStorage.setItem(TOKEN_KEY, data.token);
    localStorage.setItem(USER_KEY, JSON.stringify(data.user));
    setUser(data.user);
    return data.user;
  }, []);

  const logout = useCallback(() => {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    setUser(null);
  }, []);

  // The Axios interceptor fires this when the server rejects our token.
  useEffect(() => {
    window.addEventListener('foodhub:logout', logout);
    return () => window.removeEventListener('foodhub:logout', logout);
  }, [logout]);

  const login = useCallback(async (email, password) => persist(await authService.login(email, password)), [persist]);
  const register = useCallback(async (payload) => persist(await authService.register(payload)), [persist]);

  const updateUser = useCallback((u) => {
    localStorage.setItem(USER_KEY, JSON.stringify(u));
    setUser(u);
  }, []);

  const value = useMemo(
    () => ({
      user,
      isAuthenticated: Boolean(user),
      isAdmin: Boolean(user?.roles?.includes('ROLE_ADMIN')),
      login,
      register,
      logout,
      updateUser,
    }),
    [user, login, register, logout, updateUser],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export const useAuth = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>');
  return ctx;
};
