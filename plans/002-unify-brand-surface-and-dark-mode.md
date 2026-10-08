# 002 — Unify the visual language and dark mode

- **Status**: DONE
- **Commit**: 2e2b242
- **Severity**: HIGH
- **Category**: Cohesion and visual hierarchy
- **Estimated scope**: 4–6 files

## Problem

The documented give-to-take brand gradient is teal-to-teal in
`app/lib/core/theme/app_theme.dart:67-72`. The central create action hard-codes
the light canvas and white highlight in `app/lib/core/router/app_shell.dart`.
Clay, glass, and neumorphic elevation are concurrently used for ordinary cards.

## Target

- Restore a restrained green/teal-to-blue `swapGradient` whose end uses the
  semantic `take` hue.
- Make the central create action derive every fill, rim, and shadow from the
  active `BarterPalette`; it must be dark-surface coherent in dark mode.
- Retain glass only for navigation/chrome, use Material tonal surfaces for
  content cards, and remove clay/neomorphic decoration from routine feed and
  detail cards without changing their layout or actions.
- Restore the documented 20px card radius while leaving input/button radii at
  16px.

## Verification

- Run `cd app && flutter analyze && flutter test`.
- Check feed, detail, chat, profile, and centre create action in light/dark:
  no white rim/canvas appears in dark mode, cards sit quietly, and create is
  the only clearly elevated primary action.
