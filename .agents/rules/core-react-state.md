---
trigger: model_decision
globs: "src/store/**/*.ts, src/hooks/**/*.ts, src/services/**/*.ts"
description: "Apply this when working on React state management (Zustand), custom hooks, API services, or data synchronization."
---

# React State, Hooks & Services Guidelines

## State Ownership & Separation of Concerns
- **Zustand Stores (`src/store/`):** Own cross-component and global application state. Avoid deep React Context provider trees for frequently changing state.
- **Custom Hooks (`src/hooks/`):** Own DOM observers, timers, media lifecycles, and event listeners. Always clean up listeners, timers, and `requestAnimationFrame` handles on unmount.
- **Pure Utilities (`src/utils/`):** Hold deterministic data transformations, formatting, and geometry math with zero React state dependencies.
- **Services (`src/services/`):** Encapsulate `fetch` / API calls and response parsing.

## Acceptance & Audit Criteria
1. Every `useEffect` registering an observer, listener, or timer returns a deterministic cleanup function.
2. Strict TypeScript interfaces are defined for all store slices, hook options, and return payloads (no `any`).