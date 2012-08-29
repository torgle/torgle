#lang racket

(require (planet jaz/mysql))
(require (planet jaz/mysql:1/format))
(require "tor-dl.rkt")

(define (link-format links site)
  (string-join 
   (remove-duplicates 
    (cons site (string-split links " ")))
   " "))

(define (update-site site)
  (lambda (link)
    (if (null? (sql "SELECT url FROM sites "
                    "WHERE url='" link "'"))
        (run-query "INSERT INTO sites VALUES ('"
                   link "', '', '" site "', 0, '', '')")
        (run-query "UPDATE sites SET linked_from='" 
                   (link-format (car-sql "SELECT linked_from FROM sites WHERE url='" 
                                         link "'") site)
                   "' WHERE url='" link "'"))))

(define (update-linked-from site links)
  (lambda (results)
    (let ((link-site   (first results))
          (linked_from (string-split (cadr results) " ")))
      (cond ((not (member link-site links))
             (run-query "UPDATE sites SET linked_from='"
                        (string-join (remove site linked_from) " ")
                        "' WHERE url='" link-site "'"))))))

(define (update-linked site links)
  (void (map (update-site site) links)
        (map (update-linked-from site links) 
             (sql "SELECT url, linked_from FROM sites"
                  " WHERE linked_from LIKE '%" site "%'")))) 

(define (update-linkers site links)
  (void (update-linked site links)
        (run-query "UPDATE sites SET links_to='" 
                   (string-join links " ") 
                   "' WHERE url='" site "'")))

(define (links document)
  (regexp-match* (string-append "[a-z0-9]+\\.onion/?((?! |<|>|'|\"|\\!"
                                "|@|#|\\$|%|\\|\\^|\\&|\\*|\\(|\\)|-|;"
                                "|\\[|\\]|\\{|\\}|\\||\\\\|,|\t|\n|\r).)*")
                 document))

(define (notags code)
  (regexp-replace* "<.*?>" "sdsd <center>dsdsd</center></body>" ""))

(define (update-db site code)
  (update-linkers site (links code))
  (let ((searchable-code (notags code)))
    (if (equal? (car-sql "SELECT url FROM sites WHERE url='" site "'") 
                site)
        (run-query "UPDATE sites SET content=" code ", searchable_content=" searchable-code 
                   ", last_checked=" (number->string (current-seconds)) " WHERE url='" site "'")
        (run-query "INSERT INTO sites VALUES ("' site "', '', '', 0, " code ", " searchable-code))))

(define (newest-site)
  (car-sql "SELECT url FROM sites WHERE last_checked="
           "(SELECT MIN(last_checked) FROM sites)"))

(define (run-query . code)
  (query (apply string-append code)))

(define (sql . code)
  (map vector->list (result-set-rows (query (apply string-append code)))))

(define (car-sql . code)
  (let ((result (sql (apply string-append code))))
    (if (null? result)
        ""
        (caar result))))

(define (escape data)
  (format-sql "~s" data))

(define (crawl (site (newest-site)))
  (update-db site
             (escape (tor-dl site)))
  (crawl))

(connect "localhost" 3306 "user" "pass" #:schema "database")
(crawl)