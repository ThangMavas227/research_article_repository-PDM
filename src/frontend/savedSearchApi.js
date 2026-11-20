/* Shared Saved Searches client. Uses the existing RARAuth Reader session. */
(function () {
    'use strict';

    function requireReaderSession() {
        const session = window.RARAuth?.getSession();
        if (!session?.token || session.user.role !== 'reader') {
            throw new Error('Please sign in with a Reader account to manage saved searches.');
        }
        return session;
    }

    function endpoint(path = '') {
        const config = window.APP_CONFIG;
        const configured = config?.SAVED_SEARCHES_API_URL ||
            new URL('/api/saved-searches', config?.AUTH_BASE_URL || 'http://localhost:8080').toString();
        return configured.replace(/\/$/, '') + path;
    }

    async function request(path = '', { method = 'GET', body } = {}) {
        const session = requireReaderSession();
        let response;
        try {
            response = await fetch(endpoint(path), {
                method,
                headers: {
                    Accept: 'application/json',
                    Authorization: `Bearer ${session.token}`,
                    ...(body === undefined ? {} : { 'Content-Type': 'application/json' })
                },
                ...(body === undefined ? {} : { body: JSON.stringify(body) })
            });
        } catch (_) {
            throw new Error('Cannot connect to the Saved Searches API. Check the backend and CORS settings.');
        }
        if (!response.ok) {
            let serverMessage = '';
            try {
                const data = await response.json();
                serverMessage = typeof data?.error === 'string' ? data.error
                    : typeof data?.message === 'string' ? data.message : '';
            } catch (_) { /* The server may return an empty error body. */ }
            if (response.status === 401) throw new Error('Your session has expired. Please sign in again.');
            if (response.status === 403) throw new Error('Your account cannot access Saved Searches.');
            if (response.status === 409) throw new Error('You already have a saved search with that name.');
            if (response.status === 404) throw new Error('Saved search not found. Refresh the list and try again.');
            throw new Error(serverMessage || `Saved Searches request failed (HTTP ${response.status}).`);
        }
        return response.status === 204 ? null : response.json();
    }

    function validateName(raw) {
        const name = String(raw || '').trim();
        if (!name) throw new Error('Enter a name for your search.');
        if (name.length > 100) throw new Error('Search name cannot exceed 100 characters.');
        if (/[\\/]/.test(name)) throw new Error('Search name must not contain / or \\.');
        return name;
    }

    function validateYear(raw) {
        const text = String(raw ?? '').trim();
        if (!text) return null;
        if (!/^\d{1,4}$/.test(text) || Number(text) < 1) {
            throw new Error('Year must be a number between 1 and 9999.');
        }
        return Number(text);
    }

    // The existing Browse API supports keyword + a single exact year.
    // Encode that year as a range with equal endpoints in SavedSearch criteria.
    function criteriaFromBrowse(keyword, year) {
        const cleanKeyword = String(keyword || '').trim();
        const validYear = validateYear(year);
        if (!cleanKeyword && validYear === null) {
            throw new Error('Search by keyword and/or year before saving.');
        }
        return {
            ...(cleanKeyword ? { keyword: cleanKeyword } : {}),
            ...(validYear === null ? {} : { yearFrom: validYear, yearTo: validYear })
        };
    }

    function readableCriteria(criteria) {
        const c = criteria || {};
        const parts = [];
        if (c.keyword) parts.push(`Keyword: ${c.keyword}`);
        if (c.yearFrom != null && c.yearFrom === c.yearTo) {
            parts.push(`Year: ${c.yearFrom}`);
        } else if (c.yearFrom != null || c.yearTo != null) {
            parts.push(`Years: ${c.yearFrom ?? 'Any'}–${c.yearTo ?? 'Any'}`);
        }
        if (c.venueType) {
            parts.push(`Venue: ${c.venueType === 'J' ? 'Journal' : c.venueType === 'C' ? 'Conference' : c.venueType}`);
        }
        return parts.join(' · ') || 'No filters';
    }

    function getBrowseParams(criteria) {
        const c = criteria || {};
        // Do not pretend a broader saved search is an exact-year / keyword search.
        if (c.venueType ||
            (c.yearFrom != null && c.yearTo == null) ||
            (c.yearFrom == null && c.yearTo != null) ||
            (c.yearFrom != null && c.yearTo != null && c.yearFrom !== c.yearTo)) {
            return null;
        }
        const params = new URLSearchParams();
        const keyword = typeof c.keyword === 'string' ? c.keyword.trim() : '';
        if (keyword) params.set('keyword', keyword);
        if (c.yearFrom != null) params.set('year', String(c.yearFrom));
        return params;
    }

    async function list() {
        const data = await request();
        if (!data || !Array.isArray(data.items)) {
            throw new Error('Invalid Saved Searches response received from the backend.');
        }
        return data.items;
    }

    async function create(searchName, criteria) {
        return request('', { method: 'POST', body: { searchName: validateName(searchName), criteria } });
    }

    async function remove(searchName) {
        return request(`/${encodeURIComponent(validateName(searchName))}`, { method: 'DELETE' });
    }

    window.RARSavedSearchApi = Object.freeze({
        list, create, remove, validateName, validateYear,
        criteriaFromBrowse, readableCriteria, getBrowseParams
    });
})();
