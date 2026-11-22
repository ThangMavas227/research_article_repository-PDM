# API contract (backend `http://localhost:8080`)

All error responses have a single shape: `{ "error": "message" }`. API input/output uses JSON unless the endpoint returns `204 No Content`.

## Login, tokens and permissions

- `POST /api/auth/login` request: `{ "username": "reader1", "password": "..." }`.
  - Success `200`: `{ "token": "...", "user": { "id": "U002", "username": "reader1", "role": "reader" } }` (the id shown is illustrative; use the id actually returned).
  - Missing credentials: `400`; invalid credentials: `401`.
- For authenticated endpoints, send `Authorization: Bearer <token>` with **every** request.
  - The backend issues a random **opaque session token**, not a JWT. Tokens last 8 hours, remain in server memory, and become invalid after a backend restart or logout.
  - The current `login.js` stores the token in `sessionStorage` under `rar_auth_token`, and user info under `rar_auth_user`. User info stored in the browser is for display only and **must not** be treated as authorization.
- `GET /api/auth/me` -> `200 { "id": "...", "username": "...", "role": "reader|admin" }`; requires valid token.
- `POST /api/auth/logout` -> `204`; requires token and invalidates the token.
- `reader`: public article browse + **create/list/delete their own saved searches**; cannot create/edit/delete articles.
- `admin`: public article browse plus create/edit/delete articles. Admins have **no** saved searches: every `/api/saved-searches` call as admin returns `403`.
- Article browsing is public; SavedSearch (reader only) and article-write actions (admin only) require login. Missing/expired/invalid token -> `401`; a reader trying an article write -> `403`; an admin using SavedSearch -> `403`.
- Demo users in the provided `script.sql`: `admin` / `Admin@123`, `reader1` / `Reader@123`.

**Security rule:** The `UserID` for SavedSearch is obtained exclusively through `auth.requireUser(request).id()` after checking the Bearer token and the `reader` role. **Never** accept a `userId` / `UserID` field or URL parameter as the authority for another account.

## Article response object (unchanged)

```json
{
  "id": "AR003",
  "title": "...",
  "year": 2023,
  "doi": "10.1007/...",
  "abstract": "... or null",
  "venueId": "V001",
  "venueName": "ACM Transactions on Database Systems",
  "editionNumber": 1,
  "startPage": 123,
  "authors": [{ "id": "AU010", "name": "George Papadakis" }],
  "references": [{ "id": "AR010", "title": "..." }],
  "citedBy": [{ "id": "AR021", "title": "..." }]
}
```

`year` is read from `Edition.PubYear`; publication year is read-only. Authors appear in writing order.

## Article endpoints

| Method and path | Access | Success |
|---|---|---|
| `GET /api/articles?keyword=&yearFrom=&yearTo=&venueType=&page=1&size=10` | Public | `200 { items: [Article], page, size, totalItems, totalPages }` |
| `GET /api/articles?keyword=&year=&page=1&size=10` | Public (legacy compatibility) | Same as above |
| `POST /api/articles` | Admin | `201` with new Article |
| `PUT /api/articles/{id}` | Admin | `200` with updated Article |
| `DELETE /api/articles/{id}` | Admin | `204` no body |

**Canonical filters shared by Article search and SavedSearch.Criteria**

| Field | JSON type / query string | Rules |
|---|---|---|
| `keyword` | string or null | Optional; searched in article title or author name, substring match; trim outer whitespace; max 255 characters; blank is treated as absent |
| `yearFrom` | integer or null | Optional; publication year >= yearFrom; from 1 to 9999 |
| `yearTo` | integer or null | Optional; publication year <= yearTo; from 1 to 9999 |
| `venueType` | `"J"`, `"C"`, or null | Optional; `J` = Journal, `C` = Conference; case-insensitive input, normalized to uppercase |

- Both year bounds are inclusive. If both are supplied, `yearFrom <= yearTo`; otherwise `400`.
- Legacy `year` means an **exact** year. It remains supported for the current frontend, but must **not** be combined with `yearFrom` or `yearTo` (`400`). The SavedSearch JSON uses `yearFrom`/`yearTo`, not `year`.
- `page`: integer >= 1, default 1; `size`: integer 1..100, default 10.
- Searches are executed by the backend against the database; the frontend should not re-filter the paginated response.

Example:

```http
GET /api/articles?keyword=AI&yearFrom=2020&yearTo=2025&venueType=J&page=1&size=10
```

## SavedSearch endpoints (NEW)

The primary key in the existing MySQL schema is `(UserID, SearchName)`. No database migration is needed.

| Method and path | Access | Success |
|---|---|---|
| `POST /api/saved-searches` | Logged-in **reader** only | `201` with SavedSearch item |
| `GET /api/saved-searches` | Logged-in **reader** only | `200 { "items": [SavedSearchItem] }` |
| `DELETE /api/saved-searches/{searchName}` | Logged-in **reader** only | `204` no body |

### POST /api/saved-searches

Headers: `Authorization: Bearer <token>`, `Content-Type: application/json`.

Request (no userId field):

```json
{
  "searchName": "My AI Papers",
  "criteria": {
    "keyword": "AI",
    "yearFrom": 2020,
    "yearTo": 2025,
    "venueType": "J"
  }
}
```

- `searchName` is required, trimmed, nonblank, at most 100 characters; cannot contain `/` or backslash (so it is safe to use as a path segment in DELETE).
- `criteria` is a required JSON object with the same four canonical filters as article browsing. All individual filters are optional; missing values are treated as null. An empty criteria object means *all articles*.
- `UserID` is **never** taken from the JSON or URL; it is read from the authenticated token.
- Re-using `SearchName` in **the same account** returns `409`, and the existing saved search is **not** overwritten. A different account may use the same name. MySQL's `utf8mb4_0900_ai_ci` collation determines name equality, including case/accent insensitivity; the database primary key enforces it atomically.
- The server inserts into existing `SavedSearch` and lets the database set `CreatedDate`.

Success `201` body (`SavedSearchItem`):

```json
{
  "searchName": "My AI Papers",
  "criteria": {
    "keyword": "AI",
    "yearFrom": 2020,
    "yearTo": 2025,
    "venueType": "J"
  },
  "createdDate": "2026-11-20T10:00:00"
}
```

`createdDate` is a MySQL `DATETIME` exposed as an ISO-8601 local date-time **without timezone offset**. Do not infer UTC from it.

### GET /api/saved-searches

Headers: `Authorization: Bearer <token>`.

Success `200` body:

```json
{
  "items": [
    {
      "searchName": "My AI Papers",
      "criteria": {
        "keyword": "AI",
        "yearFrom": 2020,
        "yearTo": 2025,
        "venueType": "J"
      },
      "createdDate": "2026-11-20T10:00:00"
    }
  ]
}
```

Only the current user's searches are listed, ordered newest first, then by SearchName. If none exist, the result is `{ "items": [] }`. Optional filter properties may be JSON `null` if absent, including when reading the sample SavedSearch records already in the database.

**To run a saved search:** take `criteria` from an item, omit null/blank values, and build `GET /api/articles?keyword=...&yearFrom=...&yearTo=...&venueType=...&page=1&size=10`. Use `URLSearchParams` on the frontend to encode values.

### DELETE /api/saved-searches/{searchName}

Headers: `Authorization: Bearer <token>`.

Use the exact `searchName` returned from the GET response, encoded with `encodeURIComponent`. Example: `DELETE /api/saved-searches/My%20AI%20Papers`.

- Deletes only the row that matches both the **token-derived UserID** and `searchName`.
- `204` no body if deleted; `404 { "error": "saved search not found" }` if it does not exist **for that user** (including when another user owns a search with that name).

## Report endpoints (Topic 18 queries Q3, Q4, Q5)

Public, read-only, no token needed. The SQL is the one in `db/query.sql`; all values are bound as parameters.

| Method and path | Query | Success |
|---|---|---|
| `GET /api/reports/top-cited?areaId=SA001` | Q3: ten most cited articles of a subject area | `200 [ { "id", "title", "subjectArea", "citationCount" } ]`, most cited first (ties by title); articles that were never cited are also listed, with `citationCount` 0 |
| `GET /api/reports/authors-all-venues?venueIds=V002,V007` | Q4: authors who published in **every** listed venue | `200 [ { "id", "name" } ]` ordered by name; `venueIds` is a comma-separated list or the parameter repeated, 1 to 20 venues |
| `GET /api/reports/average-authors-by-year` | Q5: average number of authors per article, per year | `200 [ { "year", "articles", "totalAuthors", "averageAuthorsPerArticle" } ]` ordered by year |

Errors: `400` when `areaId` or `venueIds` is missing, or names a subject area or venue that does not exist.

## Article write request (unchanged)

`POST /api/articles` or `PUT /api/articles/{id}` body:

```json
{
  "title": "required, max 255",
  "doi": "10.1234/abc",
  "abstract": "optional (empty or null = none)",
  "startPage": 123,
  "venueId": "V001",
  "editionNumber": 1,
  "authors": [{ "id": "AU001" }, { "name": "New Author Name" }]
}
```

- Required: `title`, `doi` (unique), `startPage` (>= 1), `venueId`, `editionNumber` (>= 1).
- Venue/edition pair must exist, or `400`. `year` is not writable: it comes from the edition.
- Authors follow writing order. Each entry must contain **either** `{ "id": "AU001" }` (existing author) **or** `{ "name": "..." }` (creates a new author), not both. At least one author on POST.
- For PUT, `authors` is optional: omit to retain current authors, or supply a list to replace the complete list.
- The server generates the new article id (e.g., `AR026`). Do not send an id in POST.

## Error contract

All error bodies: `{ "error": "human-readable message" }`.

| Code | When |
|---|---|
| `400` | Invalid/missing JSON, invalid `searchName`, invalid filter values/range, invalid article fields, or conflicting `year`/range inputs |
| `401` | Missing, invalid, expired or logged-out Bearer token; invalid login credentials |
| `403` | Authenticated reader tries an admin-only article write; authenticated admin calls a SavedSearch endpoint |
| `404` | Article id not found for PUT/DELETE; SavedSearch name not found **for this account** on DELETE |
| `409` | Duplicate SavedSearch `(UserID, SearchName)`; duplicate article DOI/start-page uniqueness violation |
| `500` | Unexpected server/database failure; internal details are logged on the backend, not returned to the frontend |

Frontend integration notes: the existing browse UI still sends `year` and keeps working. A future UI with the advanced filters should send the new canonical query names, and the SavedSearch feature should use `sessionStorage.getItem('rar_auth_token')` for the Authorization header. The browser's cached `user` object is never an authorization source.
