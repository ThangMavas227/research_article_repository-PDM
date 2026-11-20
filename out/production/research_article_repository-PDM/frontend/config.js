/* Frontend settings for the Spring Boot GET /api/articles endpoint. */
window.APP_CONFIG = Object.freeze({
    API_URL: 'http://localhost:8080/api/articles',
    PAGE_SIZE: 10,            // Backend accepts size from 1 to 100.
    SELECTED_ARTICLE_KEY: 'research-repo-selected-article'
});
