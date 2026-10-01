#!/usr/bin/env bash

stripe_config=$(mktemp -d)
STRIPE_TEST_SECRET_KEY=$(STRIPE_API_KEY= XDG_CONFIG_HOME="$stripe_config" \
  stripe sandbox create --email test@example.com --non-interactive | \
  jq -Rsr 'match("(?s)\\{.*\\}").string | fromjson | .secret_key')
rm -r "$stripe_config"
API_VERSION='2026-09-30.endive'

customer=$(curl -sS https://api.stripe.com/v1/customers \
  -u "$STRIPE_TEST_SECRET_KEY:" -H "Stripe-Version: $API_VERSION" \
  -d 'name=Dummy Credit Note Customer' | jq -r '.id')

payment_method=$(curl -sS https://api.stripe.com/v1/payment_methods \
  -u "$STRIPE_TEST_SECRET_KEY:" -H "Stripe-Version: $API_VERSION" \
  -d 'type=card' -d 'card[token]=tok_visa' | jq -r '.id')
curl -sS "https://api.stripe.com/v1/payment_methods/$payment_method/attach" \
  -u "$STRIPE_TEST_SECRET_KEY:" -H "Stripe-Version: $API_VERSION" \
  -d "customer=$customer" >/dev/null

invoice=$(curl -sS https://api.stripe.com/v1/invoices \
  -u "$STRIPE_TEST_SECRET_KEY:" -H "Stripe-Version: $API_VERSION" \
  -d "customer=$customer" \
  -d 'collection_method=charge_automatically' \
  -d 'auto_advance=false' \
  -d "default_payment_method=$payment_method" \
  -d 'payment_settings[payment_method_types][0]=card' | jq -r '.id')
curl -sS https://api.stripe.com/v1/invoiceitems \
  -u "$STRIPE_TEST_SECRET_KEY:" -H "Stripe-Version: $API_VERSION" \
  -d "customer=$customer" -d "invoice=$invoice" \
  -d 'currency=usd' -d 'amount=1000' \
  -d 'description=Synthetic test service' >/dev/null
curl -sS "https://api.stripe.com/v1/invoices/$invoice/finalize" \
  -u "$STRIPE_TEST_SECRET_KEY:" -H "Stripe-Version: $API_VERSION" \
  -d 'auto_advance=false' >/dev/null
curl -sS "https://api.stripe.com/v1/invoices/$invoice/pay" \
  -u "$STRIPE_TEST_SECRET_KEY:" -H "Stripe-Version: $API_VERSION" \
  -d "payment_method=$payment_method" | jq '{id, status, amount_paid}'

# Returns HTTP 403 with the observed unclaimed-sandbox key.
curl -sS https://api.stripe.com/v1/credit_notes \
  -u "$STRIPE_TEST_SECRET_KEY:" -H "Stripe-Version: $API_VERSION" \
  -d "invoice=$invoice" \
  -d 'amount=1000' \
  -d 'refund_amount=1000' \
  -d 'reason=order_change' \
  -d 'email_type=none' \
  -w '\nHTTP %{http_code}\n'
