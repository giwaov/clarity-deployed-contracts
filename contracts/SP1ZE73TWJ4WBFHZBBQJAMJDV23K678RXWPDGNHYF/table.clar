;; title: Student Attendance
;; version: 1.0.0
;; summary: Simple student attendance tracking contract

;; Data map to store attendance records
;; Key: (student-name, date) tuple
;; Value: true if present
(define-map attendance (tuple (student-name (string-ascii 50)) (date (string-ascii 20))) bool)

;; Mark a student as present on a specific date
;; Anyone can mark attendance
(define-public (mark-attendance (student-name (string-ascii 50)) (date (string-ascii 20)))
  (begin
    (map-set attendance {student-name: student-name, date: date} true)
    (ok true)
  )
)

;; Check if a student was present on a specific date
(define-read-only (check-attendance (student-name (string-ascii 50)) (date (string-ascii 20)))
  (match (map-get? attendance {student-name: student-name, date: date})
    attendance-record (ok attendance-record)
    (ok false)
  )
)
