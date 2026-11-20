"use strict";

const API_URL = window.APP_CONFIG?.API_URL || "http://localhost:8080/api/articles";
const API_PAGE_SIZE = 100; 
const $ = (id) => document.getElementById(id);

const state = { articles: [], totalItems: 0 };

function setStatus(message, isError = false) {
  const element = $("dashboard-status");
  element.textContent = message;
  element.classList.toggle("error", isError);
}

function setText(id, value) {
  $(id).textContent = String(value);
}

function makeArticleLink(article) {
  const link = document.createElement("a");
  link.href = `articleDetail.html?id=${encodeURIComponent(String(article.id))}`;
  link.textContent = article.title;

  link.addEventListener("click", () => {
    try {
      const key = window.APP_CONFIG?.SELECTED_ARTICLE_KEY;
      if (key) sessionStorage.setItem(key, JSON.stringify(article));
    } catch (_) {}
  });
  return link;
}

async function fetchAllArticles() {
  const items = [];
  let totalItems = 0;
  let totalPages = 1;

  for (let page = 1; page <= totalPages; page++) {
    const url = new URL(API_URL, window.location.href);
    url.searchParams.set("page", String(page));
    url.searchParams.set("size", String(API_PAGE_SIZE));

    const response = await fetch(url, { headers: { Accept: "application/json" } });
    if (!response.ok) throw new Error(`GET /api/articles returned HTTP ${response.status}`);

    const data = await response.json();
    if (!data || !Array.isArray(data.items) ||
        !Number.isInteger(data.totalItems) || data.totalItems < 0 ||
        !Number.isInteger(data.totalPages) || data.totalPages < 0) {
      throw new Error("Unexpected API response: missing items, totalItems or totalPages.");
    }

    if (page === 1) {
      totalItems = data.totalItems;
      totalPages = data.totalPages;
    }
    items.push(...data.items);
  }

  if (items.length !== totalItems) {
    throw new Error(`API returned ${items.length} articles but totalItems is ${totalItems}.`);
  }
  return { items, totalItems };
}

function countUniqueAuthors(articles) {
  const authorIds = new Set();
  articles.forEach((article) => {
    if (!Array.isArray(article.authors)) return;
    article.authors.forEach((author) => {
      if (!author || typeof author !== "object") return;
      const key = author.id != null ? `id:${author.id}` :
        typeof author.name === "string" ? `name:${author.name.trim().toLowerCase()}` : null;
      if (key) authorIds.add(key);
    });
  });
  return authorIds.size;
}

function fillYearSelectors(articles) {
  const from = $("year-from");
  const to = $("year-to");
  from.replaceChildren();
  to.replaceChildren();

  if (articles.length === 0) {
    from.disabled = true;
    to.disabled = true;
    return;
  }

  const years = articles.map((article) => article.year)
    .filter((year) => Number.isInteger(year));
  if (years.length === 0) throw new Error("The API did not return valid publication years.");

  const min = Math.min(...years);
  const max = Math.max(...years);
  for (let year = min; year <= max; year++) {
    for (const select of [from, to]) {
      const option = document.createElement("option");
      option.value = String(year);
      option.textContent = String(year);
      select.appendChild(option);
    }
  }
  from.value = String(min);
  to.value = String(max);
  from.disabled = false;
  to.disabled = false;
}

function renderMostCited(articles) {
  const container = $("most-cited");
  container.replaceChildren();

  if (articles.some((article) => !Array.isArray(article.citedBy))) {
    container.textContent = "Citation data unavailable";
    return;
  }
  if (articles.length === 0) {
    container.textContent = "No articles in selected years";
    return;
  }

  const maxCitations = Math.max(...articles.map((article) => article.citedBy.length));
  if (maxCitations === 0) {
    container.textContent = "No citations recorded";
    return;
  }

  const leaders = articles.filter((article) => article.citedBy.length === maxCitations)
    .sort((a, b) => a.title.localeCompare(b.title));
  const title = makeArticleLink(leaders[0]);
  title.className = "most-cited-title";
  container.appendChild(title);

  const meta = document.createElement("p");
  meta.className = "most-cited-meta";
  meta.textContent = `${maxCitations} citation${maxCitations === 1 ? "" : "s"}` +
    (leaders.length > 1 ? ` · ${leaders.length} articles tied` : "");
  container.appendChild(meta);
}

function renderChart(articles, fromYear, toYear) {
  const chart = $("year-chart");
  chart.replaceChildren();
  setText("chart-range-label", `${fromYear}–${toYear}`);

  const counts = new Map();
  for (let year = fromYear; year <= toYear; year++) counts.set(year, 0);
  articles.forEach((article) => counts.set(article.year, (counts.get(article.year) || 0) + 1));
  const maxCount = Math.max(1, ...counts.values());

  for (const [year, count] of counts) {
    const column = document.createElement("div");
    column.className = "chart-year";
    column.setAttribute("role", "listitem");
    column.setAttribute("aria-label", `${year}: ${count} articles`);

    const number = document.createElement("span");
    number.className = "chart-count";
    number.textContent = String(count);

    const track = document.createElement("div");
    track.className = "chart-track";
    const bar = document.createElement("div");
    bar.className = "chart-bar";
    bar.style.height = `${(count / maxCount) * 100}%`;
    bar.title = `${year}: ${count} articles`;
    track.appendChild(bar);

    const label = document.createElement("span");
    label.className = "chart-year-label";
    label.textContent = String(year);

    column.append(number, track, label);
    chart.appendChild(column);
  }
}

function renderRecentArticles(articles) {
  const list = $("recent-articles");
  list.replaceChildren();
  const recent = [...articles]
    .sort((a, b) => b.year - a.year || a.title.localeCompare(b.title))
    .slice(0, 5);

  if (recent.length === 0) {
    const row = document.createElement("li");
    row.className = "placeholder";
    row.textContent = "No articles in the selected years.";
    list.appendChild(row);
    return;
  }

  recent.forEach((article) => {
    const row = document.createElement("li");
    const year = document.createElement("time");
    year.textContent = String(article.year);
    row.append(makeArticleLink(article), year);
    list.appendChild(row);
  });
}

function updateFilteredDashboard() {
  if (state.articles.length === 0) return;
  const fromYear = Number($("year-from").value);
  const toYear = Number($("year-to").value);
  const filtered = state.articles.filter((article) =>
    article.year >= fromYear && article.year <= toYear);

  setText("range-total", filtered.length);
  renderMostCited(state.articles);
  renderChart(filtered, fromYear, toYear);
  renderRecentArticles(filtered);
}

function onYearChange(changed) {
  const from = $("year-from");
  const to = $("year-to");
  if (Number(from.value) > Number(to.value)) {
    if (changed === "from") to.value = from.value;
    else from.value = to.value;
  }
  updateFilteredDashboard();
}

async function loadDashboard() {
  $("retry-dashboard").hidden = true;
  $("year-from").disabled = true;
  $("year-to").disabled = true;
  setStatus("Loading article statistics from backend…");
  ["total-articles", "range-total", "total-authors"].forEach((id) => setText(id, "—"));

  try {
    const { items, totalItems } = await fetchAllArticles();
    if (items.some((item) => !item || typeof item.title !== "string" ||
        item.id == null || !Number.isInteger(item.year))) {
      throw new Error("Some articles have missing id, title or year fields.");
    }
    state.articles = items;
    state.totalItems = totalItems;

    setText("total-articles", totalItems);
    setText("total-authors", countUniqueAuthors(items));
    fillYearSelectors(items);

    if (items.length > 0) {
      updateFilteredDashboard();
    } else {
      setText("range-total", 0);
      $("most-cited").textContent = "No articles available";
      $("year-chart").textContent = "No data to chart.";
      $("recent-articles").textContent = "No articles available.";
      setText("chart-range-label", "");
    }
    setStatus(`Loaded ${totalItems} articles from Backend API.`);
  } catch (error) {
    state.articles = [];
    $("most-cited").textContent = "Unavailable";
    $("year-chart").textContent = "Chart unavailable.";
    $("recent-articles").textContent = "Recent articles unavailable.";
    setText("chart-range-label", "");
    setStatus("Disconnected from server.", true);
    $("retry-dashboard").hidden = false;
    console.error("[Dashboard]", error);
  }
}

$("year-from").addEventListener("change", () => onYearChange("from"));
$("year-to").addEventListener("change", () => onYearChange("to"));
$("retry-dashboard").addEventListener("click", loadDashboard);
loadDashboard();
