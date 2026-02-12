---
title: "Trait deadman-vault"
draft: true
---
```
;; deadman-savings-vault.clar
;; A savings vault with deadman switch functionality
;; Owner deposits funds and must ping periodically
;; If owner fails to ping within timeout, beneficiary can claim all funds

(define-constant ERR-NOT-OWNER u401)
(define-constant ERR-TOO-EARLY u402)
(define-constant ERR-INSUFFICIENT u301)
(define-constant ERR-NOT-BENEFICIARY u403)

;; Deadman switch state
(define-data-var owner principal tx-sender)
(define-data-var beneficiary principal tx-sender)
(define-data-var last-ping uint burn-block-height)
(define-data-var admin principal tx-sender)
(define-data-var timeout uint u50) ;; Default 50 blocks, but owner can change

;; Per-user deposit tracking
(define-map deposits {user: principal} {amount: uint})

;; Track if beneficiary has claimed
(define-data-var has-claimed bool false)

;; ===== READ-ONLY FUNCTIONS =====

(define-read-only (get-state)
  (ok {
    owner: (var-get owner),
    beneficiary: (var-get beneficiary),
    last-ping: (var-get last-ping),
    timeout: (var-get timeout),
    has-claimed: (var-get has-claimed)
  }))

(define-read-only (get-deposit (user principal))
  (default-to u0 (get amount (map-get? deposits {user: user}))))

(define-read-only (get-owner-deposit)
  (get-deposit (var-get owner)))

(define-read-only (is-timeout-reached)
  (>= (- burn-block-height (var-get last-ping)) (var-get timeout)))

;; ===== ADMIN FUNCTIONS =====

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR-NOT-OWNER))
    (var-set admin new-admin)
    (ok true)))

;; ===== OWNER FUNCTIONS =====

(define-public (set-beneficiary (b principal))
  (if (is-eq tx-sender (var-get owner))
    (begin 
      (var-set beneficiary b) 
      (ok true))
    (err ERR-NOT-OWNER)))

(define-public (set-timeout (new-timeout uint))
  (if (is-eq tx-sender (var-get owner))
    (begin 
      (var-set timeout new-timeout) 
      (ok new-timeout))
    (err ERR-NOT-OWNER)))

(define-public (ping)
  (if (is-eq tx-sender (var-get owner))
    (begin 
      (var-set last-ping burn-block-height) 
      (ok burn-block-height))
    (err ERR-NOT-OWNER)))

(define-public (deposit (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (let ((prev (default-to u0 (get amount (map-get? deposits {user: tx-sender})))))
      (map-set deposits {user: tx-sender} {amount: (+ prev amount)})
      (ok (+ prev amount)))))

(define-public (withdraw (amount uint))
  (let ((prev (default-to u0 (get amount (map-get? deposits {user: tx-sender})))))
    (if (>= prev amount)
      (begin
        (map-set deposits {user: tx-sender} {amount: (- prev amount)})
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (ok (- prev amount)))
      (err ERR-INSUFFICIENT))))

;; ===== BENEFICIARY FUNCTIONS =====

(define-public (claim-all)
  (let (
    (lp (var-get last-ping))
    (current-owner (var-get owner))
    (current-beneficiary (var-get beneficiary))
    (owner-balance (get-deposit current-owner))
  )
    ;; Check timeout reached
    (asserts! (>= (- burn-block-height lp) (var-get timeout)) (err ERR-TOO-EARLY))
    ;; Check caller is beneficiary
    (asserts! (is-eq tx-sender current-beneficiary) (err ERR-NOT-BENEFICIARY))
    
    ;; Transfer ownership
    (var-set owner current-beneficiary)
    (var-set last-ping burn-block-height)
    (var-set has-claimed true)
    
    ;; Transfer all owner's funds to beneficiary
    (if (> owner-balance u0)
      (begin
        (map-set deposits {user: current-owner} {amount: u0})
        (let ((beneficiary-prev (get-deposit current-beneficiary)))
          (map-set deposits {user: current-beneficiary} {amount: (+ beneficiary-prev owner-balance)})
          (ok {transferred: owner-balance, new-balance: (+ beneficiary-prev owner-balance)})))
      (ok {transferred: u0, new-balance: (get-deposit current-beneficiary)}))))

```
