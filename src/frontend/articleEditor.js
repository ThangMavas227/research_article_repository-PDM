/* Manage Content: independent CRUD demo. It does not mutate MOCK_ARTICLES on other pages. */
(() => {
  'use strict';

  const STORAGE_KEY = 'research-repo-editor-mock-v1';
  const PAGE_SIZE = 5;
  const $ = id => document.getElementById(id);
  const seedArticles = Array.isArray(window.MOCK_ARTICLES) ? window.MOCK_ARTICLES : [];
  const seedDetails = window.MOCK_DETAILS || {};
  let canStore = true;
  const ui = { tab: 'articles', editingArticle: null, editingAuthor: null, page: 1, selectedAuthorIds: new Set() };

  function initialData() {
    const authors = new Map();
    const articles = seedArticles.map(item => {
      const ids = (item.authors || []).map(author => {
        if (!authors.has(author.id)) authors.set(author.id, { id: author.id, name: author.name });
        return author.id;
      });
      const detail = seedDetails[item.id] || {};
      return {
        id: item.id,
        title: item.title,
        doi: detail.doi || `10.1234/mock.${item.id.toLowerCase()}`,
        year: item.year,
        abstract: detail.abstract || '',
        authorIds: [...new Set(ids)]
      };
    });
    return { articles, authors: [...authors.values()] };
  }

  function readData() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const data = JSON.parse(raw);
        if (data && Array.isArray(data.articles) && Array.isArray(data.authors) &&
            data.articles.every(a => a && typeof a.id === 'string' && Array.isArray(a.authorIds)) &&
            data.authors.every(a => a && typeof a.id === 'string' && typeof a.name === 'string')) {
          return data;
        }
      }
    } catch (_) { canStore = false; }
    return initialData();
  }

  let data = readData();

  function saveData() {
    if (!canStore) return;
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(data)); }
    catch (_) {
      canStore = false;
      updateStorageNote();
    }
  }

  function updateStorageNote() {
    if (!canStore) $('storage-note').innerHTML = '<strong>Mock demo:</strong> Browser storage is unavailable, so changes last only until this page is refreshed. No backend is connected.';
  }

  function notify(message, type = 'success') {
    const el = $('feedback');
    el.textContent = message;
    el.className = `feedback ${type}`;
    el.hidden = false;
  }

  function clearNotice() { $('feedback').hidden = true; }
  function findAuthor(id) { return data.authors.find(author => author.id === id); }
  function authorName(id) { return findAuthor(id)?.name || 'Unknown author'; }
  function nextId(prefix, records) {
    const max = records.reduce((n, row) => {
      const match = new RegExp(`^${prefix}(\\d+)$`).exec(row.id);
      return match ? Math.max(n, Number(match[1])) : n;
    }, 0);
    return `${prefix}${String(max + 1).padStart(3, '0')}`;
  }

  function createButton(label, className, onClick) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = className;
    btn.textContent = label;
    btn.addEventListener('click', onClick);
    return btn;
  }

  function createLine(label, value) {
    const row = document.createElement('p');
    const strong = document.createElement('strong');
    strong.textContent = `${label}: `;
    row.append(strong, document.createTextNode(value));
    return row;
  }

  function filteredRecords() {
    const query = $('record-search').value.trim().toLocaleLowerCase();
    const records = ui.tab === 'articles' ? data.articles : data.authors;
    if (!query) return records;
    return records.filter(item => ui.tab === 'articles'
      ? [item.title, item.doi, String(item.year), item.id, ...(item.authorIds || []).map(authorName)]
          .some(value => String(value || '').toLocaleLowerCase().includes(query))
      : [item.id, item.name].some(value => String(value || '').toLocaleLowerCase().includes(query)));
  }

  function renderCard(item) {
    const card = document.createElement('article');
    card.className = 'record-card';
    const title = document.createElement('h4');
    title.textContent = ui.tab === 'articles' ? item.title : item.name;
    card.append(title);
    if (ui.tab === 'articles') {
      card.append(createLine('Published', String(item.year)));
      card.append(createLine('DOI', item.doi));
      const names = (item.authorIds || []).map(authorName);
      card.append(createLine('Authors', names.length ? names.join(', ') : 'No authors assigned'));
    } else {
      card.append(createLine('Author ID', item.id));
      const articleCount = data.articles.filter(a => a.authorIds.includes(item.id)).length;
      card.append(createLine('Articles', String(articleCount)));
    }
    const actions = document.createElement('div');
    actions.className = 'record-actions';
    actions.append(
      createButton('Edit', 'btn btn-secondary btn-small', () => startEdit(item.id)),
      createButton('Delete', 'btn btn-danger btn-small', () => deleteRecord(item.id))
    );
    card.append(actions);
    return card;
  }

  function renderList() {
    $('article-count').textContent = `(${data.articles.length})`;
    $('author-count').textContent = `(${data.authors.length})`;
    const records = filteredRecords();
    const pages = Math.max(1, Math.ceil(records.length / PAGE_SIZE));
    ui.page = Math.min(ui.page, pages);
    const list = $('record-list');
    list.replaceChildren();
    if (!records.length) {
      const empty = document.createElement('div');
      empty.className = 'empty-result';
      empty.textContent = 'No matching records found. Try a different search or add a new record.';
      list.append(empty);
    } else {
      records.slice((ui.page - 1) * PAGE_SIZE, ui.page * PAGE_SIZE).forEach(item => list.append(renderCard(item)));
    }
    $('record-pagination').hidden = pages <= 1;
    $('page-count').textContent = `Page ${ui.page} of ${pages}`;
    $('previous-page').disabled = ui.page <= 1;
    $('next-page').disabled = ui.page >= pages;
  }

  function clearError(inputId) {
    const input = $(inputId);
    input.removeAttribute('aria-invalid');
    $(`${inputId}-error`).textContent = '';
  }

  function setError(inputId, message) {
    $(inputId).setAttribute('aria-invalid', 'true');
    $(`${inputId}-error`).textContent = message;
  }

  function resetErrors(type) {
    (type === 'articles' ? ['article-title', 'article-doi', 'article-year'] : ['author-name']).forEach(clearError);
  }

  // Keep selections outside the DOM, because search hides non-matching checkboxes.
  // Otherwise saving after a search would accidentally remove hidden authors.
  function normalizeSearch(value) {
    return String(value ?? '').normalize('NFD').replace(/[\u0300-\u036f]/g, '')
      .replace(/[đĐ]/g, 'd').toLowerCase().trim();
  }

  function renderAuthorPicker() {
    const picker = $('author-picker');
    const query = normalizeSearch($('author-search').value);
    const authors = [...data.authors].sort((a, b) =>
      a.name.localeCompare(b.name) || a.id.localeCompare(b.id));
    const visible = query
      ? authors.filter(a => normalizeSearch(a.name).includes(query) || normalizeSearch(a.id).includes(query))
      : authors.filter(a => ui.selectedAuthorIds.has(a.id));
    picker.replaceChildren();

    const selectedCount = ui.selectedAuthorIds.size;
    $('author-selection-status').textContent = query
      ? `${visible.length} match${visible.length === 1 ? '' : 'es'} · ${selectedCount} selected`
      : `${selectedCount} author${selectedCount === 1 ? '' : 's'} selected${selectedCount ? ' · Only selected authors are shown' : ' · Search to add authors'}`;

    // Initial/cleared search + no selected authors = blank picker as requested.
    if (!query && !visible.length) return;
    if (query && !visible.length) {
      const empty = document.createElement('p');
      empty.className = 'author-picker-empty';
      empty.textContent = authors.length
        ? 'No matching authors. Try another name or Author ID.'
        : 'No authors available. Add one in the Authors tab.';
      picker.append(empty);
      return;
    }

    visible.forEach(author => {
      const label = document.createElement('label');
      label.className = 'author-option';
      const checkbox = document.createElement('input');
      checkbox.type = 'checkbox';
      checkbox.value = author.id;
      checkbox.checked = ui.selectedAuthorIds.has(author.id);
      if (checkbox.checked) label.classList.add('is-selected');

      const info = document.createElement('span');
      info.className = 'author-option-text';
      const name = document.createElement('span');
      name.className = 'author-option-name';
      name.textContent = author.name;
      const id = document.createElement('span');
      id.className = 'author-option-id';
      id.textContent = author.id;
      info.append(name, id);
      label.append(checkbox, info);

      checkbox.addEventListener('change', () => {
        if (checkbox.checked) ui.selectedAuthorIds.add(author.id);
        else ui.selectedAuthorIds.delete(author.id);
        // When search is blank, unchecking removes that item from the selected-only list.
        // During search, keep the result and checkbox focus intact.
        if (!normalizeSearch($('author-search').value)) renderAuthorPicker();
        else {
          label.classList.toggle('is-selected', checkbox.checked);
          $('author-selection-status').textContent =
            `${visible.length} match${visible.length === 1 ? '' : 'es'} · ${ui.selectedAuthorIds.size} selected`;
        }
      });
      picker.append(label);
    });
  }

  function resetArticleForm() {
    ui.editingArticle = null;
    $('article-form').reset();
    ui.selectedAuthorIds = new Set();
    $('author-search').value = '';
    resetErrors('articles');
    $('article-form-heading').textContent = 'Add Article';
    $('article-edit-id').textContent = 'New record';
    renderAuthorPicker();
  }

  function resetAuthorForm() {
    ui.editingAuthor = null;
    $('author-form').reset();
    resetErrors('authors');
    $('author-form-heading').textContent = 'Add Author';
    $('author-edit-id').textContent = 'New record';
  }

  function activateTab(tab) {
    ui.tab = tab;
    ui.page = 1;
    $('record-search').value = '';
    $('articles-tab').setAttribute('aria-selected', String(tab === 'articles'));
    $('authors-tab').setAttribute('aria-selected', String(tab === 'authors'));
    $('article-form-panel').hidden = tab !== 'articles';
    $('author-form-panel').hidden = tab !== 'authors';
    $('list-heading').textContent = tab === 'articles' ? 'Articles' : 'Authors';
    $('list-description').textContent = tab === 'articles'
      ? 'Select Edit to load an article into the form.'
      : 'Select Edit to update an author. Deleting an author also unassigns them from articles in this demo.';
    $('record-search').placeholder = tab === 'articles' ? 'Search title, DOI, author...' : 'Search name or author ID...';
    $('add-record').textContent = tab === 'articles' ? '+ Add Article' : '+ Add Author';
    renderAuthorPicker();
    renderList();
    clearNotice();
  }

  function startEdit(id) {
    clearNotice();
    if (ui.tab === 'articles') {
      const article = data.articles.find(a => a.id === id);
      if (!article) return;
      ui.editingArticle = id;
      $('article-title').value = article.title;
      $('article-doi').value = article.doi;
      $('article-year').value = article.year;
      $('article-abstract').value = article.abstract;
      $('article-form-heading').textContent = 'Edit Article';
      $('article-edit-id').textContent = article.id;
      ui.selectedAuthorIds = new Set(article.authorIds.filter(authorId => !!findAuthor(authorId)));
      $('author-search').value = '';
      renderAuthorPicker();
      resetErrors('articles');
    } else {
      const author = findAuthor(id);
      if (!author) return;
      ui.editingAuthor = id;
      $('author-name').value = author.name;
      $('author-form-heading').textContent = 'Edit Author';
      $('author-edit-id').textContent = author.id;
      resetErrors('authors');
    }
    if (window.matchMedia('(max-width: 850px)').matches) {
      $(ui.tab === 'articles' ? 'article-form-panel' : 'author-form-panel').scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }

  function deleteRecord(id) {
    if (ui.tab === 'articles') {
      const article = data.articles.find(a => a.id === id);
      if (!article || !window.confirm(`Delete article "${article.title}"? This only affects the local mock demo.`)) return;
      data.articles = data.articles.filter(a => a.id !== id);
      if (ui.editingArticle === id) resetArticleForm();
      saveData(); renderList(); notify(`Article ${id} deleted.`);
    } else {
      const author = findAuthor(id);
      if (!author) return;
      const linked = data.articles.filter(a => a.authorIds.includes(id)).length;
      const message = linked
        ? `Delete author "${author.name}"? They will also be unassigned from ${linked} article(s) in this mock demo.`
        : `Delete author "${author.name}" from this mock demo?`;
      if (!window.confirm(message)) return;
      data.authors = data.authors.filter(a => a.id !== id);
      data.articles.forEach(a => { a.authorIds = a.authorIds.filter(authorId => authorId !== id); });
      ui.selectedAuthorIds.delete(id);
      if (ui.editingAuthor === id) resetAuthorForm();
      renderAuthorPicker();
      saveData(); renderList(); notify(`Author ${id} deleted.`);
    }
  }

  $('article-form').addEventListener('submit', event => {
    event.preventDefault();
    resetErrors('articles');
    const title = $('article-title').value.trim();
    const doi = $('article-doi').value.trim();
    const yearText = $('article-year').value.trim();
    const abstract = $('article-abstract').value.trim();
    let firstError = null;
    const fail = (field, message) => { setError(field, message); if (!firstError) firstError = field; };
    if (!title) fail('article-title', 'Title is required.');
    else if (title.length > 255) fail('article-title', 'Title must be 255 characters or fewer.');
    if (!doi) fail('article-doi', 'DOI is required.');
    else if (!/^10\.\d{4,9}\/\S+$/i.test(doi)) fail('article-doi', 'Use the DOI format 10.xxxx/identifier with no spaces.');
    else if (doi.length > 100) fail('article-doi', 'DOI must be 100 characters or fewer.');
    else if (data.articles.some(a => a.id !== ui.editingArticle && a.doi.toLowerCase() === doi.toLowerCase()))
      fail('article-doi', 'This DOI already exists in the mock repository.');
    if (!/^\d{4}$/.test(yearText) || Number(yearText) < 1900 || Number(yearText) > 2100)
      fail('article-year', 'Enter a publication year between 1900 and 2100.');
    if (firstError) { $(firstError).focus(); notify('Please correct the highlighted fields.', 'error'); return; }

    // Save the full selection, not only currently visible search results.
    const authorIds = [...ui.selectedAuthorIds];
    const payload = { title, doi, year: Number(yearText), abstract, authorIds };
    let id = ui.editingArticle;
    if (id) {
      const item = data.articles.find(a => a.id === id);
      if (!item) { notify('This article no longer exists.', 'error'); resetArticleForm(); return; }
      Object.assign(item, payload);
    } else {
      id = nextId('AR', data.articles);
      data.articles.unshift({ id, ...payload });
      ui.page = 1;
    }
    saveData();
    resetArticleForm();
    renderList();
    notify(`Article ${id} saved successfully.`);
  });

  $('author-form').addEventListener('submit', event => {
    event.preventDefault();
    resetErrors('authors');
    const name = $('author-name').value.trim();
    if (!name || name.length > 150) {
      setError('author-name', name ? 'Name must be 150 characters or fewer.' : 'Full name is required.');
      $('author-name').focus();
      notify('Please correct the highlighted field.', 'error');
      return;
    }
    let id = ui.editingAuthor;
    if (id) {
      const author = findAuthor(id);
      if (!author) { notify('This author no longer exists.', 'error'); resetAuthorForm(); return; }
      author.name = name;
    } else {
      id = nextId('AU', data.authors);
      data.authors.unshift({ id, name });
      ui.page = 1;
    }
    saveData();
    resetAuthorForm();
    renderAuthorPicker();
    renderList();
    notify(`Author ${id} saved successfully.`);
  });

  ['article-title', 'article-doi', 'article-year', 'author-name'].forEach(id =>
    $(id).addEventListener('input', () => clearError(id)));

  $('articles-tab').addEventListener('click', () => activateTab('articles'));
  $('authors-tab').addEventListener('click', () => activateTab('authors'));
  $('cancel-article').addEventListener('click', () => { resetArticleForm(); clearNotice(); });
  $('cancel-author').addEventListener('click', () => { resetAuthorForm(); clearNotice(); });
  $('add-record').addEventListener('click', () => {
    clearNotice();
    if (ui.tab === 'articles') { resetArticleForm(); $('article-title').focus(); }
    else { resetAuthorForm(); $('author-name').focus(); }
  });
  $('record-search').addEventListener('input', () => { ui.page = 1; renderList(); });
  $('author-search').addEventListener('input', renderAuthorPicker);
  $('author-search').addEventListener('search', renderAuthorPicker);
  $('previous-page').addEventListener('click', () => { if (ui.page > 1) { ui.page--; renderList(); } });
  $('next-page').addEventListener('click', () => { ui.page++; renderList(); });
  $('reset-demo').addEventListener('click', () => {
    if (!window.confirm('Restore the original mock dataset? All edits made in this editor will be lost.')) return;
    data = initialData();
    saveData();
    resetArticleForm(); resetAuthorForm();
    activateTab('articles');
    notify('Original frontend mock data restored.');
  });

  updateStorageNote();
  resetArticleForm();
  resetAuthorForm();
  activateTab('articles');

  // Optional deep links for future integration: articleEditor.html?type=article&id=AR001
  const query = new URLSearchParams(location.search);
  const requestedType = query.get('type');
  const requestedId = query.get('id');
  if (requestedType === 'author') activateTab('authors');
  if (requestedId && ((ui.tab === 'articles' && requestedType === 'article') ||
                      (ui.tab === 'authors' && requestedType === 'author'))) startEdit(requestedId);
})();
