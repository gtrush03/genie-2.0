# Stripe — Creating Payment Links and Invoices

George has a Stripe account connected (TEST MODE keys in `.env` as `STRIPE_SECRET_KEY` / `STRIPE_API_KEY`). When a wish asks for a payment link, invoice, or checkout ("Genie, send X a $500 invoice", "Genie, make me a payment link for a consulting call"), use the Stripe CLI — it's installed at `/opt/homebrew/bin/stripe`.

## Auth

Export the env var once per run before calling stripe:
```bash
# STRIPE_SECRET_KEY is already in your env from .env
export STRIPE_API_KEY="$STRIPE_SECRET_KEY"
```

## Create a payment link (3 steps: product → price → payment_link)

```bash
PROD=$(stripe products create -d name="Consulting Call — George" 2>/dev/null | python3 -c "import json,sys;print(json.load(sys.stdin)['id'])")
PRICE=$(stripe prices create -d product="$PROD" -d unit_amount=50000 -d currency=usd 2>/dev/null | python3 -c "import json,sys;print(json.load(sys.stdin)['id'])")
LINK=$(stripe payment_links create -d "line_items[0][price]=$PRICE" -d "line_items[0][quantity]=1" 2>/dev/null | python3 -c "import json,sys;print(json.load(sys.stdin)['url'])")
echo "$LINK"
```

`unit_amount` is in **cents** — $500 = `50000`. Always use `usd` unless the wish specifies another currency.

## Create an invoice (only if the wish names a recipient)

```bash
CUST=$(stripe customers create -d name="Jane Doe" -d email="jane@example.com" | python3 -c "import json,sys;print(json.load(sys.stdin)['id'])")
stripe invoice_items create -d customer="$CUST" -d amount=50000 -d currency=usd -d description="Consulting — 1 hour"
INV=$(stripe invoices create -d customer="$CUST" -d collection_method=send_invoice -d days_until_due=7 | python3 -c "import json,sys;print(json.load(sys.stdin)['id'])")
stripe invoices finalize "$INV"
stripe invoices send "$INV"
stripe invoices retrieve "$INV" | python3 -c "import json,sys;print(json.load(sys.stdin)['hosted_invoice_url'])"
```

## Reporting

Telegram the short URL (`https://buy.stripe.com/test_...` or `hosted_invoice_url`), the amount, and the description. If it's a payment link you can also paste it into a tweet/DM when the wish asks for that.

## Test vs live mode

The keys currently in `.env` are `sk_test_` — links start with `https://buy.stripe.com/test_...` and only accept test cards (e.g. `4242 4242 4242 4242`). That's fine — George knows. Don't refuse because it's test mode.
