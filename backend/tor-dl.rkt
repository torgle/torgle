#lang racket

(provide tor-dl)

(define (str->bstr str)
  (string->bytes/utf-8 str))

(define (vbwrite bstr out)
  (void (write-bytes bstr out)))

(define (http-chunked-body in (content ""))
  (let ((line (read-line in)))
    (if (equal? (string->number (string-trim line))
                0)
        content
        (http-chunked-body in (string-append content line)))))

(define (string-reverse str)
  (list->string (reverse (string->list str))))

(define (bad-info-get-body in (content ""))
  (let ((line (read-line in)))
    (if (eof-object? line)
        content
        (bad-info-get-body in (string-append content line)))))

(define (http-get-body headers in)
  (let ((body-len (hash-ref headers "CONTENT-LENGTH" #f)))
    (if body-len
        (read-string (string->number body-len) in)
        (bad-info-get-body in))))

(define (http-headers in (header-hash (make-immutable-hash)))
  (let ((line (read-line in)))
    (if (or (equal? line "\r")
            (eof-object? line))
        header-hash
        (if (regexp-match ":" line)
            (let* ((headers (regexp-split ":" line))
                   (header  (string-upcase (first headers)))
                   (value   (string-upcase (second headers))))
              (http-headers in (hash-set header-hash
                                         (string-trim header)
                                         (string-trim value))))
            (http-headers in header-hash)))))

(define (http-body in)
  (let ((headers (http-headers in)))
    (if (regexp-match "CHUNKED" (hash-ref headers "TRANSFER-ENCODING" ""))
        (http-chunked-body in)
        (http-get-body headers in))))

(define (http-request site path out)
  (vbwrite
   (bytes-append #"GET /"  (str->bstr path) #" HTTP/1.1\r\n"
                 #"Host: " (str->bstr site) #"\r\n\r\n")
   out))

(define (url-parse site)
  (let* ((uri-vals (regexp-split "/" site))
         (domain (car uri-vals))
         (path (if (null? (cdr uri-vals))
                   ""
                   (string-join (cdr uri-vals) "/"))))
    (list domain path)))

(define (tor-dl site (host "localhost") (port 9050))
  (let-values (((in out) (tcp-connect "localhost" port)))
    (let* ((url  (url-parse   site))
           (site (first       url))
           (path (second      url)))
      (file-stream-buffer-mode out 'none)
      (vbwrite (bytes 5 1 0) out)
      (void (read-byte in))
      (vbwrite (apply bytes-append 
                      (list (bytes 5 1 0 3 (string-length site))
                            (str->bstr site)
                            (apply bytes '(0 80))))
               out)
      (http-request site path out)
      (http-body in))))
