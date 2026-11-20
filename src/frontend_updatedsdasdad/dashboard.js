"use strict";

/* Dashboard: Q3/Q4/Q5 reports from Spring Boot, plus existing year-range chart. */
const API_URL = window.APP_CONFIG?.API_URL || "http://localhost:8080/api/articles";
const REPORTS_URL = new URL("/api/reports/", API_URL).toString();
const API_PAGE_SIZE = 100;
const $ = id => document.getElementById(id);
const state = { articles: [], venues: [], selectedVenueIds: new Set() };
let q3RequestNumber = 0;
let q4RequestNumber = 0;

function setStatus(message, isError = false) {
  const element = $("dashboard-status");
  element.textContent = message;
  element.classList.toggle("error", isError);
}

function setText(id, value) { $(id).textContent = String(value); }

function makeArticleLink(article) {
  const link = document.createElement("a");
  link.href = `articleDetail.html?id=${encodeURIComponent(String(article.id))}`;
  link.textContent = article.title;

  // Keep old behavior for the existing Recent Articles section.
  link.addEventListener("click", () => {
    try {
      const key = window.APP_CONFIG?.SELECTED_ARTICLE_KEY;
      if (key) sessionStorage.setItem(key, JSON.stringify(article));
    } catch (_) { /* Detail can load from API. */ }
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
    if (!response.ok) throw new Error(`GET /api/articles: HTTP ${response.status}`);
    const data = await response.json();
    if (!data || !Array.isArray(data.items) || !Number.isInteger(data.totalPages) ||
        !Number.isInteger(data.totalItems) || data.totalItems < 0 || data.totalPages < 0) {
      throw new Error("Unexpected /api/articles response.");
    }
    if (page === 1) { totalItems = data.totalItems; totalPages = data.totalPages; }
    items.push(...data.items);
  }
  if (items.length !== totalItems) throw new Error("Article count does not match API totalItems.");
  return items;
}

async function fetchReport(endpoint, query = {}) {
  const url = new URL(endpoint, REPORTS_URL);
  for (const [name, value] of Object.entries(query)) {
    if (value !== undefined && value !== null && String(value).trim() !== "") {
      url.searchParams.set(name, String(value));
    }
  }
  const response = await fetch(url, { headers: { Accept: "application/json" } });
  const data = await response.json().catch(() => null);
  if (!response.ok) throw new Error(data?.error || `Report failed (HTTP ${response.status}).`);
  if (!Array.isArray(data)) throw new Error("Unexpected report response (expected an array).");
  return data;
}

function showListMessage(id, text, error = false) {
  const parent = $(id);
  parent.replaceChildren();
  const item = document.createElement("li");
  item.className = error ? "report-placeholder report-error" : "report-placeholder";
  item.textContent = text;
  parent.appendChild(item);
}

function showYearMessage(text, error = false) {
  const parent = $("q5-list");
  parent.replaceChildren();
  const p = document.createElement("p");
  p.className = error ? "report-placeholder report-error" : "report-placeholder";
  p.textContent = text;
  parent.appendChild(p);
}

// Q3: Top cited articles filtered by subject area.
async function loadQ3() {
  const requestNumber = ++q3RequestNumber;
  const areaId = $("q3-area").value.trim();
  if (!areaId) {
    showListMessage("q3-list", "Enter a Subject Area ID.", true);
    return false;
  }
  $("q3-apply").disabled = true;
  $("q3-list").replaceChildren();
  try {
    const rows = await fetchReport("top-cited", { areaId });
    if (requestNumber !== q3RequestNumber) return false;
    setText("q3-meta", `${rows.length} article(s) · Subject Area ID: ${areaId}`);
    const list = $("q3-list");
    list.replaceChildren();
    if (!rows.length) {
      showListMessage("q3-list", "No cited articles in this subject area.");
    } else {
      for (const row of rows) {
        const item = document.createElement("li");
        const link = document.createElement("a");
        link.href = `articleDetail.html?id=${encodeURIComponent(String(row.id))}`;
        link.textContent = String(row.title ?? row.id);
        const meta = document.createElement("div");
        meta.className = "report-item-meta";
        meta.textContent = `${row.citationCount} citation(s)`;
        item.append(link, meta);
        list.appendChild(item);
      }
    }
    return true;
  } catch (error) {
    if (requestNumber === q3RequestNumber) showListMessage("q3-list", error.message, true);
    return false;
  } finally {
    if (requestNumber === q3RequestNumber) $("q3-apply").disabled = false;
  }
}

function fillYearSelectors(articles) {
  const from = $("year-from");
  const to = $("year-to");
  from.replaceChildren();
  to.replaceChildren();
  if (!articles.length) { from.disabled = true; to.disabled = true; return; }

  const years = articles.map(article => article.year).filter(Number.isInteger);
  if (!years.length) throw new Error("No valid publication years.");
  const min = Math.min(...years);
  const max = Math.max(...years);
  for (let year = min; year <= max; year++) {
    for (const select of [from, to]) select.add(new Option(String(year), String(year)));
  }
  from.value = String(min);
  to.value = String(max);
  from.disabled = false;
  to.disabled = false;
}

function renderChart(articles, fromYear, toYear) {
  const chart = $("year-chart");
  chart.replaceChildren();
  setText("chart-range-label", `${fromYear}–${toYear}`);
  const counts = new Map();
  for (let year = fromYear; year <= toYear; year++) counts.set(year, 0);
  articles.forEach(article => counts.set(article.year, (counts.get(article.year) || 0) + 1));
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
    .sort((a, b) => b.year - a.year || a.title.localeCompare(b.title)).slice(0, 5);
  if (!recent.length) {
    const row = document.createElement("li");
    row.className = "placeholder";
    row.textContent = "No articles in the selected years.";
    list.appendChild(row);
    return;
  }
  for (const article of recent) {
    const row = document.createElement("li");
    const year = document.createElement("time");
    year.textContent = String(article.year);
    row.append(makeArticleLink(article), year);
    list.appendChild(row);
  }
}

function updateFilteredDashboard() {
  if (!state.articles.length) return;
  const fromYear = Number($("year-from").value);
  const toYear = Number($("year-to").value);
  const filtered = state.articles.filter(article =>
    article.year >= fromYear && article.year <= toYear);
  setText("range-total", filtered.length);
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

// Q4 venue options are derived from articles returned by GET /api/articles.
// BE does not provide a standalone venue-list API in the current contract.
function populateVenuePicker(articles) {
  const map = new Map();
  for (const article of articles) {
    if (article.venueId) map.set(String(article.venueId),
      String(article.venueName || article.venueId));
  }
  state.venues = [...map].map(([id, name]) => ({ id, name }))
    .sort((a, b) => a.id.localeCompare(b.id));

  const valid = new Set(state.venues.map(item => item.id));
  state.selectedVenueIds = new Set([...state.selectedVenueIds].filter(id => valid.has(id)));
  if (!state.selectedVenueIds.size) {
    state.selectedVenueIds = new Set(state.venues.slice(0, 2).map(item => item.id));
  }

  const container = $("q4-venue-options");
  container.replaceChildren();
  if (!state.venues.length) {
    const p = document.createElement("p");
    p.className = "report-placeholder";
    p.textContent = "No venues found in loaded articles.";
    container.appendChild(p);
  }
  for (const venue of state.venues) {
    const label = document.createElement("label");
    label.className = "report-venue-option";
    const box = document.createElement("input");
    box.type = "checkbox";
    box.value = venue.id;
    box.checked = state.selectedVenueIds.has(venue.id);
    box.addEventListener("change", () => {
      if (box.checked) state.selectedVenueIds.add(venue.id);
      else state.selectedVenueIds.delete(venue.id);
      updateVenueSummary();
      $("q4-list").replaceChildren();
    });
    const name = document.createElement("span");
    name.textContent = `${venue.name} (${venue.id})`;
    label.append(box, name);
    container.appendChild(label);
  }
  updateVenueSummary();
}

function updateVenueSummary() {
  setText("q4-summary", `${state.selectedVenueIds.size} venue(s) selected · choose venues`);
}

// Q4: authors who published in EVERY selected venue.
async function loadQ4() {
  const requestNumber = ++q4RequestNumber;
  const venueIds = [...state.selectedVenueIds];
  if (!venueIds.length || venueIds.length > 20) {
    showListMessage("q4-list", "Select 1–20 venues.", true);
    return false;
  }
  $("q4-apply").disabled = true;
  $("q4-list").replaceChildren();
  try {
    const rows = await fetchReport("authors-all-venues", { venueIds: venueIds.join(",") });
    if (requestNumber !== q4RequestNumber) return false;
    setText("q4-meta", `${rows.length} author(s) matching all ${venueIds.length} selected venue(s).`);
    const list = $("q4-list");
    list.replaceChildren();
    if (!rows.length) {
      showListMessage("q4-list", "No authors have published in every selected venue.");
    } else {
      for (const author of rows) {
        const item = document.createElement("li");
        item.textContent = `${author.name} (${author.id})`;
        list.appendChild(item);
      }
    }
    return true;
  } catch (error) {
    if (requestNumber === q4RequestNumber) showListMessage("q4-list", error.message, true);
    return false;
  } finally {
    if (requestNumber === q4RequestNumber) $("q4-apply").disabled = false;
  }
}

// Q5: average authors per article for every publication year returned by BE.
async function loadQ5() {
  $("q5-list").replaceChildren();
  try {
    const rows = await fetchReport("average-authors-by-year");
    const list = $("q5-list");
    list.replaceChildren();
    if (!rows.length) {
      showYearMessage("No year data available.");
      return true;
    }
    for (const row of rows) {
      const div = document.createElement("div");
      div.className = "report-year-row";
      const main = document.createElement("strong");
      const detail = document.createElement("span");
      const avg = Number(row.averageAuthorsPerArticle);
      main.textContent = `${row.year}: ${Number.isFinite(avg) ? avg.toFixed(2) : "—"}`;
      detail.textContent = `${row.articles} articles`;
      div.append(main, detail);
      list.appendChild(div);
    }
    return true;
  } catch (error) {
    showYearMessage(error.message, true);
    return false;
  }
}

// Existing year chart and recent articles are still loaded from /api/articles.
async function loadArticleStats() {
  $("year-from").disabled = true;
  $("year-to").disabled = true;
  setText("range-total", "—");
  try {
    const items = await fetchAllArticles();
    if (items.some(item => !item || typeof item.title !== "string" ||
        item.id == null || !Number.isInteger(item.year))) {
      throw new Error("Articles have invalid id, title or year fields.");
    }
    state.articles = items;
    fillYearSelectors(items);
    populateVenuePicker(items);
    if (items.length) {
      updateFilteredDashboard();
    } else {
      setText("range-total", 0);
      $("year-chart").textContent = "No data to chart.";
      $("recent-articles").textContent = "No articles available.";
      setText("chart-range-label", "");
    }
    return true;
  } catch (error) {
    state.articles = [];
    $("year-chart").textContent = "Chart unavailable.";
    $("recent-articles").textContent = "Recent articles unavailable.";
    setText("chart-range-label", "");
    showListMessage("q4-list", "Cannot load venues: " + error.message, true);
    console.error("[Dashboard /articles]", error);
    return false;
  }
}

async function loadDashboard() {
  $("retry-dashboard").hidden = true;

  const [articlesOK, q3OK, q5OK] = await Promise.all([
    loadArticleStats(), loadQ3(), loadQ5()
  ]);
  const q4OK = articlesOK ? await loadQ4() : false;
  const allOK = articlesOK && q3OK && q4OK && q5OK;
  setStatus(allOK
    ? ""
    : "Some dashboard data could not load. Please try again.", !allOK);
  $("retry-dashboard").hidden = allOK;
}

$("year-from").addEventListener("change", () => onYearChange("from"));
$("year-to").addEventListener("change", () => onYearChange("to"));
$("q3-form").addEventListener("submit", event => { event.preventDefault(); void loadQ3(); });
$("q4-apply").addEventListener("click", () => { void loadQ4(); });
$("retry-dashboard").addEventListener("click", () => { void loadDashboard(); });
void loadDashboard();
