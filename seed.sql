PRAGMA foreign_keys = ON;

INSERT INTO categories(name) VALUES ('Computer Science'),('Fiction'),('Science'),('History');

INSERT INTO authors(name) VALUES
 ('Abraham Silberschatz'),('Henry F. Korth'),('S. Sudarshan'),
 ('Ramez Elmasri'),('Shamkant Navathe'),('George Orwell'),
 ('A. P. J. Abdul Kalam'),('Carl Sagan'),('Yuval Noah Harari');

INSERT INTO books(isbn,title,category_id,published_year,total_copies,available_copies) VALUES
 ('9780078022159','Database System Concepts',1,2019,3,3),
 ('9780133970777','Fundamentals of Database Systems',1,2015,2,2),
 ('9780451524935','1984',2,1949,2,2),
 ('9788173711466','Wings of Fire',4,1999,2,2),
 ('9780345539434','Cosmos',3,1980,1,1),
 ('9780062316097','Sapiens',4,2011,2,2);

INSERT INTO book_authors(book_id,author_id) VALUES
 (1,1),(1,2),(1,3),(2,4),(2,5),(3,6),(4,7),(5,8),(6,9);

INSERT INTO members(name,email,phone,joined_on) VALUES
 ('Aarav Sharma','aarav@example.com','9000000001','2026-01-10'),
 ('Diya Verma','diya@example.com','9000000002','2026-02-14'),
 ('Rohan Mehta','rohan@example.com','9000000003','2026-03-05'),
 ('Sneha Iyer','sneha@example.com','9000000004','2026-04-21');

-- Historic loans (triggers keep stock + fines consistent)
INSERT INTO loans(book_id,member_id,issue_date,due_date) VALUES (1,1,'2026-09-01','2026-09-15');
UPDATE loans SET return_date='2026-09-20' WHERE loan_id=1;   -- 5 days late -> fine Rs 10
INSERT INTO loans(book_id,member_id,issue_date,due_date) VALUES (3,2,'2026-09-10','2026-09-24');
UPDATE loans SET return_date='2026-09-22' WHERE loan_id=2;   -- on time
INSERT INTO loans(book_id,member_id,issue_date,due_date) VALUES (5,3,'2026-10-20','2026-11-03'); -- still out, overdue
INSERT INTO loans(book_id,member_id,issue_date,due_date) VALUES (6,1,'2026-11-15','2026-11-29');
