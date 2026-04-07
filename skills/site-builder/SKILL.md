# Site Builder Workflow — Genie 2.0

This skill defines the exact step-by-step process for building and deploying a website. Follow every phase in order. Do not skip phases. Do not write HTML until the Design phase is complete.

---

## Phase 1: Research (before touching any code)

### Gather Real Content
1. **WebSearch** for the subject of the site — company, person, event, product. Get real facts, real names, real descriptions.
2. **WebSearch** for 3-5 real, relevant images. Prefer:
   - Company press kits / media pages
   - Wikimedia Commons (direct file URLs)
   - Official social media images
   - NASA, government, or open-license sources
3. **WebFetch** key pages to extract actual copy — taglines, mission statements, feature lists, bios.
4. **Never fabricate facts.** If you can't find something, say so in the Telegram report. Don't fill gaps with fiction.

### Image Strategy
- Find at least 3 real images (hero background, feature visual, secondary section)
- Get the **direct image URL** (ends in .jpg, .png, .webp, or served as image content-type)
- **Hotlink by default.** Only download if the URL is ephemeral.
- If you download: run `file image.jpg` — if it says "HTML document", discard it and hotlink the original URL
- Test each image URL with `curl -sI <url> | head -5` to confirm it returns an image content-type

---

## Phase 2: Design (before writing HTML)

### Decisions to Make FIRST
Write these down in your plan (mentally or in TodoWrite) before coding:

1. **Palette:** Pick a background shade, 1 accent color, and text colors from the web-design skill
2. **Fonts:** Pick ONE pair from the web-design skill's proven pairings table
3. **Layout structure:** Sketch the sections:
   - Hero (full viewport, what's the headline, what's the CTA?)
   - Section 2 (features/about — grid or split layout?)
   - Section 3 (showcase/testimonials/stats)
   - Section 4 (CTA/contact/footer)
4. **Image placement:** Which images go where?
5. **Accent usage:** Where does the accent color appear? (CTA button, gradient text, glow, link hovers)

### Design Principles
- **Contrast creates hierarchy.** The hero heading is huge; everything else is smaller.
- **Asymmetry is interesting.** Not every section is centered. Mix centered heroes with left-aligned content sections.
- **Whitespace is a feature.** Sections need 80-120px vertical padding. Cards need 32px internal padding.
- **Dark backgrounds need depth.** Use subtle gradients, ambient glows, or card elevation to prevent flatness.

---

## Phase 3: Build

### File Structure
```
/tmp/genie/<slug>-<timestamp>/
  index.html        <- Everything lives here
  (optional images)  <- Only if hotlinking failed
```

### HTML Template
Build a single `index.html` with all CSS inline in `<style>`. The only external dependencies are Google Fonts (via `<link>`) and image URLs.

**Reference template structure (adapt to each wish — never copy verbatim):**

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Page Title — Tagline</title>
  <meta name="description" content="One-sentence description for SEO and link previews.">

  <!-- Fonts -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Space+Grotesk:wght@500;600;700&display=swap" rel="stylesheet">

  <!-- Favicon (inline SVG) -->
  <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>EMOJI</text></svg>">

  <style>
    /* ===== RESET ===== */
    *, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }
    html { scroll-behavior: smooth; }

    /* ===== DESIGN TOKENS ===== */
    :root {
      /* Colors */
      --bg-primary:    #0A0A0B;
      --bg-secondary:  #111114;
      --bg-tertiary:   #1A1A1F;
      --bg-glass:      rgba(255, 255, 255, 0.03);
      --border-subtle: rgba(255, 255, 255, 0.06);
      --border-medium: rgba(255, 255, 255, 0.10);
      --text-primary:  rgba(255, 255, 255, 0.92);
      --text-secondary: rgba(255, 255, 255, 0.64);
      --text-tertiary: rgba(255, 255, 255, 0.40);
      --accent:        #8B5CF6;
      --accent-rgb:    139, 92, 246;

      /* Typography scale */
      --text-sm:   clamp(0.875rem, 0.8rem + 0.35vw, 1rem);
      --text-base: clamp(1rem, 0.9rem + 0.5vw, 1.125rem);
      --text-lg:   clamp(1.125rem, 1rem + 0.6vw, 1.35rem);
      --text-xl:   clamp(1.25rem, 1rem + 1.2vw, 1.75rem);
      --text-2xl:  clamp(1.75rem, 1.2rem + 2.5vw, 2.75rem);
      --text-3xl:  clamp(2.25rem, 1.5rem + 3.5vw, 3.75rem);
      --text-hero: clamp(2.75rem, 1.5rem + 5.5vw, 5.5rem);

      /* Spacing */
      --section-padding: clamp(5rem, 8vw, 8rem);
    }

    /* ===== BASE ===== */
    body {
      font-family: 'Inter', system-ui, sans-serif;
      background: var(--bg-primary);
      color: var(--text-secondary);
      font-size: var(--text-base);
      line-height: 1.65;
      -webkit-font-smoothing: antialiased;
      -moz-osx-font-smoothing: grayscale;
      overflow-x: hidden;
    }

    h1, h2, h3, h4, h5, h6 {
      font-family: 'Space Grotesk', system-ui, sans-serif;
      color: var(--text-primary);
      line-height: 1.15;
      letter-spacing: -0.02em;
    }

    a { color: var(--accent); text-decoration: none; }
    img { max-width: 100%; height: auto; display: block; }

    /* ===== LAYOUT ===== */
    .container {
      width: 100%;
      max-width: 1200px;
      margin: 0 auto;
      padding: 0 clamp(1.5rem, 4vw, 3rem);
    }

    section {
      padding: var(--section-padding) 0;
    }

    /* ===== HERO ===== */
    .hero {
      min-height: 100svh;
      display: flex;
      align-items: center;
      justify-content: center;
      text-align: center;
      position: relative;
      overflow: hidden;
    }

    .hero-glow {
      position: absolute;
      width: clamp(300px, 50vw, 700px);
      height: clamp(300px, 50vw, 700px);
      background: radial-gradient(circle, rgba(var(--accent-rgb), 0.2) 0%, transparent 70%);
      filter: blur(100px);
      top: 20%;
      left: 50%;
      transform: translateX(-50%);
      pointer-events: none;
      z-index: 0;
    }

    .hero-content {
      position: relative;
      z-index: 1;
      max-width: 800px;
    }

    .hero-tag {
      display: inline-block;
      font-size: var(--text-sm);
      color: var(--accent);
      letter-spacing: 0.08em;
      text-transform: uppercase;
      font-weight: 600;
      margin-bottom: 1.5rem;
      padding: 6px 16px;
      border: 1px solid rgba(var(--accent-rgb), 0.3);
      border-radius: 100px;
    }

    .hero h1 {
      font-size: var(--text-hero);
      margin-bottom: 1.5rem;
      font-weight: 700;
    }

    .gradient-text {
      background: linear-gradient(135deg, var(--accent), #c084fc, #f472b6);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
    }

    .hero p {
      font-size: var(--text-xl);
      color: var(--text-secondary);
      max-width: 600px;
      margin: 0 auto 2.5rem;
    }

    .hero-actions {
      display: flex;
      gap: 16px;
      justify-content: center;
      flex-wrap: wrap;
    }

    /* ===== BUTTONS ===== */
    .btn {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 14px 32px;
      font-weight: 600;
      font-size: var(--text-base);
      border-radius: 12px;
      border: none;
      cursor: pointer;
      transition: all 0.2s ease;
      text-decoration: none;
    }
    .btn-primary {
      background: var(--accent);
      color: #fff;
    }
    .btn-primary:hover {
      transform: translateY(-2px);
      box-shadow: 0 8px 24px rgba(var(--accent-rgb), 0.35);
    }
    .btn-ghost {
      background: transparent;
      color: var(--text-secondary);
      border: 1px solid var(--border-medium);
    }
    .btn-ghost:hover {
      border-color: var(--text-tertiary);
      color: var(--text-primary);
      background: var(--bg-glass);
    }
    .btn:active { transform: scale(0.98); }

    /* ===== CARDS ===== */
    .card {
      background: var(--bg-glass);
      backdrop-filter: blur(12px);
      -webkit-backdrop-filter: blur(12px);
      border: 1px solid var(--border-subtle);
      border-radius: 16px;
      padding: 32px;
      transition: all 0.3s ease;
    }
    .card:hover {
      background: rgba(255, 255, 255, 0.05);
      border-color: var(--border-medium);
      transform: translateY(-4px);
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
    }
    .card h3 {
      font-size: var(--text-xl);
      margin-bottom: 0.75rem;
    }
    .card p {
      color: var(--text-secondary);
      line-height: 1.65;
    }
    .card-icon {
      font-size: 2rem;
      margin-bottom: 1rem;
    }

    /* ===== GRID ===== */
    .grid {
      display: grid;
      gap: 24px;
      grid-template-columns: 1fr;
    }
    @media (min-width: 768px) {
      .grid { grid-template-columns: repeat(2, 1fr); }
    }
    @media (min-width: 1024px) {
      .grid { grid-template-columns: repeat(3, 1fr); }
    }

    /* ===== SECTION ALTERNATION ===== */
    .section-alt {
      background: var(--bg-secondary);
    }
    .section-header {
      text-align: center;
      max-width: 700px;
      margin: 0 auto 3rem;
    }
    .section-header h2 {
      font-size: var(--text-3xl);
      margin-bottom: 1rem;
    }
    .section-header p {
      font-size: var(--text-lg);
      color: var(--text-secondary);
    }

    /* ===== IMAGE ===== */
    .img-cover {
      width: 100%;
      height: 100%;
      object-fit: cover;
      border-radius: 12px;
    }
    .image-container {
      position: relative;
      overflow: hidden;
      border-radius: 16px;
      aspect-ratio: 16/9;
    }
    .image-container img {
      width: 100%;
      height: 100%;
      object-fit: cover;
      transition: transform 0.4s ease;
    }
    .image-container:hover img {
      transform: scale(1.03);
    }

    /* ===== DIVIDER ===== */
    .divider {
      height: 1px;
      background: linear-gradient(90deg, transparent, var(--border-medium), transparent);
      border: none;
      margin: 0;
    }

    /* ===== FOOTER ===== */
    footer {
      padding: 3rem 0;
      border-top: 1px solid var(--border-subtle);
      color: var(--text-tertiary);
      font-size: var(--text-sm);
    }
    footer .container {
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 1rem;
    }

    /* ===== ANIMATIONS ===== */
    .animate-on-scroll {
      opacity: 0;
      transform: translateY(30px);
    }
    .animate-on-scroll.visible {
      animation: fadeUp 0.6s ease forwards;
    }
    .animate-on-scroll.visible:nth-child(2) { animation-delay: 0.1s; }
    .animate-on-scroll.visible:nth-child(3) { animation-delay: 0.2s; }
    .animate-on-scroll.visible:nth-child(4) { animation-delay: 0.3s; }
    .animate-on-scroll.visible:nth-child(5) { animation-delay: 0.4s; }
    .animate-on-scroll.visible:nth-child(6) { animation-delay: 0.5s; }

    @keyframes fadeUp {
      from { opacity: 0; transform: translateY(30px); }
      to   { opacity: 1; transform: translateY(0); }
    }
    @keyframes fadeIn {
      from { opacity: 0; }
      to   { opacity: 1; }
    }

    /* Hero entrance — plays immediately */
    .hero-content { animation: fadeUp 0.8s ease forwards; }
    .hero-glow { animation: fadeIn 1.5s ease forwards; }

    /* ===== RESPONSIVE ===== */
    @media (max-width: 768px) {
      .hero-actions { flex-direction: column; align-items: center; }
      .btn { width: 100%; max-width: 320px; justify-content: center; }
    }
  </style>
</head>
<body>

  <!-- ===== HERO ===== -->
  <section class="hero">
    <div class="hero-glow"></div>
    <div class="container hero-content">
      <span class="hero-tag">Category or tagline</span>
      <h1>The Main Bold<br><span class="gradient-text">Headline Here</span></h1>
      <p>One to two lines of supporting copy that communicates the core value proposition clearly.</p>
      <div class="hero-actions">
        <a href="#" class="btn btn-primary">Primary Action</a>
        <a href="#" class="btn btn-ghost">Secondary Action</a>
      </div>
    </div>
  </section>

  <!-- ===== FEATURES ===== -->
  <section class="section-alt">
    <div class="container">
      <div class="section-header animate-on-scroll">
        <h2>Section Heading</h2>
        <p>Brief supporting description of this section's purpose.</p>
      </div>
      <div class="grid">
        <div class="card animate-on-scroll">
          <div class="card-icon">ICON</div>
          <h3>Feature One</h3>
          <p>Two to three lines of concise description explaining this feature or benefit.</p>
        </div>
        <div class="card animate-on-scroll">
          <div class="card-icon">ICON</div>
          <h3>Feature Two</h3>
          <p>Two to three lines of concise description explaining this feature or benefit.</p>
        </div>
        <div class="card animate-on-scroll">
          <div class="card-icon">ICON</div>
          <h3>Feature Three</h3>
          <p>Two to three lines of concise description explaining this feature or benefit.</p>
        </div>
      </div>
    </div>
  </section>

  <hr class="divider">

  <!-- ===== SHOWCASE (image + text split) ===== -->
  <section>
    <div class="container" style="display:grid; grid-template-columns:1fr 1fr; gap:64px; align-items:center;">
      <div class="image-container animate-on-scroll">
        <img src="REAL_IMAGE_URL" alt="Descriptive alt text" loading="lazy">
      </div>
      <div class="animate-on-scroll">
        <h2 style="font-size:var(--text-2xl); margin-bottom:1rem;">A Compelling Point</h2>
        <p style="margin-bottom:1.5rem;">Explain this section's key message in two or three sentences. Keep it scannable and benefit-oriented.</p>
        <a href="#" class="btn btn-primary">Call to Action</a>
      </div>
    </div>
  </section>

  <!-- ===== FOOTER ===== -->
  <footer>
    <div class="container">
      <span>Brand Name</span>
      <span>Built with care.</span>
    </div>
  </footer>

  <!-- ===== SCROLL ANIMATIONS ===== -->
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
</body>
</html>
```

### Customization Notes
- Replace `Space Grotesk` + `Inter` with your chosen pair from the web-design skill
- Replace `--accent: #8B5CF6` and `--accent-rgb` with your chosen accent
- Replace `EMOJI` in the favicon with a relevant emoji
- Replace `ICON` in card-icons with relevant emoji or inline SVG
- Replace `REAL_IMAGE_URL` with actual researched image URLs
- Replace ALL placeholder text with real researched content
- Add or remove sections as needed — 3-5 sections is the sweet spot
- The showcase grid becomes single-column on mobile via the responsive grid styles

---

## Phase 4: Quality Check

Run every check from the **design-review** skill (`~/.claurst/skills/design-review/SKILL.md`). If any check fails, fix it before deploying.

Additionally:
1. **Screenshot the site** using Playwright MCP at both desktop (1440px) and mobile (375px) widths
2. **Verify all images load** — check the browser console for 404s
3. **Read through all text** — catch typos, broken sentences, placeholder text you forgot to replace
4. **Check the footer** — does it have real content, not "Brand Name"?

---

## Phase 5: Deploy

```bash
cd /tmp/genie/<slug>-<ts>
npx vercel deploy --yes --prod --name genie-<slug> 2>&1 | tee deploy.log
```

### Post-Deploy Verification
1. Extract the production URL: `genie-<slug>.vercel.app` (NOT the hash URL)
2. Verify with `curl -sI https://genie-<slug>.vercel.app | head -5` — must return 200
3. If 401 (SSO-protected preview URL), you grabbed the wrong URL. Use the project alias.
4. Open the URL in Playwright, take a final screenshot, send to George on Telegram

### Report to George
Send a Telegram message with:
- The public URL
- A screenshot of the live site
- Brief description of what was built
- Any content you couldn't verify or find

---

## Common Patterns

### Adding a Navigation Bar
```css
nav {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  z-index: 100;
  padding: 16px 0;
  background: rgba(10, 10, 11, 0.8);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border-bottom: 1px solid var(--border-subtle);
}
nav .container {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
nav .logo {
  font-family: 'Space Grotesk', sans-serif;
  font-weight: 700;
  font-size: var(--text-lg);
  color: var(--text-primary);
}
nav .nav-links {
  display: flex;
  gap: 32px;
  list-style: none;
}
nav .nav-links a {
  color: var(--text-secondary);
  font-size: var(--text-sm);
  font-weight: 500;
  transition: color 0.2s;
}
nav .nav-links a:hover {
  color: var(--text-primary);
}
```

### Adding a Stats Row
```html
<section style="border-top:1px solid var(--border-subtle); border-bottom:1px solid var(--border-subtle);">
  <div class="container" style="display:flex; justify-content:center; gap:clamp(2rem,6vw,6rem); flex-wrap:wrap; text-align:center;">
    <div class="animate-on-scroll">
      <div style="font-size:var(--text-3xl); font-weight:700; color:var(--text-primary);">10K+</div>
      <div style="font-size:var(--text-sm); color:var(--text-tertiary); margin-top:0.25rem;">Users</div>
    </div>
    <div class="animate-on-scroll">
      <div style="font-size:var(--text-3xl); font-weight:700; color:var(--text-primary);">99.9%</div>
      <div style="font-size:var(--text-sm); color:var(--text-tertiary); margin-top:0.25rem;">Uptime</div>
    </div>
    <div class="animate-on-scroll">
      <div style="font-size:var(--text-3xl); font-weight:700; color:var(--text-primary);">50ms</div>
      <div style="font-size:var(--text-sm); color:var(--text-tertiary); margin-top:0.25rem;">Latency</div>
    </div>
  </div>
</section>
```

### Adding a CTA Band (before footer)
```html
<section style="text-align:center; background:var(--bg-secondary);">
  <div class="container animate-on-scroll" style="max-width:700px;">
    <h2 style="font-size:var(--text-3xl); margin-bottom:1rem;">Ready to Get Started?</h2>
    <p style="font-size:var(--text-lg); color:var(--text-secondary); margin-bottom:2rem;">One to two sentences that reinforce the value and create urgency.</p>
    <a href="#" class="btn btn-primary" style="padding:16px 40px; font-size:var(--text-lg);">Start Now</a>
  </div>
</section>
```
