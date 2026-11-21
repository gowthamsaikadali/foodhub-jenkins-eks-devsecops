import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// In development, requests to /api are forwarded to the Spring Boot backend, which avoids CORS problems.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': { target: process.env.VITE_DEV_PROXY_TARGET || 'http://localhost:8080', changeOrigin: true },
    },
  },
  test: { environment: 'node' },
});
