# Uber Eats Skills for Claurst

These are **Claurst skills** — markdown instruction files that Claurst auto-discovers at `~/.claurst/skills/`. They teach Claurst how to navigate and order from Uber Eats via the Playwright MCP browser automation server.

## Skills included

| Skill | Purpose |
|-------|---------|
| `ubereats-order` | Full end-to-end ordering flow: parse wish, search, add to cart, checkout, pay, confirm |
| `ubereats-search` | Search the Uber Eats top bar for stores, restaurants, or products (handles the overlay quirk) |
| `ubereats-add-to-cart` | Add items to cart from a store page: find product, handle modals, adjust quantity, substitutions |
| `ubereats-checkout` | Navigate from cart to the checkout page, verify address/payment/tip, screenshot before paying |
| `ubereats-pay` | Click "Place Order", handle confirmations/CAPTCHAs, capture order confirmation and receipt |

## How they work together

`ubereats-order` is the top-level orchestrator. It calls the other four as sub-skills in sequence:

```
ubereats-order
  -> ubereats-search      (find the right store)
  -> ubereats-add-to-cart  (add each item)
  -> ubereats-checkout     (review and prepare)
  -> ubereats-pay          (place the order)
```

## Installation

### Automatic (via setup.sh)

The repo's `setup.sh` script copies these skills into the Claurst skills directory:

```bash
./setup.sh
```

### Manual

```bash
cp -r skills/ubereats-* ~/.claurst/skills/
```

Each skill directory contains a single `SKILL.md` file that Claurst reads when the skill is invoked.

## Prerequisites

- Claurst installed and configured
- Playwright MCP server connected to a persistent Chrome instance (CDP)
- The Chrome instance must be logged into Uber Eats with a saved delivery address and payment method
- Telegram bot configured for order status reporting (optional but expected by the skills)
