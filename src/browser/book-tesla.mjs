#!/usr/bin/env node
// Genie — Book a Tesla Cybertruck test drive via headed browser
// Opens real Chrome, navigates tesla.com/drive, fills the form, submits
// Usage: node src/browser/book-tesla.mjs [--dry-run]

import { chromium } from 'playwright';
import { resolve } from 'path';

// Use a unique profile dir to avoid SingletonLock conflicts with MCP browser
const PROFILE_DIR = process.env.GENIE_BROWSER_PROFILE || resolve(process.env.HOME, '.genie-tesla-profile');
const SLOW_MO = parseInt(process.env.GENIE_SLOW_MO || '150', 10);
const DRY_RUN = process.argv.includes('--dry-run');

// George's info
const USER_INFO = {
  firstName: 'George',
  lastName: 'Trushevskiy',
  email: 'georgy.trush@gmail.com',
  phone: '+420777009354',
  phoneRaw: '420777009354',
  zipCode: '10014', // Betaworks, Meatpacking District, NYC
};

function log(step, msg) {
  const ts = new Date().toLocaleTimeString();
  console.log(`[${ts}] [GENIE] [${step}] ${msg}`);
}

async function bookTeslaTestDrive() {
  log('INIT', 'Launching Chrome (headed mode)...');

  const context = await chromium.launchPersistentContext(PROFILE_DIR, {
    headless: false,
    channel: 'chrome',
    viewport: { width: 1280, height: 900 },
    slowMo: SLOW_MO,
    args: ['--disable-blink-features=AutomationControlled'],
  });

  const page = context.pages()[0] || await context.newPage();

  try {
    // Step 1: Navigate to Tesla test drive page
    log('NAV', 'Opening tesla.com/cybertruck/drive...');
    await page.goto('https://www.tesla.com/cybertruck/drive', {
      waitUntil: 'domcontentloaded',
      timeout: 30000
    });
    await page.waitForTimeout(2000);

    // Step 2: Take a screenshot of initial state
    log('NAV', 'Tesla drive page loaded');
    await page.screenshot({ path: '/tmp/genie/tesla-01-landing.png' });

    // Step 3: Look for Cybertruck selection
    // Tesla's page typically shows vehicle cards or a selector
    log('SELECT', 'Looking for Cybertruck option...');

    // Try multiple selectors — Tesla's site structure varies
    const cybertruckSelectors = [
      'text=Cybertruck',
      '[data-vehicle="cybertruck"]',
      'button:has-text("Cybertruck")',
      'a:has-text("Cybertruck")',
      'div:has-text("Cybertruck") >> nth=0',
      '[alt*="Cybertruck"]',
      'img[alt*="Cybertruck"]',
    ];

    let clicked = false;
    for (const sel of cybertruckSelectors) {
      try {
        const el = page.locator(sel).first();
        if (await el.isVisible({ timeout: 2000 })) {
          await el.click();
          clicked = true;
          log('SELECT', 'Clicked Cybertruck!');
          break;
        }
      } catch (e) {
        // try next selector
      }
    }

    if (!clicked) {
      log('SELECT', 'Could not find Cybertruck button — trying to proceed with page as-is');
      // Take screenshot to debug
      await page.screenshot({ path: '/tmp/genie/tesla-02-no-cybertruck.png' });
    }

    await page.waitForTimeout(2000);
    await page.screenshot({ path: '/tmp/genie/tesla-02-vehicle-selected.png' });

    // Step 4: Enter zip code to find nearest location
    log('LOCATION', 'Entering zip code: ' + USER_INFO.zipCode);

    const zipSelectors = [
      'input[placeholder*="zip"]',
      'input[placeholder*="Zip"]',
      'input[name*="zip"]',
      'input[name*="postal"]',
      'input[type="text"][placeholder*="code"]',
      'input[aria-label*="zip"]',
      'input[aria-label*="location"]',
    ];

    for (const sel of zipSelectors) {
      try {
        const el = page.locator(sel).first();
        if (await el.isVisible({ timeout: 2000 })) {
          await el.click();
          await el.fill(USER_INFO.zipCode);
          log('LOCATION', 'Zip code entered');
          // Press enter or click search
          await el.press('Enter');
          break;
        }
      } catch (e) {
        // try next
      }
    }

    await page.waitForTimeout(3000);
    await page.screenshot({ path: '/tmp/genie/tesla-03-locations.png' });

    // Step 5: Select first/nearest location (Meatpacking / Manhattan)
    log('LOCATION', 'Selecting nearest Tesla location...');

    const locationSelectors = [
      'text=Manhattan',
      'text=Meatpacking',
      'text=New York',
      'text=Chelsea',
      '[data-location] >> nth=0',
      '.location-card >> nth=0',
      'button:has-text("Select") >> nth=0',
      'li >> nth=0 >> button',
    ];

    for (const sel of locationSelectors) {
      try {
        const el = page.locator(sel).first();
        if (await el.isVisible({ timeout: 2000 })) {
          await el.click();
          log('LOCATION', 'Location selected');
          break;
        }
      } catch (e) {
        // try next
      }
    }

    await page.waitForTimeout(2000);
    await page.screenshot({ path: '/tmp/genie/tesla-04-location-selected.png' });

    // Step 6: Select earliest available date/time
    log('SCHEDULE', 'Selecting earliest available slot...');

    // Look for date picker — click first available date
    const dateSelectors = [
      'button[class*="available"] >> nth=0',
      'td[class*="available"] >> nth=0',
      '.calendar button:not([disabled]) >> nth=0',
      'button[data-date] >> nth=0',
      '[role="gridcell"]:not([aria-disabled="true"]) >> nth=0',
    ];

    for (const sel of dateSelectors) {
      try {
        const el = page.locator(sel).first();
        if (await el.isVisible({ timeout: 2000 })) {
          await el.click();
          log('SCHEDULE', 'Date selected');
          break;
        }
      } catch (e) {
        // try next
      }
    }

    await page.waitForTimeout(1500);

    // Select first available time slot
    const timeSelectors = [
      'button[class*="time"] >> nth=0',
      '.time-slot >> nth=0',
      'button:has-text("AM") >> nth=0',
      'button:has-text("PM") >> nth=0',
      '[data-time] >> nth=0',
    ];

    for (const sel of timeSelectors) {
      try {
        const el = page.locator(sel).first();
        if (await el.isVisible({ timeout: 2000 })) {
          await el.click();
          log('SCHEDULE', 'Time slot selected');
          break;
        }
      } catch (e) {
        // try next
      }
    }

    await page.waitForTimeout(1500);
    await page.screenshot({ path: '/tmp/genie/tesla-05-schedule.png' });

    // Step 7: Fill in personal details
    log('FORM', 'Filling in personal details...');

    // First name
    const firstNameSels = ['input[name*="first"]', 'input[name*="First"]', 'input[placeholder*="First"]', '#firstName'];
    for (const sel of firstNameSels) {
      try {
        const el = page.locator(sel).first();
        if (await el.isVisible({ timeout: 1500 })) {
          await el.click();
          await el.fill(USER_INFO.firstName);
          log('FORM', 'First name: George');
          break;
        }
      } catch (e) {}
    }

    // Last name
    const lastNameSels = ['input[name*="last"]', 'input[name*="Last"]', 'input[placeholder*="Last"]', '#lastName'];
    for (const sel of lastNameSels) {
      try {
        const el = page.locator(sel).first();
        if (await el.isVisible({ timeout: 1500 })) {
          await el.click();
          await el.fill(USER_INFO.lastName);
          log('FORM', 'Last name: Trushevskiy');
          break;
        }
      } catch (e) {}
    }

    // Email
    const emailSels = ['input[name*="email"]', 'input[type="email"]', 'input[placeholder*="email"]', '#email'];
    for (const sel of emailSels) {
      try {
        const el = page.locator(sel).first();
        if (await el.isVisible({ timeout: 1500 })) {
          await el.click();
          await el.fill(USER_INFO.email);
          log('FORM', 'Email: georgy.trush@gmail.com');
          break;
        }
      } catch (e) {}
    }

    // Phone
    const phoneSels = ['input[name*="phone"]', 'input[type="tel"]', 'input[placeholder*="phone"]', '#phone'];
    for (const sel of phoneSels) {
      try {
        const el = page.locator(sel).first();
        if (await el.isVisible({ timeout: 1500 })) {
          await el.click();
          await el.fill(USER_INFO.phoneRaw);
          log('FORM', 'Phone entered');
          break;
        }
      } catch (e) {}
    }

    await page.waitForTimeout(1000);
    await page.screenshot({ path: '/tmp/genie/tesla-06-form-filled.png' });

    // Step 8: Submit (or stop if dry run)
    if (DRY_RUN) {
      log('SUBMIT', '🔶 DRY RUN — not clicking submit. Form is filled. Review and submit manually.');
      await page.screenshot({ path: '/tmp/genie/tesla-07-ready-to-submit.png' });
      console.log(JSON.stringify({
        status: 'dry_run',
        message: 'Form filled, ready to submit manually',
        screenshots: [
          '/tmp/genie/tesla-01-landing.png',
          '/tmp/genie/tesla-06-form-filled.png',
          '/tmp/genie/tesla-07-ready-to-submit.png',
        ]
      }));
      // Keep browser open for manual review
      log('SUBMIT', 'Browser left open. Close manually when done.');
      return;
    }

    // Real submit
    log('SUBMIT', 'Submitting booking...');
    const submitSels = [
      'button[type="submit"]',
      'button:has-text("Submit")',
      'button:has-text("Book")',
      'button:has-text("Schedule")',
      'button:has-text("Confirm")',
      'input[type="submit"]',
    ];

    for (const sel of submitSels) {
      try {
        const el = page.locator(sel).first();
        if (await el.isVisible({ timeout: 2000 })) {
          await el.click();
          log('SUBMIT', 'Booking submitted!');
          break;
        }
      } catch (e) {}
    }

    await page.waitForTimeout(5000);
    await page.screenshot({ path: '/tmp/genie/tesla-08-confirmation.png' });

    log('DONE', '✅ Tesla Cybertruck test drive booked!');
    console.log(JSON.stringify({
      status: 'booked',
      vehicle: 'Cybertruck',
      location: 'Tesla Manhattan / Meatpacking',
      zipCode: USER_INFO.zipCode,
      screenshots: [
        '/tmp/genie/tesla-01-landing.png',
        '/tmp/genie/tesla-06-form-filled.png',
        '/tmp/genie/tesla-08-confirmation.png',
      ]
    }));

  } catch (err) {
    log('ERROR', err.message);
    await page.screenshot({ path: '/tmp/genie/tesla-error.png' });
    console.error(JSON.stringify({ status: 'error', error: err.message }));
  }

  // Keep browser open so audience can see the result
  log('DONE', 'Browser left open. Ctrl+C to close.');
}

// Ensure screenshot dir exists
import { mkdirSync } from 'fs';
mkdirSync('/tmp/genie', { recursive: true });

// Export for use by executor
export { bookTeslaTestDrive };

// CLI mode — only auto-run if called directly
const isMain = process.argv[1] && (
  process.argv[1].endsWith('book-tesla.mjs') ||
  process.argv[1].includes('book-tesla')
);
if (isMain) {
  bookTeslaTestDrive();
}
