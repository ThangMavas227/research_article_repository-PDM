/* Shared navigation / UI session support. The backend must independently enforce permissions. */
(function () {
  "use strict";

  const TOKEN_KEY = "rar_auth_token";
  const USER_KEY = "rar_auth_user";
  const NOTICE_KEY = "rar_navigation_notice";
  const ROOT = "index.html";
  const EDITOR = "articleEditor.html";
  const ALLOWED_ROLES = new Set(["admin", "reader"]);

  function getSession() {
    try {
      const token = sessionStorage.getItem(TOKEN_KEY);
      const rawUser = sessionStorage.getItem(USER_KEY);
      if (!token || !rawUser) return null;
      const user = JSON.parse(rawUser);
      if (!user || typeof user.username !== "string" || !user.username.trim() ||
          typeof user.role !== "string" || !ALLOWED_ROLES.has(user.role.toLowerCase())) {
        return null;
      }
      return { token, user: { ...user, role: user.role.toLowerCase() } };
    } catch (_) {
      return null; // Do not expose privileged UI when stored data is damaged.
    }
  }

  function getRole() {
    return getSession()?.user.role || "guest";
  }

  function saveSession(data) {
    if (!data || typeof data.token !== "string" || !data.token.trim() ||
        !data.user || typeof data.user.username !== "string" ||
        !data.user.username.trim() || typeof data.user.role !== "string" ||
        !ALLOWED_ROLES.has(data.user.role.toLowerCase())) {
      throw new Error("Invalid login response from Backend.");
    }
    try {
      sessionStorage.setItem(TOKEN_KEY, data.token);
      sessionStorage.setItem(USER_KEY, JSON.stringify({
        ...data.user, role: data.user.role.toLowerCase()
      }));
    } catch (_) {
      clearSession();
      throw new Error("Cannot save login session in this browser.");
    }
    renderNavigation();
  }

  function clearSession() {
    try {
      sessionStorage.removeItem(TOKEN_KEY);
      sessionStorage.removeItem(USER_KEY);
    } catch (_) { /* Navigation still falls back to Guest. */ }
    renderNavigation();
  }

  function makeLink(text, url, page, currentPage) {
    const link = document.createElement("a");
    link.href = url;
    link.textContent = text;
    if (page === currentPage) {
      link.setAttribute("aria-current", "page");
      link.classList.add("active");
    }
    return link;
  }

  function currentPageName() {
    const filename = window.location.pathname.split("/").pop() || ROOT;
    return filename === "" ? ROOT : filename;
  }

  function renderNavigation() {
    const session = getSession();
    const role = session?.user.role || "guest";
    document.querySelectorAll("[data-app-navigation]").forEach(nav => {
      const fragment = document.createDocumentFragment();
      const append = (label, url, page) =>
        fragment.appendChild(makeLink(label, url, page, currentPageName()));

      append("Browse Articles", ROOT, ROOT);
      append("Dashboard", "dashboard.html", "dashboard.html");
      if (role === "admin") {
        append("Manage Content", EDITOR, EDITOR);
      }
      if (role === "guest") {
        append("Login", "login.html", "login.html");
      } else {
        const username = document.createElement("span");
        username.className = "nav-username";
        username.textContent = session.user.username;
        username.title = `Signed in as ${session.user.username} (${role})`;
        fragment.appendChild(username);

        const logoutButton = document.createElement("button");
        logoutButton.type = "button";
        logoutButton.className = "nav-logout";
        logoutButton.textContent = "Logout";
        logoutButton.addEventListener("click", async () => {
          if (logoutButton.disabled) return;
          logoutButton.disabled = true;
          logoutButton.textContent = "Logging out…";
          await logout();
        });
        fragment.appendChild(logoutButton);
      }
      nav.replaceChildren(fragment);
    });
  }

  function notice(text, kind) {
    try { sessionStorage.setItem(NOTICE_KEY, JSON.stringify({ text, kind })); }
    catch (_) { /* Non-essential UI message. */ }
  }

  function renderNotice() {
    const target = document.querySelector("[data-navigation-notice]");
    if (!target) return;
    let stored;
    try {
      stored = JSON.parse(sessionStorage.getItem(NOTICE_KEY) || "null");
      sessionStorage.removeItem(NOTICE_KEY);
    } catch (_) { /* Ignore invalid notice. */ }
    const search = new URLSearchParams(window.location.search);
    if (!stored && search.get("access") === "denied") {
      stored = { text: "Manage Content is available to administrators only.", kind: "error" };
    }
    if (stored && typeof stored.text === "string") {
      target.textContent = stored.text;
      target.className = `nav-notice ${stored.kind === "error" ? "nav-notice-error" : ""}`.trim();
      target.hidden = false;
    }
  }

  function requireAdmin() {
    const role = getRole();
    if (role === "admin") return true;
    if (role === "guest") {
      // Only a known, same-site page is accepted as the post-login destination.
      window.location.replace("login.html?next=articleEditor.html&reason=admin-required");
    } else {
      window.location.replace("index.html?access=denied");
    }
    return false;
  }

  async function logout() {
    const session = getSession();
    let serverConfirmed = false;
    try {
      if (session) {
        const base = window.APP_CONFIG?.AUTH_BASE_URL || "http://localhost:8080";
        const path = window.APP_CONFIG?.AUTH_LOGOUT_PATH || "/api/auth/logout";
        const url = new URL(path, base).toString();
        const response = await fetch(url, {
          method: "POST",
          headers: { Authorization: `Bearer ${session.token}`, Accept: "application/json" }
        });
        if (!response.ok) throw new Error(`Logout failed (HTTP ${response.status})`);
        serverConfirmed = true;
      }
    } catch (error) {
      // Never leave a stale FE session solely because the backend is unavailable.
      console.warn("Server logout could not be confirmed:", error);
    } finally {
      clearSession();
      notice(serverConfirmed ? "You have logged out." :
        "Signed out from this browser. Server logout could not be confirmed.",
        serverConfirmed ? "success" : "error");
      window.location.replace(ROOT);
    }
  }

  function initialize() {
    if (currentPageName() === EDITOR && !requireAdmin()) return;
    document.documentElement.classList.remove("auth-pending");
    renderNavigation();
    renderNotice();
  }

  window.RARAuth = Object.freeze({ getSession, getRole, saveSession, clearSession,
    renderNavigation, requireAdmin, logout });

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initialize);
  } else {
    initialize();
  }
  // Handles restored pages from browser back/forward cache after logout/login.
  window.addEventListener("pageshow", () => {
    if (currentPageName() === EDITOR && !requireAdmin()) return;
    document.documentElement.classList.remove("auth-pending");
    renderNavigation();
  });
  window.addEventListener("storage", event => {
    if (event.key === TOKEN_KEY || event.key === USER_KEY) renderNavigation();
  });
})();
