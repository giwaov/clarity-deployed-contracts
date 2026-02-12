(define-map stealth-meta-addresses principal {spending-pubkey: (buff 33), viewing-pubkey: (buff 33)})
(define-map announcements uint {scheme-id: uint, stealth-address: principal, ephemeral-pubkey: (buff 33), view-tag: (buff 1), metadata: (buff 256)})
(define-data-var announcement-nonce uint u0)

(define-constant err-invalid-pubkey (err u300))
(define-constant err-invalid-scheme (err u301))
(define-constant err-announcement-not-found (err u302))

(define-read-only (get-stealth-meta-address (user principal))
  (ok (map-get? stealth-meta-addresses user)))

(define-read-only (get-announcement (id uint))
  (ok (map-get? announcements id)))

(define-public (register-stealth-meta-address (spending-pubkey (buff 33)) (viewing-pubkey (buff 33)))
  (begin
    (asserts! (> (len spending-pubkey) u0) err-invalid-pubkey)
    (asserts! (> (len viewing-pubkey) u0) err-invalid-pubkey)
    (map-set stealth-meta-addresses tx-sender {spending-pubkey: spending-pubkey, viewing-pubkey: viewing-pubkey})
    (ok true)))

(define-public (announce (scheme-id uint) (stealth-address principal) (ephemeral-pubkey (buff 33)) (view-tag (buff 1)) (metadata (buff 256)))
  (let ((id (+ (var-get announcement-nonce) u1)))
    (asserts! (is-eq scheme-id u1) err-invalid-scheme)
    (map-set announcements id {
      scheme-id: scheme-id,
      stealth-address: stealth-address,
      ephemeral-pubkey: ephemeral-pubkey,
      view-tag: view-tag,
      metadata: metadata
    })
    (var-set announcement-nonce id)
    (ok id)))

(define-read-only (check-stealth-address (stealth-address principal) (ephemeral-pubkey (buff 33)) (view-tag (buff 1)))
  (ok true))

(define-read-only (parse-announcements (start-id uint) (end-id uint))
  (ok (map get-announcement-by-id (generate-id-list start-id end-id))))

(define-private (get-announcement-by-id (id uint))
  (default-to {scheme-id: u0, stealth-address: tx-sender, ephemeral-pubkey: 0x00, view-tag: 0x00, metadata: 0x00}
    (map-get? announcements id)))

(define-private (generate-id-list (start uint) (end uint))
  (list start))
