# Design Review Checklist — Genie 2.0

Run this checklist BEFORE deploying any website. Every item must pass. If an item fails, fix it immediately — do not deploy a site that fails any of these checks.

---

## The Checklist

### 1. Hero Section
- [ ] **Does the hero fill the viewport?** `min-height: 100svh` or `100vh` on the hero section. Scroll should not be needed to see the full hero.
- [ ] **Is there a single, dominant headline?** One H1, visually the largest text on the page. Not two competing headings.
- [ ] **Is there supporting text?** 1-2 lines below the headline explaining the value prop. Not a wall of text.
- [ ] **Is there at least one CTA button?** Visually prominent, with padding `14px 32px` or larger. Action-oriented label ("Get Started", "See Demo", not "Click Here" or "Submit").
- [ ] **Is there visual depth?** Ambient glow, gradient, background image, or pattern. Never a flat solid color with just text.

### 2. Visual Hierarchy
- [ ] **Can you identify H1 > H2 > H3 instantly by size alone?** The difference between heading levels should be immediately obvious.
- [ ] **Is body text clearly smaller than headings?** No ambiguity about what's a heading vs what's body copy.
- [ ] **Is there only ONE primary CTA per section?** Not three competing buttons of equal visual weight.
- [ ] **Do section headings have supporting descriptions?** A heading without context is a missed opportunity.

### 3. Images
- [ ] **Are there at least 3 real images?** Real photos, illustrations, or screenshots relevant to the content. Not placeholders, not broken URLs.
- [ ] **Do all images load?** Open the browser console — zero 404 errors on images. If hotlinked, verify the URL returns an image content-type.
- [ ] **Do images have `alt` attributes?** Descriptive alt text, not empty or "image".
- [ ] **Are images properly sized?** Using `object-fit: cover`, `aspect-ratio`, and `border-radius`. No stretched or squished images.
- [ ] **Are below-fold images lazy loaded?** `loading="lazy"` on any `<img>` not in the hero.

### 4. Color & Contrast
- [ ] **Is the palette consistent?** Maximum 1 accent color + neutrals (grays/blacks/whites). Not a rainbow.
- [ ] **Is body text readable?** Minimum contrast ratio 4.5:1 against its background. Quick check: `rgba(255,255,255,0.64)` on `#0A0A0B` passes. `rgba(255,255,255,0.30)` does NOT.
- [ ] **Is heading text high-contrast?** `rgba(255,255,255,0.90)` or higher.
- [ ] **Are there no pure #FFFFFF text blocks on dark backgrounds?** Use `rgba(255,255,255,0.92)` for the softer feel.
- [ ] **Does the accent color appear in at least 2 places?** (CTA button + one other: gradient text, tag, link hover, glow). Consistency.

### 5. Mobile Responsiveness (375px width)
- [ ] **Does it look good at 375px?** Take a screenshot at 375px width using Playwright. Actually look at it.
- [ ] **Do grids stack to single column?** No horizontal overflow, no tiny two-column layouts on phones.
- [ ] **Is text still readable?** Body text >= 16px (no iOS auto-zoom).
- [ ] **Are buttons full-width or large enough to tap?** Minimum 44px tap target height.
- [ ] **Is horizontal padding at least 24px?** Content shouldn't touch the screen edges.
- [ ] **Does the hero still work?** Headline should be readable, CTA visible without excessive scrolling.

### 6. Interactivity & Polish
- [ ] **Do buttons have hover states?** Lift, shadow, color shift — something visible changes on hover.
- [ ] **Do cards have hover states?** Subtle lift (`translateY(-4px)`) + shadow increase.
- [ ] **Are there scroll animations?** Elements fade/slide in as the user scrolls. Not everything visible at once.
- [ ] **Do links look like links?** Either colored (accent), underlined, or have hover state. Not indistinguishable from body text.
- [ ] **Is `cursor: pointer` set on all clickable elements?** Buttons, links, cards that are clickable.

### 7. Structure & Content
- [ ] **Are sections visually distinct?** Alternating backgrounds, borders, or spacing differences. Not one continuous flat page.
- [ ] **Is there enough whitespace?** Sections have >= 80px vertical padding. Cards have >= 24px padding. Nothing feels cramped.
- [ ] **Is the max content width constrained?** Content should not span edge-to-edge on a wide monitor. `max-width: 1200px` on the container.
- [ ] **Is all text real?** No "Lorem ipsum", no "Company Name", no "Your text here", no "[placeholder]".
- [ ] **Is the footer present and real?** Contains actual brand/site name and isn't empty.

### 8. Technical
- [ ] **Is the page a single `index.html`?** No external CSS files, no JS files (except optional inline `<script>`).
- [ ] **Are fonts loading from Google Fonts?** `<link>` in `<head>` with `rel="preconnect"`.
- [ ] **Is there a `<meta name="viewport">` tag?** Must have `width=device-width, initial-scale=1.0`.
- [ ] **Is there a `<title>` tag?** Real title, not "Document" or empty.
- [ ] **No console errors?** Open Playwright console, verify clean.

### 9. The George Test
- [ ] **Would George be proud to share this link?** Not "it's fine for AI-generated." Actually impressive. If the answer is "meh," you're not done.
- [ ] **Does it look like a real company's landing page?** Not a tutorial project, not a Bootstrap template, not a homework assignment.
- [ ] **Is there personality?** A unique gradient, an interesting layout choice, a detail that shows craft. Not generic.

---

## How to Run This Checklist

1. Open the site in Playwright at `1440px` width — take a screenshot, review visually
2. Resize to `375px` width — take a screenshot, review visually
3. Walk through each checkbox above
4. For any failure, fix it in the HTML immediately
5. Re-screenshot after fixes to confirm
6. Only then proceed to `npx vercel deploy`

## Quick Fixes for Common Failures

| Failure | Fix |
|---------|-----|
| Hero doesn't fill viewport | Add `min-height: 100svh` to `.hero` |
| Text is too low contrast | Bump `rgba` alpha to at least `0.64` for body, `0.92` for headings |
| No hover states | Add `transition: all 0.3s ease` + `:hover` rules with `transform` and `box-shadow` |
| Images broken | Test URL with `curl -sI`, switch to hotlink if download was HTML |
| No scroll animations | Add `animate-on-scroll` class + IntersectionObserver snippet from site-builder skill |
| Grid doesn't stack on mobile | Add `@media (max-width: 768px) { .grid { grid-template-columns: 1fr; } }` |
| No visual depth on hero | Add a `.hero-glow` div with radial gradient + blur filter |
| Sections look identical | Alternate between `var(--bg-primary)` and `var(--bg-secondary)` backgrounds |
| Content too wide | Ensure `.container` has `max-width: 1200px; margin: 0 auto;` |
| Placeholder text found | Search the HTML for "lorem", "placeholder", "your text", "Company Name" — replace all |
