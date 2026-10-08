# 001 — Make motion calm, accessible, and cheap

- **Status**: DONE
- **Commit**: 2e2b242
- **Severity**: HIGH
- **Category**: Performance and accessibility
- **Estimated scope**: 4–6 files

## Problem

`app/lib/main.dart:79` puts an animated `AuroraBackground` under every route.
It repeats forever and composites a full-screen `BackdropFilter` at
`app/lib/core/widgets/backgrounds.dart:48-51,125-133`; it ignores the platform
motion preference. Loading shimmers have the same omission.

## Target

- Keep the app canvas still by default; use the aurora only where explicitly
  requested by a picture-free screen or sheet.
- Never put an animated, full-screen backdrop blur behind ordinary route
  content. Retain the static drawn bloom/pattern treatment where it is used.
- Derive `reduceMotion` from `MediaQuery.disableAnimationsOf(context)` or
  `MediaQuery.accessibleNavigationOf(context)`. When true: stop continuous
  controllers, remove transform/scale/panning, and retain only static colour
  and opacity states.
- Shimmers become a static skeleton under that policy.

## Boundaries

- Do not add packages or change API/data behaviour.
- Do not use `BackdropFilter` as a global wallpaper treatment.

## Verification

- Run `cd app && flutter analyze && flutter test`.
- On a physical device, scroll the feed and open/close a sheet: no permanent
  wallpaper animation or full-screen blur should be present behind it.
- Enable Reduce Motion in the OS and confirm wallpaper, shimmer, and looping
  typing movement stop while content remains visible.
