(define-non-fungible-token hnft uint)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-INVALID-PARENT (err u102))
(define-constant ERR-CIRCULAR-REF (err u103))

(define-data-var token-id-nonce uint u0)

(define-map token-parent uint uint)
(define-map token-children uint (list 100 uint))
(define-map token-uri uint (string-ascii 256))

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (token uint))
  (ok (map-get? token-uri token))
)

(define-read-only (get-owner (token uint))
  (ok (nft-get-owner? hnft token))
)

(define-read-only (parent-of (token uint))
  (ok (default-to u0 (map-get? token-parent token)))
)

(define-read-only (children-of (token uint))
  (ok (default-to (list) (map-get? token-children token)))
)

(define-read-only (is-root (token uint))
  (ok (is-eq (default-to u0 (map-get? token-parent token)) u0))
)

(define-read-only (is-leaf (token uint))
  (let ((children (default-to (list) (map-get? token-children token))))
    (ok (is-eq (len children) u0))
  )
)

(define-public (mint (recipient principal) (uri (string-ascii 256)))
  (let ((new-id (+ (var-get token-id-nonce) u1)))
    (try! (nft-mint? hnft new-id recipient))
    (map-set token-uri new-id uri)
    (map-set token-parent new-id u0)
    (var-set token-id-nonce new-id)
    (ok new-id)
  )
)

(define-public (mint-child (parent-id uint) (recipient principal) (uri (string-ascii 256)))
  (let (
    (new-id (+ (var-get token-id-nonce) u1))
    (parent-owner (unwrap! (nft-get-owner? hnft parent-id) ERR-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender parent-owner) ERR-NOT-AUTHORIZED)
    (try! (nft-mint? hnft new-id recipient))
    (map-set token-uri new-id uri)
    (map-set token-parent new-id parent-id)
    (let ((current-children (default-to (list) (map-get? token-children parent-id))))
      (map-set token-children parent-id (unwrap! (as-max-len? (append current-children new-id) u100) ERR-INVALID-PARENT))
    )
    (var-set token-id-nonce new-id)
    (ok new-id)
  )
)

(define-public (transfer (token uint) (sender principal) (recipient principal))
  (let ((owner (unwrap! (nft-get-owner? hnft token) ERR-NOT-FOUND)))
    (asserts! (or (is-eq tx-sender owner) (is-eq tx-sender sender)) ERR-NOT-AUTHORIZED)
    (try! (nft-transfer? hnft token sender recipient))
    (ok true)
  )
)

(define-public (transfer-parent (new-parent-id uint) (token uint))
  (let (
    (owner (unwrap! (nft-get-owner? hnft token) ERR-NOT-FOUND))
    (old-parent (default-to u0 (map-get? token-parent token)))
  )
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq token new-parent-id)) ERR-CIRCULAR-REF)
    ;; Check if new-parent-id is a descendant of token (would create circular ref)
    (asserts! (not (is-descendant new-parent-id token)) ERR-CIRCULAR-REF)
    (if (> old-parent u0)
      (let ((old-parent-children (default-to (list) (map-get? token-children old-parent))))
        (map-set token-children old-parent (filter-out-token old-parent-children token))
      )
      true
    )
    (map-set token-parent token new-parent-id)
    (if (> new-parent-id u0)
      (let ((new-parent-children (default-to (list) (map-get? token-children new-parent-id))))
        (map-set token-children new-parent-id (unwrap! (as-max-len? (append new-parent-children token) u100) ERR-INVALID-PARENT))
      )
      true
    )
    (ok true)
  )
)

(define-public (burn (token uint))
  (let (
    (owner (unwrap! (nft-get-owner? hnft token) ERR-NOT-FOUND))
    (children (default-to (list) (map-get? token-children token)))
  )
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (len children) u0) ERR-INVALID-PARENT)
    (let ((parent (default-to u0 (map-get? token-parent token))))
      (if (> parent u0)
        (let ((parent-children (default-to (list) (map-get? token-children parent))))
          (map-set token-children parent (filter-out-token parent-children token))
        )
        true
      )
    )
    (try! (nft-burn? hnft token owner))
    (map-delete token-parent token)
    (map-delete token-uri token)
    (ok true)
  )
)

(define-private (filter-out-token (children-list (list 100 uint)) (target uint))
  (filter filter-not-target children-list)
)

(define-private (filter-not-target (child-id uint))
  (not (is-eq child-id u0))
)

;; Check if potential-descendant is a descendant of ancestor
;; Checks up to 100 levels of hierarchy using fold
(define-private (is-descendant (potential-descendant uint) (ancestor uint))
  (if (is-eq potential-descendant u0)
    false
    (get found (fold check-ancestor-level
      (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
            u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40
            u41 u42 u43 u44 u45 u46 u47 u48 u49 u50 u51 u52 u53 u54 u55 u56 u57 u58 u59 u60
            u61 u62 u63 u64 u65 u66 u67 u68 u69 u70 u71 u72 u73 u74 u75 u76 u77 u78 u79 u80
            u81 u82 u83 u84 u85 u86 u87 u88 u89 u90 u91 u92 u93 u94 u95 u96 u97 u98 u99 u100)
      {current: potential-descendant, ancestor: ancestor, found: false}
    ))
  )
)

(define-private (check-ancestor-level (level uint) (state {current: uint, ancestor: uint, found: bool}))
  (if (get found state)
    state
    (let ((current (get current state))
          (ancestor (get ancestor state)))
      (if (is-eq current u0)
        state
        (let ((parent (default-to u0 (map-get? token-parent current))))
          (if (is-eq parent u0)
            state
            (if (is-eq parent ancestor)
              {current: u0, ancestor: ancestor, found: true}
              {current: parent, ancestor: ancestor, found: false}
            )
          )
        )
      )
    )
  )
)
