# Web Design System — Genie 2.0

You are building websites that must be genuinely beautiful. Not "decent for AI-generated." Beautiful enough that a designer would share the link. This document is your design bible. Follow it exactly.

---

## Typography

### Font Selection
- **Maximum 2 fonts.** One for headings, one for body. Never three.
- Load via Google Fonts `<link>` in `<head>`. No local files, no system font stacks for display type.

### Proven Pairings (pick ONE pair)
| Headings | Body | Vibe |
|----------|------|------|
| **Inter** | Inter | Clean, technical, startup |
| **Montserrat** | Source Sans 3 | Bold, modern, confident |
| **Poppins** | Inter | Friendly, approachable, SaaS |
| **Space Grotesk** | Inter | Techy, futuristic, dev tools |
| **Playfair Display** | Source Sans 3 | Elegant, editorial, luxury |
| **Sora** | DM Sans | Contemporary, geometric, Web3 |
| **Cabinet Grotesk** (self-host) | Inter | Premium, design-forward |
| **Manrope** | Inter | Minimal, UI-focused |

### Size Scale (use clamp for fluid sizing)
```css
:root {
  --text-xs:   clamp(0.75rem, 0.7rem + 0.25vw, 0.875rem);   /* 12-14px */
  --text-sm:   clamp(0.875rem, 0.8rem + 0.35vw, 1rem);      /* 14-16px */
  --text-base: clamp(1rem, 0.9rem + 0.5vw, 1.125rem);       /* 16-18px */
  --text-lg:   clamp(1.125rem, 1rem + 0.6vw, 1.35rem);      /* 18-21px */
  --text-xl:   clamp(1.25rem, 1rem + 1.2vw, 1.75rem);       /* 20-28px */
  --text-2xl:  clamp(1.75rem, 1.2rem + 2.5vw, 2.75rem);     /* 28-44px */
  --text-3xl:  clamp(2.25rem, 1.5rem + 3.5vw, 3.75rem);     /* 36-60px */
  --text-hero: clamp(2.75rem, 1.5rem + 5.5vw, 5.5rem);      /* 44-88px */
}
```

### Line Height & Spacing
- **Headings:** `line-height: 1.1` to `1.2` (tight)
- **Body text:** `line-height: 1.6` to `1.75` (generous — dark backgrounds need more breathing room)
- **Letter-spacing on headings:** `-0.02em` to `-0.03em` (tighten large type)
- **Letter-spacing on small caps / labels:** `0.05em` to `0.1em` (widen)
- **Max paragraph width:** `65ch` (optimal reading length)

### Text Rendering
```css
body {
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-rendering: optimizeLegibility;
}
```

---

## Color

### Dark Mode Palette Construction
Dark mode is the default. Every site you build uses a dark palette unless the wish explicitly says "light" or "bright."

**Base grays (pick a tint family and stick with it):**
```css
:root {
  /* Neutral (cool gray) */
  --bg-primary:    #0A0A0B;   /* Page background — near-black, not pure #000 */
  --bg-secondary:  #111114;   /* Card/section background */
  --bg-tertiary:   #1A1A1F;   /* Elevated surfaces, hover states */
  --bg-glass:      rgba(255, 255, 255, 0.03);  /* Glass panel fill */
  --border-subtle: rgba(255, 255, 255, 0.06);  /* Dividers, card borders */
  --border-medium: rgba(255, 255, 255, 0.10);  /* More prominent borders */

  /* Text hierarchy — never use pure #FFFFFF for body text */
  --text-primary:   rgba(255, 255, 255, 0.92);  /* Headings */
  --text-secondary: rgba(255, 255, 255, 0.64);  /* Body, descriptions */
  --text-tertiary:  rgba(255, 255, 255, 0.40);  /* Captions, metadata */
}
```

### Accent Colors
Choose ONE accent color. Use it sparingly: CTAs, links, key highlights, gradient anchors. Never more than 15% of the visible surface.

| Accent | Hex | Use case |
|--------|-----|----------|
| Electric blue | `#3B82F6` | Tech, SaaS, developer tools |
| Violet | `#8B5CF6` | AI, creative, premium |
| Emerald | `#10B981` | Finance, health, sustainability |
| Amber/Gold | `#F59E0B` | Luxury, warmth, crypto |
| Rose | `#F43F5E` | Social, entertainment, bold |
| Cyan | `#06B6D4` | Data, analytics, futuristic |

### Gradient Techniques
```css
/* Text gradient — use on hero headings */
.gradient-text {
  background: linear-gradient(135deg, #fff 0%, var(--accent) 50%, #fff 100%);
  /* OR for a bolder look: */
  background: linear-gradient(135deg, var(--accent) 0%, #c084fc 50%, #f472b6 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

/* Ambient glow — place behind hero content */
.ambient-glow {
  position: absolute;
  width: 600px;
  height: 600px;
  background: radial-gradient(circle, var(--accent) 0%, transparent 70%);
  opacity: 0.15;
  filter: blur(120px);
  pointer-events: none;
  z-index: 0;
}

/* Section divider gradient */
.section-divider {
  height: 1px;
  background: linear-gradient(90deg, transparent, var(--border-medium), transparent);
}
```

### Contrast Rules
- **Body text on dark bg:** minimum contrast ratio 4.5:1 (WCAG AA)
- **Large headings (24px+):** minimum 3:1
- **Never** put colored text on colored backgrounds without checking contrast
- **Never** use `opacity` below 0.6 on readable text

---

## Spacing

### The 8px Grid
All spacing values must be multiples of 8px: `8, 16, 24, 32, 48, 64, 80, 96, 120, 160`.

```css
:root {
  --space-1:  0.25rem;  /* 4px — rare, icon gaps only */
  --space-2:  0.5rem;   /* 8px */
  --space-3:  0.75rem;  /* 12px */
  --space-4:  1rem;     /* 16px */
  --space-6:  1.5rem;   /* 24px */
  --space-8:  2rem;     /* 32px */
  --space-12: 3rem;     /* 48px */
  --space-16: 4rem;     /* 64px */
  --space-20: 5rem;     /* 80px */
  --space-24: 6rem;     /* 96px */
  --space-32: 8rem;     /* 128px */
}
```

### Section Spacing
- **Between major sections:** `padding: 80px 0` minimum, `120px 0` preferred on desktop
- **Content max-width:** `1200px` with `margin: 0 auto`
- **Content padding (mobile):** `padding: 0 24px` minimum
- **Between heading and paragraph:** `16px` to `24px`
- **Between cards in a grid:** `24px` gap

---

## Layout

### Page Structure
```css
.container {
  width: 100%;
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 clamp(1.5rem, 4vw, 3rem);
}
```

### CSS Grid Patterns
```css
/* 3-column feature grid */
.feature-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
  gap: 24px;
}

/* 2-column with sticky sidebar */
.content-layout {
  display: grid;
  grid-template-columns: 1fr 380px;
  gap: 48px;
  align-items: start;
}

/* Asymmetric hero (60/40 split) */
.hero-split {
  display: grid;
  grid-template-columns: 1.4fr 1fr;
  gap: 64px;
  align-items: center;
  min-height: 100vh;
}
```

### Full-Bleed Sections
Some sections should break out of the container and span the full viewport width (hero, image showcases, testimonial bands):
```css
.full-bleed {
  width: 100vw;
  margin-left: calc(-50vw + 50%);
}
```

---

## Hero Sections

The hero is the first thing anyone sees. It must be exceptional.

### Requirements
- **Height:** `min-height: 100vh` or `min-height: 100svh` (use svh for mobile accuracy)
- **Content:** One headline, one supporting sentence (max 2 lines), one CTA button, optionally one visual
- **Visual weight:** The headline should be the largest text on the entire page
- **Background:** Never flat. Use ambient gradient glows, mesh gradients, subtle grid patterns, or a real image with dark overlay

### Hero Pattern
```html
<section class="hero">
  <div class="hero-glow"></div>
  <div class="container hero-content">
    <span class="hero-tag">Tagline or category</span>
    <h1 class="hero-title">The Big Bold<br><span class="gradient-text">Statement</span></h1>
    <p class="hero-subtitle">One or two lines of supporting copy that explains the value.</p>
    <div class="hero-actions">
      <a href="#" class="btn btn-primary">Get Started</a>
      <a href="#" class="btn btn-ghost">Learn More</a>
    </div>
  </div>
</section>
```

### CTA Buttons
```css
.btn-primary {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 14px 32px;
  background: var(--accent);
  color: #fff;
  font-weight: 600;
  font-size: var(--text-base);
  border-radius: 12px;
  border: none;
  cursor: pointer;
  transition: all 0.2s ease;
  text-decoration: none;
}
.btn-primary:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(var(--accent-rgb), 0.3);
}
.btn-ghost {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 14px 32px;
  background: transparent;
  color: var(--text-secondary);
  font-weight: 500;
  font-size: var(--text-base);
  border: 1px solid var(--border-medium);
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.2s ease;
  text-decoration: none;
}
.btn-ghost:hover {
  border-color: var(--text-tertiary);
  color: var(--text-primary);
  background: var(--bg-glass);
}
```

---

## Cards & Panels

### Glass Morphism (done right)
```css
.card {
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.06);
  border-radius: 16px;
  padding: 32px;
  transition: all 0.3s ease;
}
.card:hover {
  background: rgba(255, 255, 255, 0.05);
  border-color: rgba(255, 255, 255, 0.10);
  transform: translateY(-4px);
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
}
```

### Card Hierarchy
- **Don't** make every card identical. Vary size, emphasis, or layout.
- **Feature cards** in a grid: icon/emoji top, heading, 1-2 lines of text
- **Testimonial cards:** quote text, author name, author role, optional avatar
- **Stat cards:** large number, label below

---

## Images

### Rules
1. **Real images only.** Search the web for actual relevant photos. Never use placeholder services.
2. **Prefer hotlinking** direct URLs (`<img src="https://...">`) over downloading. Many servers return HTML to curl.
3. If you must download, verify with `file image.jpg` — if it says "HTML document", discard and hotlink instead.
4. **Aspect ratios:** Use `aspect-ratio` CSS property. Common ratios: `16/9` (hero), `4/3` (cards), `1/1` (avatars).
5. **Object fit:** Always set `object-fit: cover` on images inside constrained containers.
6. **Lazy loading:** Add `loading="lazy"` to all images below the fold.
7. **Border radius:** Images in cards get `border-radius: 12px`.

```css
.img-cover {
  width: 100%;
  height: 100%;
  object-fit: cover;
  border-radius: 12px;
}
```

### Image Overlay Pattern
```css
.image-container {
  position: relative;
  overflow: hidden;
  border-radius: 16px;
}
.image-container::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(to top, rgba(0,0,0,0.7) 0%, transparent 50%);
  pointer-events: none;
}
```

---

## Animations

### Entrance Animations (scroll-triggered)
Use CSS `@keyframes` + a small JS snippet with `IntersectionObserver`. Keep it simple.

```css
/* Animation keyframes */
@keyframes fadeUp {
  from { opacity: 0; transform: translateY(30px); }
  to   { opacity: 1; transform: translateY(0); }
}
@keyframes fadeIn {
  from { opacity: 0; }
  to   { opacity: 1; }
}
@keyframes scaleIn {
  from { opacity: 0; transform: scale(0.95); }
  to   { opacity: 1; transform: scale(1); }
}

/* Applied via class */
.animate-on-scroll {
  opacity: 0;
  transform: translateY(30px);
}
.animate-on-scroll.visible {
  animation: fadeUp 0.6s ease forwards;
}

/* Stagger children */
.animate-on-scroll.visible:nth-child(2) { animation-delay: 0.1s; }
.animate-on-scroll.visible:nth-child(3) { animation-delay: 0.2s; }
.animate-on-scroll.visible:nth-child(4) { animation-delay: 0.3s; }
```

```html
<script>
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.1 });
  document.querySelectorAll('.animate-on-scroll').forEach(el => observer.observe(el));
</script>
```

### Hover Micro-Interactions
```css
/* Subtle lift on cards */
.card { transition: transform 0.3s ease, box-shadow 0.3s ease; }
.card:hover { transform: translateY(-4px); box-shadow: 0 20px 40px rgba(0,0,0,0.3); }

/* Button press effect */
.btn:active { transform: scale(0.98); }

/* Link underline animation */
a.animated-link {
  text-decoration: none;
  background-image: linear-gradient(var(--accent), var(--accent));
  background-size: 0% 2px;
  background-position: left bottom;
  background-repeat: no-repeat;
  transition: background-size 0.3s ease;
}
a.animated-link:hover { background-size: 100% 2px; }

/* Image zoom on hover */
.card-image { overflow: hidden; border-radius: 12px; }
.card-image img { transition: transform 0.4s ease; }
.card-image:hover img { transform: scale(1.05); }
```

### Performance Rules
- **Only animate** `transform` and `opacity`. Never animate `width`, `height`, `margin`, `padding`, `top/left`.
- Keep `backdrop-filter: blur()` values between 8-16px. Higher = GPU strain.
- Don't stack multiple blurred elements.
- All transitions: `0.2s` to `0.4s`. Faster = snappy. Slower = sluggish.

---

## Responsive Design

### Breakpoints
```css
/* Mobile-first. Write base styles for mobile, then add: */
@media (min-width: 768px)  { /* Tablet  */ }
@media (min-width: 1024px) { /* Desktop */ }
```

### Mobile Rules
- **Touch targets:** Minimum `44px` height and width for any tappable element
- **Font sizes:** Body never below `16px` (prevents iOS zoom)
- **Padding:** Minimum `24px` horizontal padding on mobile
- **Grid columns:** Stack to single column below 768px
- **Hero height:** Use `min-height: 100svh` (svh accounts for mobile browser chrome)
- **Images:** Full-width on mobile, constrained on desktop
- **Navigation:** Collapse to hamburger below 768px (or keep it minimal enough to not need one)

### Responsive Grid
```css
.grid {
  display: grid;
  gap: 24px;
  grid-template-columns: 1fr; /* Mobile: single column */
}
@media (min-width: 768px) {
  .grid { grid-template-columns: repeat(2, 1fr); }
}
@media (min-width: 1024px) {
  .grid { grid-template-columns: repeat(3, 1fr); }
}
```

---

## Anti-Patterns (NEVER do these)

1. **NO Bootstrap or Tailwind CDN.** Write custom CSS. It's a single page — you don't need a framework.
2. **NO generic stock photos.** Every image must be relevant to the actual content.
3. **NO placeholder text.** No "Lorem ipsum", no "Your text here", no "Company Name". Use real content from the wish or research it.
4. **NO centered-everything layouts.** Not every section is text-center. Use left-aligned text with intentional centering only for heroes and CTAs.
5. **NO walls of text.** Max 3 lines per paragraph in a card. Max 5 lines in a section body.
6. **NO pure white (#FFFFFF) text on dark backgrounds.** Use `rgba(255,255,255,0.92)` for headings, lower for body.
7. **NO flat sections.** Every section needs visual distinction — different background shade, border, spacing, or layout.
8. **NO font sizes in px.** Use `rem` or `clamp()`.
9. **NO inline styles.** All CSS goes in a `<style>` block in `<head>`.
10. **NO Unsplash Source URLs** (`source.unsplash.com`) — deprecated, returns 404.

---

## Quick Reference: The 10-Second Audit

Before you consider the site done, scan for:
1. Does the page have visual rhythm? (Alternating section styles, not monotonous)
2. Is there ONE dominant visual per section? (Not five competing elements)
3. Can you identify the heading hierarchy instantly? (H1 > H2 > H3 obvious by size)
4. Is there generous whitespace? (Sections feel like they can breathe)
5. Do interactive elements signal interactivity? (Hover states, cursor: pointer)
