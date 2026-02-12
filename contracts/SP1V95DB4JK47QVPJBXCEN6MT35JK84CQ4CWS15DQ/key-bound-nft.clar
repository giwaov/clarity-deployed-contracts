(define-constant ERR_NOT_AUTHORIZED (err u300))
(define-constant ERR_NOT_FOUND (err u301))
(define-constant ERR_INVALID_KEY_WALLET (err u302))
(define-constant ERR_TRANSFER_NOT_ALLOWED (err u303))
(define-constant ERR_APPROVAL_NOT_ALLOWED (err u304))
(define-constant ERR_ALREADY_SECURED (err u305))

(define-non-fungible-token key-bound-nft uint)

(define-data-var token-id-nonce uint u0)

(define-map bindings 
  principal 
  {key-wallet-1: principal, key-wallet-2: principal}
)

(define-map transfer-conditions 
  principal 
  {token-id: uint, time: uint, to: principal, any-token: bool}
)

(define-map approval-conditions 
  principal 
  {time: uint, num-transfers: uint}
)

(define-map token-owners uint principal)

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (id uint))
  (ok none)
)

(define-read-only (get-owner (id uint))
  (ok (nft-get-owner? key-bound-nft id))
)

(define-public (transfer (id uint) (sender principal) (recipient principal))
  (let (
    (holder-bindings (map-get? bindings sender))
    (conditions (map-get? transfer-conditions sender))
  )
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    (if (is-some holder-bindings)
      (begin
        (asserts! (is-some conditions) ERR_TRANSFER_NOT_ALLOWED)
        (let (
          (cond (unwrap-panic conditions))
        )
          (asserts! 
            (or (get any-token cond)
                (and (is-eq (get token-id cond) id)
                     (or (is-eq (get time cond) u0) (<= stacks-block-time (get time cond)))
                     (or (is-eq (get to cond) recipient) (is-eq (get to cond) 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM))))
            ERR_TRANSFER_NOT_ALLOWED
          )
          (nft-transfer? key-bound-nft id sender recipient)
        )
      )
      (nft-transfer? key-bound-nft id sender recipient)
    )
  )
)

(define-public (mint (recipient principal))
  (let (
    (id (+ (var-get token-id-nonce) u1))
  )
    (try! (nft-mint? key-bound-nft id recipient))
    (var-set token-id-nonce id)
    (ok id)
  )
)

(define-public (add-bindings (key-wallet-1 principal) (key-wallet-2 principal))
  (begin
    (asserts! (not (is-eq key-wallet-1 key-wallet-2)) ERR_INVALID_KEY_WALLET)
    (asserts! (not (is-eq key-wallet-1 tx-sender)) ERR_INVALID_KEY_WALLET)
    (asserts! (not (is-eq key-wallet-2 tx-sender)) ERR_INVALID_KEY_WALLET)
    (asserts! (is-none (map-get? bindings tx-sender)) ERR_ALREADY_SECURED)
    (map-set bindings tx-sender {key-wallet-1: key-wallet-1, key-wallet-2: key-wallet-2})
    (print {event: "account-secured", account: tx-sender})
    (ok true)
  )
)

(define-public (reset-bindings (holder principal))
  (let (
    (binding (unwrap! (map-get? bindings holder) ERR_NOT_FOUND))
  )
    (asserts! 
      (or (is-eq tx-sender (get key-wallet-1 binding))
          (is-eq tx-sender (get key-wallet-2 binding)))
      ERR_NOT_AUTHORIZED
    )
    (map-delete bindings holder)
    (print {event: "account-reset-binding", account: holder})
    (ok true)
  )
)

(define-public (safe-fallback (holder principal))
  (let (
    (binding (unwrap! (map-get? bindings holder) ERR_NOT_FOUND))
    (target-wallet (if (is-eq tx-sender (get key-wallet-1 binding))
                      (get key-wallet-2 binding)
                      (get key-wallet-1 binding)))
  )
    (asserts! 
      (or (is-eq tx-sender (get key-wallet-1 binding))
          (is-eq tx-sender (get key-wallet-2 binding)))
      ERR_NOT_AUTHORIZED
    )
    (print {event: "safe-fallback-activated", account: holder, target: target-wallet})
    (ok true)
  )
)

(define-public (allow-transfer (token-id uint) (time uint) (to principal) (any-token bool))
  (let (
    (binding (map-get? bindings tx-sender))
  )
    (if (is-some binding)
      (begin
        (map-set transfer-conditions tx-sender {
          token-id: token-id, 
          time: time, 
          to: to, 
          any-token: any-token
        })
        (print {event: "account-enabled-transfer", account: tx-sender, token-id: token-id, time: time, to: to, any-token: any-token})
        (ok true)
      )
      ERR_NOT_AUTHORIZED
    )
  )
)

(define-public (allow-approval (time uint) (num-transfers uint))
  (let (
    (binding (map-get? bindings tx-sender))
  )
    (if (is-some binding)
      (begin
        (map-set approval-conditions tx-sender {
          time: time, 
          num-transfers: num-transfers
        })
        (print {event: "account-enabled-approval", account: tx-sender, time: time, num-transfers: num-transfers})
        (ok true)
      )
      ERR_NOT_AUTHORIZED
    )
  )
)

(define-read-only (get-bindings (account principal))
  (ok (map-get? bindings account))
)

(define-read-only (get-transfer-conditions (account principal))
  (ok (map-get? transfer-conditions account))
)

(define-read-only (get-approval-conditions (account principal))
  (ok (map-get? approval-conditions account))
)

(define-read-only (is-secure-wallet (account principal))
  (ok (is-some (map-get? bindings account)))
)
