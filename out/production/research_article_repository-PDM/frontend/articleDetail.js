/* The provided API contract supports GET /api/articles only.
 * Keep the selected list item for API-mode details, and never invent
 * DOI, abstract, references or cited-by records from mock data.
 */
const params = new URLSearchParams(window.location.search);
const articleId = params.get('id');
const mode = window.getArticleMode();
const detailEl = document.getElementById('articleDetail');

function cachedArticle() {
    try {
        const json = sessionStorage.getItem(window.APP_CONFIG.SELECTED_ARTICLE_KEY);
        const item = json ? JSON.parse(json) : null;
        return item && String(item.id) === articleId &&
            typeof item.title === 'string' && Array.isArray(item.authors) ? item : null;
    } catch (_) {
        return null;
    }
}

const articles = mode === 'mock' ? (window.MOCK_ARTICLES || []) : [];
const article = mode === 'mock'
    ? articles.find(a => a.id === articleId)
    : cachedArticle();

function showMissingArticle() {
    detailEl.replaceChildren();
    const box = document.createElement('div');
    box.className = 'state-box';
    const title = document.createElement('h2');
    title.className = 'state-title';
    title.textContent = mode === 'mock' ? 'Article not found' : 'Article details unavailable';
    const message = document.createElement('p');
    message.textContent = mode === 'mock'
        ? 'The requested article does not exist in the mock dataset.'
        : 'This API currently only provides article lists. Open an article from Browse to view its title, authors and year.';
    box.append(title, message);
    detailEl.appendChild(box);
}

function showCitationState(containerId, title, message) {
    const container = document.getElementById(containerId);
    container.replaceChildren();
    const box = document.createElement('div');
    box.className = 'state-box';
    const heading = document.createElement('div');
    heading.className = 'state-title';
    heading.textContent = title;
    const body = document.createElement('p');
    body.textContent = message;
    box.append(heading, body);
    container.appendChild(box);
}

function renderCitations(ids, containerId) {
    const relatedArticles = ids.map(id => articles.find(a => a.id === id)).filter(Boolean);
    if (relatedArticles.length === 0) {
        showCitationState(containerId, 'No citations found', 'No citations are recorded for this article in the mock data.');
        return;
    }

    const container = document.getElementById(containerId);
    container.replaceChildren();
    relatedArticles.forEach(item => {
        const row = document.createElement('article');
        row.className = 'article-row';
        const title = document.createElement('h3');
        title.className = 'article-title';
        const link = document.createElement('a');
        link.href = `articleDetail.html?id=${encodeURIComponent(item.id)}`;
        link.textContent = item.title;
        title.appendChild(link);
        const meta = document.createElement('div');
        meta.className = 'article-meta';
        meta.textContent = `${item.authors.map(a => a.name).join(', ')} (${item.year})`;
        row.append(title, meta);
        container.appendChild(row);
    });
}

if (!article) {
    showMissingArticle();
} else {
    document.getElementById('detail-title').textContent = article.title;
    document.getElementById('detail-authors').textContent =
        article.authors.length ? article.authors.map(a => a.name).join(', ') : 'Unknown author';
    document.getElementById('detail-year').textContent = String(article.year);

    if (mode === 'api') {
        document.getElementById('detail-doi').textContent = 'Not provided by the API';
        document.getElementById('detail-abstract').textContent = 'Not provided by the API.';
        const note = document.getElementById('detail-api-note');
        note.hidden = false;
        note.textContent = 'The current GET /api/articles response provides only ID, title, year and authors. DOI, abstract and citation relationships need additional backend endpoints.';
        showCitationState('references-list', 'References unavailable', 'The current API does not provide reference data.');
        showCitationState('cited-by-list', 'Cited-by unavailable', 'The current API does not provide citing-article data.');
    } else {
        const details = window.MOCK_DETAILS || {};
        const itemDetail = details[article.id];
        document.getElementById('detail-doi').textContent = itemDetail?.doi || 'Not available';
        document.getElementById('detail-abstract').textContent = itemDetail?.abstract || 'Abstract not available.';

        if (!itemDetail || !Array.isArray(itemDetail.references)) {
            showCitationState('references-list', 'Citation data unavailable', 'This article has no citation details in the mock dataset.');
            showCitationState('cited-by-list', 'Citation data unavailable', 'This article has no citation details in the mock dataset.');
        } else {
            const citedBy = Object.entries(details)
                .filter(([, detail]) => Array.isArray(detail.references) && detail.references.includes(article.id))
                .map(([id]) => id);
            renderCitations(itemDetail.references, 'references-list');
            renderCitations(citedBy, 'cited-by-list');
        }
    }
}
