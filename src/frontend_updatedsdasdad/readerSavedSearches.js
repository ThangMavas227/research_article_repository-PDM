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

    // Dropdown choices come from the real Article API, not hardcoded years.
    const yearBox = $('saved-year-combobox');
    const yearToggle = $('saved-year-toggle');
    const yearMenu = $('saved-year-menu');
    let availableYears = [];
    let yearsStatus = 'loading';
    let suppressFocusOpen = false;

    function closeYearMenu() {
        yearMenu.hidden = true;
        yearInput.setAttribute('aria-expanded', 'false');
        yearToggle.setAttribute('aria-expanded', 'false');
    }

    function showYearMenu(showAll = false) {
        const filter = showAll ? '' : yearInput.value.trim();
        yearMenu.replaceChildren();
        if (yearsStatus === 'loading') {
            const note = document.createElement('p');
            note.className = 'saved-year-message';
            note.textContent = 'Loading available years...';
            yearMenu.appendChild(note);
        } else if (yearsStatus === 'error') {
            const note = document.createElement('p');
            note.className = 'saved-year-message';
            note.textContent = 'Could not load years. You can type a year manually.';
            yearMenu.appendChild(note);
        } else {
            const matches = availableYears.filter(value => !filter || value.includes(filter));
            if (!matches.length) {
                const note = document.createElement('p');
                note.className = 'saved-year-message';
                note.textContent = 'No matching years. You can type another year.';
                yearMenu.appendChild(note);
            }
            for (const value of matches) {
                const option = document.createElement('button');
                option.type = 'button';
                option.className = 'saved-year-option';
                option.setAttribute('role', 'option');
                option.setAttribute('aria-selected', String(yearInput.value === value));
                option.textContent = value;
                option.addEventListener('click', () => {
                    yearInput.value = value;
                    closeYearMenu();
                    suppressFocusOpen = true;
                    yearInput.focus();
                    suppressFocusOpen = false;
                });
                yearMenu.appendChild(option);
            }
        }
        yearMenu.hidden = false;
        yearInput.setAttribute('aria-expanded', 'true');
        yearToggle.setAttribute('aria-expanded', 'true');
    }

    yearToggle.addEventListener('click', () => {
        if (yearMenu.hidden) showYearMenu(true);
        else closeYearMenu();
    });
    yearInput.addEventListener('focus', () => {
        if (!suppressFocusOpen) showYearMenu(true);
    });
    yearInput.addEventListener('input', () => showYearMenu(false));
    yearInput.addEventListener('keydown', event => {
        if (event.key === 'Escape') {
            closeYearMenu();
            return;
        }
        if (event.key === 'ArrowDown') {
            event.preventDefault();
            if (yearMenu.hidden) showYearMenu(true);
            const firstOption = yearMenu.querySelector('.saved-year-option');
            firstOption?.focus();
        }
    });
    document.addEventListener('pointerdown', event => {
        if (!yearBox.contains(event.target)) closeYearMenu();
    });
    document.addEventListener('focusin', event => {
        if (!yearBox.contains(event.target)) closeYearMenu();
    });

    async function loadYearSuggestions() {
        const apiUrl = window.APP_CONFIG?.API_URL;
        if (!apiUrl) {
            yearsStatus = 'error';
            if (!yearMenu.hidden) showYearMenu(true);
            return;
        }
        const years = new Set();
        let page = 1;
        let totalPages = 1;
        try {
            do {
                const url = new URL(apiUrl, window.location.href);
                url.searchParams.set('page', String(page));
                url.searchParams.set('size', '100');
                const response = await fetch(url.toString(), {
                    headers: { Accept: 'application/json' }
                });
                if (!response.ok) throw new Error(`HTTP ${response.status}`);
                const data = await response.json();
                if (!Array.isArray(data.items) || !Number.isInteger(data.totalPages)) {
                    throw new Error('Unexpected article response');
                }
                for (const article of data.items) {
                    const year = Number(article.year);
                    if (Number.isInteger(year) && year >= 1000 && year <= 9999) {
                        years.add(String(year));
                    }
                }
                totalPages = data.totalPages;
                page += 1;
            } while (page <= totalPages);
            availableYears = [...years].sort((a, b) => Number(b) - Number(a));
            yearsStatus = 'ready';
        } catch (error) {
            yearsStatus = 'error';
            console.warn('[Saved Searches] Could not load publication years:', error);
        }
        if (!yearMenu.hidden) showYearMenu(true);
    }

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
        closeYearMenu();
        notify('');
    });
    refreshBtn.addEventListener('click', async () => {
        notify('');
        await loadSavedSearches();
    });

    void loadYearSuggestions();
    loadSavedSearches();
})();
