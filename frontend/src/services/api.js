import axios from 'axios';

export const TOKEN_KEY = 'foodhub_token';
export const USER_KEY = 'foodhub_user';

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '/api',
  timeout: 15000,
  headers: { 'Content-Type': 'application/json' },
});

// Attach the JWT to every request.
api.interceptors.request.use((config) => {
  const token = localStorage.getItem(TOKEN_KEY);
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// If the server says our token is invalid/expired, log out everywhere.
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401 && localStorage.getItem(TOKEN_KEY)) {
      localStorage.removeItem(TOKEN_KEY);
      localStorage.removeItem(USER_KEY);
      window.dispatchEvent(new Event('foodhub:logout'));
    }
    return Promise.reject(error);
  },
);

/** Turns any Axios error into a short message a user can read. */
export function getErrorMessage(error) {
  if (error.response) {
    const data = error.response.data;
    if (data?.fieldErrors && Object.keys(data.fieldErrors).length) {
      return Object.entries(data.fieldErrors).map(([f, m]) => `${f}: ${m}`).join(' | ');
    }
    return data?.message || `Request failed (${error.response.status})`;
  }
  if (error.code === 'ECONNABORTED') return 'The server took too long to respond.';
  return 'Cannot reach the server. Check your connection.';
}

export default api;
