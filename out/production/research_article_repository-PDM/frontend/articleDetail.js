const params = new URLSearchParams(window.location.search);
const articleId = params.get('id');
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

const article = cachedArticle();

function showMissingArticle() {
    detailEl.replaceChildren();
    const box = document.createElement('div');
    box.className = 'state-box';
    const title = document.createElement('h2');
    title.className = 'state-title';
    title.textContent = 'Article details unavailable';
    const message = document.createElement('p');
    message.textContent = 'This API currently only provides article lists. Open an article from Browse to view its title, authors and year.';
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

if (!article) {
    showMissingArticle();
} else {
    document.getElementById('detail-title').textContent = article.title;
    document.getElementById('detail-authors').textContent =
        article.authors.length ? article.authors.map(a => a.name).join(', ') : 'Unknown author';
    document.getElementById('detail-year').textContent = String(article.year);

    document.getElementById('detail-doi').textContent = 'Not provided by the API';
    document.getElementById('detail-abstract').textContent = 'Not provided by the API.';
    const note = document.getElementById('detail-api-note');
    note.hidden = false;
    note.textContent = 'The current GET /api/articles response provides only ID, title, year and authors. DOI, abstract and citation relationships need additional backend endpoints.';
    showCitationState('references-list', 'References unavailable', 'The current API does not provide reference data.');
    showCitationState('cited-by-list', 'Cited-by unavailable', 'The current API does not provide citing-article data.');
}
