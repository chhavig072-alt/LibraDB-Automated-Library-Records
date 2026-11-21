-- Library Management System: schema (3NF), constraints, triggers, views
PRAGMA foreign_keys = ON;

DROP VIEW  IF EXISTS v_overdue;
DROP VIEW  IF EXISTS v_book_availability;
DROP TABLE IF EXISTS fines;
DROP TABLE IF EXISTS loans;
DROP TABLE IF EXISTS book_authors;
DROP TABLE IF EXISTS books;
DROP TABLE IF EXISTS authors;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS members;

CREATE TABLE categories (
    category_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL UNIQUE
);

CREATE TABLE authors (
    author_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name      TEXT NOT NULL UNIQUE
);

CREATE TABLE books (
    book_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    isbn             TEXT NOT NULL UNIQUE,
    title            TEXT NOT NULL,
    category_id      INTEGER NOT NULL REFERENCES categories(category_id),
    published_year   INTEGER CHECK (published_year BETWEEN 1000 AND 2100),
    total_copies     INTEGER NOT NULL CHECK (total_copies >= 0),
    available_copies INTEGER NOT NULL CHECK (available_copies >= 0),
    CHECK (available_copies <= total_copies)
);

-- M:N between books and authors
CREATE TABLE book_authors (
    book_id   INTEGER NOT NULL REFERENCES books(book_id)     ON DELETE CASCADE,
    author_id INTEGER NOT NULL REFERENCES authors(author_id) ON DELETE CASCADE,
    PRIMARY KEY (book_id, author_id)
);

CREATE TABLE members (
    member_id  INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT NOT NULL,
    email      TEXT NOT NULL UNIQUE,
    phone      TEXT,
    joined_on  TEXT NOT NULL DEFAULT (date('now')),
    status     TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED'))
);

CREATE TABLE loans (
    loan_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    book_id     INTEGER NOT NULL REFERENCES books(book_id),
    member_id   INTEGER NOT NULL REFERENCES members(member_id),
    issue_date  TEXT NOT NULL DEFAULT (date('now')),
    due_date    TEXT NOT NULL,
    return_date TEXT,
    CHECK (due_date >= issue_date),
    CHECK (return_date IS NULL OR return_date >= issue_date)
);
CREATE INDEX idx_loans_member ON loans(member_id);
CREATE INDEX idx_loans_open   ON loans(book_id) WHERE return_date IS NULL;

CREATE TABLE fines (
    fine_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    loan_id   INTEGER NOT NULL UNIQUE REFERENCES loans(loan_id),
    amount    REAL NOT NULL CHECK (amount > 0),
    paid      INTEGER NOT NULL DEFAULT 0 CHECK (paid IN (0,1))
);

-- ---------- Triggers ----------
-- Block issuing when no copy is available or member is suspended
CREATE TRIGGER trg_loan_before_insert
BEFORE INSERT ON loans
BEGIN
    SELECT RAISE(ABORT, 'No copies available')
    WHERE (SELECT available_copies FROM books WHERE book_id = NEW.book_id) <= 0;
    SELECT RAISE(ABORT, 'Member is suspended')
    WHERE (SELECT status FROM members WHERE member_id = NEW.member_id) = 'SUSPENDED';
    SELECT RAISE(ABORT, 'Member already has 3 books issued')
    WHERE (SELECT COUNT(*) FROM loans
           WHERE member_id = NEW.member_id AND return_date IS NULL) >= 3;
END;

CREATE TRIGGER trg_loan_after_insert
AFTER INSERT ON loans
BEGIN
    UPDATE books SET available_copies = available_copies - 1 WHERE book_id = NEW.book_id;
END;

-- On return: restore copy and auto-create fine (Rs 2/day late)
CREATE TRIGGER trg_loan_after_return
AFTER UPDATE OF return_date ON loans
WHEN OLD.return_date IS NULL AND NEW.return_date IS NOT NULL
BEGIN
    UPDATE books SET available_copies = available_copies + 1 WHERE book_id = NEW.book_id;
    INSERT INTO fines(loan_id, amount)
    SELECT NEW.loan_id, 2.0 * (julianday(NEW.return_date) - julianday(NEW.due_date))
    WHERE NEW.return_date > NEW.due_date;
END;

-- ---------- Views ----------
CREATE VIEW v_book_availability AS
SELECT b.book_id, b.isbn, b.title, c.name AS category,
       GROUP_CONCAT(a.name, ', ') AS authors,
       b.available_copies, b.total_copies
FROM books b
JOIN categories c ON c.category_id = b.category_id
LEFT JOIN book_authors ba ON ba.book_id = b.book_id
LEFT JOIN authors a ON a.author_id = ba.author_id
GROUP BY b.book_id;

CREATE VIEW v_overdue AS
SELECT l.loan_id, m.name AS member, m.email, b.title, l.due_date,
       CAST(julianday(date('now')) - julianday(l.due_date) AS INTEGER) AS days_overdue
FROM loans l
JOIN members m ON m.member_id = l.member_id
JOIN books b   ON b.book_id   = l.book_id
WHERE l.return_date IS NULL AND l.due_date < date('now');
