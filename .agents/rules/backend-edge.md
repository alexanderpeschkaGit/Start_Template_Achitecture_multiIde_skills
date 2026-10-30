---
trigger: model_decision
globs: "server/**/*.ts, functions/**/*.ts, wrangler.toml"
description: "Apply this when working on backend API routes, Cloudflare Pages/Workers, storage integrations, or edge functions."
---

# Backend & Edge Architecture Guidelines

## Runtime & Security Invariants
- **Edge Compatibility:** Keep shared API routes compatible with both local Node development and edge runtimes (Cloudflare Workers/Pages Functions). Avoid Node-only filesystem APIs inside edge handlers.
- **Secret Hygiene:** Never expose server-side API keys or storage credentials to client bundles (`VITE_*` is strictly for public client configuration).
- **Structured Errors:** Return consistent JSON payloads (`{ error: string, details?: unknown }`) with explicit HTTP status codes.

## Acceptance & Audit Criteria
1. No server secrets are referenced via `import.meta.env.VITE_*`.
2. Edge bundle verification passes cleanly without unresolved Node built-ins.