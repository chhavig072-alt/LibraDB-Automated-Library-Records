-- Sample queries for the report / viva

-- 1. Books with their authors and availability (view)
SELECT * FROM v_book_availability;

-- 2. Members who currently have overdue books (view)
SELECT * FROM v_overdue;

-- 3. Top borrowers (JOIN + GROUP BY + HAVING)
SELECT m.name, COUNT(*) AS loans_taken
FROM loans l JOIN members m USING(member_id)
GROUP BY m.member_id HAVING COUNT(*) >= 1
ORDER BY loans_taken DESC;

-- 4. Books never borrowed (subquery)
SELECT title FROM books WHERE book_id NOT IN (SELECT book_id FROM loans);

-- 5. Total unpaid fines per member
SELECT m.name, SUM(f.amount) AS unpaid
FROM fines f JOIN loans l USING(loan_id) JOIN members m USING(member_id)
WHERE f.paid = 0 GROUP BY m.member_id;

-- 6. Category-wise stock summary
SELECT c.name, SUM(b.total_copies) AS total, SUM(b.available_copies) AS available
FROM books b JOIN categories c USING(category_id) GROUP BY c.category_id;

-- 7. Books by more than one author
SELECT b.title, COUNT(*) AS n_authors
FROM books b JOIN book_authors USING(book_id) GROUP BY b.book_id HAVING n_authors > 1;
