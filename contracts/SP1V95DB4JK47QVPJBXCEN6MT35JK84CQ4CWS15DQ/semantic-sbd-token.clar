(define-non-fungible-token semantic-sbt uint)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-SOULBOUND (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))

(define-data-var token-id-nonce uint u0)
(define-data-var schema-uri (string-ascii 256) "")

(define-map token-locked uint bool)
(define-map token-rdf uint (string-utf8 2048))
(define-map token-uri uint (string-ascii 256))

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (token uint))
  (ok (map-get? token-uri token))
)

(define-read-only (get-owner (token uint))
  (ok (nft-get-owner? semantic-sbt token))
)

(define-read-only (locked (token uint))
  (ok (default-to true (map-get? token-locked token)))
)

(define-read-only (rdf-of (token uint))
  (ok (map-get? token-rdf token))
)

(define-read-only (schema-uri-get)
  (ok (var-get schema-uri))
)

(define-public (mint (recipient principal) (uri (string-ascii 256)) (rdf (string-utf8 2048)))
  (let ((new-id (+ (var-get token-id-nonce) u1)))
    (try! (nft-mint? semantic-sbt new-id recipient))
    (map-set token-uri new-id uri)
    (map-set token-locked new-id true)
    (map-set token-rdf new-id rdf)
    (var-set token-id-nonce new-id)
    (print {event: "create-rdf", token-id: new-id, rdf: rdf})
    (ok new-id)
  )
)

(define-public (update-rdf (token uint) (rdf (string-utf8 2048)))
  (let ((owner (unwrap! (nft-get-owner? semantic-sbt token) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    (map-set token-rdf token rdf)
    (print {event: "update-rdf", token-id: token, rdf: rdf})
    (ok true)
  )
)

(define-public (burn (token uint))
  (let (
    (owner (unwrap! (nft-get-owner? semantic-sbt token) ERR-NOT-FOUND))
    (rdf (default-to u"" (map-get? token-rdf token)))
  )
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    (try! (nft-burn? semantic-sbt token owner))
    (map-delete token-locked token)
    (map-delete token-rdf token)
    (map-delete token-uri token)
    (print {event: "remove-rdf", token-id: token, rdf: rdf})
    (ok true)
  )
)

(define-public (set-schema-uri (new-uri (string-ascii 256)))
  (begin
    (var-set schema-uri new-uri)
    (ok true)
  )
)

(define-public (transfer (token uint) (sender principal) (recipient principal))
  (let (
    (is-locked (unwrap! (locked token) ERR-NOT-FOUND))
  )
    (asserts! (not is-locked) ERR-SOULBOUND)
    ERR-SOULBOUND
  )
)
