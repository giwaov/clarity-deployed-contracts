---
title: "Trait kv-datastore"
draft: true
---
```
;; kv-store.clar
;; Key-Value store with namespaces and permissions

;; Constants
(define-constant ERR-NAMESPACE-NOT-FOUND (err u100))
(define-constant ERR-NOT-NAMESPACE-OWNER (err u101))
(define-constant ERR-NO-READ-PERMISSION (err u102))
(define-constant ERR-NO-WRITE-PERMISSION (err u103))
(define-constant ERR-ENTRY-NOT-FOUND (err u104))
(define-constant ERR-EMPTY-KEY (err u105))
(define-constant ERR-NAMESPACE-EXISTS (err u106))

;; Maps
(define-map namespaces (buff 32)
  {
    name: (string-ascii 64),
    owner: principal,
    public-read: bool,
    public-write: bool
  }
)

(define-map entries { namespace-id: (buff 32), key: (string-ascii 64) }
  {
    value: (string-ascii 256),
    owner: principal,
    timestamp: uint
  }
)

(define-map namespace-readers { namespace-id: (buff 32), user: principal } bool)
(define-map namespace-writers { namespace-id: (buff 32), user: principal } bool)

;; Public Functions
(define-public (create-namespace (name (string-ascii 64)) (public-read bool) (public-write bool))
  (let ((namespace-id (sha256 (concat (unwrap-panic (to-consensus-buff? tx-sender)) (unwrap-panic (to-consensus-buff? name))))))
    (begin
      (asserts! (is-none (map-get? namespaces namespace-id)) ERR-NAMESPACE-EXISTS)
      (map-set namespaces namespace-id {
        name: name,
        owner: tx-sender,
        public-read: public-read,
        public-write: public-write
      })
      (ok namespace-id)
    )
  )
)

(define-public (put (namespace-id (buff 32)) (key (string-ascii 64)) (value (string-ascii 256)))
  (let ((ns (unwrap! (map-get? namespaces namespace-id) ERR-NAMESPACE-NOT-FOUND)))
    (begin
      (asserts! (> (len key) u0) ERR-EMPTY-KEY)
      (asserts! (> (len value) u0) (err u107))
      (asserts! (has-write-permission namespace-id ns tx-sender) ERR-NO-WRITE-PERMISSION)
      
      (map-set entries { namespace-id: namespace-id, key: key } {
        value: value,
        owner: tx-sender,
        timestamp: stacks-block-time
      })
      (ok true)
    )
  )
)

(define-public (delete-entry (namespace-id (buff 32)) (key (string-ascii 64)))
  (let (
    (ns (unwrap! (map-get? namespaces namespace-id) ERR-NAMESPACE-NOT-FOUND))
  )
    (begin
      (asserts! (> (len key) u0) ERR-EMPTY-KEY)
      (asserts! (is-eq (get owner ns) tx-sender) ERR-NOT-NAMESPACE-OWNER)
      (map-delete entries { namespace-id: namespace-id, key: key })
      (ok true)
    )
  )
)

(define-public (grant-read-permission (namespace-id (buff 32)) (user principal))
  (let ((ns (unwrap! (map-get? namespaces namespace-id) ERR-NAMESPACE-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get owner ns) tx-sender) ERR-NOT-NAMESPACE-OWNER)
      (asserts! (not (is-eq user tx-sender)) (err u108))
      (ok (map-set namespace-readers { namespace-id: namespace-id, user: user } true))
    )
  )
)

(define-public (grant-write-permission (namespace-id (buff 32)) (user principal))
  (let ((ns (unwrap! (map-get? namespaces namespace-id) ERR-NAMESPACE-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get owner ns) tx-sender) ERR-NOT-NAMESPACE-OWNER)
      (asserts! (not (is-eq user tx-sender)) (err u109))
      (ok (map-set namespace-writers { namespace-id: namespace-id, user: user } true))
    )
  )
)

;; Read-only
(define-read-only (get-value (namespace-id (buff 32)) (key (string-ascii 64)))
  (let ((ns (unwrap! (map-get? namespaces namespace-id) ERR-NAMESPACE-NOT-FOUND)))
    (begin
      (asserts! (has-read-permission namespace-id ns tx-sender) ERR-NO-READ-PERMISSION)
      (ok (get value (unwrap! (map-get? entries { namespace-id: namespace-id, key: key }) ERR-ENTRY-NOT-FOUND)))
    )
  )
)

;; Private helpers
(define-private (has-read-permission (ns-id (buff 32)) (ns {name: (string-ascii 64), owner: principal, public-read: bool, public-write: bool}) (user principal))
  (or 
    (is-eq (get owner ns) user)
    (get public-read ns)
    (default-to false (map-get? namespace-readers { namespace-id: ns-id, user: user }))
  )
)

(define-private (has-write-permission (ns-id (buff 32)) (ns {name: (string-ascii 64), owner: principal, public-read: bool, public-write: bool}) (user principal))
  (or 
    (is-eq (get owner ns) user)
    (get public-write ns)
    (default-to false (map-get? namespace-writers { namespace-id: ns-id, user: user }))
  )
)

```
