# Library Management System (DBMS Capstone)

**Stack:** Python 3 (`sqlite3`, standard library only) + SQLite. No installs needed.

## Run
```
python3 app.py            # first run builds library.db from schema.sql + seed.sql
python3 app.py --reset    # rebuild from scratch
```

## How the app connects to the database
`app.py` opens a connection with `sqlite3.connect()`, enables `PRAGMA foreign_keys`, and uses
parameterised queries (`?` placeholders, which prevent SQL injection). Multi-step changes run inside
`with conn:` so they commit together or roll back together (transactions / atomicity).

## ER diagram
```
categories 1 ──< books >──< book_authors >── authors
                  │ 1
                  │
                  ∧ N
members 1 ──────< loans 1 ──── 0..1 fines
```
- `books`–`authors` is many-to-many, resolved by `book_authors`.
- `loans` is the associative entity between `members` and `books` (with its own attributes).
- `fines` is 1:0..1 with `loans` (`loan_id` UNIQUE).

## Normalization
All tables are in 3NF: every non-key attribute depends on the key, the whole key, and nothing but
the key. Category and author names live in their own tables instead of being repeated in `books`
(removes update anomalies); the multi-author repeating group is split out into `book_authors` (1NF).

## DBMS concepts demonstrated (for viva/report)
| Concept | Where |
|---|---|
| PK, FK, UNIQUE, NOT NULL, CHECK, DEFAULT | `schema.sql` |
| Referential integrity (ON DELETE CASCADE / restrict) | `book_authors`, `loans` |
| Index (incl. partial index) | `idx_loans_member`, `idx_loans_open` |
| Triggers | stock update, borrowing rules, auto-fine on late return |
| Views | `v_book_availability`, `v_overdue` |
| Joins, GROUP BY, aggregates, subqueries | `queries.sql`, report menu options |
| Transactions | `with conn:` blocks in `add_book`, `issue_book` |

## Business rules enforced in the database (not just in Python)
- Cannot issue a book with 0 available copies.
- Suspended members cannot borrow; max 3 books out per member.
- Returning late creates a fine automatically (Rs 2/day).
- Cannot delete a member who has loan history (the app suspends them instead).

## Ideas to extend
GUI (Tkinter/Flask), switch to MySQL/PostgreSQL (the SQL is almost portable; replace `julianday`/`date('now')`), user roles/login, reservations table.
