
(() => {
  "use strict";
  if (!window.RARAuth || window.RARAuth.getRole() !== "admin") return;

  const $ = id => document.getElementById(id);
  const PAGE_SIZE_ARTICLES = 6;
  const PAGE_SIZE_AUTHORS = 12;
  const state = { articles: [], authors: [], tab: "articles", page: 1, selectedAuthors: [] };
  document.body.dataset.activeTab = state.tab;
  const saveButton = $("save-article");
  let editingArticleId = null;
  let deletingArticleId = null;

  function feedback(text, error = false) {
    const element = $("feedback");
    element.textContent = text;
    element.className = `feedback ${error ? "error" : "success"}`;
    element.hidden = false;
  }

  async function readJson(response) {
    return response.json().catch(() => ({}));
  }

  async function verifyAdmin() {
    const session = window.RARAuth.getSession();
    if (!session?.token) throw new Error("Please log in as Admin.");
    const response = await fetch(`${window.APP_CONFIG.AUTH_BASE_URL}/api/auth/me`, {
      headers: { Authorization: `Bearer ${session.token}` }
    });
    if (response.status === 401 || response.status === 403) {
      window.RARAuth.clearSession();
      window.location.replace("login.html");
      throw new Error("Session expired. Please log in again.");
    }
    if (!response.ok) throw new Error(`Cannot verify Admin session (HTTP ${response.status}).`);
    const user = await readJson(response);
    if (user.role !== "admin") {
      window.location.replace("index.html");
      throw new Error("Only Admin can manage articles.");
    }
    return session.token;
  }

  async function fetchArticles() {
    const items = [];
    let totalPages = 1;
    let totalItems = 0;
    const size = 100;
    for (let page = 1; page <= totalPages; page++) {
      const url = new URL(window.APP_CONFIG.API_URL);
      url.searchParams.set("page", String(page));
      url.searchParams.set("size", String(size));
      const response = await fetch(url);
      if (!response.ok) throw new Error(`Cannot load articles (HTTP ${response.status}).`);
      const data = await readJson(response);
      if (!data || !Array.isArray(data.items) || !Number.isInteger(data.totalPages) ||
          !Number.isInteger(data.totalItems)) {
        throw new Error("Unexpected article list response.");
      }
      if (page === 1) { totalPages = data.totalPages; totalItems = data.totalItems; }
      items.push(...data.items);
    }
    if (items.length !== totalItems) throw new Error("Article pagination totals do not match.");
    return items;
  }

  function extractAuthors(articles) {
    const map = new Map();
    for (const article of articles) {
      for (const author of (article.authors || [])) {
        if (author?.id && author?.name) map.set(author.id, { id: author.id, name: author.name });
      }
    }
    return [...map.values()].sort((a,b) => a.name.localeCompare(b.name));
  }

  function populateEditions() {
    const select = $("article-edition");
    const previous = select.value;
    select.replaceChildren(new Option("Choose a venue / edition", ""));
    const unique = new Map();
    for (const article of state.articles) {
      if (!article.venueId || !Number.isInteger(article.editionNumber)) continue;
      const key = `${article.venueId}::${article.editionNumber}`;
      if (!unique.has(key)) unique.set(key, article);
    }
    for (const article of [...unique.values()].sort((a,b) =>
        String(a.venueName || a.venueId).localeCompare(String(b.venueName || b.venueId)) ||
        a.editionNumber - b.editionNumber)) {
      const option = new Option(
          `${article.venueName || article.venueId} — ${article.venueId} / Edition ${article.editionNumber} (${article.year})`,
          `${article.venueId}::${article.editionNumber}`
      );
      select.add(option);
    }
    if ([...select.options].some(opt => opt.value === previous)) select.value = previous;
  }

  function renderAuthors() {
    const parent = $("author-picker");
    parent.replaceChildren();
    const term = $("author-search").value.trim().toLocaleLowerCase();
    const items = state.authors.filter(author =>
        state.selectedAuthors.includes(author.id) ||
        (term && `${author.name} ${author.id}`.toLocaleLowerCase().includes(term))
    );
    for (const author of items) {
      const label = document.createElement("label");
      label.className = "author-option";
      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.checked = state.selectedAuthors.includes(author.id);
      checkbox.addEventListener("change", () => {
        state.selectedAuthors = checkbox.checked
            ? [...state.selectedAuthors, author.id]
            : state.selectedAuthors.filter(id => id !== author.id);
        renderAuthors();
      });
      const text = document.createElement("span");
      text.textContent = `${author.name} (${author.id})`;
      label.append(checkbox, text);
      parent.appendChild(label);
    }
    if (!items.length) {
      const empty = document.createElement("p");
      empty.className = "author-picker-empty";
      empty.textContent = term ? "No matching authors in loaded articles." : "Search authors above, or enter a new author name.";
      parent.appendChild(empty);
    }
    $("author-selection-status").textContent = `${state.selectedAuthors.length} existing author(s) selected, in selection order.`;
  }

  function filtered() {
    const term = $("record-search").value.trim().toLocaleLowerCase();
    const data = state.tab === "authors" ? state.authors : state.articles;
    return data.filter(item => !term || (state.tab !== "authors"
            ? [item.id, item.title, item.doi, item.year, ...(item.authors || []).map(a=>a.name)]
            : [item.id,item.name]
    ).some(value => String(value ?? "").toLocaleLowerCase().includes(term)));
  }

  function addLine(parent, label, value) {
    const p = document.createElement("p");
    const strong = document.createElement("strong");
    strong.textContent = `${label}: `;
    p.append(strong, document.createTextNode(String(value ?? "—")));
    parent.appendChild(p);
  }

  function render() {
    const items = filtered();
    const pageSize = state.tab === "authors" ? PAGE_SIZE_AUTHORS : PAGE_SIZE_ARTICLES;
    const pages = Math.max(1, Math.ceil(items.length / pageSize));
    state.page = Math.max(1, Math.min(state.page, pages));
    const parent = $("record-list");
    parent.replaceChildren();
    for (const item of items.slice((state.page-1)*pageSize,state.page*pageSize)) {
      const card = document.createElement("article");
      card.className = "record-card";
      const heading = document.createElement("h4");
      if (state.tab === "articles") {
        const link = document.createElement("a");
        link.href = `articleDetail.html?id=${encodeURIComponent(String(item.id))}`;
        link.textContent = item.title;
        heading.append(link);
        card.appendChild(heading);
        addLine(card,"Article ID",item.id);
        addLine(card,"DOI",item.doi);
        addLine(card,"Year",item.year);
        addLine(card,"Authors",(item.authors || []).map(a=>a.name).join(", "));
        const editButton = document.createElement("button");

        editButton.type = "button";
        editButton.className = "btn btn-secondary btn-small";
        editButton.textContent = "Edit";

        editButton.addEventListener("click", () => {
          showEditForm(item);
        });

        card.appendChild(editButton);

        const deleteButton = document.createElement("button");
        deleteButton.type = "button";
        deleteButton.className = "btn btn-secondary btn-small";
        deleteButton.textContent = "Delete";
        deleteButton.setAttribute("aria-label", `Delete article ${item.id}`);
        deleteButton.addEventListener("click", () => deleteArticle(item, deleteButton));
        card.appendChild(deleteButton);
      } else {
        heading.textContent = item.name;
        card.appendChild(heading);
        addLine(card,"Author ID",item.id);
      }
      parent.appendChild(card);
    }
    if (!items.length) {
      const empty = document.createElement("p");
      empty.className = "empty-result";
      empty.textContent = "No matching records.";
      parent.appendChild(empty);
    }
    $("record-pagination").hidden = pages <= 1;
    $("page-count").textContent = `Page ${state.page} / ${pages}`;
    $("previous-page").disabled = state.page <= 1;
    $("next-page").disabled = state.page >= pages;
  }

  function showTab(tab) {
    if (!["articles", "add", "authors"].includes(tab)) return;
    state.tab = tab;
    state.page = 1;
    document.body.dataset.activeTab = tab;
    $("record-search").value = "";

    const tabIds = { articles: "articles-tab", add: "add-article-tab", authors: "authors-tab" };
    for (const [name, id] of Object.entries(tabIds)) {
      const selected = name === tab;
      $(id).setAttribute("aria-selected", String(selected));
      $(id).tabIndex = selected ? 0 : -1;
    }

    $("records-panel").hidden = tab === "add";
    $("article-form-panel").hidden = tab !== "add";
    $("records-panel").setAttribute("aria-labelledby", tab === "authors" ? "authors-tab" : "articles-tab");

    if (tab !== "add") {
      $("list-heading").textContent = tab === "articles" ? "Articles" : "Authors appearing in articles";
      $("list-description").textContent = tab === "articles"
          ? ""
          : "";
      $("record-search").placeholder = tab === "articles"
          ? "Search article or author..."
          : "Search author name or ID...";
      render();
    }
  }

  async function load() {
    $("reload-records").disabled = true;
    feedback("Loading data from MySQL...");
    try {
      state.articles = await fetchArticles();
      state.authors = extractAuthors(state.articles);
      $("article-count").textContent = String(state.articles.length);
      $("author-count").textContent = String(state.authors.length);
      populateEditions();
      renderAuthors();
      render();
      feedback(`Loaded ${state.articles.length} articles.`);
    } catch (error) {
      feedback(`Could not load records: ${error.message}`, true);
      console.error("[Manage Content]", error);
    } finally {
      $("reload-records").disabled = false;
    }
  }

  function resetForm({ focus = true } = {}) {
    editingArticleId = null;
    $("article-form").reset();
    state.selectedAuthors = [];
    $("author-search").value = "";
    $("article-form-heading").textContent = "Add Article";
    saveButton.disabled = false;
    saveButton.textContent = "Save New Article";
    renderAuthors();
    if (focus) $("article-title").focus();
  }

  function showEditForm(article) {
    const feedbackElement = $("feedback");
    feedbackElement.textContent = "";
    feedbackElement.hidden = true;
    feedbackElement.className = "feedback";
    editingArticleId = article.id;

    $("article-title").value = article.title || "";
    $("article-doi").value = article.doi || "";
    $("article-abstract").value = article.abstract || "";
    $("article-start-page").value = article.startPage ?? "";

    $("article-edition").value =
        `${article.venueId}::${article.editionNumber}`;

    state.selectedAuthors = (article.authors || [])
        .map(author => author.id);

    $("author-search").value = "";
    $("new-author-name").value = "";

    renderAuthors();

    $("article-form-heading").textContent =
        `Edit Article — ${article.id}`;


    saveButton.disabled = false;
    saveButton.textContent = "Save Changes";

    showTab("add");

    $("article-form-panel").scrollIntoView({
      behavior: "smooth",
      block: "start"
    });
  }

  async function deleteArticle(article, button) {
    if (deletingArticleId || !article?.id) return;

    const confirmed = window.confirm(
        `Delete article ${article.id}?\n\n${article.title}\n\n` +
        "This permanently deletes the article and its associated links. This cannot be undone."
    );
    if (!confirmed) return;

    deletingArticleId = article.id;
    button.disabled = true;
    button.textContent = "Deleting...";

    try {
      const token = await verifyAdmin();
      const url = `${window.APP_CONFIG.API_URL}/${encodeURIComponent(String(article.id))}`;

      const response = await fetch(url, {
        method: "DELETE",
        headers: {
          Authorization: `Bearer ${token}`
        }
      });

      if (response.status !== 204) {
        const data = await readJson(response);

        if (response.status === 401) {
          window.RARAuth.clearSession();
          window.location.replace("login.html");
          throw new Error("Session expired. Please log in again.");
        }

        if (response.status === 403) {
          throw new Error("Only Admin can delete articles.");
        }

        if (response.status === 404) {
          throw new Error(`Article ${article.id} no longer exists.`);
        }

        throw new Error(
            data.error || `Delete failed (HTTP ${response.status}).`
        );
      }

      if (editingArticleId === article.id) {
        resetForm({ focus: false });
      }

      await load();

      feedback(
          `Article ${article.id} deleted successfully from MySQL.`
      );

    } catch (error) {
      feedback(
          error.message || "Could not delete article.",
          true
      );
    } finally {
      deletingArticleId = null;
      button.disabled = false;
      button.textContent = "Delete";
    }
  }

  function makeCreateBody() {
    const title = $("article-title").value.trim();
    const doi = $("article-doi").value.trim();
    const startPage = Number($("article-start-page").value);
    const edition = $("article-edition").value;
    const newAuthor = $("new-author-name").value.trim();

    if (!title) {
      throw new Error("Title is required.");
    }

    if (title.length > 255) {
      throw new Error("Title must be at most 255 characters.");
    }

    if (!/^10\.[0-9]{4,9}\/.+/.test(doi) || doi.length > 100) {
      throw new Error("Invalid DOI format.");
    }

    if (!Number.isSafeInteger(startPage) || startPage < 1) {
      throw new Error("Start Page must be a positive integer.");
    }

    if (!edition) {
      throw new Error("Choose a Venue / Edition.");
    }

    const [venueId, editionText] = edition.split("::");
    const editionNumber = Number(editionText);

    if (!venueId || !Number.isSafeInteger(editionNumber)) {
      throw new Error("Invalid edition selected.");
    }

    const authors = state.selectedAuthors.map(id => ({ id }));

    if (newAuthor) {
      authors.push({ name: newAuthor });
    }

    if (!authors.length) {
      throw new Error(
          "Select an existing author or enter a new author name."
      );
    }

    return {
      title,
      doi,
      abstract: $("article-abstract").value.trim() || null,
      startPage,
      venueId,
      editionNumber,
      authors
    };
  }

  $("article-form").addEventListener("submit", async event => {
    event.preventDefault();

    if (saveButton.disabled) return;

    let body;

    try {
      body = makeCreateBody();
    } catch (error) {
      feedback(error.message, true);
      return;
    }

    const articleId = editingArticleId;
    const isEditing = articleId !== null;
    const method = isEditing ? "PUT" : "POST";

    const url = isEditing
        ? `${window.APP_CONFIG.API_URL}/${encodeURIComponent(articleId)}`
        : window.APP_CONFIG.API_URL;

    saveButton.disabled = true;
    saveButton.textContent = "Saving...";

    try {
      const token = await verifyAdmin();

      const response = await fetch(url, {
        method,
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`
        },
        body: JSON.stringify(body)
      });

      const data = await readJson(response);

      if (!response.ok) {
        if (response.status === 401) {
          window.RARAuth.clearSession();
          window.location.replace("login.html");
          throw new Error("Session expired. Please log in again.");
        }

        if (response.status === 403) {
          throw new Error("Only Admin can manage articles.");
        }

        throw new Error(
            data.error ||
            `Could not save article (HTTP ${response.status}).`
        );
      }

      resetForm({ focus: false });
      await load();
      showTab("articles");

      feedback(
          isEditing
              ? `Article ${articleId} updated successfully in MySQL.`
              : `Article created in MySQL: ${data.id || "success"}.`
      );

    } catch (error) {
      feedback(
          error.message || "Could not save article.",
          true
      );
    } finally {
      saveButton.disabled = false;
      saveButton.textContent =
          editingArticleId === null
              ? "Save New Article"
              : "Save Changes";
    }
  });

  $("articles-tab").addEventListener("click", () => showTab("articles"));
  $("add-article-tab").addEventListener("click", () => {
    showTab("add");
    resetForm();
  });
  $("authors-tab").addEventListener("click", () => showTab("authors"));

  const tabs = [$("articles-tab"), $("add-article-tab"), $("authors-tab")];
  $("articles-tab").parentElement.addEventListener("keydown", event => {
    const index = tabs.indexOf(document.activeElement);
    if (index === -1) return;
    const next = event.key === "ArrowRight" ? (index + 1) % tabs.length
        : event.key === "ArrowLeft" ? (index + tabs.length - 1) % tabs.length
        : event.key === "Home" ? 0
        : event.key === "End" ? tabs.length - 1 : -1;
    if (next < 0) return;
    event.preventDefault();
    tabs[next].click();
    tabs[next].focus();
  });

  $("record-search").addEventListener("input", () => {
    state.page = 1;
    render();
  });

  $("author-search").addEventListener("input", renderAuthors);

  $("previous-page").addEventListener("click", () => {
    if (state.page > 1) {
      state.page--;
      render();
    }
  });

  $("next-page").addEventListener("click", () => {
    state.page++;
    render();
  });

  $("reload-records").addEventListener("click", load);
  $("cancel-article").addEventListener("click", () => resetForm());

  (async () => {
    try {
      await verifyAdmin();
      await load();
    } catch (error) {
      feedback(
          error.message || "Cannot verify session.",
          true
      );
    }
  })();
})();
