# JellyJelly Design System Reference

**Purpose:** When building sites for Genie wishes, use JellyJelly's design language as the foundation. Use their colors, their playful energy, their modern aesthetic. Every site Genie builds should feel like it belongs in the JellyJelly ecosystem — dark, glassy, alive with subtle glow.

---

## Brand Identity

JellyJelly is "The Human Social Network" — a video-first social platform focused on raw, unfiltered, authentic content. Founded by Sam Lessin (ex-Facebook VP) and Iqram Magdon-Ismail (Venmo co-founder). The brand energy is: **authentic, playful, modern, bold, crypto-native**. Think TikTok meets Venmo with a dark-mode premium feel.

Tagline: "You & what you see."
Sub-tagline: "Share your world and get paid."

---

## Color Palette

### CSS Custom Properties (from their codebase)

```css
:root {
  /* Core palette */
  --world-black: #000000;
  --world-charcoal: #141416;
  --world-gray-dark: #1E1E21;
  --world-gray: #6B7280;
  --world-gray-light: #9CA3AF;
  --world-gray-muted: #E5E7EB;
  --world-white: #FFFFFF;

  /* Accent colors */
  --world-teal: #00D4AA;
  --world-teal-dark: #00B894;
  --world-orange: #F97316;
  --world-orange-light: #FB923C;

  /* Signature blue (used EVERYWHERE — links, glows, badges, pills, cards) */
  --jj-blue: #8babf3;
  --jj-blue-hover: #a8c4f7;
  --jj-blue-light: #cfe3ff;
  --jj-blue-accent: #4f8bff;
  --jj-blue-username: #9bbcff;

  /* Glass system */
  --glass-bg: rgba(139, 171, 243, 0.05);
  --glass-bg-hover: rgba(139, 171, 243, 0.1);
  --glass-border: rgba(139, 171, 243, 0.15);
  --glass-border-hover: rgba(139, 171, 243, 0.3);
  --glow-blue: 0 0 20px rgba(139, 171, 243, 0.15);

  /* Surfaces */
  --surface-dark: #14151a;
  --surface-header: rgba(10, 6, 24, 0.9);  /* #0a0618e6 — deep indigo-black */
  --surface-card: #000000;
  --surface-overlay: rgba(0, 0, 0, 0.6);

  /* Text */
  --text-primary: #f2ebf7;  /* warm off-white with lavender tint */
  --text-secondary: rgba(255, 255, 255, 0.9);
  --text-muted: rgba(255, 255, 255, 0.6);

  /* Easing */
  --ease-smooth: cubic-bezier(0.4, 0, 0.2, 1);
  --ease-premium: cubic-bezier(0.16, 1, 0.3, 1);
  --duration-normal: 0.3s;

  /* Layout */
  --page-padding: 40px;
}
```

### Color Summary

| Role | Hex | Usage |
|---|---|---|
| Background | `#000000` | Page background, pure black |
| Surface | `#141416` | Cards, panels, modals |
| Surface deep | `#0a0618` | Header bg (deep indigo-black) |
| Gray dark | `#1E1E21` | Borders, dividers |
| Gray | `#6B7280` | Secondary text |
| Gray light | `#9CA3AF` | Body text on dark |
| White | `#FFFFFF` | Primary headings |
| **Signature Blue** | `#8babf3` | Links, badges, glows, highlights — THE brand color |
| Blue accent | `#4f8bff` | Buttons, CTAs, active states |
| Blue light | `#cfe3ff` | Paywall text, light accents |
| Blue username | `#9bbcff` | Usernames, attribution |
| Teal | `#00D4AA` | "Read more" links, spinners, success states |
| Teal dark | `#00B894` | Teal hover state |
| Orange | `#F97316` | Alerts, warnings |
| Text primary | `#f2ebf7` | Nav text — warm lavender-white |
| Green | `#22c55e` | "Free" badges |

---

## Typography

### Font Stack

```css
/* Primary — used for headings, UI, body */
font-family: 'Outfit', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;

/* Brand wordmark — logo text only */
font-family: 'Ranchers', cursive;

/* Secondary — used for form inputs, system UI */
font-family: 'Roboto', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;

/* Tertiary — featured in some sections */
font-family: 'Inter', sans-serif;
```

### Google Fonts Import

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&family=Inter:wght@300;400;500&family=Ranchers&display=swap" rel="stylesheet">
```

### Type Scale

| Element | Font | Size | Weight | Notes |
|---|---|---|---|---|
| Hero headline | Outfit | `clamp(32px, 6vw, 52px)` | 600 | letter-spacing: -0.02em, text-shadow |
| Section title | Outfit | 48px (36px mobile) | 600 | letter-spacing: -0.02em |
| Section subtitle | Outfit | 17px | 400 | line-height: 1.7, color: gray-light |
| Happening title | Outfit | 28px | 300 | Light weight for elegance |
| Card title | Outfit | 22px | 600 | |
| Body text | Outfit | 15-17px | 400 | line-height: 1.55 |
| Event name | Outfit | 15px | 600 | |
| Username | Outfit | 13px | 600 | color: #9bbcff |
| Label | Outfit | 12px | 600 | uppercase, letter-spacing: 0.14em |
| Brand wordmark | Ranchers | 1.1rem | 400 | letter-spacing: 0.02em |
| Small text | Outfit | 11-12px | 400-500 | |

---

## Layout Patterns

### Page Structure
- **Full black background** (`#000`) with fixed bg div
- **Floating pill header** — fixed at top, 56px tall, border-radius: 999px, centered at max-width 1200px, glassmorphism backdrop-filter blur
- **Hero section** — min-height 85vh, video background with gradient overlay, centered content
- **Content sections** — max-width 1200px, padding: 0 40px (16px on mobile)
- **Horizontal scroll carousels** — for events, jellies, featured content. Flex row, gap 12px, overflow-x auto, hidden scrollbar
- **Footer** — centered, minimal, logo + tagline + links

### Card Patterns

```css
/* Glass card */
.card {
  background: rgba(139, 171, 243, 0.08);
  border: 1px solid rgba(139, 171, 243, 0.2);
  border-radius: 12px;
  padding: 16px 20px;
  color: #fff;
  transition: background 0.2s ease, border-color 0.2s ease, transform 0.2s ease;
}
.card:hover {
  background: rgba(139, 171, 243, 0.15);
  border-color: rgba(139, 171, 243, 0.35);
  transform: translateY(-2px);
}

/* Video card */
.video-card {
  background: #000;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
  transition: box-shadow 0.2s ease, transform 0.2s ease;
}
.video-card:hover {
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
  transform: translateY(-2px);
}
```

### Pill / Badge Pattern

```css
.pill {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  border-radius: 999px;
  background: rgba(139, 171, 243, 0.25);
  color: #fff;
  font-size: 13px;
  font-weight: 600;
  transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1),
              background 0.3s cubic-bezier(0.16, 1, 0.3, 1),
              box-shadow 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}
.pill:hover {
  transform: translateY(-1px);
  background: rgba(139, 171, 243, 0.32);
  box-shadow: 0 0 16px rgba(139, 171, 243, 0.25);
}
```

### Glassmorphism Header

```css
.header {
  position: fixed;
  top: 12px;
  left: 50%;
  transform: translateX(-50%);
  width: calc(100% - 48px);
  max-width: 1200px;
  height: 56px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(12px) saturate(1.2);
  -webkit-backdrop-filter: blur(12px) saturate(1.2);
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 20px;
}
```

---

## Animation Patterns

### Bounce (logo, header)
```css
@keyframes jelly-bounce {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-4px); }
}
/* Usage: animation: jelly-bounce 2.5s ease-in-out infinite */
```

### Glow Pulse
```css
@keyframes glow-pulse {
  0%, 100% { box-shadow: 0 0 8px rgba(139, 171, 243, 0.1); }
  50% { box-shadow: 0 0 20px rgba(139, 171, 243, 0.25), 0 0 40px rgba(139, 171, 243, 0.08); }
}
```

### Skeleton Loading
```css
@keyframes skeleton-pulse {
  0%, 100% { opacity: 0.4; }
  50% { opacity: 0.8; }
}
.skeleton {
  border-radius: 4px;
  background: rgba(255, 255, 255, 0.06);
  animation: skeleton-pulse 1.5s ease-in-out infinite;
}
```

### Spinner
```css
.spinner {
  width: 40px;
  height: 40px;
  border: 3px solid #1E1E21;
  border-top-color: #00D4AA;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
```

### Interaction Transitions
```css
/* Standard interactive element */
transition: all 0.35s cubic-bezier(0.16, 1, 0.3, 1);

/* Hover lift */
transform: translateY(-2px);

/* Scale pop on CTA hover */
transform: scale(1.02);

/* Link glow on hover */
text-shadow: 0 0 14px rgba(139, 171, 243, 0.6), 0 0 40px rgba(139, 171, 243, 0.25);
box-shadow: 0 1px rgba(139, 171, 243, 0.7), 0 6px 20px -4px rgba(139, 171, 243, 0.45);
```

### Reduced Motion
```css
@media (prefers-reduced-motion: reduce) {
  * { transition: none !important; animation: none !important; }
}
```

---

## Design Language Description

JellyJelly's visual identity is **dark-mode premium with blue-glass accents**. Key characteristics:

1. **Pure black canvas** — `#000` background everywhere, never gray, never off-black
2. **Blue glass system** — `#8babf3` is THE signature color. It appears as borders, glows, text highlights, badge backgrounds. Every interactive element has a blue glass treatment.
3. **Glassmorphism** — heavy use of `backdrop-filter: blur()`, translucent backgrounds with `rgba()`, glass borders
4. **Playful but not childish** — the "Ranchers" display font for the brand, bouncy animations, but the UI is sophisticated and premium
5. **Generous whitespace** — sections have 56-120px vertical padding, content is never cramped
6. **Horizontal scrolling content** — carousels of cards, events, video thumbnails scroll sideways
7. **Video-first** — 9:16 aspect ratio thumbnails, video backgrounds, poster images with gradient overlays
8. **Pill-shaped everything** — buttons, badges, headers, tags all use `border-radius: 999px`
9. **Subtle text shadows and glows** — headlines get text-shadow, links get text-shadow + box-shadow glow on hover
10. **Warm text tones** — primary text is `#f2ebf7` (lavender-tinted white), not pure `#fff`

---

## Downloaded Assets

| Asset | Path | Size |
|---|---|---|
| Logo (blue, 1770x1770) | `/Users/gtrush/Downloads/genie-2.0/assets/jellyjelly/jelly-logo-blue.png` | 1770x1770 PNG |
| Favicon | `/Users/gtrush/Downloads/genie-2.0/assets/jellyjelly/favicon.png` | 32x32 PNG |
| Wobble product | `/Users/gtrush/Downloads/genie-2.0/assets/jellyjelly/wobble_product.png` | 631x641 PNG |

Logo CDN URL (hotlinkable): `https://static1.jellyjelly.com/jelly-logo-blue.png`

---

## Reference HTML Template

A JellyJelly-styled single-page site template. Copy and adapt for Genie-built sites:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <title>Page Title — JellyJelly Style</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&family=Ranchers&display=swap" rel="stylesheet">
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    :root {
      --black: #000000;
      --charcoal: #141416;
      --gray-dark: #1E1E21;
      --gray: #6B7280;
      --gray-light: #9CA3AF;
      --white: #FFFFFF;
      --blue: #8babf3;
      --blue-hover: #a8c4f7;
      --blue-accent: #4f8bff;
      --blue-light: #cfe3ff;
      --teal: #00D4AA;
      --glass-bg: rgba(139, 171, 243, 0.05);
      --glass-border: rgba(139, 171, 243, 0.15);
      --glass-border-hover: rgba(139, 171, 243, 0.3);
      --text-primary: #f2ebf7;
      --text-secondary: rgba(255, 255, 255, 0.9);
      --text-muted: rgba(255, 255, 255, 0.6);
      --ease-premium: cubic-bezier(0.16, 1, 0.3, 1);
      --page-padding: 40px;
    }

    html { scrollbar-gutter: stable; }
    body {
      font-family: 'Outfit', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: var(--black);
      color: var(--white);
      -webkit-font-smoothing: antialiased;
      -moz-osx-font-smoothing: grayscale;
    }

    /* --- FLOATING GLASS HEADER --- */
    .header {
      position: fixed;
      top: 12px;
      left: 50%;
      transform: translateX(-50%);
      width: calc(100% - 48px);
      max-width: 1200px;
      height: 56px;
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.03);
      backdrop-filter: blur(12px) saturate(1.2);
      -webkit-backdrop-filter: blur(12px) saturate(1.2);
      z-index: 1000;
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 24px;
    }
    .header-brand {
      display: flex;
      align-items: center;
      gap: 8px;
      text-decoration: none;
      color: var(--text-primary);
      animation: jelly-bounce 2.5s ease-in-out infinite;
    }
    .header-brand img { width: 24px; height: 24px; border-radius: 6px; }
    .header-brand span { font-family: 'Ranchers', cursive; font-size: 1.1rem; }
    .header-nav { display: flex; gap: 8px; }
    .header-nav a {
      display: flex;
      align-items: center;
      justify-content: center;
      width: 40px;
      height: 40px;
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.04);
      color: var(--text-primary);
      text-decoration: none;
      transition: all 0.35s var(--ease-premium);
    }
    .header-nav a:hover {
      background: rgba(255, 255, 255, 0.08);
      border-color: rgba(242, 235, 247, 0.2);
    }

    /* --- HERO --- */
    .hero {
      position: relative;
      min-height: 90vh;
      display: flex;
      align-items: center;
      justify-content: center;
      overflow: hidden;
    }
    .hero-bg {
      position: absolute;
      inset: 0;
      background: linear-gradient(135deg, #0a0e1a, #1a2332, #0d1424);
    }
    .hero-overlay {
      position: absolute;
      inset: 0;
      background: linear-gradient(to bottom, rgba(0,0,0,0.55), rgba(0,0,0,0.7), rgba(0,0,0,0.95));
    }
    .hero-content {
      position: relative;
      z-index: 1;
      text-align: center;
      padding: 0 var(--page-padding);
      max-width: 680px;
    }
    .hero h1 {
      font-size: clamp(32px, 6vw, 52px);
      font-weight: 600;
      line-height: 1.2;
      letter-spacing: -0.02em;
      text-shadow: 0 2px 24px rgba(0, 0, 0, 0.4);
      margin-bottom: 20px;
    }
    .hero p {
      font-size: clamp(18px, 2.5vw, 22px);
      line-height: 1.55;
      color: var(--text-secondary);
      margin-bottom: 32px;
      max-width: 480px;
      margin-left: auto;
      margin-right: auto;
    }
    .cta-btn {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      padding: 14px 32px;
      font-size: 16px;
      font-weight: 600;
      color: #fff;
      background: var(--blue-accent);
      border: none;
      border-radius: 999px;
      text-decoration: none;
      cursor: pointer;
      transition: background 0.2s ease, transform 0.15s ease, box-shadow 0.2s ease;
    }
    .cta-btn:hover {
      background: var(--blue);
      transform: scale(1.02);
      box-shadow: 0 0 20px rgba(139, 171, 243, 0.3);
    }
    .cta-btn-outline {
      background: transparent;
      border: 2px solid #fff;
      color: #fff;
    }
    .cta-btn-outline:hover {
      background: #fff;
      color: #000;
    }

    /* --- SECTIONS --- */
    .section {
      padding: 80px var(--page-padding);
      max-width: 1200px;
      margin: 0 auto;
    }
    .section-title {
      font-size: 48px;
      font-weight: 600;
      letter-spacing: -0.02em;
      text-align: center;
      margin-bottom: 16px;
      text-shadow: 0 0 20px rgba(139, 171, 243, 0.15);
    }
    .section-subtitle {
      font-size: 17px;
      color: var(--gray-light);
      text-align: center;
      line-height: 1.7;
      max-width: 680px;
      margin: 0 auto 48px;
    }
    .glass-divider {
      height: 1px;
      background: linear-gradient(90deg, transparent, rgba(139, 171, 243, 0.3), transparent);
      max-width: 200px;
      margin: 16px auto 24px;
    }

    /* --- CARDS GRID --- */
    .cards-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
      gap: 16px;
    }
    .card {
      background: rgba(139, 171, 243, 0.08);
      border: 1px solid rgba(139, 171, 243, 0.2);
      border-radius: 16px;
      padding: 24px 28px;
      transition: background 0.2s ease, border-color 0.2s ease, transform 0.2s ease;
    }
    .card:hover {
      background: rgba(139, 171, 243, 0.15);
      border-color: rgba(139, 171, 243, 0.35);
      transform: translateY(-2px);
    }
    .card h3 {
      font-size: 22px;
      font-weight: 600;
      margin-bottom: 8px;
    }
    .card p {
      font-size: 15px;
      color: var(--text-secondary);
      line-height: 1.5;
    }

    /* --- SCROLL CAROUSEL --- */
    .carousel {
      overflow-x: auto;
      overflow-y: hidden;
      -webkit-overflow-scrolling: touch;
      scrollbar-width: none;
      scroll-behavior: smooth;
    }
    .carousel::-webkit-scrollbar { display: none; }
    .carousel-track {
      display: flex;
      gap: 12px;
      padding: 0 var(--page-padding) 8px;
      min-width: max-content;
    }

    /* --- PILLS --- */
    .pill {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 8px 14px;
      border-radius: 999px;
      background: rgba(139, 171, 243, 0.25);
      color: #fff;
      font-size: 13px;
      font-weight: 600;
      text-decoration: none;
      transition: all 0.3s var(--ease-premium);
    }
    .pill:hover {
      transform: translateY(-1px);
      background: rgba(139, 171, 243, 0.32);
      box-shadow: 0 0 16px rgba(139, 171, 243, 0.25);
    }

    /* --- GLOWING LINK --- */
    .glow-link {
      color: var(--blue);
      text-decoration: none;
      border-bottom: 1px solid rgba(139, 171, 243, 0.5);
      padding-bottom: 2px;
      text-shadow: 0 0 10px rgba(139, 171, 243, 0.4), 0 0 30px rgba(139, 171, 243, 0.15);
      transition: all 0.3s ease;
    }
    .glow-link:hover {
      color: var(--blue-hover);
      text-shadow: 0 0 14px rgba(139, 171, 243, 0.6), 0 0 40px rgba(139, 171, 243, 0.25);
    }

    /* --- FOOTER --- */
    .footer {
      padding: 64px var(--page-padding);
      border-top: 1px solid rgba(255, 255, 255, 0.06);
      text-align: center;
    }
    .footer-brand img { width: 40px; height: 40px; border-radius: 10px; margin-bottom: 16px; }
    .footer-tagline { font-size: 14px; color: var(--gray); margin-bottom: 16px; }
    .footer-links { font-size: 14px; color: var(--gray); }
    .footer-links a { color: inherit; text-decoration: none; margin: 0 8px; }
    .footer-links a:hover { color: var(--white); }

    /* --- ANIMATIONS --- */
    @keyframes jelly-bounce {
      0%, 100% { transform: translateY(0); }
      50% { transform: translateY(-4px); }
    }
    @keyframes glow-pulse {
      0%, 100% { box-shadow: 0 0 8px rgba(139, 171, 243, 0.1); }
      50% { box-shadow: 0 0 20px rgba(139, 171, 243, 0.25), 0 0 40px rgba(139, 171, 243, 0.08); }
    }

    /* --- RESPONSIVE --- */
    @media (max-width: 768px) {
      :root { --page-padding: 16px; }
      .header { width: calc(100% - 24px); padding: 0 12px; }
      .hero { min-height: 75vh; }
      .section-title { font-size: 36px; }
      .cards-grid { grid-template-columns: 1fr; }
    }

    @media (prefers-reduced-motion: reduce) {
      *, *::before, *::after {
        animation-duration: 0.01ms !important;
        transition-duration: 0.01ms !important;
      }
    }
  </style>
</head>
<body>

  <!-- FLOATING GLASS HEADER -->
  <header class="header">
    <a href="/" class="header-brand">
      <img src="https://static1.jellyjelly.com/jelly-logo-blue.png" alt="Logo">
      <span>brandname</span>
    </a>
    <nav class="header-nav">
      <a href="#features" aria-label="Features">F</a>
      <a href="#about" aria-label="About">A</a>
    </nav>
  </header>

  <!-- HERO -->
  <section class="hero">
    <div class="hero-bg"></div>
    <div class="hero-overlay"></div>
    <div class="hero-content">
      <h1>Bold headline here.</h1>
      <p>A compelling description that captures the essence of whatever this page is about.</p>
      <div style="display: flex; gap: 12px; justify-content: center; flex-wrap: wrap;">
        <a href="#" class="cta-btn">Get Started</a>
        <a href="#" class="cta-btn cta-btn-outline">Learn More</a>
      </div>
    </div>
  </section>

  <!-- FEATURES SECTION -->
  <section class="section" id="features">
    <h2 class="section-title">Why this matters</h2>
    <div class="glass-divider"></div>
    <p class="section-subtitle">A brief explanation of the value proposition, written in plain, honest language.</p>
    <div class="cards-grid">
      <div class="card">
        <h3>Feature One</h3>
        <p>Description of the feature and why it matters to the user.</p>
      </div>
      <div class="card">
        <h3>Feature Two</h3>
        <p>Another compelling feature explained in simple terms.</p>
      </div>
      <div class="card">
        <h3>Feature Three</h3>
        <p>The third key benefit, keeping it real and authentic.</p>
      </div>
    </div>
  </section>

  <!-- FOOTER -->
  <footer class="footer">
    <div class="footer-brand">
      <img src="https://static1.jellyjelly.com/jelly-logo-blue.png" alt="Logo">
    </div>
    <p class="footer-tagline">Your tagline here</p>
    <div class="footer-links">
      <a href="#">About</a>
      <span style="opacity: 0.5;">·</span>
      <a href="#">Terms</a>
      <span style="opacity: 0.5;">·</span>
      <a href="#">Privacy</a>
    </div>
  </footer>

</body>
</html>
```

---

## Key Design Do's and Don'ts

### DO
- Use pure `#000` black backgrounds
- Use `#8babf3` blue as the accent everywhere — borders, glows, links, badges
- Use glassmorphism on headers and overlays (`backdrop-filter: blur(12px)`)
- Use pill shapes (`border-radius: 999px`) for buttons, badges, nav elements
- Use the premium easing `cubic-bezier(0.16, 1, 0.3, 1)` for hover transitions
- Use warm off-white `#f2ebf7` for primary text, not harsh `#fff`
- Add subtle text-shadow and box-shadow glow to interactive links
- Use Outfit as the primary font with weight 300-700
- Include bounce animations on brand elements
- Use horizontal scroll carousels for collections
- Respect `prefers-reduced-motion`

### DON'T
- Use gray or off-white backgrounds — JellyJelly is pure black
- Use harsh primary colors — the palette is muted blues and teals
- Make things look corporate or clinical — JellyJelly is playful and human
- Use sharp corners on interactive elements — everything is rounded
- Skip the glass border treatment on cards — `rgba(139,171,243,0.2)` border is essential
- Use heavy gradients — gradients are subtle, mostly overlays on video/images
- Forget the `text-shadow: 0 0 20px rgba(139,171,243,0.15)` on headings

---

## Tech Stack (for reference)
- **Framework:** SvelteKit (deployed on Vercel)
- **Backend:** Supabase (auth + data)
- **Payments:** Stripe
- **CDN:** `static1.jellyjelly.com`, `cdn.jellyjelly.com`, `cdn3.jellyjelly.com`
- **Monitoring:** Sentry
- **Token:** JELLYJELLY on Solana

---

## Sources
- [JellyJelly Homepage](https://jellyjelly.com/)
- [JellyJelly Manifesto](https://jellyjelly.com/manifesto)
- [App Store Listing](https://apps.apple.com/us/app/jellyjelly-post-povs-earn/id6505022038)
- [Bitget Research Report](https://www.bitget.com/news/detail/12560604567724)
- [PANews Overview](https://www.panewslab.com/en/articledetails/8mt7k8lb.html)
