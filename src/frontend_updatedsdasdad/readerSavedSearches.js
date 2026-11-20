(function () {
    'use strict';

    if (window.RARAuth?.getRole() !== 'reader') return;

    const $ = id => document.getElementById(id);
    const api = window.RARSavedSearchApi;
    const form = $('saved-search-form');
    const keywordInput = $('saved-search-keyword');
    const yearInput = $('saved-search-year');
    const nameInput = $('saved-search-name');
    const listEl = $('saved-searches-list');
    const statusEl = $('saved-searches-message');
    const countEl = $('saved-search-count');
    const refreshBtn = $('refresh-saved-searches');
    const createBtn = $('create-saved-search');
    let isLoading = false;

    function notify(message, kind = 'info') {
        statusEl.textContent = message;
        statusEl.dataset.kind = kind;
        statusEl.hidden = !message;
    }

    function showEmpty(title, message) {
        const box = document.createElement('div');
        box.className = 'saved-searches-empty';
        const strong = document.createElement('strong');
        strong.textContent = title;
        const text = document.createElement('span');
        text.textContent = message;
        box.append(strong, text);
        listEl.replaceChildren(box);
    }

    function readableDate(value) {
        if (!value || typeof value !== 'string') return 'Unknown';
        return value.replace('T', ' ').slice(0, 16);
    }

    function rowFor(item) {
        const row = document.createElement('div');
        row.className = 'saved-searches-row';
        const details = document.createElement('div');
        details.className = 'saved-searches-row-info';
        const name = document.createElement('strong');
        name.className = 'saved-searches-row-title';
        name.textContent = item.searchName;
        const criteria = document.createElement('span');
        criteria.className = 'saved-searches-criteria';
        criteria.textContent = api.readableCriteria(item.criteria);
        const date = document.createElement('span');
        date.className = 'saved-searches-date';
        date.textContent = `Saved: ${readableDate(item.createdDate)}`;
        details.append(name, criteria, date);

        const actions = document.createElement('div');
        actions.className = 'saved-searches-row-actions';
        const runBtn = document.createElement('button');
        runBtn.type = 'button';
        runBtn.textContent = 'Run search';
        runBtn.className = 'saved-searches-button primary';
        const params = api.getBrowseParams(item.criteria);
        if (params === null) {
            const warning = document.createElement('span');
            warning.className = 'saved-searches-limitation';
            warning.textContent = 'This saved search contains unsupported or invalid filter values.';
            details.appendChild(warning);
            runBtn.disabled = true;
            runBtn.title = 'Check the saved search filters. Valid venue types are J or C and years must be 1–9999.';
        } else {
            runBtn.addEventListener('click', () => {
                const query = params.toString();
                window.location.assign(`index.html${query ? '?' + query : ''}`);
            });
        }

        const deleteBtn = document.createElement('button');
        deleteBtn.type = 'button';
        deleteBtn.textContent = 'Delete';
        deleteBtn.className = 'saved-searches-button danger';
        deleteBtn.addEventListener('click', async () => {
            if (!window.confirm(`Delete saved search "${item.searchName}"? This cannot be undone.`)) return;
            deleteBtn.disabled = true;
            runBtn.disabled = true;
            try {
                await api.remove(item.searchName);
                await loadSavedSearches();
                notify(`Deleted "${item.searchName}".`, 'success');
            } catch (error) {
                notify(error.message, 'error');
                deleteBtn.disabled = false;
                runBtn.disabled = params === null;
            }
        });
        actions.append(runBtn, deleteBtn);
        row.append(details, actions);
        return row;
    }

    async function loadSavedSearches() {
        if (isLoading) return;
        isLoading = true;
        refreshBtn.disabled = true;
        showEmpty('Loading saved searches…', 'Getting your saved filters from the server.');
        try {
            const items = await api.list();
            countEl.textContent = String(items.length);
            countEl.hidden = false;
            if (!items.length) {
                showEmpty('No saved searches yet', 'Save a search above or from the Browse Articles page.');
            } else {
                listEl.replaceChildren(...items.map(rowFor));
            }
        } catch (error) {
            countEl.hidden = true;
            showEmpty('Unable to load saved searches', 'Try refreshing after checking your connection.');
            notify(error.message, 'error');
        } finally {
            isLoading = false;
            refreshBtn.disabled = false;
        }
    }

    form.addEventListener('submit', async event => {
        event.preventDefault();
        if (createBtn.disabled) return;
        try {
            const criteria = api.criteriaFromBrowse(keywordInput.value, yearInput.value);
            const name = api.validateName(nameInput.value);
            createBtn.disabled = true;
            await api.create(name, criteria);
            nameInput.value = '';
            await loadSavedSearches();
            notify(`Saved "${name}" successfully.`, 'success');
        } catch (error) {
            notify(error.message, 'error');
        } finally {
            createBtn.disabled = false;
        }
    });

    $('clear-saved-search-form').addEventListener('click', () => {
        form.reset();
        notify('');
    });
    refreshBtn.addEventListener('click', async () => {
        notify('');
        await loadSavedSearches();
    });

    loadSavedSearches();
})();
