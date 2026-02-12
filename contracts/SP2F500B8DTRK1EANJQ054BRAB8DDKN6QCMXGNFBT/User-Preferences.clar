(define-map prefs principal bool)

(define-public (set-pref (value bool))
  (begin
    (map-set prefs tx-sender value)
    (ok value)
  )
)
