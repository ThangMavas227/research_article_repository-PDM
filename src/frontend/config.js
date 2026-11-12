/*
 * Live Server sometimes opens pages at 127.0.0.1:5500, while the team backend
 * only allows CORS origins matching http://localhost:*.  These names refer to
 * the same computer but are DIFFERENT browser origins.
 *
 * Move the frontend tab to localhost, keeping its port/path/query/hash.
 * This does not change the backend URL or disable CORS security.
 */
if (window.location.protocol === 'http:' &&
    window.location.hostname === '127.0.0.1' &&
    window.location.port && window.location.port !== '8080') {
    const localhostUrl = new URL(window.location.href);
    localhostUrl.hostname = 'localhost';
    window.location.replace(localhostUrl.href);
}

/* Shared frontend settings. The supplied backend runs on port 8080 by default. */
window.APP_CONFIG = Object.freeze({
    API_URL: 'http://localhost:8080/api/articles',
    PAGE_SIZE: 10,
    MOCK_DELAY_MS: 600,
    DEFAULT_MODE: 'api',
    MODE_STORAGE_KEY: 'research-repo-data-mode',
    SELECTED_ARTICLE_KEY: 'research-repo-selected-article'
});

window.getArticleMode = function () {
    try {
        const mode = sessionStorage.getItem(window.APP_CONFIG.MODE_STORAGE_KEY);
        return mode === 'mock' || mode === 'api' ? mode : window.APP_CONFIG.DEFAULT_MODE;
    } catch (_) {
        return window.APP_CONFIG.DEFAULT_MODE;
    }
};

window.setArticleMode = function (mode) {
    if (mode !== 'api' && mode !== 'mock') return;
    try {
        sessionStorage.setItem(window.APP_CONFIG.MODE_STORAGE_KEY, mode);
        sessionStorage.removeItem(window.APP_CONFIG.SELECTED_ARTICLE_KEY);
    } catch (_) {
        // The app still works when browser storage is disabled on the Browse page.
    }
};
