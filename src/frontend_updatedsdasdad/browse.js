/* Browse/Search: data comes exclusively from GET /api/articles. */
const CONFIG = window.APP_CONFIG;
const state = {
    page: 1,
    keyword: '',
    year: null,
    requestId: 0,
    controller: null
};

const $ = id => document.getElementById(id);
const listEl = $('article-list');
const statusEl = $('status-region');
const pagerEl = $('pagination');

// API article shape: { id, title, year, doi, abstract, authors, references, citedBy }.
// Keep all detail fields when normalizing: the selected article is saved in sessionStorage
// and articleDetail.js reads it after navigation.
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

    // null means absent/unavailable; [] means the API confirmed there are no citations.
    const normalizeCitations = (items, field) => {
        if (items == null) return null;
        if (!Array.isArray(items) || items.some(item =>
            !item ||
            !((typeof item.id === 'string' && item.id.trim() !== '') ||
              (typeof item.id === 'number' && Number.isInteger(item.id))) ||
            typeof item.title !== 'string')) {
            throw new Error(`Invalid ${field} data returned by the server.`);
        }
        return items.map(item => ({ id: String(item.id), title: item.title }));
    };

    if ((raw.doi != null && typeof raw.doi !== 'string') ||
        (raw.abstract != null && typeof raw.abstract !== 'string')) {
        throw new Error('Invalid DOI or abstract data returned by the server.');
    }
    return {
        id: String(raw.id),
        title: raw.title,
        year: raw.year,
        authors: raw.authors.map(author => ({ id: String(author.id), name: author.name })),
        doi: raw.doi ?? null,
        abstract: raw.abstract ?? null,
        references: normalizeCitations(raw.references, 'references'),
        citedBy: normalizeCitations(raw.citedBy, 'citedBy')
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

async function getArticles({ page, keyword, year, signal }) {
    // The backend filters and paginates. Do not filter its results again.
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
            err?.name === 'TypeError'
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

// A Reader may save the filters that are currently applied to Browse.
// Do not take values from the input boxes before Search has been submitted.
function setupReaderSavedSearch() {
    if (window.RARAuth?.getRole() !== 'reader') return;
    const openBtn = $('open-save-search');
    const panel = $('save-search-panel');
    const form = $('save-search-form');
    const nameInput = $('save-search-name');
    const messageEl = $('save-search-message');
    const saveBtn = $('confirm-save-search');
    const api = window.RARSavedSearchApi;
    if (!api) return;

    const showMessage = (message, kind = 'info') => {
        messageEl.textContent = message;
        messageEl.dataset.kind = kind;
        messageEl.hidden = !message;
    };
    openBtn.hidden = false;
    openBtn.addEventListener('click', () => {
        panel.hidden = false;
        showMessage('');
        $('save-search-summary').textContent = `Current filters: ${
            [state.keyword && `Keyword: ${state.keyword}`,
             state.year !== null && `Year: ${state.year}`].filter(Boolean).join(' · ') || 'None'}`;
        nameInput.focus();
    });
    $('cancel-save-search').addEventListener('click', () => {
        panel.hidden = true;
        showMessage('');
    });
    form.addEventListener('submit', async event => {
        event.preventDefault();
        if (saveBtn.disabled) return;
        try {
            const criteria = api.criteriaFromBrowse(state.keyword, state.year);
            const name = api.validateName(nameInput.value);
            saveBtn.disabled = true;
            await api.create(name, criteria);
            showMessage(`Saved "${name}". Open Saved Searches from the navigation to run or delete it.`, 'success');
            nameInput.value = '';
        } catch (error) {
            showMessage(error.message, 'error');
        } finally {
            saveBtn.disabled = false;
        }
    });
}

// Run searches from My Saved Searches by restoring both query parameters.
function loadInitialBrowseFilters() {
    const params = new URLSearchParams(window.location.search);
    if (!params.has('keyword') && !params.has('year')) {
        loadPage();
        return;
    }
    const keyword = params.get('keyword') || '';
    const yearText = params.get('year') || '';
    if (yearText && (!/^\d{1,4}$/.test(yearText) || Number(yearText) < 1)) {
        showState('error', 'Invalid saved search', 'The publication year in the saved search is invalid.');
        return;
    }
    state.keyword = keyword.trim();
    state.year = yearText ? Number(yearText) : null;
    $('keyword').value = state.keyword;
    $('year').value = yearText;
    state.page = 1;
    loadPage();
}

// navigation.js is loaded with defer in index.html and may not be ready
// when the regular browse.js script runs at the end of the body.
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setupReaderSavedSearch, { once: true });
} else {
    setupReaderSavedSearch();
}
loadInitialBrowseFilters();
