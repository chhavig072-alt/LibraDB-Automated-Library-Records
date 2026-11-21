#!/usr/bin/env python3
"""Library Management System - menu-driven app backed by SQLite.

Run:  python3 app.py          (creates library.db from schema.sql + seed.sql on first run)
      python3 app.py --reset  (rebuild the database from scratch)
"""
import os
import sqlite3
import sys
from datetime import date, timedelta

BASE = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE, "library.db")
LOAN_DAYS = 14


def connect():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db(reset=False):
    if reset and os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    if os.path.exists(DB_PATH):
        return
    conn = connect()
    for f in ("schema.sql", "seed.sql"):
        with open(os.path.join(BASE, f), encoding="utf-8") as fh:
            conn.executescript(fh.read())
    conn.commit()
    conn.close()
    print("Database created and seeded.")


def show(rows, headers=None):
    rows = [tuple(r) for r in rows]
    if not rows:
        print("  (no records)")
        return
    headers = headers or [f"col{i}" for i in range(len(rows[0]))]
    table = [headers] + [["" if v is None else str(v) for v in r] for r in rows]
    widths = [max(len(r[i]) for r in table) for i in range(len(headers))]
    line = "  ".join("-" * w for w in widths)
    print(line)
    print("  ".join(h.ljust(w) for h, w in zip(table[0], widths)))
    print(line)
    for r in table[1:]:
        print("  ".join(v.ljust(w) for v, w in zip(r, widths)))
    print(line)


def run_select(conn, sql, params=()):
    cur = conn.execute(sql, params)
    headers = [d[0] for d in cur.description]
    show(cur.fetchall(), headers)


# ---------------------------- Features ----------------------------
def list_books(conn):
    run_select(conn, "SELECT book_id, title, authors, category, available_copies, total_copies "
                     "FROM v_book_availability ORDER BY title")


def search_books(conn):
    term = f"%{input('Search title/author: ').strip()}%"
    run_select(conn, "SELECT book_id, title, authors, available_copies FROM v_book_availability "
                     "WHERE title LIKE ? OR authors LIKE ?", (term, term))


def add_book(conn):
    isbn = input("ISBN: ").strip()
    title = input("Title: ").strip()
    cat = input("Category: ").strip()
    year = int(input("Published year: "))
    copies = int(input("Copies: "))
    authors = [a.strip() for a in input("Authors (comma separated): ").split(",") if a.strip()]
    with conn:  # one transaction: all inserts succeed or none do
        conn.execute("INSERT OR IGNORE INTO categories(name) VALUES (?)", (cat,))
        cid = conn.execute("SELECT category_id FROM categories WHERE name=?", (cat,)).fetchone()[0]
        cur = conn.execute("INSERT INTO books(isbn,title,category_id,published_year,total_copies,available_copies) "
                           "VALUES (?,?,?,?,?,?)", (isbn, title, cid, year, copies, copies))
        bid = cur.lastrowid
        for a in authors:
            conn.execute("INSERT OR IGNORE INTO authors(name) VALUES (?)", (a,))
            aid = conn.execute("SELECT author_id FROM authors WHERE name=?", (a,)).fetchone()[0]
            conn.execute("INSERT INTO book_authors VALUES (?,?)", (bid, aid))
    print(f"Book added with id {bid}.")


def add_member(conn):
    name = input("Name: ").strip()
    email = input("Email: ").strip()
    phone = input("Phone: ").strip() or None
    with conn:
        cur = conn.execute("INSERT INTO members(name,email,phone) VALUES (?,?,?)", (name, email, phone))
    print(f"Member added with id {cur.lastrowid}.")


def list_members(conn):
    run_select(conn, "SELECT m.member_id, m.name, m.email, m.status, "
                     "COUNT(l.loan_id) AS books_out FROM members m "
                     "LEFT JOIN loans l ON l.member_id=m.member_id AND l.return_date IS NULL "
                     "GROUP BY m.member_id")


def issue_book(conn):
    bid = int(input("Book id: "))
    mid = int(input("Member id: "))
    issue = date.today()
    with conn:
        cur = conn.execute("INSERT INTO loans(book_id,member_id,issue_date,due_date) VALUES (?,?,?,?)",
                           (bid, mid, issue.isoformat(), (issue + timedelta(days=LOAN_DAYS)).isoformat()))
    print(f"Issued. Loan id {cur.lastrowid}, due {issue + timedelta(days=LOAN_DAYS)}.")


def return_book(conn):
    run_select(conn, "SELECT l.loan_id, m.name, b.title, l.due_date FROM loans l "
                     "JOIN members m USING(member_id) JOIN books b USING(book_id) WHERE return_date IS NULL")
    lid = int(input("Loan id to return: "))
    with conn:
        cur = conn.execute("UPDATE loans SET return_date=? WHERE loan_id=? AND return_date IS NULL",
                           (date.today().isoformat(), lid))
    if cur.rowcount == 0:
        print("No open loan with that id.")
        return
    fine = conn.execute("SELECT amount FROM fines WHERE loan_id=?", (lid,)).fetchone()
    print(f"Returned. Fine charged: Rs {fine[0]:.2f}" if fine else "Returned on time. No fine.")


def overdue_report(conn):
    run_select(conn, "SELECT * FROM v_overdue ORDER BY days_overdue DESC")


def fines_report(conn):
    run_select(conn, "SELECT m.name, SUM(f.amount) AS total_fines, "
                     "SUM(CASE WHEN f.paid=0 THEN f.amount ELSE 0 END) AS unpaid "
                     "FROM fines f JOIN loans l USING(loan_id) JOIN members m USING(member_id) "
                     "GROUP BY m.member_id")


def pay_fine(conn):
    run_select(conn, "SELECT f.fine_id, m.name, f.amount FROM fines f JOIN loans l USING(loan_id) "
                     "JOIN members m USING(member_id) WHERE f.paid=0")
    fid = int(input("Fine id to mark paid: "))
    with conn:
        conn.execute("UPDATE fines SET paid=1 WHERE fine_id=?", (fid,))
    print("Updated.")


def popular_books(conn):
    run_select(conn, "SELECT b.title, COUNT(*) AS times_issued FROM loans l "
                     "JOIN books b USING(book_id) GROUP BY b.book_id ORDER BY times_issued DESC LIMIT 5")


def delete_member(conn):
    mid = int(input("Member id to delete: "))
    try:
        with conn:
            cur = conn.execute("DELETE FROM members WHERE member_id=?", (mid,))
        print("Deleted." if cur.rowcount else "Not found.")
    except sqlite3.IntegrityError:
        print("Cannot delete: member has loan history (foreign key protects it). Suspend instead.")
        with conn:
            conn.execute("UPDATE members SET status='SUSPENDED' WHERE member_id=?", (mid,))


MENU = [
    ("List books", list_books), ("Search books", search_books), ("Add book", add_book),
    ("List members", list_members), ("Add member", add_member),
    ("Issue book", issue_book), ("Return book", return_book),
    ("Overdue report", overdue_report), ("Fines report", fines_report), ("Pay fine", pay_fine),
    ("Most popular books", popular_books), ("Delete/suspend member", delete_member),
]


def main():
    init_db(reset="--reset" in sys.argv)
    conn = connect()
    while True:
        print("\n=== Library Management System ===")
        for i, (label, _) in enumerate(MENU, 1):
            print(f"{i:>2}. {label}")
        print(" 0. Exit")
        choice = input("Choose: ").strip()
        if choice == "0":
            break
        if not choice.isdigit() or not 1 <= int(choice) <= len(MENU):
            print("Invalid choice.")
            continue
        try:
            MENU[int(choice) - 1][1](conn)
        except (sqlite3.Error, ValueError) as e:
            print(f"Error: {e}")
    conn.close()


if __name__ == "__main__":
    main()
