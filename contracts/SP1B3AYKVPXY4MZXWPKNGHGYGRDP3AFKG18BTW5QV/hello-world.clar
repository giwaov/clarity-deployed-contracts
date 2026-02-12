;; Kontrak: hello-world
;; Menyimpan pemilik kontrak dan memastikan hanya pemilik yang dapat memperbarui.
(define-data-var owner principal tx-sender)

(define-read-only (get-owner)
  (ok (var-get owner)))

(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u403))
    (var-set owner new-owner)
    (ok (var-get owner))))