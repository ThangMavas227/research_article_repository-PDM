/* Shared settings for the real Spring Boot / MySQL API. */
window.APP_CONFIG = Object.freeze({
    API_URL: 'http://localhost:8080/api/articles',
    PAGE_SIZE: 10, // Backend accepts a page size between 1 and 100.
    SELECTED_ARTICLE_KEY: 'research-repo-api-selected-article'
});
