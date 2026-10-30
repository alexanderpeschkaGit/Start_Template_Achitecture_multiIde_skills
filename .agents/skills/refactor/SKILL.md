---
name: refactor
description: Improve structure and maintainability without intentionally changing observable behavior. Triggered when the user uses the #refactor tag or /refactor command.
---

# Behavior-Preserving Refactor Skill (`#refactor`)

1. **100% Behavior Parity:** Preserve all existing props, public types, side effects, and user-visible behavior.
2. **Modular Extraction:** Extract cross-component state to `src/store/`, lifecycle/observers to `src/hooks/`, pure logic to `src/utils/`, and leaf UI to `src/components/`.
3. **Verification:** Run `npm run lint` and `npm test` to verify zero regressions.