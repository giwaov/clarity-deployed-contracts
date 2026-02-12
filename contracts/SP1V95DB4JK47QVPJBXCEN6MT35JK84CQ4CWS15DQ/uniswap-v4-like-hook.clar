(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-already-exists (err u104))

(define-map hooks 
  {pool-id: (string-ascii 64)} 
  {
    hook-contract: principal,
    before-swap: bool,
    after-swap: bool,
    before-add-liquidity: bool,
    after-add-liquidity: bool,
    before-remove-liquidity: bool,
    after-remove-liquidity: bool,
    enabled: bool
  }
)

(define-map hook-data
  {pool-id: (string-ascii 64), hook-type: (string-ascii 32)}
  {data: (buff 1024)}
)

(define-data-var hook-counter uint u0)

(define-read-only (get-hook (pool-id (string-ascii 64)))
  (map-get? hooks {pool-id: pool-id})
)

(define-read-only (get-hook-data (pool-id (string-ascii 64)) (hook-type (string-ascii 32)))
  (map-get? hook-data {pool-id: pool-id, hook-type: hook-type})
)

(define-public (register-hook 
  (pool-id (string-ascii 64))
  (hook-contract principal)
  (before-swap bool)
  (after-swap bool)
  (before-add-liquidity bool)
  (after-add-liquidity bool)
  (before-remove-liquidity bool)
  (after-remove-liquidity bool)
)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-none (map-get? hooks {pool-id: pool-id})) err-already-exists)
    (ok (map-set hooks {pool-id: pool-id}
      {
        hook-contract: hook-contract,
        before-swap: before-swap,
        after-swap: after-swap,
        before-add-liquidity: before-add-liquidity,
        after-add-liquidity: after-add-liquidity,
        before-remove-liquidity: before-remove-liquidity,
        after-remove-liquidity: after-remove-liquidity,
        enabled: true
      }
    ))
  )
)

(define-public (update-hook-status (pool-id (string-ascii 64)) (enabled bool))
  (let ((hook (unwrap! (map-get? hooks {pool-id: pool-id}) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set hooks {pool-id: pool-id}
      (merge hook {enabled: enabled})
    ))
  )
)

(define-public (execute-before-swap
  (pool-id (string-ascii 64))
  (sender principal)
  (amount-in uint)
  (amount-out-min uint)
)
  (let ((hook (unwrap! (map-get? hooks {pool-id: pool-id}) err-not-found)))
    (asserts! (get enabled hook) err-unauthorized)
    (asserts! (get before-swap hook) err-unauthorized)
    (var-set hook-counter (+ (var-get hook-counter) u1))
    (ok true)
  )
)

(define-public (execute-after-swap
  (pool-id (string-ascii 64))
  (sender principal)
  (amount-in uint)
  (amount-out uint)
)
  (let ((hook (unwrap! (map-get? hooks {pool-id: pool-id}) err-not-found)))
    (asserts! (get enabled hook) err-unauthorized)
    (asserts! (get after-swap hook) err-unauthorized)
    (var-set hook-counter (+ (var-get hook-counter) u1))
    (ok true)
  )
)

(define-public (execute-before-add-liquidity
  (pool-id (string-ascii 64))
  (sender principal)
  (amount0 uint)
  (amount1 uint)
)
  (let ((hook (unwrap! (map-get? hooks {pool-id: pool-id}) err-not-found)))
    (asserts! (get enabled hook) err-unauthorized)
    (asserts! (get before-add-liquidity hook) err-unauthorized)
    (var-set hook-counter (+ (var-get hook-counter) u1))
    (ok true)
  )
)

(define-public (execute-after-add-liquidity
  (pool-id (string-ascii 64))
  (sender principal)
  (amount0 uint)
  (amount1 uint)
  (liquidity uint)
)
  (let ((hook (unwrap! (map-get? hooks {pool-id: pool-id}) err-not-found)))
    (asserts! (get enabled hook) err-unauthorized)
    (asserts! (get after-add-liquidity hook) err-unauthorized)
    (var-set hook-counter (+ (var-get hook-counter) u1))
    (ok true)
  )
)

(define-public (execute-before-remove-liquidity
  (pool-id (string-ascii 64))
  (sender principal)
  (liquidity uint)
)
  (let ((hook (unwrap! (map-get? hooks {pool-id: pool-id}) err-not-found)))
    (asserts! (get enabled hook) err-unauthorized)
    (asserts! (get before-remove-liquidity hook) err-unauthorized)
    (var-set hook-counter (+ (var-get hook-counter) u1))
    (ok true)
  )
)

(define-public (execute-after-remove-liquidity
  (pool-id (string-ascii 64))
  (sender principal)
  (liquidity uint)
  (amount0 uint)
  (amount1 uint)
)
  (let ((hook (unwrap! (map-get? hooks {pool-id: pool-id}) err-not-found)))
    (asserts! (get enabled hook) err-unauthorized)
    (asserts! (get after-remove-liquidity hook) err-unauthorized)
    (var-set hook-counter (+ (var-get hook-counter) u1))
    (ok true)
  )
)

(define-public (store-hook-data
  (pool-id (string-ascii 64))
  (hook-type (string-ascii 32))
  (data (buff 1024))
)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set hook-data 
      {pool-id: pool-id, hook-type: hook-type}
      {data: data}
    ))
  )
)

(define-read-only (get-hook-counter)
  (ok (var-get hook-counter))
)
