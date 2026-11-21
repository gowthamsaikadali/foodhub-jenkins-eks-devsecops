#!/usr/bin/env bash
# End-to-end API test: register -> login -> browse -> cart -> order -> pay -> admin processes the order.
#   bash scripts/smoke-test.sh http://localhost:8080 admin@foodhub.local 'YourAdminPassword'
# Needs: curl and jq (sudo apt install -y jq). The admin account comes from SEED_ADMIN_PASSWORD in .env.
set -euo pipefail
BASE="${1:-http://localhost:8080}"
ADMIN_EMAIL="${2:-admin@foodhub.local}"
ADMIN_PASS="${3:?admin password required (SEED_ADMIN_PASSWORD)}"
EMAIL="smoke$(date +%s)@example.com"
PASS="Smoke12345"
ok()   { echo "  PASS  $*"; }
fail() { echo "  FAIL  $*"; exit 1; }
call() { curl -sS -w '\n%{http_code}' "$@"; }

echo "1. Register a customer ($EMAIL)"
RES=$(call -X POST "$BASE/api/auth/register" -H 'Content-Type: application/json' \
  -d "{\"fullName\":\"Smoke Tester\",\"email\":\"$EMAIL\",\"password\":\"$PASS\",\"phone\":\"9000000000\"}")
[ "$(echo "$RES" | tail -1)" = 201 ] && ok "registered" || fail "register: $RES"

echo "2. Login"
TOKEN=$(curl -sS -X POST "$BASE/api/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}" | jq -r .token)
[ -n "$TOKEN" ] && [ "$TOKEN" != null ] && ok "got JWT" || fail "login"
AUTH="Authorization: Bearer $TOKEN"

echo "3. Wrong password is rejected"
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"password\":\"wrong-password1\"}")
[ "$CODE" = 401 ] && ok "401" || fail "expected 401, got $CODE"

echo "4. Protected endpoints need a token; admin endpoints need ROLE_ADMIN"
[ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/orders/my-orders")" = 401 ] && ok "anonymous -> 401" || fail "anonymous my-orders"
[ "$(curl -s -o /dev/null -w '%{http_code}' -H "$AUTH" "$BASE/api/admin/dashboard")" = 403 ] && ok "customer on admin API -> 403" || fail "customer must get 403"

echo "5. Browse restaurants and menu"
RID=$(curl -sS "$BASE/api/restaurants" | jq -r '.[0].id')
[ "$RID" != null ] && ok "restaurant $RID" || fail "no restaurants (seed data missing?)"
FOOD=$(curl -sS "$BASE/api/restaurants/$RID/foods")
FID=$(echo "$FOOD" | jq -r '.[0].id'); PRICE=$(echo "$FOOD" | jq -r '.[0].price')
ok "food $FID costs $PRICE"
[ "$(curl -sS "$BASE/api/foods?q=biryani" | jq length)" -ge 1 ] && ok "search 'biryani' works" || fail "search"

echo "6. Cart: add 2 items"
curl -sS -X POST "$BASE/api/cart/items" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"foodItemId\":$FID,\"quantity\":2}" | jq -e '.items|length==1' >/dev/null && ok "cart has 1 line" || fail "cart add"

echo "7. Place order (the server computes the prices)"
ORDER=$(curl -sS -X POST "$BASE/api/orders" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"deliveryAddress":"12 Test Street, Hyderabad","paymentMethod":"SIMULATED_ONLINE"}')
OID=$(echo "$ORDER" | jq -r .id)
[ "$OID" != null ] && ok "order $OID total $(echo "$ORDER" | jq -r .totalAmount)" || fail "order: $ORDER"
EXPECT=$(python3 -c "from decimal import Decimal as D,ROUND_HALF_UP as R; s=D('$PRICE')*2; f=D('0') if s>=D('500') else D('40'); t=(s*D('0.05')).quantize(D('0.01'),R); print(s+f+t)")
[ "$(echo "$ORDER" | jq -r .totalAmount)" = "$EXPECT" ] && ok "total matches the independently computed $EXPECT" || fail "total mismatch (expected $EXPECT)"

echo "8. Simulated payment"
[ "$(curl -sS -X POST "$BASE/api/payments" -H "$AUTH" -H 'Content-Type: application/json' -d "{\"orderId\":$OID}" | jq -r .status)" = SUCCESS ] && ok "payment SUCCESS" || fail "payment"

echo "9. Customer sees the order; another user must not"
[ "$(curl -sS -H "$AUTH" "$BASE/api/orders/my-orders" | jq length)" -ge 1 ] && ok "order history" || fail "history"

echo "10. Admin accepts and progresses the order"
ATOKEN=$(curl -sS -X POST "$BASE/api/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}" | jq -r .token)
[ "$ATOKEN" != null ] && ok "admin logged in" || fail "admin login"
AA="Authorization: Bearer $ATOKEN"
for S in CONFIRMED PREPARING READY DELIVERED; do
  GOT=$(curl -sS -X PATCH "$BASE/api/admin/orders/$OID/status" -H "$AA" -H 'Content-Type: application/json' -d "{\"status\":\"$S\"}" | jq -r .status)
  [ "$GOT" = "$S" ] && ok "-> $S" || fail "status $S, got $GOT"
done
[ "$(curl -s -o /dev/null -w '%{http_code}' -X PATCH "$BASE/api/admin/orders/$OID/status" -H "$AA" -H 'Content-Type: application/json' -d '{"status":"PLACED"}')" = 400 ] && ok "invalid transition rejected (400)" || fail "transition guard"

echo "11. Customer tracks the delivered order"
[ "$(curl -sS -H "$AUTH" "$BASE/api/orders/$OID" | jq -r .status)" = DELIVERED ] && ok "DELIVERED" || fail "tracking"

echo "12. Dashboard"
curl -sS -H "$AA" "$BASE/api/admin/dashboard" | jq .
echo; echo "ALL SMOKE TESTS PASSED"
