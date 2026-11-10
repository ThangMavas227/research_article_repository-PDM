
/*
 * Browse Articles — vanilla JavaScript.
 * Switch to the real Backend ONLY AFTER the BE confirms the API contract.
 */

const CONFIG = {
    USE_API: false,
    API_URL: 'http://localhost:8080/api/articles',
    PAGE_SIZE: 8,
    MOCK_DELAY_MS: 700
};

const state = { page: 1, scenario: 'normal', requestId: 0, keyword: '' };

const $ = (id) => document.getElementById(id);
const listEl = $('article-list');
const statusEl = $('status-region');
const pagerEl = $('pagination');

function delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Normalize article data
function normalizeArticle(raw) {
    if (!raw || typeof raw.id !== 'string' || typeof raw.title !== 'string') {
        throw new Error('Invalid API response: article requires string id and title.');
    }

    const year = Number(raw.year ?? raw.publicationYear);
    if (!Number.isInteger(year) || year < 1900 || year > 2100) {
        throw new Error('Invalid API response: missing/invalid publication year.');
    }

    if (!Array.isArray(raw.authors) || raw.authors.some(a => !a || typeof a.name !== 'string')) {
        throw new Error('Invalid API response: authors must be an array with a name field.');
    }

    return { id: raw.id, title: raw.title, year, authors: raw.authors };
}

// Search articles by keyword
function searchArticles(articles, keyword) {
    if (!keyword) return articles;

    const searchText = keyword.toLowerCase();

    return articles.filter(article => {
        const title = (article.title || '').toLowerCase();
        const authors = (article.authors || []).map(a => a.name || '').join(' ').toLowerCase();
        return title.includes(searchText) || authors.includes(searchText);
    });
}

// Get articles from Mock Data or Backend API
async function getArticles(page) {
    if (!CONFIG.USE_API) {
        await delay(CONFIG.MOCK_DELAY_MS);

        if (state.scenario === 'error') {
            throw new Error('Simulated network error for UI testing.');
        }

        if (!Array.isArray(window.MOCK_ARTICLES)) {
            throw new Error('Data is not loaded.');
        }

        const source = state.scenario === 'empty'
            ? []
            : searchArticles(window.MOCK_ARTICLES, state.keyword);

        const items = source.slice((page - 1) * CONFIG.PAGE_SIZE, page * CONFIG.PAGE_SIZE);

        return {
            items: items.map(normalizeArticle),
            page,
            totalItems: source.length,
            totalPages: Math.ceil(source.length / CONFIG.PAGE_SIZE)
        };
    }

    // GET /api/articles?page=1&size=8
    const url = new URL(CONFIG.API_URL);
    url.searchParams.set('page', String(page));
    url.searchParams.set('size', String(CONFIG.PAGE_SIZE));
    if (state.keyword) url.searchParams.set('keyword', state.keyword);

    const response = await fetch(url.toString(), {
        headers: { Accept: 'application/json' }
    });

    if (!response.ok) {
        throw new Error(`HTTP ${response.status} — unable to load articles.`);
    }

    const data = await response.json();

    if (!data || !Array.isArray(data.items) ||
        !Number.isInteger(data.totalItems) || !Number.isInteger(data.totalPages)) {
        throw new Error('Invalid API response: expected items[], totalItems, totalPages.');
    }

    return {
        items: data.items.map(normalizeArticle),
        page,
        totalItems: data.totalItems,
        totalPages: data.totalPages
    };
}

// Display Loading Skeleton
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

// Display Empty State or Error State
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
        retry.addEventListener('click', () => loadPage());
        wrapper.appendChild(retry);
    }

    listEl.appendChild(wrapper);
}

// Render Article List
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
        title.appendChild(link);

        const meta = document.createElement('div');
        meta.className = 'article-meta';

        // Authors
        const authors = document.createElement('div');
        const authorsLabel = document.createElement('span');
        authorsLabel.className = 'meta-name';
        authorsLabel.textContent = 'Authors:';

        authors.append(
            authorsLabel,
            document.createTextNode(
                article.authors.length > 0
                    ? article.authors.map(a => a.name).join(', ')
                    : 'Unknown author'
            )
        );

        // Publication Year
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

// Render Pagination
function renderPager(page, totalPages) {
    pagerEl.hidden = totalPages <= 1;
    $('page-info').textContent = `Page ${page} of ${totalPages}`;
    $('prev-btn').disabled = page <= 1;
    $('next-btn').disabled = page >= totalPages;
}

// Load Articles
async function loadPage() {
    const requestId = ++state.requestId;
    showLoading();

    try {
        const result = await getArticles(state.page);
        if (requestId !== state.requestId) return;

        statusEl.textContent = '';
        $('count-pill').textContent = `${result.totalItems} articles`;

        if (result.totalItems === 0 || result.items.length === 0) {
            $('page-label').textContent = '';
            showState('empty', 'No articles found', 'There are no articles to display at the moment.');
            return;
        }

        const start = (result.page - 1) * CONFIG.PAGE_SIZE + 1;
        const end = start + result.items.length - 1;

        $('page-label').textContent = `Showing ${start}–${end} of ${result.totalItems}`;
        renderArticles(result.items);
        renderPager(result.page, result.totalPages);

    } catch (err) {
        if (requestId !== state.requestId) return;

        statusEl.textContent = '';
        $('count-pill').textContent = 'Unavailable';
        $('page-label').textContent = '';

        showState('error', 'Could not load articles',
            err.message || 'Something went wrong. Please try again.');

        console.error('[Browse Articles]', err);
    }
}

// Previous Page Button
$('prev-btn').addEventListener('click', () => {
    if (state.page > 1) {
        state.page--;
        loadPage();
    }
});

// Next Page Button
$('next-btn').addEventListener('click', () => {
    state.page++;
    loadPage();
});

// Search Form
const searchForm = $('browse-filter-form');

searchForm.addEventListener('submit', event => {
    event.preventDefault();
    state.keyword = $('keyword').value.trim();
    state.page = 1;
    loadPage();
});

// Initial Load
loadPage();
