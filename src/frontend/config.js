/*
 * Frontend integration settings for GET /api/articles.
 * Keep USE_API = false until your local Spring Boot + MySQL are ready.
 * Set it to true to start in API mode, or switch modes on the Browse page.
 * The backend's CorsConfig allows both localhost and 127.0.0.1 origins.
 */
window.APP_CONFIG = Object.freeze({
    API_URL: 'http://localhost:8080/api/articles',
    USE_API: false,
    PAGE_SIZE: 10,            // Backend accepts size from 1 to 100.
    MOCK_DELAY_MS: 600,
    // New key avoids a saved API preference from an older build overriding USE_API=false.
    MODE_STORAGE_KEY: 'research-repo-data-mode-v3',
    SELECTED_ARTICLE_KEY: 'research-repo-selected-article'
});

window.getArticleMode = function () {
    const defaultMode = window.APP_CONFIG.USE_API ? 'api' : 'mock';
    try {
        const mode = sessionStorage.getItem(window.APP_CONFIG.MODE_STORAGE_KEY);
        return mode === 'mock' || mode === 'api' ? mode : defaultMode;
    } catch (_) {
        return defaultMode;
    }
};

window.setArticleMode = function (mode) {
    if (mode !== 'api' && mode !== 'mock') return;
    try {
        sessionStorage.setItem(window.APP_CONFIG.MODE_STORAGE_KEY, mode);
        sessionStorage.removeItem(window.APP_CONFIG.SELECTED_ARTICLE_KEY);
    } catch (_) {
        // Browse keeps working even when sessionStorage is unavailable.
    }
};
