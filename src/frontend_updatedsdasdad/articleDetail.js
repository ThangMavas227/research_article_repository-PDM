/* Article Detail: always retrieve the latest record from the Spring Boot API.
 * Do not read sessionStorage: previously selected articles may be stale after Admin edits.
 */
const params = new URLSearchParams(window.location.search);
const articleId = params.get('id');
const detailEl = document.getElementById('articleDetail');
let latestRequestId = 0;

function showMessage(title, message) {
    detailEl.replaceChildren();
    const box = document.createElement('div');
    box.className = 'state-box';
    const heading = document.createElement('h2');
    heading.className = 'state-title';
    heading.textContent = title;
    const body = document.createElement('p');
    body.textContent = message;
    box.append(heading, body);
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

// New API: references/citedBy already contain the related article's id and title.
// A real empty array is not the same as a missing field in an older API response.
function renderApiCitations(items, containerId, emptyTitle, emptyMessage) {
    if (!Array.isArray(items)) {
        showCitationState(containerId, 'Citation data unavailable',
            'The API response did not include this citation list.');
        return;
    }
    if (items.length === 0) {
        showCitationState(containerId, emptyTitle, emptyMessage);
        return;
    }

    const container = document.getElementById(containerId);
    container.replaceChildren();
    items.forEach(item => {
        if (!item || item.id == null || typeof item.title !== 'string') return;
        const row = document.createElement('article');
        row.className = 'article-row';
        const title = document.createElement('h3');
        title.className = 'article-title';
        const link = document.createElement('a');
        // The target page always retrieves a fresh article record from the API.
        link.href = `articleDetail.html?id=${encodeURIComponent(String(item.id))}`;
        link.textContent = item.title;
        title.appendChild(link);
        const meta = document.createElement('div');
        meta.className = 'article-meta';
        meta.textContent = `Article ID: ${item.id}`;
        row.append(title, meta);
        container.appendChild(row);
    });
}

function renderDetail(article) {
    document.getElementById('detail-title').textContent = article.title;
    document.getElementById('detail-authors').textContent =
        article.authors.length ? article.authors.map(a => a.name).join(', ') : 'Unknown author';
    document.getElementById('detail-year').textContent = String(article.year);

    document.getElementById('detail-doi').textContent = article.doi?.trim() || 'Not available';
    document.getElementById('detail-abstract').textContent = article.abstract?.trim() || 'Abstract not available.';
    const missing = !Array.isArray(article.references) || !Array.isArray(article.citedBy);
    const note = document.getElementById('detail-api-note');
    note.hidden = !missing;
    if (missing) note.textContent = 'The backend response is missing one or more citation fields. Make sure the updated backend is running.';
    renderApiCitations(article.references, 'references-list',
        'No references recorded', 'This article has no recorded references.');
    renderApiCitations(article.citedBy, 'cited-by-list',
        'No citing articles recorded', 'No articles in the repository currently cite this article.');
}

/* The backend currently has no GET /api/articles/{id} endpoint.
 * For a direct URL / a clicked citation, look up the ID in paginated list results.
 * Use size=100 (the controller's maximum) to minimize requests; do not assume that
 * the article lives on the first page. A dedicated detail endpoint is preferable
 * if the repository becomes large.
 */
async function findArticleFromApi(id) {
    const url = new URL(window.APP_CONFIG.API_URL, window.location.href);
    url.searchParams.set('size', '100');
    let page = 1;
    while (true) {
        url.searchParams.set('page', String(page));
        const response = await fetch(url, {
            cache: 'no-store',
            headers: { Accept: 'application/json' }
        });
        if (!response.ok) throw new Error(`Backend request failed (HTTP ${response.status}).`);
        const data = await response.json();
        if (!data || !Array.isArray(data.items) || !Number.isInteger(data.totalPages) || data.totalPages < 0) {
            throw new Error('Unexpected API response format.');
        }
        const item = data.items.find(article => String(article.id) === id);
        if (item) return item;
        if (page >= data.totalPages) return null;
        page++;
    }
}

async function initDetail() {
    const requestId = ++latestRequestId;
    if (!articleId) {
        showMessage('Article not found', 'No article ID was supplied in the URL.');
        return;
    }

    // Show a loading state instead of displaying old article fields during refresh.
    const title = document.getElementById('detail-title');
    if (!title) {
        // The original markup can be replaced by an error/not-found message.
        window.location.reload();
        return;
    }
    title.textContent = 'Loading article details...';
    for (const id of ['detail-authors', 'detail-year', 'detail-doi', 'detail-abstract']) {
        document.getElementById(id).textContent = '';
    }
    document.getElementById('references-list').replaceChildren();
    document.getElementById('cited-by-list').replaceChildren();
    document.getElementById('detail-api-note').hidden = true;

    try {
        // Always re-fetch, even if a previous visit put this article in sessionStorage.
        const article = await findArticleFromApi(articleId);
        if (requestId !== latestRequestId) return;
        if (!article) {
            showMessage('Article not found', 'No article with this ID was found in the backend.');
            return;
        }
        renderDetail(article);
    } catch (error) {
        if (requestId !== latestRequestId) return;
        console.error('[Article Detail]', error);
        showMessage('Could not load article details',
            'Could not load data from the backend. Check that Spring Boot and MySQL are running, then try again.');
    }
}

// Browser back/forward cache (bfcache) can restore an old DOM without rerunning JS.
window.addEventListener('pageshow', event => {
    if (event.persisted) window.location.reload();
});

// If an Admin edited the article in another tab, re-check when this tab becomes visible.
document.addEventListener('visibilitychange', () => {
    if (!document.hidden) initDetail();
});

initDetail();
