# 003 — Normalize feedback and state transitions

- **Status**: DONE
- **Commit**: 2e2b242
- **Severity**: HIGH
- **Category**: Purpose, duration, and physicality
- **Estimated scope**: 8–10 files

## Problem

The trust dial uses `1500ms` plus `Curves.elasticOut`; matches/payments delay
each item by unbounded index multiples; frequent feedback is slower or more
theatrical than its purpose.

## Target

- Use only capped 30–80ms stagger steps; list animation must finish inside
  300ms after its final capped delay.
- Trust progress enters once with a calm decelerate curve, `250ms`, no bounce.
- Press down/up stays inside 100–160ms with transform scale no lower than 0.97.
- Routine status changes use a short opacity/colour transition; add restrained
  gallery image, unread-notification, and deal-state handoffs.
- Keep splash/onboarding delight rare and under user control; do not hold the
  splash merely for decorative motion.

## Verification

- Run `cd app && flutter analyze && flutter test`.
- Slow-motion check a long matches/payments list: late items never wait more
  than the capped delay; trust does not overshoot; gallery, notification, and
  deal changes do not teleport.
