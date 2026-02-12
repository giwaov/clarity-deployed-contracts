---
title: "Trait flip-core"
draft: true
---
```
;; COIN FLIP GAME (Stable / Clarity 2)
;; Contract Name: flip-core

(define-fungible-token flip-token)

(define-constant ERR-COOLDOWN (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-GAME-FULL (err u102))
(define-constant ERR-TOO-EARLY (err u104))
(define-constant ERR-ALREADY-RESOLVED (err u105))

;; HELPER: Context switching
(define-private (get-vault)
  (as-contract tx-sender)
)

(define-map last-faucet-use principal uint)

(define-public (faucet-mint)
    (let
        (
            (caller tx-sender)
            (last-mint (default-to u0 (map-get? last-faucet-use caller)))
            (current-height block-height)
        )
        (asserts! (> current-height (+ last-mint u10)) ERR-COOLDOWN)
        (try! (ft-mint? flip-token u1000 caller))
        (map-set last-faucet-use caller current-height)
        (ok u1000)
    )
)

(define-map games 
    uint 
    {
        player-1: principal,
        player-2: (optional principal),
        wager: uint,
        state: (string-ascii 10),
        flip-block: uint
    }
)

(define-data-var game-nonce uint u0)

(define-public (create-game (wager-amount uint))
    (let
        (
            (game-id (+ (var-get game-nonce) u1))
            (caller tx-sender)
            (vault (get-vault))
        )
        (try! (ft-transfer? flip-token wager-amount caller vault))

        (map-set games game-id {
            player-1: caller,
            player-2: none,
            wager: wager-amount,
            state: "OPEN",
            flip-block: u0
        })

        (var-set game-nonce game-id)
        (ok game-id)
    )
)

(define-public (join-game (game-id uint))
    (let
        (
            (game (unwrap! (map-get? games game-id) ERR-NOT-FOUND))
            (caller tx-sender)
            (wager (get wager game))
            (vault (get-vault))
        )
        (asserts! (is-eq (get state game) "OPEN") ERR-GAME-FULL)
        (try! (ft-transfer? flip-token wager caller vault))

        (map-set games game-id (merge game {
            player-2: (some caller),
            state: "LOCKED",
            flip-block: (+ block-height u1)
        }))
        
        (ok game-id)
    )
)

(define-public (resolve-game (game-id uint))
    (let
        (
            (game (unwrap! (map-get? games game-id) ERR-NOT-FOUND))
            (flip-height (get flip-block game))
            (p1 (get player-1 game))
            (p2 (unwrap! (get player-2 game) ERR-NOT-FOUND))
            (wager (get wager game))
            (total-pot (+ wager wager))
        )
        (asserts! (is-eq (get state game) "LOCKED") ERR-ALREADY-RESOLVED)
        (asserts! (> block-height flip-height) ERR-TOO-EARLY)

        ;; --- RANDOMNESS LOGIC (Fixed for Strict Typing) ---
        (let
            (
                ;; 1. Get the 32-byte Block Hash
                (block-hash (unwrap-panic (get-block-info? id-header-hash flip-height)))
                
                ;; 2. Slice it to 16 bytes
                (random-slice (unwrap-panic (slice? block-hash u0 u16)))
                
                ;; 3. FORCE the compiler to accept it is 16 bytes using 'as-max-len?'
                ;; We unwrap-panic again because as-max-len? returns an option
                (random-uint (buff-to-uint-be (unwrap-panic (as-max-len? random-slice u16))))
                
                ;; 4. Modulo 2
                (is-heads (is-eq (mod random-uint u2) u0))
            )
            
            (if is-heads
                (try! (as-contract (ft-transfer? flip-token total-pot tx-sender p1)))
                (try! (as-contract (ft-transfer? flip-token total-pot tx-sender p2)))
            )

            (map-set games game-id (merge game { state: "ENDED" }))
            (ok is-heads)
        
        )
    )
)
```
