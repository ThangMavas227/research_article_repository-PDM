# Backend – Research Article Repository API

Spring Boot REST API over the MySQL database in `/db` (Group 8, IT079IU, Topic 18). The API reads and writes the
database through SQL written with `JdbcTemplate` (JDBC); every user value is a bound `?` parameter.

## Requirements and versions
| Item | Version |
|---|---|
| JDK | 21 or newer (project targets Java 21; tested on JDK 25) – check with `java -version` |
| MySQL | 8.0 or newer (tested on 8.0.46) – `CHECK` constraints need 8.0.16+ |
| JDBC driver | MySQL Connector/J (`mysql-connector-j`, version managed by Spring Boot) |
| Framework | Spring Boot 4.1.2 (Spring MVC, Spring JDBC, Tomcat 11) |
| Password hashing | `spring-security-crypto` (bcrypt only, not the full Spring Security) |
| Build | Maven is not needed separately: the project includes `mvnw` / `mvnw.cmd` |

## 1. Create the database
Run `db/script.sql` once in MySQL Workbench (File > Open SQL Script > Run). It drops and recreates the
`research_repo` schema (18 tables, 3 indexes, 6 triggers) and loads the sample data (25 real articles from OpenAlex plus
synthetic users, reading lists and saved searches). Running it again resets the data.

Check: `SELECT COUNT(*) FROM research_repo.Article;` returns `25`.

## 2. Connection settings (outside the code)
The connection is read from environment variables, so nothing is recompiled to use another server and the password is
never stored in the repository (`src/main/resources/application.properties`).

| Variable | Meaning | Default |
|---|---|---|
| `DB_PASSWORD` | MySQL password | empty |
| `DB_USER` | MySQL user | `root` |
| `DB_URL` | JDBC URL | `jdbc:mysql://localhost:3306/research_repo` |
| `PORT` | HTTP port of the API | `8080` (the frontend expects 8080) |

## 3. Build and run (PowerShell)
Run from the `src\backend` folder. Put the password in single quotes.
```powershell
cd src\backend
$env:DB_PASSWORD = 'your-mysql-password'
.\mvnw.cmd spring-boot:run
```
Wait for `Started ResearchRepoApiApplication`. The first run downloads dependencies and can take a few minutes.
The variable lasts only for that terminal window.

To build an executable JAR and run it instead:
```powershell
.\mvnw.cmd -DskipTests package
java -jar target\research-repo-api-0.0.1-SNAPSHOT.jar
```

Quick check in a browser: `http://localhost:8080/api/articles?size=1` should show one article as JSON.

## 4. Demo accounts
| Username | Password | Role |
|---|---|---|
| `admin` | `Admin@123` | admin |
| `reader1` | `Reader@123` | reader |

The other sample users (`phuong_an`, `nguyen_bao`, ...) are readers with the password `Reader@123`.
Passwords are stored only as bcrypt hashes. Type the plain password in the login form, never the hash.

## 5. Endpoints
Details, request bodies and error cases are in [`API_CONTRACT.md`](API_CONTRACT.md).

| Endpoint | Who | What |
|---|---|---|
| `GET /api/articles` | public | browse and search with paging (filters below) |
| `POST /api/articles` | admin | add an article with its authors (one transaction) |
| `PUT /api/articles/{id}` | admin | edit an article |
| `DELETE /api/articles/{id}` | admin | delete an article and its links |
| `POST /api/auth/login`, `POST /api/auth/logout`, `GET /api/auth/me` | any / logged in | sign in, sign out, current user |
| `GET /api/saved-searches`, `POST /api/saved-searches`, `DELETE /api/saved-searches/{searchName}` | reader | the reader's own saved searches |
| `GET /api/reports/top-cited?areaId=SA001` | public | Q3: ten most cited articles of a subject area |
| `GET /api/reports/authors-all-venues?venueIds=V002,V007` | public | Q4: authors who published in every listed venue |
| `GET /api/reports/average-authors-by-year` | public | Q5: average number of authors per article per year |

Write operations need the header `Authorization: Bearer <token>` from the login response. No token: `401`.
Wrong role (reader on an article write, admin on saved searches): `403`.

### `GET /api/articles` (public, no login)
| Query param | Meaning | Default |
|---|---|---|
| `keyword` | text matched against the title **or** any author's name (ignores case and accents) | none |
| `year` | exact publication year (cannot be combined with `yearFrom` / `yearTo`) | none |
| `yearFrom`, `yearTo` | publication year range, both inclusive | none |
| `venueType` | `J` (journal) or `C` (conference), case-insensitive | none |
| `page` | page number, starting at 1 | 1 |
| `size` | items per page (1–100) | 10 |

Example: `/api/articles?keyword=data&yearFrom=2019&yearTo=2023&venueType=J&page=1&size=8`

```json
{
  "items": [
    { "id": "AR003", "title": "An analysis of one-to-one matching algorithms for entity resolution", "year": 2023,
      "doi": "10.1007/s00778-023-00791-3", "abstract": "Abstract Entity resolution (ER) is ...",
      "venueId": "V002", "venueName": "The VLDB Journal", "editionNumber": 1, "startPage": 1369,
      "authors": [ { "id": "AU010", "name": "George Papadakis" } ],
      "references": [ { "id": "AR010", "title": "Blocking and Filtering Techniques for Entity Resolution" } ],
      "citedBy": [] }
  ],
  "page": 1, "size": 8, "totalItems": 25, "totalPages": 4
}
```

- `references` = articles this article cites; `citedBy` = articles that cite it (both `{id, title}`, `[]` if none).
- `abstract` may be `null`. `year` comes from `Edition.PubYear`; `authors` are ordered by `Writes.Position`.
- No match: HTTP 200 with `"items": []` and `totalItems: 0`.
- Invalid parameter (`page=0`, `size=1000`, `yearFrom` greater than `yearTo`, `venueType=X`): HTTP 400 with `{"error": "..."}`.
- CORS is enabled for `http://localhost:*` so a frontend on another local port can call it.

## 6. Errors and security notes
- Every error is JSON: `{"error": "message"}`. Codes: `400` invalid input, `401` not logged in, `403` wrong role,
  `404` not found, `409` conflict (duplicate DOI, same start page in an edition, duplicate saved-search name).
- Database constraint errors (duplicate DOI, unknown author or venue, ...) are turned into readable messages, never a stack trace.
- Login returns a random token kept **in memory** for 8 hours. Restarting the API logs everyone out (`401`: sign in again).
- Article writes run in one `@Transactional` method: if any statement fails, nothing is saved.

## 7. Project layout
```
src/main/java/com/example/research_repo_api/
  ResearchRepoApiApplication.java   entry point
  ArticleController.java            browse, add, edit, delete articles
  SavedSearchController.java        reader's saved searches
  ReportController.java             Q3, Q4, Q5 reports
  AuthController.java, AuthService.java   login, token sessions, roles
  ApiExceptionHandler.java, ApiException.java, BadRequestException.java   error responses
  CorsConfig.java, SearchCriteria.java    CORS and shared filter validation
src/main/resources/application.properties   connection settings (environment variables)
```

## 8. Tests
```powershell
.\mvnw.cmd test
```
Needs MySQL running with `research_repo` loaded (the application connects to it on start-up).
The test suite currently only checks that the application context starts.

## 9. Troubleshooting
| Symptom | Cause and fix |
|---|---|
| `Port 8080 was already in use` | The API is already running (or another program uses 8080). Stop it, or set `$env:PORT = '8081'` (then change the frontend `config.js`). |
| `{"error":"internal server error"}` | Look at the API's console log. Most often the MySQL password or database is wrong: set `DB_PASSWORD`, and run `db/script.sql` first. |
| `Unknown database 'research_repo'` | `db/script.sql` has not been run. |
| `Access denied for user 'root'` | Wrong `DB_PASSWORD` / `DB_USER`. |
| `401` after the API restarted | Tokens are in memory. Sign in again. |
| `$env:DB_PASSWORD = abc` shows "not recognized" | Put the password in single quotes: `'abc'`. |
