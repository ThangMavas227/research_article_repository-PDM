/* Browse Articles — vanilla JavaScript.
 * Switch to the real Backend ONLY AFTER the BE confirms the API contract.
 */
const CONFIG = {
  USE_API: false,             // false = mock data; true = real backend
  API_URL: 'http://localhost:8080/api/articles',
  PAGE_SIZE: 8,
  MOCK_DELAY_MS: 700
};

//const state = { page: 1, scenario: 'normal', requestId: 0 };
const state = { page: 1, scenario: 'normal', requestId: 0, keyword: '' };
const $ = id => document.getElementById(id);
const listEl = $('article-list');
const statusEl = $('status-region');
const pagerEl = $('pagination');

function delay(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

// Align Frontend fields with the agreed API contract. Report any mismatches explicitly.
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

async function getArticles(page) {
    if (!CONFIG.USE_API) {
        await delay(CONFIG.MOCK_DELAY_MS); // See loading skeleton before showing mock result.
        if (state.scenario === 'error') throw new Error('Simulated network error for UI testing.');
        // const source = state.scenario === 'empty' ? [] : window.MOCK_ARTICLES;
        if (!Array.isArray(window.MOCK_ARTICLES)) {
            throw new Error('Data is not loaded.');
        }
        const source = state.scenario === 'empty'
            ? []
            : searchArticles(window.MOCK_ARTICLES, state.keyword);
        const items = source.slice((page - 1) * CONFIG.PAGE_SIZE, page * CONFIG.PAGE_SIZE);
        return { items: items.map(normalizeArticle), page, totalItems: source.length,
                totalPages: Math.ceil(source.length / CONFIG.PAGE_SIZE) };
    }

  // API contract (to confirm with Backend): GET /api/articles?page=1&size=8
  // Returns: { items:[{id,title,year,authors:[{id,name}]}],page,size,totalItems,totalPages }
  const url = new URL(CONFIG.API_URL);
  url.searchParams.set('page', String(page));
  url.searchParams.set('size', String(CONFIG.PAGE_SIZE));
  const response = await fetch(url.toString(), { headers: { Accept: 'application/json' } });
  if (!response.ok) throw new Error(`HTTP ${response.status} — unable to load articles.`);
  const data = await response.json();
  if (!data || !Array.isArray(data.items) || !Number.isInteger(data.totalItems)
      || !Number.isInteger(data.totalPages)) {
    throw new Error('Invalid API response: expected items[], totalItems, totalPages.');
  }
  return { items: data.items.map(normalizeArticle), page,
           totalItems: data.totalItems, totalPages: data.totalPages };
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
  heading.className = 'state-title'; heading.textContent = title;
  const body = document.createElement('p'); body.textContent = message;
  wrapper.append(icon, heading, body);
  if (kind === 'error') {
    const retry = document.createElement('button');
    retry.className = 'retry-btn'; retry.type = 'button';
    retry.textContent = 'Try again';
    retry.addEventListener('click', () => loadPage());
    wrapper.appendChild(retry);
  }
  listEl.appendChild(wrapper);
}

function renderArticles(items) {
  listEl.replaceChildren();
  for (const article of items) {
    const row = document.createElement('article'); row.className = 'article-row';
    const title = document.createElement('h3'); title.className = 'article-title';
    title.textContent = article.title;
    const meta = document.createElement('div'); meta.className = 'article-meta';
    const authors = document.createElement('div');
    const authorsLabel = document.createElement('span'); authorsLabel.className = 'meta-name';
    authorsLabel.textContent = 'Authors:';
    authors.append(authorsLabel, document.createTextNode(article.authors.length
      ? article.authors.map(a => a.name).join(', ') : 'Unknown author'));
    const year = document.createElement('div');
    const yearLabel = document.createElement('span'); yearLabel.className = 'meta-name';
    yearLabel.textContent = 'Published:';
    const yearValue = document.createElement('span'); yearValue.className = 'meta-year';
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
    showLoading();
    try {
        const result = await getArticles(state.page);
        if (requestId !== state.requestId) return; // Discard stale async results.
        statusEl.textContent = '';
        $('count-pill').textContent = `${result.totalItems} articles`;
        if (result.totalItems === 0 || result.items.length === 0) {
        $('page-label').textContent = '';
        showState('empty', 'No articles found', 'There are no articles to display at the moment.');
        return;
        }
        $('page-label').textContent = `Showing ${(result.page - 1) * CONFIG.PAGE_SIZE + 1}–${(result.page - 1) * CONFIG.PAGE_SIZE + result.items.length} of ${result.totalItems}`;
        renderArticles(result.items);
        renderPager(result.page, result.totalPages);
    } catch (err) {
        if (requestId !== state.requestId) return;
        statusEl.textContent = '';
        $('count-pill').textContent = 'Unavailable';
        $('page-label').textContent = '';
        showState('error', 'Could not load articles', err.message || 'Something went wrong. Please try again.');
        console.error('[Browse Articles]', err);
    }
}

$('prev-btn').addEventListener('click', () => {
  if (state.page > 1) { state.page--; loadPage(); }
});
$('next-btn').addEventListener('click', () => { state.page++; loadPage(); });

// if (!CONFIG.USE_API) {
//     $('testing-panel').hidden = false;
//         document.querySelectorAll('[data-scenario]').forEach(button => {
//             button.addEventListener('click', () => {
//             state.scenario = button.dataset.scenario;
//             state.page = 1;
//             document.querySelectorAll('[data-scenario]').forEach(b => {
//                 const active = b === button;
//                 b.classList.toggle('active', active);
//                 b.setAttribute('aria-pressed', String(active));
//             });
//             loadPage();
//         });
//     });
// }

const searchForm = $('browse-filter-form');
searchForm.addEventListener('submit', function(event) {
    event.preventDefault();

    state.keyword = $('keyword').value.trim();
    state.page = 1;

    loadPage();
});

loadPage();
