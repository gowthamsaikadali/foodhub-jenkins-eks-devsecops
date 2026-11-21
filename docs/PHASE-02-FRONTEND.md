# PHASE 2: React Frontend

Cost: **free**. Needs Node.js 20.

---

### A. What are we doing?
Running, testing and understanding the React single-page application: 12 customer pages and 6 admin pages (login, dashboard, restaurants, foods, orders, customers), routing, login handling, a cart, forms with validation, loading and error states.

### B. Why are we doing it?
This is Tier 1 (presentation). Every user action becomes an HTTP call to the backend. Understanding how the browser stores the login token, protects routes and reports errors is a common interview topic.

### C. How does it work?
* **Vite** compiles the JSX into plain JavaScript/CSS (`npm run build` produces `dist/`). In development `npm run dev` serves it on port 5173 with hot reload and **forwards `/api/*` to `http://localhost:8080`** (see `vite.config.js`), so there are no CORS problems.
* **React Router** maps URLs to pages (`src/App.jsx`). `ProtectedRoute` guards groups of pages by role.
* **Axios** is configured once in `src/services/api.js`: it adds `Authorization: Bearer <token>` to every request and, if the server answers 401, clears the login and sends the user to login.
* **Context providers** hold shared state: `AuthContext` (who is logged in), `CartContext` (mirror of the server-side cart), `ToastContext` (popup messages).
* **The cart lives on the server**, so it follows the user between devices; the frontend only mirrors it.
* **The frontend never sends prices.** Checkout sends only address, notes and payment method; the backend reads the cart and computes totals.
* In production the same build is served by Nginx and the browser calls `/api` on the same host, so `VITE_API_URL=/api` is used everywhere.

### D. Where should I execute it?
**Windows local machine** (WSL2 Ubuntu terminal recommended).

### E. Which directory should I be in?
```bash
cd foodhub-devsecops/frontend
```

### F. Which file should I create?
None: all files exist. This is the map of what you will read:

| Path | Purpose |
|---|---|
| `package.json` | Dependencies (react, react-router-dom, axios) and scripts |
| `vite.config.js`, `index.html` | Build tool config and the single HTML page |
| `src/main.jsx` | Starts React and wraps the app in the providers |
| `src/App.jsx` | The route table |
| `src/services/*.js` | One file per API area: auth, catalog, cart, orders, admin |
| `src/context/*.jsx` | Auth, cart, toast state |
| `src/components/*.jsx` | Navbar, cards, guards, form field, loader, error box, status badge |
| `src/layouts/*.jsx` | `CustomerLayout` (navbar + footer) and `AdminLayout` (sidebar) |
| `src/pages/*.jsx` | Customer pages: Home, Login, Register, Restaurants, RestaurantDetails, FoodMenu, Cart, Checkout, OrderConfirmation, MyOrders, OrderTracking, Profile |
| `src/pages/admin/*.jsx` | AdminLogin, AdminDashboard, ManageRestaurants, ManageFoods, ManageOrders, ManageCustomers |
| `src/utils/validators.js` | Form validation helpers (with unit tests) |
| `src/styles/main.css` | Responsive styling (mobile menu under 720px, admin sidebar collapses under 860px) |

### G. Complete code
Every file is complete in the zip at the paths above. Do not retype them; open them in VS Code.

### H. Explain the code
Read these four files first; they explain the whole app.

**`src/services/api.js`**
* `axios.create({ baseURL: import.meta.env.VITE_API_URL || '/api', timeout: 15000 })`: every call goes to `/api/...`; after 15 seconds it gives up instead of hanging.
* Request interceptor: reads the token from `localStorage` and adds the `Authorization` header.
* Response interceptor: on 401 with a stored token, removes it and fires a `foodhub:logout` event that `AuthContext` listens to.
* `getErrorMessage(error)`: converts any failure into a readable sentence (server message, field errors, timeout, or "Cannot reach the server").

**`src/context/AuthContext.jsx`**: stores `{token, user}` in `localStorage`, exposes `login`, `register`, `logout`, `isAdmin`. Note for interviews: `localStorage` is simple but readable by any script injected through XSS; the safer alternative is an HttpOnly cookie plus CSRF protection. We keep `localStorage` for clarity, and mitigate XSS by never rendering raw HTML (React escapes text) and by sending security headers from Nginx.

**`src/components/ProtectedRoute.jsx`**: not logged in goes to login; a customer opening `/admin` is sent home; an admin opening customer pages is sent to `/admin`. This only hides screens. **Real security is in the backend**, which re-checks every request.

**`src/pages/Checkout.jsx`**: validates the address, calls `POST /api/orders` with `{deliveryAddress, notes, paymentMethod}`, then (for simulated online payment) `POST /api/payments`, refreshes the cart and navigates to the confirmation page.

Other ideas worth knowing:
* `hooks/useFetch.js` wraps "load data, show spinner, show error with Retry" so each page stays short.
* `OrderTracking` polls every 10 seconds until the order is delivered/cancelled/rejected.
* `ManageOrders` (admin) refreshes every 15 seconds and only shows buttons for the **allowed next statuses** that the backend returns (`nextStatuses`), so the UI cannot offer an illegal transition.

### I. Execute commands
```bash
npm ci
```
```bash
npm test
```
```bash
npm run build
```
```bash
npm run dev
```
(`npm ci` installs exactly the versions in `package-lock.json`. Use `npm install` only when you add a package.)

### J. Expected output
Real output captured when the project was generated:

`npm test`:
```
 ✓ src/utils/validators.test.js (4 tests)
 Test Files  1 passed (1)
      Tests  4 passed (4)
```
`npm run build`:
```
✓ 136 modules transformed.
dist/index.html                   0.55 kB
dist/assets/index-<hash>.css      8.60 kB
dist/assets/index-<hash>.js     273.38 kB | gzip: 87.53 kB
✓ built in ~1.5s
```
`npm run dev` prints `Local: http://localhost:5173/`.

### K. Verification
Open http://localhost:5173 in your browser. **The backend is not running yet**, so you should see:
1. The page layout, navbar and hero search box (UI works).
2. A red banner "Cannot reach the server..." with a **Retry** button on the Home page (this proves error handling works).
3. `/login` and `/register`: submit empty forms and see inline validation messages without any network call.
4. Open `/cart` while logged out: you are redirected to `/login`.
5. Open `/admin`: redirected to `/admin/login`.
6. Resize the window below 720px: the navbar turns into a hamburger menu.

The full flow is verified in Phase 4/5 once the backend exists.

### L. Troubleshooting
| Error | Cause and fix |
|---|---|
| `npm ERR! code EACCES` | Do not use `sudo npm`. Fix folder ownership or use `nvm`. |
| `Error: Cannot find module` after pulling changes | Run `npm ci` again. |
| Port 5173 in use | Stop the other dev server or run `npm run dev -- --port 5174`. |
| Blank page | Open the browser console (F12). A red error names the file and line. |
| `ECONNREFUSED 127.0.0.1:8080` in the terminal | Expected until the backend runs (Phase 3/4). |

### M. Completion checklist
- [ ] `npm test` passes (4 tests).
- [ ] `npm run build` succeeds.
- [ ] `npm run dev` shows the UI and the "Cannot reach the server" banner with Retry.
- [ ] I can explain what the Axios interceptors do and why prices are never sent by the frontend.
- [ ] I know why `ProtectedRoute` is a convenience and the backend is the real gate.
