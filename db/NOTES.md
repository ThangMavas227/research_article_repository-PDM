# Ghi chú chốt schema – Group 8, Topic 18 (Research Article Repository)

Dùng để cả nhóm đối chiếu giữa **Diagram Schema (2).svg**, **ERD**, và script trong thư mục `db`
(`schema.sql`, `queries.sql`, `dml.sql`). Đã chạy thử trên MySQL 8.0.46.

## 1. Việc đã chốt: `Edition.PubYear` = `SMALLINT` (nhóm đã đồng ý; diagram sẽ được sửa theo)

| # | Vấn đề | Diagram | Script | Đề xuất |
|---|---|---|---|---|
| 1 | `Edition.PubYear` | `YEAR` | `SMALLINT` + `CHECK (1900..2100)` | **Giữ `SMALLINT`, sửa diagram thành `SMALLINT`** |

Lý do: Connector/J mặc định coi `YEAR` là ngày và trả `java.sql.Date` (`2018-01-01`), không phải số `2018`.
Nếu vẫn muốn `YEAR` thì phải thêm `?yearIsDateType=false` vào chuỗi kết nối JDBC và ghi vào README.

Hai cách, chọn một:
- [x] A. Giữ `SMALLINT` (sửa 1 chữ trong diagram + report). **ĐÃ CHỐT** – script không cần đổi gì thêm.
- [ ] B. Đổi script về `YEAR` + thêm `yearIsDateType=false` vào cấu hình kết nối và README.

## 2. Đối chiếu từng bảng với Diagram Schema (2)

Tất cả tên bảng, tên cột, kiểu dữ liệu, khóa chính, khóa ngoại và NULL / NOT NULL **khớp** Diagram (2)/(3), **trừ bảng `Reader`**: script có thêm `PasswordHash` và `Role` (mục 7.2), diagram cần cập nhật theo.
Hai chỗ đã sửa theo diagram trong bản này:
- `Article.StartPage`: NOT NULL (đã sửa).
- `Institution.Country`: cho NULL (đã sửa).

Quy ước đọc icon (MySQL Workbench): chìa khóa vàng = PK, chìa khóa đỏ = PK đồng thời FK,
hình thoi đỏ = FK, hình thoi xanh = cột thường; **đặc = NOT NULL, rỗng = NULL**.

Khác biệt về tên: relationship `Write` trong ERD/diagram là bảng **`Writes`** trong script
(WRITE là từ khóa của MySQL). Nên đổi tên trong diagram/report cho thống nhất.

## 3. Những thứ script có mà diagram không thể hiện (cần ghi vào report)

- `UNIQUE`: Orcid, DOI, Issn, Acronym, Reader.UserName, Reader.Email, Keyword.Term, Venue.Name, SubjectArea.Name, Institution.Name, `Writes(ArticleID, Position)`.
- `CHECK`: định dạng DOI / ISSN / ORCID / email, `Position >= 1`, `EditionNumber > 0`, `Volume > 0`, `StartPage > 0`, `EndDate >= StartDate`, `PubYear 1900..2100`, `VenueType` theo ISA, `JSON_VALID`.
- `ON DELETE` / `ON UPDATE` cho mọi FK (CASCADE cho bảng nối, RESTRICT cho bảng danh mục, SET NULL cho `ParentAreaID`).
- ISA của Edition: `JournalEdition.VenueID → Journal` và `ConferenceEdition.VenueID → Conference` (FK thứ hai) để đúng loại venue.
- 3 index: `Citation(CitedArticleID)`, `Article(Title)`, `Edition(PubYear)`.
- Trigger (rule không khai báo được bằng CHECK): không tự trích dẫn, không trích dẫn bài năm sau, affiliation không chồng thời gian ở cùng institution, `ParentAreaID <> AreaID`.
  Lý do dùng trigger thay CHECK cho các cột có FK `CASCADE` / `SET NULL`: MySQL cấm (lỗi 3823).

## 4. Quyết định nghiệp vụ nên thống nhất

1. Một tác giả có được làm **hai nơi cùng lúc** không? Script hiện cho phép (chỉ cấm chồng ở cùng institution). Bản của bạn bạn cấm hoàn toàn.
2. `UNIQUE (VenueID, EditionNumber, StartPage)` trên Article (bản bạn bạn có, bản này không có): hai bài cùng edition có được bắt đầu cùng trang không?
3. Xóa SubjectArea / Keyword còn gắn bài: script hiện **CASCADE** (xóa luôn liên kết), bản bạn bạn **RESTRICT** (chặn xóa). RESTRICT an toàn hơn cho dữ liệu danh mục.
4. Web hay Java desktop: cô cho nhóm tự chọn. Nên giữ tin nhắn xác nhận của cô.

## 5. Chỗ ERD / thiết kế có thể làm tốt hơn (tùy chọn)

- **Total participation của ISA Edition** (mỗi Edition phải có đúng một JournalEdition hoặc ConferenceEdition) không khai báo được bằng SQL. Cách xử lý: luôn insert Edition và subtype trong **một transaction**, ghi rõ trong report.
- Nhóm đã quyết định **bỏ** trạng thái duyệt / bài bị rút, file PDF, lịch sử tìm kiếm tự động: report cần sửa phần mô tả cho khớp schema.
- `Writes.Position` liên tục (1,2,3…) không có gaps: DB chỉ đảm bảo không trùng; kiểm tra liên tục để app xử lý.
- Năm xuất bản của Article suy ra từ `Edition.PubYear` (không lặp ở Article): giữ như vậy là chuẩn hóa tốt.

## 6. Còn lại phải làm (ngoài phần database)

- 4 query bằng đại số quan hệ (gợi ý: Q1, Q4, Q6, Q8 trong `queries.sql`).
- Danh sách phụ thuộc hàm, minimal cover, candidate key, chứng minh 3NF.
- Ứng dụng Java, README (JDK, driver, cấu hình kết nối).
- Dữ liệu mẫu hiện là dữ liệu giả; thay nếu giảng viên yêu cầu dữ liệu thật.

## 7. Chức năng nhóm chọn (cập nhật)

Nhóm **bỏ**: cột `Article.Status` (trạng thái duyệt / bài bị rút), upload PDF, lịch sử tìm kiếm tự động.
Vì vậy FE không làm theo dõi submission hay duyệt bài; report cần sửa phần mô tả cho khớp.

### 7.1 Lưu tìm kiếm cho mỗi tài khoản
- Dùng bảng `SavedSearch` đã có (người dùng chủ động lưu tìm kiếm, tiêu chí dạng JSON). Không sửa schema.

### 7.2 Đăng nhập và phân quyền (MỚI, cần cập nhật diagram và ERD)
- Bảng `Reader` thêm 2 cột: `PasswordHash VARCHAR(255) NOT NULL` (băm bcrypt, không lưu mật khẩu gốc)
  và `Role VARCHAR(10) NOT NULL DEFAULT 'reader'` với `CHECK (Role IN ('reader','author','admin'))`.
- **Không** thêm `AuthorID` vào `Reader` (không cần cho phạm vi hiện tại).
- Không làm chức năng đăng ký; tài khoản demo được insert sẵn trong script (xem `DEMO_ACCOUNTS.md`).
- Kiểm tra mật khẩu nằm ở **Java** (bcrypt), không nằm trong SQL. App lấy dòng theo `UserName`
  rồi so `PasswordHash`. Vai trò `author` hiện chỉ là nhãn quyền, chưa gắn với bảng `Author`.
- Việc cần làm: thêm 2 cột vào diagram và ERD của `Reader`; ghi vào report mục thiết kế.
- Web hay Java desktop: cô cho nhóm tự chọn (nên có xác nhận bằng văn bản).
