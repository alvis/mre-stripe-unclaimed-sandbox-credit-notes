# Stripe unclaimed sandbox: credit-note creation returns HTTP 403

Minimal reproduction: use the Stripe CLI to create an unclaimed sandbox, then
use Bash + curl to create and pay a **USD 10.00 test invoice** and request a full
credit note and refund. The payment succeeds, but
`POST /v1/credit_notes` returns **HTTP 403** with an unclaimed-sandbox key.

## Run

Requirements: Bash, curl, jq, and [Stripe CLI](https://docs.stripe.com/stripe-cli)
1.53.0 or later.

Clone this repository, then run:

```bash
bash reproduction.sh
```

The script creates a fresh unclaimed sandbox using the dummy email
`test@example.com` and captures its returned test key automatically. It uses a
temporary CLI profile directory to avoid reusing an existing sandbox or opening
Dashboard for an already logged-in CLI, then removes it. The key and claim URL
are not printed.

Each run leaves synthetic test objects in a new sandbox, which expires after
seven days. It prints the paid invoice summary, then the credit-note response
and HTTP status. Do not claim the sandbox: a regular test key or claimed sandbox
might not reproduce the same restriction.

## Reproduction steps

The Stripe CLI is used only to provision the sandbox. All invoice, payment, and
credit-note API requests use curl with API version `2026-09-30.endive`:

1. Create an unclaimed sandbox with the Stripe CLI and extract its returned key.
2. Create a dummy customer.
3. Create a card PaymentMethod using Stripe's `tok_visa` test token and attach it.
4. Create a draft invoice with that PaymentMethod and automatic advancement off.
5. Add a USD 10.00 invoice item, then finalize the invoice.
6. Pay the invoice.
7. Create a credit note with `invoice=<paid invoice>`, `amount=1000`,
   `refund_amount=1000`, `reason=order_change`, and `email_type=none`.

## Observed result

Tested on **2026-10-01** with an existing unclaimed sandbox's restricted test key:

- Customer, PaymentMethod, invoice creation, finalization, and payment: HTTP 200
- Credit-note creation: **HTTP 403**, `invalid_request_error`
- The error identifies a claimable sandbox key with limited permissions and says
  it does not have access to the endpoint until the sandbox is claimed and a full
  API key is obtained

The final curl request prints the Stripe response directly, followed by `HTTP 403`.
The automatic sandbox bootstrap was checked against CLI 1.53.0's output format
and offline fixtures; it has not been rerun against a newly provisioned sandbox.

The original run left the invoice paid, with no credit note or refund. All
objects were in test mode; no real money moved. This may be an intentional
unclaimed-sandbox limitation rather than a Stripe bug.

Separately, `refunded` is not an invoice status: a successful credit-note refund
does not change a paid invoice to `refunded`. Refund state is represented on the
credit note, refund, and charge objects.

## References

- [Unclaimed sandboxes](https://docs.stripe.com/cli/sandbox)
- [Create a credit note](https://docs.stripe.com/api/credit_notes/create)
- [Invoice status values](https://docs.stripe.com/api/invoices/object)
- [Test payments](https://docs.stripe.com/testing)
