# Backend – Research Article Repository API

Spring Boot (Java) REST API over the MySQL database in `/db`.

## Requirements
- JDK 21 or newer (`java -version`)
- MySQL 8.0 or newer
- Maven is not needed separately (the project includes `mvnw` / `mvnw.cmd`)

## 1. Create the database
Run `db/script.sql` once in MySQL Workbench (File > Open SQL Script > Run). It drops and recreates the
`research_repo` schema and loads the sample data (25 real articles from OpenAlex plus synthetic users and lists). Running it again resets the data.

## 2. Run the API (PowerShell)
```powershell
cd src\backend
$env:DB_PASSWORD = 'your-mysql-password'
.\mvnw.cmd spring-boot:run
```
The API listens on `http://localhost:8080` (same as the frontend's `API_URL`).
Optional environment variables: `DB_USER` (default `root`), `DB_URL`
(default `jdbc:mysql://localhost:3306/research_repo`), `PORT` (default `8080`).
The password is never stored in the code.

Wait for `Started ResearchRepoApiApplication`. The first run downloads dependencies and can take a few minutes.

## Endpoints
### `GET /api/articles` (public, no login)
| Query param | Meaning | Default |
|---|---|---|
| `keyword` | text matched against the title **or** any author's name (ignores case and accents) | none |
| `year` | publication year filter | none |
| `page` | page number, starting at 1 | 1 |
| `size` | items per page (1–100) | 10 |

Example: `/api/articles?keyword=data&year=2019&page=1&size=8`

```json
{
  "items": [
    { "id": "AR005", "title": "Deep Residual Models for Medical Image Classification", "year": 2020,
      "authors": [ { "id": "AU003", "name": "Le Hoang Cuong" }, { "id": "AU004", "name": "Pham Minh Duc" } ] }
  ],
  "page": 1, "size": 8, "totalItems": 24, "totalPages": 3
}
```

- `year` comes from `Edition.PubYear`; `authors` are ordered by `Writes.Position`.
- No match: HTTP 200 with `"items": []` and `totalItems: 0`.
- Invalid parameter (`page=0`, `size=1000`, `year=abc`): HTTP 400 with `{"error": "..."}`.
- Server error: HTTP 500 with `{"error": "internal server error"}`.
- CORS is enabled for `http://localhost:*` so a frontend on another local port can call it.
