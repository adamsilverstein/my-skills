---
name: web-performance-tuner
description: "Diagnose and fix web performance issues. Use when analyzing site performance, checking Core Web Vitals, querying CrUX data, optimizing load times, or fixing LCP/CLS/INP issues. Triggers: 'improve performance', 'fix slow page', 'analyze web vitals', 'optimize site speed'."
---

# Web Performance Tuner

Diagnose, benchmark, and fix web performance issues with measurable validation.

## Workflow

1. **Analyze** - Identify issues via CrUX data, Lighthouse, Chrome DevTools, or user-provided specifics
2. **Setup** - Ensure local dev environment exists (ask user if unclear)
3. **Baseline** - Establish benchmarks before making changes
4. **Fix** - Make ONE granular change at a time
5. **Validate** - Rebuild, re-run benchmarks, compare to baseline
6. **Commit or Revert** - Only commit if measurable improvement; otherwise discard and move on
7. **Repeat** - Continue through prioritized issues until all top issues addressed

## Data Sources

**CrUX API** (real-user field data, if available for site):
```bash
curl "https://chromeuxreport.googleapis.com/v1/records:queryRecord?key=API_KEY" \
  -d '{"url": "https://example.com"}'
```

**Lighthouse** (local or remote):
```bash
npx lighthouse http://localhost:3000 --output=json --output-path=./baseline.json
```

**Chrome DevTools Performance Tab** - Use browser automation to capture traces and analyze runtime performance. Claude Code can control Chrome DevTools for automated profiling.

## Core Web Vitals Targets

| Metric | Good | Needs Work | Poor |
|--------|------|------------|------|
| LCP | ≤2.5s | ≤4.0s | >4.0s |
| INP | ≤200ms | ≤500ms | >500ms |
| CLS | ≤0.1 | ≤0.25 | >0.25 |

## Benchmarking Rules

- Run 3-5 times to account for variance; use median values
- Store baseline before any changes
- Document methodology in commit messages

## Fix Prioritization

1. Render-blocking resources
2. Large/unoptimized images
3. Excessive JavaScript
4. Layout shifts
5. Slow server response (TTFB)

## Important Rules

- **One change at a time** - Isolate each fix for accurate measurement
- **No improvement = no commit** - Discard changes that don't help
- **Be persistent** - Work through all identified issues systematically
