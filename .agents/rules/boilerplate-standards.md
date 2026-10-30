---
trigger: model_decision
globs: "src/components/**/*.tsx, src/hooks/**/*.ts, src/config/siteConfig.ts, .agents/rules/*.md"
description: "Apply this when authoring .agents rules, updating white-label SITE_CONFIG settings, or scaffolding React components and custom hooks."
---

# Boilerplate Standards & Rule Authoring

## 1. Meta-Rule Authoring Standards (for `.agents/rules/*.md`)
1. **Progressive Disclosure Frontmatter:** Every rule in `.agents/rules/` MUST start with YAML frontmatter using `trigger: model_decision`, explicit `globs: "..."`, and a 1-sentence `description: "Apply this when..."`.
2. **Strict Token Budget (< 300 Lines):** Keep each rule file concise and domain-focused.
3. **Falsifiable Audit Checklist:** End every rule file with 2â€“5 concrete, verifiable audit criteria.

## 2. White-Label Configuration SSOT (`src/config/siteConfig.ts`)
- Keep all brand identity, navigation categories, contact links, CDN endpoints, and SEO defaults in `SITE_CONFIG`.

## Acceptance & Audit Criteria
1. Every `.agents/rules/*.md` file has valid `trigger: model_decision` frontmatter and is listed in `AGENTS.md`.
2. New components consume brand/config values from `SITE_CONFIG` rather than hardcoding strings.