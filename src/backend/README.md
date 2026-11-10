# Backend – Research Article Repository API

Spring Boot (Java) REST API over the MySQL database in `/db`.

## Requirements
- JDK 21 or newer (`java -version`)
- MySQL 8.0 or newer
- Maven is not needed separately (the project includes `mvnw` / `mvnw.cmd`)

## 1. Create the database
Run `db/script.sql` once in MySQL Workbench (File > Open SQL Script > Run). It drops and recreates the
`research_repo` schema and loads the sample data (24 articles). Running it again resets the data.

## 2. Run the API (PowerShell)
```powershell
cd src\backend
$env:DB_PASSWORD = 'your-mysql-password'
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.arguments=--server.port=8081"
```
Optional environment variables: `DB_USER` (default `root`), `DB_URL`
(default `jdbc:mysql://localhost:3306/research_repo`). The password is never stored in the code.

Wait for `Started ResearchRepoApiApplication`. The API is then at `http://localhost:8081`.
The first run downloads dependencies and can take a few minutes.

## Endpoints
### `GET /api/articles` (public, no login)
| Query param | Meaning | Default |
|---|---|---|
| `q` | text to search in the title | none |
| `year` | publication year filter | none |
| `page` | page number, starting at 1 | 1 |
| `size` | items per page (1–100) | 10 |

Example: `/api/articles?q=data&year=2019&page=1&size=10`

```json
{
  "data": [
    { "articleId": "AR005", "title": "Deep Residual Models for Medical Image Classification",
      "authors": ["Le Hoang Cuong", "Pham Minh Duc", "Tran Thi Binh"], "publicationYear": 2020 }
  ],
  "pagination": { "page": 1, "size": 3, "totalItems": 24, "totalPages": 8 }
}
```

- No match: HTTP 200 with `"data": []` and `totalItems: 0`.
- Invalid parameter (`page=0`, `size=1000`, `year=abc`): HTTP 400 with `{"error": "..."}`.
- Server error: HTTP 500 with `{"error": "internal server error"}`.
- CORS is enabled for `http://localhost:*` so a frontend on another local port can call it.
