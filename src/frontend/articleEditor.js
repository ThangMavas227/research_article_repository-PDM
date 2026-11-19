/* Manage Content: real API-backed read-only listing until CRUD endpoints exist. */
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const PAGE_SIZE = 5;
  const state = { articles: [], authors: [], tab: 'articles', page: 1 };

  function message(text, isError = false) {
    const el = $('feedback');
    el.textContent = text;
    el.className = `feedback ${isError ? 'error' : 'success'}`;
    el.hidden = false;
  }

  async function fetchArticles() {
    const items = [];
    let totalPages = 1;
    let totalItems = 0;
    const pageSize = 100; // Current backend maximum.
    for (let page = 1; page <= totalPages; page++) {
      const url = new URL(window.APP_CONFIG.API_URL, window.location.href);
      url.searchParams.set('page', String(page));
      url.searchParams.set('size', String(pageSize));
      const response = await fetch(url, { headers: { Accept: 'application/json' } });
      if (!response.ok) throw new Error(`Backend returned HTTP ${response.status}.`);
      const data = await response.json();
      if (!data || !Array.isArray(data.items) ||
          !Number.isInteger(data.totalPages) || data.totalPages < 0 ||
          !Number.isInteger(data.totalItems) || data.totalItems < 0) {
        throw new Error('Unexpected API response format.');
      }
      if (page === 1) {
        totalPages = data.totalPages;
        totalItems = data.totalItems;
      }
      items.push(...data.items);
    }
    if (items.length !== totalItems) throw new Error('Backend response has inconsistent pagination totals.');
    return items;
  }

  function filtered() {
    const q = $('record-search').value.trim().toLocaleLowerCase();
    const data = state.tab === 'articles' ? state.articles : state.authors;
    if (!q) return data;
    return data.filter(item => (state.tab === 'articles'
      ? [item.id, item.title, item.doi, item.year,
          ...(Array.isArray(item.authors) ? item.authors.map(a => a.name) : [])]
      : [item.id, item.name]).some(value => String(value ?? '').toLocaleLowerCase().includes(q)));
  }

  function line(label, value) {
    const p = document.createElement('p');
    const strong = document.createElement('strong');
    strong.textContent = `${label}: `;
    p.append(strong, document.createTextNode(String(value ?? '—')));
    return p;
  }

  function render() {
    const items = filtered();
    const pages = Math.ceil(items.length / PAGE_SIZE);
    state.page = Math.max(1, Math.min(state.page, Math.max(1, pages)));
    const start = (state.page - 1) * PAGE_SIZE;
    const container = $('record-list');
    container.replaceChildren();
    if (items.length === 0) {
      const empty = document.createElement('p');
      empty.className = 'empty-result';
      empty.textContent = 'No matching records.';
      container.appendChild(empty);
    }
    for (const item of items.slice(start, start + PAGE_SIZE)) {
      const card = document.createElement('article');
      card.className = 'record-card';
      const h4 = document.createElement('h4');
      if (state.tab === 'articles') {
        const link = document.createElement('a');
        link.href = `articleDetail.html?id=${encodeURIComponent(String(item.id))}`;
        link.textContent = item.title;
        link.addEventListener('click', () => {
          try { sessionStorage.setItem(window.APP_CONFIG.SELECTED_ARTICLE_KEY, JSON.stringify(item)); }
          catch (_) { /* Detail page can fetch again. */ }
        });
        h4.appendChild(link);
        card.append(h4, line('Article ID', item.id), line('DOI', item.doi),
          line('Year', item.year),
          line('Authors', Array.isArray(item.authors) ? item.authors.map(a => a.name).join(', ') || 'Unknown' : 'Unavailable'));
      } else {
        h4.textContent = item.name;
        card.append(h4, line('Author ID', item.id));
      }
      container.appendChild(card);
    }
    $('record-pagination').hidden = pages <= 1;
    $('page-count').textContent = `Page ${state.page} / ${Math.max(1, pages)}`;
    $('previous-page').disabled = state.page <= 1;
    $('next-page').disabled = state.page >= pages;
  }

  function showTab(tab) {
    state.tab = tab;
    state.page = 1;
    $('record-search').value = '';
    $('articles-tab').setAttribute('aria-selected', String(tab === 'articles'));
    $('authors-tab').setAttribute('aria-selected', String(tab === 'authors'));
    $('list-heading').textContent = tab === 'articles' ? 'Articles' : 'Authors appearing in articles';
    $('list-description').textContent = tab === 'articles'
      ? 'Browse records from MySQL. Select an article to open its details.'
      : 'This list includes authors attached to returned articles, not all authors in the database.';
    render();
  }

  async function load() {
    $('reload-records').disabled = true;
    message('Loading records from Backend API...');
    try {
      const articles = await fetchArticles();
      const authors = new Map();
      articles.forEach(article => (Array.isArray(article.authors) ? article.authors : []).forEach(author => {
        if (author && author.id != null && typeof author.name === 'string') {
          authors.set(String(author.id), { id: String(author.id), name: author.name });
        }
      }));
      state.articles = articles;
      state.authors = [...authors.values()].sort((a, b) => a.name.localeCompare(b.name));
      state.page = 1;
      $('article-count').textContent = String(state.articles.length);
      $('author-count').textContent = String(state.authors.length);
      message(`Loaded ${state.articles.length} articles from the Backend API.`);
      render();
    } catch (error) {
      state.articles = [];
      state.authors = [];
      $('article-count').textContent = '0';
      $('author-count').textContent = '0';
      render();
      message(`Could not load records. Check Spring Boot/MySQL and the API URL. ${error.message}`, true);
      console.error('[Manage Content]', error);
    } finally {
      $('reload-records').disabled = false;
    }
  }

  $('articles-tab').addEventListener('click', () => showTab('articles'));
  $('authors-tab').addEventListener('click', () => showTab('authors'));
  $('record-search').addEventListener('input', () => { state.page = 1; render(); });
  $('previous-page').addEventListener('click', () => { if (state.page > 1) { state.page--; render(); } });
  $('next-page').addEventListener('click', () => { state.page++; render(); });
  $('reload-records').addEventListener('click', load);
  load();
})();
