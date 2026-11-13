/* Browse/Search: matches GET /api/articles?keyword=&year=&page=1&size=10.
 * Use the real backend only when selected. Mock mode follows the same response contract.
 */
const CONFIG = window.APP_CONFIG;
const state = {
    page: 1,
    keyword: '',
    year: null,
    mode: window.getArticleMode(),
    scenario: 'normal', // mock-only: normal, empty, error
    requestId: 0,
    controller: null
};

const $ = id => document.getElementById(id);
const listEl = $('article-list');
const statusEl = $('status-region');
const pagerEl = $('pagination');

const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

// Backend article: { id, title, year, authors: [{ id, name }] }
function normalizeArticle(raw) {
    const validId = (typeof raw?.id === 'string' && raw.id.trim() !== '') ||
        (typeof raw?.id === 'number' && Number.isInteger(raw.id));
    if (!validId || typeof raw.title !== 'string' || !Number.isInteger(raw.year) ||
        !Array.isArray(raw.authors) || raw.authors.some(author =>
            !author ||
            !(typeof author.id === 'string' || Number.isInteger(author.id)) ||
            typeof author.name !== 'string')) {
        throw new Error('Invalid article data returned by the server.');
    }
    return {
        id: String(raw.id),
        title: raw.title,
        year: raw.year,
        authors: raw.authors.map(author => ({ id: String(author.id), name: author.name }))
    };
}

// Backend response: { items, page, size, totalItems, totalPages }
function normalizeResponse(data) {
    if (!data || !Array.isArray(data.items) ||
        !Number.isInteger(data.page) || data.page < 1 ||
        !Number.isInteger(data.size) || data.size < 1 ||
        !Number.isInteger(data.totalItems) || data.totalItems < 0 ||
        !Number.isInteger(data.totalPages) || data.totalPages < 0 ||
        data.items.length > data.size ||
        data.totalPages !== Math.ceil(data.totalItems / data.size)) {
        throw new Error('Invalid API response format. Expected items, page, size, totalItems and totalPages.');
    }
    return { ...data, items: data.items.map(normalizeArticle) };
}

async function getArticles({ page, keyword, year, mode, scenario, signal }) {
    if (mode === 'mock') {
        await delay(CONFIG.MOCK_DELAY_MS);
        if (scenario === 'error') throw new Error('Simulated network error (mock mode).');
        if (!Array.isArray(window.MOCK_ARTICLES)) throw new Error('Mock data is not loaded.');
        const matched = searchArticles(window.MOCK_ARTICLES, keyword);
        const source = scenario === 'empty' ? [] : matched.filter(article => year === null || article.year === year);
        const start = (page - 1) * CONFIG.PAGE_SIZE;
        return normalizeResponse({
            items: source.slice(start, start + CONFIG.PAGE_SIZE),
            page,
            size: CONFIG.PAGE_SIZE,
            totalItems: source.length,
            totalPages: Math.ceil(source.length / CONFIG.PAGE_SIZE)
        });
    }

    // Actual API request. Do not filter or paginate the server's result again.
    const url = new URL(CONFIG.API_URL, window.location.href);
    url.searchParams.set('page', String(page));
    url.searchParams.set('size', String(CONFIG.PAGE_SIZE));
    if (keyword) url.searchParams.set('keyword', keyword);
    if (year !== null) url.searchParams.set('year', String(year));

    const response = await fetch(url, {
        method: 'GET',
        headers: { Accept: 'application/json' },
        signal
    });
    if (!response.ok) {
        let message = `Request failed (HTTP ${response.status}).`;
        try {
            const errorData = await response.json();
            if (typeof errorData.error === 'string' && errorData.error.trim()) {
                message = errorData.error;
            }
        } catch (_) { /* keep HTTP status */ }
        const error = new Error(`HTTP ${response.status}: ${message}`);
        error.status = response.status;
        throw error;
    }
    return normalizeResponse(await response.json());
}

function showLoading() {
    pagerEl.hidden = true;
    statusEl.textContent = 'Loading articles...';
    $('count-pill').textContent = 'Loading...';
    $('page-label').textContent = '';
    listEl.replaceChildren();

    for (let i = 0; i < 4; i++) {
        const row = document.createElement('div');
        row.className = 'skeleton';
        for (const width of ['wide', 'short', 'year']) {
            const bar = document.createElement('div');
            bar.className = `shimmer ${width}`;
            row.appendChild(bar);
        }
        listEl.appendChild(row);
    }
}

function showState(kind, title, message) {
    listEl.replaceChildren();
    pagerEl.hidden = true;
    const wrapper = document.createElement('div');
    wrapper.className = `state-box ${kind}`;

    const icon = document.createElement('div');
    icon.className = 'state-icon';
    icon.textContent = kind === 'error' ? '!' : '○';

    const heading = document.createElement('div');
    heading.className = 'state-title';
    heading.textContent = title;

    const body = document.createElement('p');
    body.textContent = message;
    wrapper.append(icon, heading, body);

    if (kind === 'error') {
        const retry = document.createElement('button');
        retry.className = 'retry-btn';
        retry.type = 'button';
        retry.textContent = 'Try again';
        retry.addEventListener('click', loadPage);
        wrapper.appendChild(retry);
    }
    listEl.appendChild(wrapper);
}

function rememberArticle(article) {
    try {
        sessionStorage.setItem(CONFIG.SELECTED_ARTICLE_KEY, JSON.stringify(article));
    } catch (_) { /* detail page will explain that article data is not available */ }
}

function renderArticles(items) {
    listEl.replaceChildren();
    for (const article of items) {
        const row = document.createElement('article');
        row.className = 'article-row';
        const title = document.createElement('h3');
        title.className = 'article-title';
        const link = document.createElement('a');
        link.href = `articleDetail.html?id=${encodeURIComponent(article.id)}`;
        link.textContent = article.title;
        link.addEventListener('click', () => rememberArticle(article));
        title.appendChild(link);

        const meta = document.createElement('div');
        meta.className = 'article-meta';
        const authors = document.createElement('div');
        const authorsLabel = document.createElement('span');
        authorsLabel.className = 'meta-name';
        authorsLabel.textContent = 'Authors:';
        authors.append(authorsLabel, document.createTextNode(
            article.authors.length ? article.authors.map(a => a.name).join(', ') : 'Unknown author'
        ));

        const year = document.createElement('div');
        const yearLabel = document.createElement('span');
        yearLabel.className = 'meta-name';
        yearLabel.textContent = 'Published:';
        const yearValue = document.createElement('span');
        yearValue.className = 'meta-year';
        yearValue.textContent = String(article.year);
        year.append(yearLabel, yearValue);
        meta.append(authors, year);
        row.append(title, meta);
        listEl.appendChild(row);
    }
}

function renderPager(page, totalPages) {
    pagerEl.hidden = totalPages <= 1;
    $('page-info').textContent = `Page ${page} of ${totalPages}`;
    $('prev-btn').disabled = page <= 1;
    $('next-btn').disabled = page >= totalPages;
}

async function loadPage() {
    const requestId = ++state.requestId;
    if (state.controller) state.controller.abort();
    state.controller = new AbortController();
    const request = {
        page: state.page,
        keyword: state.keyword,
        year: state.year,
        mode: state.mode,
        scenario: state.scenario,
        signal: state.controller.signal
    };
    showLoading();

    try {
        const result = await getArticles(request);
        if (requestId !== state.requestId) return;

        // Data may have been deleted while the user was on a later page.
        if (result.totalPages > 0 && state.page > result.totalPages) {
            state.page = result.totalPages;
            loadPage();
            return;
        }
        state.page = result.page;
        statusEl.textContent = '';
        $('count-pill').textContent = `${result.totalItems} article${result.totalItems === 1 ? '' : 's'}`;

        if (result.totalItems === 0 || result.items.length === 0) {
            $('page-label').textContent = '';
            const criteria = [
                state.keyword ? `keyword "${state.keyword}"` : null,
                state.year !== null ? `year ${state.year}` : null
            ].filter(Boolean).join(' and ');
            showState('empty', 'No articles found', criteria
                ? `No articles match ${criteria}. Try different filters.`
                : 'There are no articles to display at the moment.');
            return;
        }
        const start = (result.page - 1) * result.size + 1;
        const end = start + result.items.length - 1;
        $('page-label').textContent = `Showing ${start}–${end} of ${result.totalItems}`;
        renderArticles(result.items);
        renderPager(result.page, result.totalPages);
    } catch (err) {
        if (requestId !== state.requestId || err.name === 'AbortError') return;
        statusEl.textContent = '';
        $('count-pill').textContent = 'Unavailable';
        $('page-label').textContent = '';
        showState('error', 'Could not load articles',
            err?.name === 'TypeError' && state.mode === 'api'
                ? `Cannot connect to ${CONFIG.API_URL}. Check that Spring Boot is running on port 8080, MySQL is accessible, and CORS allows this page's origin (${window.location.origin}).`
                : err.message || 'Something went wrong. Please try again.');
        console.error('[Browse Articles]', err);
    }
}

$('prev-btn').addEventListener('click', () => {
    if (state.page > 1) { state.page--; loadPage(); }
});
$('next-btn').addEventListener('click', () => {
    state.page++;
    loadPage();
});
$('browse-filter-form').addEventListener('submit', event => {
    event.preventDefault();
    const yearText = $('year').value.trim();
    // Validate before sending the request. HTTP 400 from the API is handled by getArticles().
    if (yearText && (!/^\d{1,4}$/.test(yearText) || Number(yearText) < 1)) {
        statusEl.textContent = '';
        $('count-pill').textContent = '';
        $('page-label').textContent = '';
        showState('error', 'Invalid publication year', 'Enter a year between 1 and 9999, or leave it blank.');
        return;
    }
    state.keyword = $('keyword').value.trim();
    state.year = yearText ? Number(yearText) : null;
    state.page = 1;
    loadPage();
});
$('clear-filters').addEventListener('click', () => {
    $('keyword').value = '';
    $('year').value = '';
    state.keyword = '';
    state.year = null;
    state.page = 1;
    loadPage();
});

const modeSelect = $('data-mode');
const scenarioSelect = $('mock-scenario');
const scenarioLabel = $('mock-scenario-label');
modeSelect.value = state.mode;
function updateModeControls() {
    scenarioLabel.hidden = state.mode !== 'mock';
}
modeSelect.addEventListener('change', () => {
    state.mode = modeSelect.value;
    window.setArticleMode(state.mode);
    state.page = 1;
    updateModeControls();
    loadPage();
});
scenarioSelect.addEventListener('change', () => {
    state.scenario = scenarioSelect.value;
    state.page = 1;
    loadPage();
});
updateModeControls();
loadPage();
