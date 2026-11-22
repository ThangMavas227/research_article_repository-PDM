# Research Article Repository — Frontend

**IT079IU – Principles of Database Management | Group 8**

Frontend for the Research Article Repository project. The interface allows visitors to explore research articles and their citation relationships, readers to manage saved searches, and administrators to manage article records.

## 1. Technology and architecture

- **Frontend:** HTML, CSS, and vanilla JavaScript (no frontend framework or npm build step).
- **Frontend development server:** VS Code **Live Server** or another local HTTP static-file server.
- **Backend:** Java Spring Boot REST API.
- **Database access:** Backend → JDBC → MySQL. Browser JavaScript **does not connect directly to MySQL**.
- **Communication:** HTTP requests using `fetch()`, with JSON request/response bodies where applicable.

The instructor has permitted the group to use a web interface instead of a Java desktop interface (as confirmed by the group). Database operations and authorization are still handled by the backend.

## 2. Requirements

To **run the frontend locally**:

- A modern desktop browser (Chrome, Edge, or Firefox).
- VS Code with the **Live Server** extension, or an equivalent local static HTTP server.
- The project's **Spring Boot backend** running and connected to the MySQL database.

The frontend itself does **not** require Node.js, npm, Maven, or a JDK. These may be needed for other parts of the project; see the backend README for its own setup instructions.

## 3. Run locally

1. **Start MySQL and the backend** following the backend team's README. With the current default configuration, the API is available at `http://localhost:8080`.
2. **Verify the API** in a browser: `http://localhost:8080/api/articles?page=1&size=1`. A working backend should return a JSON object containing an `items` array.
3. **Open the frontend folder** (the directory containing `index.html` and `config.js`) in VS Code.
4. Right-click **`index.html` → Open with Live Server**.
5. Use the local URL shown by Live Server. An example is `http://127.0.0.1:5500/index.html`; the port may differ on your machine.

> Open the frontend through an HTTP server, not by double-clicking an HTML file using the `file://` protocol.

### Backend URL configuration

The shared API addresses are configured in **`config.js`**:

```javascript
window.APP_CONFIG = Object.freeze({
    API_URL: 'http://localhost:8080/api/articles',
    AUTH_BASE_URL: 'http://localhost:8080',
    AUTH_LOGOUT_PATH: '/api/auth/logout',
    SAVED_SEARCHES_API_URL: 'http://localhost:8080/api/saved-searches',
    PAGE_SIZE: 10
});
```

If the backend runs on another host or port, change the corresponding URLs in `config.js`, save, and reload the page. Keep the URLs consistent with the actual backend configuration.

## 4. Pages and functionality

| Page | Entry file | Access | Purpose |
|---|---|---|---|
| Browse Articles | `index.html` | Public | Search articles by title/author keyword and publication year, browse paginated results. |
| Article Detail | `articleDetail.html?id=AR003` | Public | Show an article's metadata, references, and articles that cite it. |
| Dashboard | `dashboard.html` | Public | Show articles by year, recent articles, and the Q3/Q4/Q5 SQL-backed reports. |
| Master–Detail | `masterDetail.html` | Public | Select an article in the **upper Articles grid** to show its related authors in the **lower Authors grid**. Includes search, pagination, and Reload. |
| Login | `login.html` | Guest | Authenticate using a backend account. |
| Saved Searches | `readerSavedSearches.html` | Reader UI | Create, view, run, and delete the current reader's saved search criteria. |
| Manage Content | `articleEditor.html` | Admin | Browse articles, view referenced authors, and create/edit/delete article records. |

### Roles

- **Guest:** A visitor who is not logged in. “Guest” is a frontend state, **not** a database role.
- **Reader (`reader`):** Can use public pages and the reader-facing Saved Searches screen.
- **Admin (`admin`):** Can use public pages and Manage Content (article creation, updates, and deletion).

The backend contract permits logged-in accounts to access their own saved-search endpoints, but the current **frontend Saved Searches page is exposed to readers**. Hiding a page or button in JavaScript is **not a security boundary**: the backend must enforce authorization.

## 5. Frontend files

The primary files in the frontend directory are:

```text
frontend/
├── index.html                 # Browse Articles
├── browse.js
├── articleDetail.html         # Article details and citations
├── articleDetail.js
├── dashboard.html            
├── dashboard.css
├── dashboard.js
├── masterDetail.html          # Articles → Authors, two-grid view
├── masterDetail.css
├── masterDetail.js
├── login.html                 # Authentication UI
├── login.css
├── login.js
├── readerSavedSearches.html   # Reader saved searches
├── readerSavedSearches.css
├── readerSavedSearches.js
├── savedSearchApi.js
├── articleEditor.html         # Admin article CRUD
├── articleEditor.css
├── articleEditor.js
├── navigation.js              # Shared navigation, session and logout UI
├── navigation.css
├── config.js                  # Backend endpoints and common settings
├── theme.css                 # Shared visual tokens/styles
├── style.css                 # Shared / browse styles
└── assets/                   # Local images
```

This is a **file map**, not a requirement to reorganize existing directories. Keep linked HTML, CSS, JavaScript, and asset paths consistent when integrating changes.

## 6. Backend API integration

The frontend uses the following API contract (default base URL: `http://localhost:8080`):

| Method | Endpoint | Used for | Access |
|---|---|---|---|
| `GET` | `/api/articles` | Browse, Article Detail, Master–Detail, article counts / charts | Public |
| `POST` | `/api/auth/login` | Login | Public |
| `GET` | `/api/auth/me` | Validate authenticated session | Authenticated |
| `POST` | `/api/auth/logout` | Logout and invalidate token | Authenticated |
| `GET` | `/api/saved-searches` | List own saved searches | Authenticated |
| `POST` | `/api/saved-searches` | Save search criteria | Authenticated |
| `DELETE` | `/api/saved-searches/{searchName}` | Delete own saved search | Authenticated |
| `POST` | `/api/articles` | Create an article | Admin |
| `PUT` | `/api/articles/{id}` | Edit an article | Admin |
| `DELETE` | `/api/articles/{id}` | Delete an article | Admin |
| `GET` | `/api/reports/top-cited?areaId=...` | Q3: top-cited articles in a subject area | Public |
| `GET` | `/api/reports/authors-all-venues?venueIds=...` | Q4: authors published in every selected venue | Public |
| `GET` | `/api/reports/average-authors-by-year` | Q5: average authors per article per year | Public |

**Important integration details:**

- `GET /api/articles` returns paginated results with `items`, `page`, `size`, `totalItems`, and `totalPages`. Each article includes its associated `authors` list.
- **Master–Detail** reads article rows from `GET /api/articles`. Selecting a row displays the selected article's `authors` in the lower grid; it does **not** require a new backend endpoint.
- The current **Article Detail** implementation finds the requested article by reading paginated article responses. The supplied backend contract does not define a dedicated `GET /api/articles/{id}` route.
- Article search accepts `keyword`, an exact `year`, or an inclusive `yearFrom` / `yearTo` range, plus optional `venueType` (`J` = journal, `C` = conference). Do **not** combine exact `year` with range filters.
- An article's publication year comes from the selected **Venue / Edition**. Admin create/edit requests send `venueId` and `editionNumber`, **not** a standalone writable year.
- Protected requests must send `Authorization: Bearer <token>`. Backend errors use a JSON `{ "error": "message" }` response where a response body is provided.

See the backend's **`API_CONTRACT.md`** for full parameters, payloads, HTTP status codes, and validation rules.

## 7. Login/session behavior

- Successful login stores an opaque backend session token in browser `sessionStorage` as `rar_auth_token` and display information as `rar_auth_user`.
- Logging out clears the browser session and invalidates the token on the backend.
- Backend tokens are held in backend server memory; restarting the backend invalidates existing sessions. **Log in again after a backend restart.**
- Frontend role-aware navigation is for user experience only. The backend checks permissions for protected operations.

No passwords, database credentials, or real tokens should be committed to the frontend repository.

## 8. Manual verification before submission

Run the frontend and backend together, then check:

1. **Public browse:** Open `index.html`, search for an existing article, clear filters, and change pages.
2. **Article details:** Open an article and confirm the displayed title, authors, year, DOI, references, and cited-by list match backend data.
3. **Dashboard:** Check that the yearly chart, recent articles, and the three report sections load from the API.
4. **Master–Detail:** Open `masterDetail.html`, select **two different Article rows**, and verify the lower Authors grid changes accordingly. Test Search, Clear, Reload, and pagination.
5. **Reader:** Log in as a reader, save a search, run it, and delete it. Confirm the saved item persists after refreshing until deleted.
6. **Admin:** Log in as an admin, open Manage Content, and verify add, edit, and delete using test records. Confirm changes through the backend/database. Test the delete confirmation.
7. **Access control:** Verify a reader cannot perform admin-only article writes; verify an expired token requires login again.

**Testing status:** These are the recommended acceptance checks, not a claim that the latest merged branch has passed them all. Run them against the group's final source code and database before submitting.

## 9. Troubleshooting

| Symptom | What to check |
|---|---|
| Articles do not load / `Failed to fetch` | Spring Boot and MySQL are running; `config.js` uses the correct backend host/port; browser Network tab shows the actual request error. |
| CORS error | Serve the frontend over localhost/127.0.0.1 HTTP and check backend CORS settings for that origin. |
| `401 Unauthorized` | Log in again; the token may be missing, expired, logged out, or invalidated by a backend restart. |
| `403 Forbidden` | The current account lacks permission for the requested operation (e.g., reader attempting Admin CRUD). |
| Layout or menu changes are not visible | Save the files and hard-refresh (`Ctrl + Shift + R`); verify the browser is serving the intended frontend folder. |
| Master–Detail link does not appear in navigation | Verify `navigation.js` includes the `Master–Detail` link to `masterDetail.html`; the page may also be opened directly. |
| Empty article/author table | Check the API response, selected search filters, and whether the database has relevant records. |

## 10. Scope notes

The current frontend's application roles are **Reader** and **Admin**, with public access for guests. Features such as manuscript PDF submission or moderation should **not** be described as implemented unless they exist in the final merged codebase. The frontend relies on the backend and its database constraints for secure data changes.

---

**Documentation reference:** IT079IU project assignment; Group 8 frontend source snapshot and its integrated Master–Detail screen; backend `API_CONTRACT.md` and backend README. If the team's final merge changes routes, filenames, or behavior, update this README accordingly.
