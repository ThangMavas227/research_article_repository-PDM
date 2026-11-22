(() => {
  "use strict";

  const $ = (id) => document.getElementById(id);
  const PAGE_SIZE = 10;
  const state = {
    page: 1,
    keyword: "",
    articles: [],
    totalItems: 0,
    totalPages: 0,
    selectedId: null,
    requestId: 0,
    controller: null,
    loading: false
  };

  function showError(message) {
    const notice = $("request-error");
    notice.textContent = message || "Could not load articles.";
    notice.hidden = false;
  }

  function hideError() {
    const notice = $("request-error");
    notice.textContent = "";
    notice.hidden = true;
  }

  function blankRow(tableBodyId, colspan, message) {
    const body = $(tableBodyId);
    body.replaceChildren();
    const row = document.createElement("tr");
    const cell = document.createElement("td");
    cell.className = "md-empty";
    cell.colSpan = colspan;
    cell.textContent = message;
    row.appendChild(cell);
    body.appendChild(row);
  }

  function cell(row, value, className = "") {
    const item = document.createElement("td");
    if (className) item.className = className;
    item.textContent = value === null || value === undefined || value === "" ? "—" : String(value);
    row.appendChild(item);
    return item;
  }

  function updatePagination() {
    const pages = Math.max(1, state.totalPages);
    const start = state.totalItems ? (state.page - 1) * PAGE_SIZE + 1 : 0;
    const end = state.totalItems ? start + state.articles.length - 1 : 0;
    $("master-page-summary").textContent = state.totalItems
      ? `Showing ${start}–${end} articles`
      : "0 articles";
    $("article-total").textContent = String(state.totalItems);
    $("page-indicator").textContent = `Page ${state.totalPages ? state.page : 1} / ${pages}`;
    $("previous-button").disabled = state.loading || state.page <= 1;
    $("next-button").disabled = state.loading || state.page >= state.totalPages;
  }

  function selectArticle(articleId) {
    const article = state.articles.find((item) => String(item.id) === String(articleId));
    if (!article) return;
    state.selectedId = String(article.id);
    for (const row of $("articles-body").querySelectorAll("tr[data-article-id]")) {
      row.setAttribute("aria-selected", String(row.dataset.articleId === state.selectedId));
    }

    const authors = Array.isArray(article.authors) ? article.authors : [];
    $("author-total").textContent = String(authors.length);
    $("selected-article-summary").textContent = `${article.id} · ${article.title || "Untitled article"}`;
    const link = $("open-article-link");
    link.href = `articleDetail.html?id=${encodeURIComponent(String(article.id))}`;
    link.hidden = false;
    if (!authors.length) {
      blankRow("authors-body", 3, "No authors recorded for this article.");
      return;
    }

    const fragment = document.createDocumentFragment();
    authors.forEach((author, index) => {
      const row = document.createElement("tr");
      cell(row, index + 1, "md-numeric"); // Backend orders authors by Writes.Position.
      cell(row, author?.id, "md-article-id");
      cell(row, author?.name);
      fragment.appendChild(row);
    });
    $("authors-body").replaceChildren(fragment);
  }

  function clearSelectedArticle(message = "Select an article in the upper grid.") {
    state.selectedId = null;
    $("selected-article-summary").textContent = message;
    $("author-total").textContent = "0";
    $("open-article-link").hidden = true;
    $("open-article-link").removeAttribute("href");
    blankRow("authors-body", 3, message);
  }

  function renderArticles() {
    const body = $("articles-body");
    body.replaceChildren();

    if (!state.articles.length) {
      blankRow("articles-body", 5, "No articles match these search criteria.");
      clearSelectedArticle("No article selected.");
      updatePagination();
      return;
    }

    const fragment = document.createDocumentFragment();
    for (const article of state.articles) {
      const row = document.createElement("tr");
      row.dataset.articleId = String(article.id);
      row.tabIndex = 0;
      row.setAttribute("aria-selected", "false");
      row.title = `Select ${article.id} to view its authors`;
      cell(row, article.id, "md-article-id");
      cell(row, article.title, "md-article-title");
      cell(row, article.year, "md-numeric");
      cell(row, article.venueName || article.venueId, "md-venue");
      cell(row, Array.isArray(article.authors) ? article.authors.length : 0, "md-numeric");
      row.addEventListener("click", () => selectArticle(article.id));
      row.addEventListener("keydown", (event) => {
        if (event.target === row && (event.key === "Enter" || event.key === " ")) {
          event.preventDefault();
          selectArticle(article.id);
        }
      });
      fragment.appendChild(row);
    }
    body.appendChild(fragment);
    updatePagination();
    // Automatically select the first record on the new page. No mock data is used.
    selectArticle(state.articles[0].id);
  }

  function setLoading(loading) {
    state.loading = loading;
    $("search-button").disabled = loading;
    $("clear-button").disabled = loading;
    $("refresh-button").disabled = loading;
    updatePagination();
  }

  async function loadArticles() {
    const requestId = ++state.requestId;
    state.controller?.abort();
    const controller = new AbortController();
    state.controller = controller;
    hideError();
    setLoading(true);
    blankRow("articles-body", 5, "Loading articles from Backend...");
    clearSelectedArticle("Loading authors...");
    $("master-page-summary").textContent = "Loading articles...";

    try {
      if (!window.APP_CONFIG?.API_URL) throw new Error("Missing API_URL in config.js.");
      const url = new URL(window.APP_CONFIG.API_URL, window.location.href);
      url.searchParams.set("page", String(state.page));
      url.searchParams.set("size", String(PAGE_SIZE));
      if (state.keyword) url.searchParams.set("keyword", state.keyword);

      const response = await fetch(url.toString(), {
        method: "GET",
        headers: { Accept: "application/json" },
        cache: "no-store",
        signal: controller.signal
      });
      if (!response.ok) throw new Error(`Could not load articles (HTTP ${response.status}).`);
      const result = await response.json();
      if (!result || !Array.isArray(result.items) ||
          !Number.isInteger(result.totalItems) || !Number.isInteger(result.totalPages) ||
          !Number.isInteger(result.page) || result.page < 1 ||
          result.totalItems < 0 || result.totalPages < 0 ||
          result.items.some(item => !item || item.id == null || !Array.isArray(item.authors))) {
        throw new Error("Unexpected response from /api/articles.");
      }
      if (requestId !== state.requestId) return;

      // If a record was deleted on the last page, move back to the remaining last page.
      if (result.totalPages > 0 && state.page > result.totalPages) {
        state.page = result.totalPages;
        return loadArticles();
      }
      state.page = result.page;
      state.articles = result.items;
      state.totalItems = result.totalItems;
      state.totalPages = result.totalPages;
      renderArticles();
    } catch (error) {
      if (error.name === "AbortError" || requestId !== state.requestId) return;
      console.error("[Master–Detail]", error);
      state.articles = [];
      state.totalItems = 0;
      state.totalPages = 0;
      blankRow("articles-body", 5, "Articles could not be loaded.");
      clearSelectedArticle("No article selected.");
      showError(`${error.message} Make sure Spring Boot and MySQL are running, then click Reload.`);
    } finally {
      if (requestId === state.requestId) setLoading(false);
    }
  }

  $("article-search-form").addEventListener("submit", (event) => {
    event.preventDefault();
    state.keyword = $("article-search").value.trim();
    state.page = 1;
    loadArticles();
  });

  $("clear-button").addEventListener("click", () => {
    $("article-search").value = "";
    state.keyword = "";
    state.page = 1;
    loadArticles();
  });

  $("refresh-button").addEventListener("click", loadArticles);
  $("previous-button").addEventListener("click", () => {
    if (state.loading || state.page <= 1) return;
    state.page--;
    loadArticles();
  });
  $("next-button").addEventListener("click", () => {
    if (state.loading || state.page >= state.totalPages) return;
    state.page++;
    loadArticles();
  });

  loadArticles();
})();
