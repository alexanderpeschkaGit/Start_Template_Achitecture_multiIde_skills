---
trigger: model_decision
globs: "src/**/*.tsx, src/**/*.css"
description: "Apply this when working on UI layout, components, modals, animations, responsive styling, or Tailwind CSS."
---

# UI & Styling Guidelines

## Styling & Animation Defaults
- **Tailwind CSS First:** Use Tailwind utility classes as the default styling mechanism. Reserve global CSS for keyframes, scrollbars, View Transitions, and pseudo-elements.
- **Animations:** Use `motion/react` for interactive component animations and layout transitions.
- **Icons:** Use `lucide-react`.
- **Viewport & Input:** Use dynamic viewport units (`dvh`) for fullscreen layouts. Never infer touch vs. mouse solely from viewport width; combine `@media (hover: hover)` with Pointer Event `pointerType`.

## Acceptance & Audit Criteria
1. No hardcoded brand strings or inline magic hex values that belong in `SITE_CONFIG` / theme tokens.
2. Animations import from `motion/react` (not legacy `framer-motion`).
3. Component files stay below the 300-line warning threshold (and strictly below the 500-line decomposition limit).