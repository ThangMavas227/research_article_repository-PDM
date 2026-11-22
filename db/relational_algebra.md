# Đại số quan hệ cho 4 query: Q1, Q4, Q9, Q13

Ký hiệu: σ (chọn), π (chiếu), ⋈ (kết nối tự nhiên hoặc theta), ρ (đổi tên), ∪ (hợp), − (hiệu), ÷ (chia).
Lược đồ rút gọn: Citation(CitingArticleID, CitedArticleID), Article(ArticleID, Title, DOI, ..., VenueID, EditionNumber), Edition(VenueID, EditionNumber, PubYear, ...), Venue(VenueID, Name, VenueType), Writes(ArticleID, AuthorID, Position), Author(AuthorID, FullName).

---

## Q1: Reference list của bài AR003 (kết nối)

```
Refs  = σ CitingArticleID = 'AR003' (Citation)

R1    = Refs ⋈ CitedArticleID = ArticleID (Article)

R2    = R1 ⋈ (VenueID, EditionNumber) (Edition)

R3    = R2 ⋈ VenueID ( ρ VenueName ← Name (Venue) )

Q1    = π ArticleID, Title, DOI, PubYear, VenueName (R3)
```

Dạng một dòng:

```
π ArticleID, Title, DOI, PubYear, VenueName (
    σ CitingArticleID='AR003' (Citation)
      ⋈ CitedArticleID=ArticleID Article
      ⋈ Edition
      ⋈ ρ VenueName←Name (Venue) )
```

(ORDER BY chỉ là sắp xếp hiển thị, đại số quan hệ thuần không biểu diễn.)

---

## Q4: Tác giả đã đăng ở mọi venue trong danh sách {V002, V007} (phép chia)

```
R   = π AuthorID, VenueID (Writes ⋈ Article)        -- cặp (tác giả, venue đã đăng)

S   = π VenueID ( σ VenueID='V002' ∨ VenueID='V007' (Venue) )   -- danh sách venue

Q4  = π AuthorID, FullName ( Author ⋈ (R ÷ S) )
```

Giải thích: `R ÷ S` giữ các AuthorID có cặp với **mọi** VenueID trong S. Phép chia tương đương:

```
R ÷ S = π AuthorID (R)  −  π AuthorID ( ( π AuthorID (R) × S ) − R )
```

Đây chính là hai tầng `NOT EXISTS` trong SQL: không tồn tại venue trong danh sách mà tác giả chưa đăng.

---

## Q9: Tác giả đã đăng ở Venue A hoặc Venue B (phép hợp)

```
A  = π AuthorID, FullName (
         Author ⋈ Writes ⋈ Article ⋈ σ Name='ACM Transactions on Database Systems' (Venue) )

B  = π AuthorID, FullName (
         Author ⋈ Writes ⋈ Article ⋈ σ Name='The VLDB Journal' (Venue) )

Q9 = A ∪ B
```

Phép hợp loại bỏ trùng, nên tác giả đăng ở cả hai venue chỉ xuất hiện một lần (giống `UNION` trong SQL).

---

## Q13: Tác giả có ít nhất một bài chưa được ai trích dẫn (truy vấn lồng EXISTS / NOT EXISTS)

```
Cited    = ρ ArticleID ← CitedArticleID ( π CitedArticleID (Citation) )

Uncited  = π ArticleID (Article)  −  Cited          -- bài chưa được trích dẫn

Q13      = π AuthorID, FullName ( Author ⋈ Writes ⋈ Uncited )
```

`EXISTS` tương ứng với phép kết nối (tác giả có ít nhất một dòng trong `Writes ⋈ Uncited`), `NOT EXISTS` tương ứng với phép hiệu `−`.
