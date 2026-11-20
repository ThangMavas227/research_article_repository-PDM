# Manage Content layout update

Changes are limited to the Manage Content page (`articleEditor.html`, `articleEditor.css`, `articleEditor.js`).

- Three navigation tabs: **Articles**, **Add Article**, **Referenced Authors**.
- Only one content view is visible at a time. The visible panel occupies the full available content width.
- Articles use two columns on desktop (six per page). Referenced Authors use three columns on wide desktop, two on medium widths, one on narrow mobile (twelve per page).
- The Add/Edit form has a dedicated full-width panel. Clicking **Edit** from Articles opens that panel with the article loaded; clicking **Add Article** resets it to create mode.
- Existing API endpoints, admin session checks, validation, Create/Update/Delete calls and Reload from MySQL are unchanged.
- Arrow Left/Right, Home and End work on the three tabs.

## Run and verify

1. Extract the entire ZIP to a *new* directory (avoid mixing old and new files).
2. Start your existing frontend dev server from the extracted `frontend_update` directory. Ensure your Java backend is running as configured in `config.js`, and log in using an admin account.
3. Open `articleEditor.html`. Click each of the three tabs and verify the record panel expands across the page.
4. Test Add, Edit, Reload and Delete against your actual backend before deploying. This package does not include a Java backend.

The page includes its Option A theme CSS inline. Both the HTML's embedded style and `articleEditor.css` have the updated layout so the page does not depend on an additional theme asset.

### UI verification performed

Chromium/Playwright smoke checks were run against *mocked* article API responses at 1440px and 390px, checking panel dimensions, tab switches, card counts, Edit → form, and Add → cleared form. JavaScript syntax was validated. No live backend API tests were performed.
