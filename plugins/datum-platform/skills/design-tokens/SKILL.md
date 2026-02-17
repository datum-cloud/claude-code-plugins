---
name: design-tokens
description: Covers the design token architecture for Datum Cloud UIs including colors, spacing, typography, and theme support. Use when implementing UI components to ensure visual consistency.
---

# Design Tokens

This skill covers the design token architecture for Datum Cloud UIs.

## Overview

Design tokens are the visual design atoms — colors, spacing, typography. They ensure consistency across all UIs.

## Token Categories

### Colors

Semantic color tokens:

```css
/* Surfaces */
--color-surface-primary: /* main background */
--color-surface-secondary: /* card backgrounds */
--color-surface-elevated: /* modals, dropdowns */

/* Text */
--color-text-primary: /* main text */
--color-text-secondary: /* subdued text */
--color-text-disabled: /* disabled state */

/* Status */
--color-status-success: /* success states */
--color-status-warning: /* warning states */
--color-status-error: /* error states */
--color-status-info: /* info states */

/* Interactive */
--color-interactive-primary: /* buttons, links */
--color-interactive-hover: /* hover state */
--color-interactive-active: /* active state */
```

### Spacing

Consistent spacing scale:

```css
--space-1: 4px;
--space-2: 8px;
--space-3: 12px;
--space-4: 16px;
--space-6: 24px;
--space-8: 32px;
--space-12: 48px;
--space-16: 64px;
```

### Typography

```css
/* Font families */
--font-sans: 'Inter', system-ui, sans-serif;
--font-mono: 'JetBrains Mono', monospace;

/* Font sizes */
--text-xs: 0.75rem;
--text-sm: 0.875rem;
--text-base: 1rem;
--text-lg: 1.125rem;
--text-xl: 1.25rem;
--text-2xl: 1.5rem;

/* Font weights */
--font-normal: 400;
--font-medium: 500;
--font-semibold: 600;
--font-bold: 700;
```

### Borders & Radius

```css
--radius-sm: 4px;
--radius-md: 8px;
--radius-lg: 12px;
--radius-full: 9999px;

--border-width: 1px;
--border-color: var(--color-border-default);
```

## Usage

### In Tailwind

```tsx
<div className="bg-surface-primary text-text-primary p-4 rounded-md">
  Content
</div>
```

### In CSS

```css
.card {
  background: var(--color-surface-secondary);
  padding: var(--space-4);
  border-radius: var(--radius-md);
}
```

## Theme Support

Tokens support light and dark themes:

```css
:root {
  --color-surface-primary: #ffffff;
  --color-text-primary: #1a1a1a;
}

[data-theme="dark"] {
  --color-surface-primary: #1a1a1a;
  --color-text-primary: #ffffff;
}
```

## Related Files

- `pattern-registry.md` — UI pattern documentation
