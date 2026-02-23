---
name: wp-admin-tester
description: "Debug issues in wp-admin on a local WordPress dev environment. Use when the user asks to debug wp-admin, test admin flows, check console errors, tail PHP logs, upload images, create posts, or troubleshoot any issue in the WordPress admin. Triggers include 'debug wp-admin', 'test in wp-admin', 'check the admin', 'upload an image', 'tail the PHP logs', 'check console errors', 'test this in the admin', or any local WordPress admin debugging task."
---

# WP-Admin Local Debugger

Debug and test WordPress admin flows in a local development environment. Combines browser automation, PHP log tailing, and console error capture to diagnose issues end-to-end. This skill focuses exclusively on wp-admin interactions — all testing is done through the browser (Playwright) or direct page fetches with cookie auth.

## Local Environment

| Setting | Value |
|---------|-------|
| Admin URL | `https://wpdev.localhost/wp-admin` |
| Username | `admin` |
| Password | `password` |
| PHP error log | `/Applications/MAMP/logs/php_error.log` |
| Test image | `~/Downloads/IMG_0299.jpg` (or any image the user specifies) |

## Authentication (Cookie Auth)

All operations use cookie-based authentication, the same way a real admin user interacts with wp-admin.

```bash
# Log in and save cookies
curl -sk -c /tmp/wp-cookies.txt -b /tmp/wp-cookies.txt \
  -d "log=admin&pwd=password&wp-submit=Log+In&redirect_to=%2Fwp-admin%2F&testcookie=1" \
  "https://wpdev.localhost/wp-login.php"
```

## Core Operations

### Navigate to Any Admin Page

```bash
# Fetch any admin page (check for errors, verify content)
curl -sk -b /tmp/wp-cookies.txt "https://wpdev.localhost/wp-admin/edit.php" | head -100

# Check if a page loads without PHP errors
curl -sk -b /tmp/wp-cookies.txt -o /dev/null -w "%{http_code}" "https://wpdev.localhost/wp-admin/options-general.php"
```

## Log Monitoring

### Tail PHP Error Log

```bash
# Start tailing in background, capture to a temp file for later review
tail -f /Applications/MAMP/logs/php_error.log > /tmp/php-errors-session.log 2>&1 &
TAIL_PID=$!

# ... perform the operation being debugged ...

# Stop tailing and review captured errors
kill $TAIL_PID 2>/dev/null
cat /tmp/php-errors-session.log
```

### Check Recent PHP Errors

```bash
# Last 50 lines of PHP error log
tail -50 /Applications/MAMP/logs/php_error.log

# Search for errors in the last few minutes
grep "$(date +%d-%b-%Y)" /Applications/MAMP/logs/php_error.log | tail -30
```

### Add Temporary PHP Debug Logging

When debugging a specific issue, add targeted error_log() calls:

```php
// Add to the function being debugged
error_log( 'DEBUG: function_name called with args: ' . print_r( $args, true ) );
error_log( 'DEBUG: variable state: ' . var_export( $variable, true ) );
```

Remember to remove debug logging after the investigation.

## Browser Automation (Console Errors & Interactive Testing)

For capturing JavaScript console errors and testing interactive admin flows, use Playwright.

### Setup (one-time)

```bash
# Install Playwright if not already available
npm ls playwright 2>/dev/null || npm install -D playwright
npx playwright install chromium
```

### Capture Console Errors on a Page

Create and run a temporary Playwright script:

```javascript
// /tmp/wp-admin-test.mjs
import { chromium } from 'playwright';

const browser = await chromium.launch({
  ignoreHTTPSErrors: true,
});
const context = await browser.newContext({
  ignoreHTTPSErrors: true,
});
const page = await context.newPage();

// Collect console errors
const consoleErrors = [];
page.on('console', msg => {
  if (msg.type() === 'error') {
    consoleErrors.push({ text: msg.text(), location: msg.location() });
  }
});
page.on('pageerror', err => {
  consoleErrors.push({ text: err.message, stack: err.stack });
});

// Log in
await page.goto('https://wpdev.localhost/wp-login.php');
await page.fill('#user_login', 'admin');
await page.fill('#user_pass', 'password');
await page.click('#wp-submit');
await page.waitForURL('**/wp-admin/**');

// Navigate to the target page (replace with the actual page)
await page.goto('https://wpdev.localhost/wp-admin/post-new.php');
await page.waitForLoadState('networkidle');

// Wait a moment for any deferred JS errors
await page.waitForTimeout(3000);

// Report results
if (consoleErrors.length > 0) {
  console.log('=== CONSOLE ERRORS FOUND ===');
  consoleErrors.forEach((err, i) => {
    console.log(`\n--- Error ${i + 1} ---`);
    console.log(err.text);
    if (err.location) console.log(`Location: ${err.location.url}:${err.location.lineNumber}`);
    if (err.stack) console.log(`Stack: ${err.stack}`);
  });
} else {
  console.log('No console errors detected.');
}

await browser.close();
```

```bash
node /tmp/wp-admin-test.mjs
```

### Create a Post and Insert an Image in the Block Editor

This tests post creation and image uploading entirely through wp-admin using the block editor:

```javascript
// /tmp/wp-admin-image-test.mjs
import { chromium } from 'playwright';
import path from 'path';

const browser = await chromium.launch({ ignoreHTTPSErrors: true });
const context = await browser.newContext({ ignoreHTTPSErrors: true });
const page = await context.newPage();

const consoleErrors = [];
const networkErrors = [];

page.on('console', msg => {
  if (msg.type() === 'error') {
    consoleErrors.push({ text: msg.text(), location: msg.location() });
  }
});
page.on('pageerror', err => {
  consoleErrors.push({ text: err.message, stack: err.stack });
});
page.on('response', response => {
  if (response.status() >= 400) {
    networkErrors.push({ url: response.url(), status: response.status() });
  }
});

// Log in
await page.goto('https://wpdev.localhost/wp-login.php');
await page.fill('#user_login', 'admin');
await page.fill('#user_pass', 'password');
await page.click('#wp-submit');
await page.waitForURL('**/wp-admin/**');

// Create a new post in the block editor
await page.goto('https://wpdev.localhost/wp-admin/post-new.php');
await page.waitForLoadState('networkidle');
await page.waitForTimeout(2000);

// Dismiss the welcome guide if present
const welcomeButton = page.locator('button:has-text("Get started")');
if (await welcomeButton.isVisible({ timeout: 2000 }).catch(() => false)) {
  await welcomeButton.click();
}

// Type a post title
await page.locator('[aria-label="Add title"]').fill('Test Post with Image');

// Add an Image block using the slash command inserter
await page.click('.block-editor-default-block-appender__content');
await page.keyboard.type('/image');
await page.waitForTimeout(1000);
await page.keyboard.press('Enter');
await page.waitForTimeout(1000);

// Upload an image file via the file input in the Image block
const fileInput = page.locator('input[type="file"]');
await fileInput.setInputFiles(path.join(process.env.HOME, 'Downloads', 'IMG_0299.jpg'));

// Wait for the upload to complete
await page.waitForTimeout(5000);

// Check if the image block now has an image
const imgElement = page.locator('.wp-block-image img');
const hasImage = await imgElement.isVisible({ timeout: 10000 }).catch(() => false);
if (hasImage) {
  const src = await imgElement.getAttribute('src');
  console.log('Image uploaded successfully:', src);
} else {
  console.log('WARNING: Image may not have uploaded — no img element found in block.');
}

// Report errors
console.log(`\nConsole errors: ${consoleErrors.length}`);
consoleErrors.forEach((err, i) => console.log(`  ${i + 1}. ${err.text}`));
console.log(`Network errors: ${networkErrors.length}`);
networkErrors.forEach((err, i) => console.log(`  ${i + 1}. ${err.status} ${err.url}`));

await browser.close();
```

```bash
node /tmp/wp-admin-image-test.mjs
```

### Test Image Upload via Media Library

```javascript
// /tmp/wp-admin-upload-test.mjs
import { chromium } from 'playwright';

const browser = await chromium.launch({ ignoreHTTPSErrors: true });
const context = await browser.newContext({ ignoreHTTPSErrors: true });
const page = await context.newPage();

const consoleErrors = [];
page.on('console', msg => {
  if (msg.type() === 'error') {
    consoleErrors.push({ text: msg.text(), location: msg.location() });
  }
});
page.on('pageerror', err => {
  consoleErrors.push({ text: err.message, stack: err.stack });
});

// Log in
await page.goto('https://wpdev.localhost/wp-login.php');
await page.fill('#user_login', 'admin');
await page.fill('#user_pass', 'password');
await page.click('#wp-submit');
await page.waitForURL('**/wp-admin/**');

// Go to Media > Add New
await page.goto('https://wpdev.localhost/wp-admin/media-new.php');
await page.waitForLoadState('networkidle');

// Upload file via the file input
const fileInput = await page.locator('input[type="file"]');
await fileInput.setInputFiles(process.env.HOME + '/Downloads/IMG_0299.jpg');

// Wait for upload to complete
await page.waitForTimeout(5000);

// Check for success or errors
const successMsg = await page.locator('.media-item .filename').textContent().catch(() => null);
if (successMsg) {
  console.log('Upload succeeded:', successMsg);
}

if (consoleErrors.length > 0) {
  console.log('\n=== CONSOLE ERRORS DURING UPLOAD ===');
  consoleErrors.forEach((err, i) => {
    console.log(`\n--- Error ${i + 1} ---`);
    console.log(err.text);
  });
} else {
  console.log('No console errors during upload.');
}

await browser.close();
```

### Test in Block Editor (Gutenberg)

```javascript
// /tmp/wp-admin-editor-test.mjs
import { chromium } from 'playwright';

const browser = await chromium.launch({ ignoreHTTPSErrors: true });
const context = await browser.newContext({ ignoreHTTPSErrors: true });
const page = await context.newPage();

const consoleErrors = [];
const networkErrors = [];

page.on('console', msg => {
  if (msg.type() === 'error') {
    consoleErrors.push({ text: msg.text(), location: msg.location() });
  }
});
page.on('pageerror', err => {
  consoleErrors.push({ text: err.message, stack: err.stack });
});
page.on('response', response => {
  if (response.status() >= 400) {
    networkErrors.push({ url: response.url(), status: response.status() });
  }
});

// Log in
await page.goto('https://wpdev.localhost/wp-login.php');
await page.fill('#user_login', 'admin');
await page.fill('#user_pass', 'password');
await page.click('#wp-submit');
await page.waitForURL('**/wp-admin/**');

// Open block editor for new post
await page.goto('https://wpdev.localhost/wp-admin/post-new.php');
await page.waitForLoadState('networkidle');
await page.waitForTimeout(3000);

// Add an image block and upload
// Click the inserter
await page.click('[aria-label="Toggle block inserter"]').catch(() => {});
await page.waitForTimeout(1000);

// Report
console.log(`Console errors: ${consoleErrors.length}`);
consoleErrors.forEach((err, i) => console.log(`  ${i + 1}. ${err.text}`));
console.log(`Network errors: ${networkErrors.length}`);
networkErrors.forEach((err, i) => console.log(`  ${i + 1}. ${err.status} ${err.url}`));

await browser.close();
```

## Debugging Workflow

When asked to debug a wp-admin issue, follow this procedure:

### 1. Start Log Monitoring

```bash
# Clear old entries and start fresh tail in background
echo "--- Debug session started $(date) ---" >> /Applications/MAMP/logs/php_error.log
tail -f /Applications/MAMP/logs/php_error.log &
```

### 2. Add Debug Code (if needed)

- Add `error_log()` calls to the PHP code being investigated
- Add `console.log()` or breakpoints to JS code being investigated
- Use `wp_die()` with debug info for quick checks

### 3. Reproduce the Issue

Choose the appropriate method:

- **Browser automation** (for UI/JS issues, interactive flows, image uploads): Use Playwright to navigate, interact, and capture console errors
- **Direct page fetch** (for PHP rendering issues, HTTP status checks): Use curl with cookies

### 4. Collect Evidence

```bash
# Check PHP errors captured during the test
tail -50 /Applications/MAMP/logs/php_error.log

# If using Playwright, the console errors are captured automatically

# Check WordPress debug.log if WP_DEBUG_LOG is enabled
# Replace <site-docroot> with your MAMP site document root, e.g. /Applications/MAMP/htdocs/wpdev
tail -50 /Applications/MAMP/htdocs/<site-docroot>/wp-content/debug.log 2>/dev/null
```

### 5. Analyze and Fix

- Cross-reference PHP errors with JS console errors
- Identify the root cause
- Apply the fix
- Re-run the test to confirm

### 6. Clean Up

- Remove any `error_log()` debug statements added
- Remove temporary Playwright scripts
- Stop background tail processes

## Quick Reference

| Task | Command |
|------|---------|
| Log in (cookies) | `curl -sk -c /tmp/wp-cookies.txt -d "log=admin&pwd=password&wp-submit=Log+In&redirect_to=%2Fwp-admin%2F&testcookie=1" "https://wpdev.localhost/wp-login.php"` |
| Tail PHP log | `tail -f /Applications/MAMP/logs/php_error.log` |
| Recent PHP errors | `tail -50 /Applications/MAMP/logs/php_error.log` |
| Check admin page | `curl -sk -b /tmp/wp-cookies.txt -o /dev/null -w "%{http_code}" "https://wpdev.localhost/wp-admin/PAGE"` |
| Console errors | Run Playwright script (see browser automation section) |
| Create post + image | Run block editor Playwright script (see browser automation section) |
| Upload via Media Library | Run media upload Playwright script (see browser automation section) |

## Important Rules

- All testing is done through wp-admin — use cookie auth for curl requests and Playwright for interactive flows
- Do not use the REST API or application passwords — this skill is for testing wp-admin interactions only
- Tail the PHP log before and during reproduction to catch transient errors
- When using Playwright, always collect both console errors AND network errors (failed requests)
- Remove all temporary debug code (`error_log`, `console.log`) after investigation
- Report findings clearly: what was tested, what errors were found, where they originated
- If an issue requires changes to WordPress core or plugin code, make the fix, then re-test to confirm
- Keep temporary scripts in `/tmp/` so they are automatically cleaned up
