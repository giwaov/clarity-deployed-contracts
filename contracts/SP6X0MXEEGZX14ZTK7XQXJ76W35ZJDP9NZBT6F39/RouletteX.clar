;; ROULETTE-X (Comprehensive Casino Game)
;; Contract Name: roulette-x

(define-fungible-token rlt-token)

;; --- ERROR CODES ---
(define-constant ERR-INSUFFICIENT-FUNDS (err u100))
(define-constant ERR-INVALID-BET-TYPE (err u101))
(define-constant ERR-INVALID-NUMBER (err u102))
(define-constant ERR-GAME-NOT-FOUND (err u103))
(define-constant ERR-TOO-EARLY (err u104))
(define-constant ERR-ALREADY-RESOLVED (err u105))

;; --- CONSTANTS ---
(define-constant PAYOUT-STRAIGHT u36) ;; 35:1 + original wager
(define-constant PAYOUT-COLOR u2)     ;; 1:1 + original wager
(define-constant PAYOUT-DOZEN u3)     ;; 2:1 + original wager

;; --- RED NUMBERS (European Layout) ---
;; Used to determine color logic
(define-constant RED-NUMBERS (list u1 u3 u5 u7 u9 u12 u14 u16 u18 u19 u21 u23 u25 u27 u30 u32 u34 u36))

;; --- FAUCET (Free Chips) ---
(define-public (get-chips)
    (ft-mint? rlt-token u1000 tx-sender)
)

;; --- GAME STORAGE ---
(define-map spins 
    uint 
    {
        player: principal,
        wager: uint,
        bet-type: (string-ascii 20), ;; "STRAIGHT", "RED", "BLACK", "EVEN", "ODD", "1-12", "13-24", "25-36"
        bet-value: uint,             ;; Used only for STRAIGHT bets
        spin-block: uint,
        state: (string-ascii 10)     ;; "OPEN", "CLOSED"
    }
)

(define-data-var spin-nonce uint u0)

;; --- HELPER: IS RED? ---
(define-private (is-red (num uint))
    (is-some (index-of RED-NUMBERS num))
)

;; --- 1. PLACE BET ---
(define-public (place-bet (wager uint) (bet-type (string-ascii 20)) (number-choice uint))
    (let
        (
            (spin-id (+ (var-get spin-nonce) u1))
            (caller tx-sender)
        )
        ;; Validations
        (if (is-eq bet-type "STRAIGHT")
            (asserts! (<= number-choice u36) ERR-INVALID-NUMBER)
            true
        )
        
        ;; Lock Tokens
        (try! (ft-transfer? rlt-token wager caller (as-contract tx-sender)))

        ;; Save Game
        (map-set spins spin-id {
            player: caller,
            wager: wager,
            bet-type: bet-type,
            bet-value: number-choice, ;; Only matters for "STRAIGHT"
            spin-block: (+ block-height u1),
            state: "OPEN"
        })

        (var-set spin-nonce spin-id)
        (ok spin-id)
    )
)

;; --- 2. SPIN THE WHEEL ---
(define-public (spin-wheel (spin-id uint))
    (let
        (
            (game (unwrap! (map-get? spins spin-id) ERR-GAME-NOT-FOUND))
            (target-block (get spin-block game))
            (wager (get wager game))
            (type (get bet-type game))
            (choice (get bet-value game))
        )
        (asserts! (is-eq (get state game) "OPEN") ERR-ALREADY-RESOLVED)
        (asserts! (> block-height target-block) ERR-TOO-EARLY)

        (let
            (
                ;; GENERATE RANDOM NUMBER (0-36)
                (block-hash (unwrap-panic (get-block-info? id-header-hash target-block)))
                (random-slice (unwrap-panic (slice? block-hash u0 u16)))
                (random-uint (buff-to-uint-be (unwrap-panic (as-max-len? random-slice u16))))
                (result (mod random-uint u37))
                
                ;; CALCULATE PAYOUT
                (winnings (calculate-winnings type choice wager result))
            )

            ;; TRANSFER WINNINGS (If any)
            (if (> winnings u0)
                (try! (as-contract (ft-transfer? rlt-token winnings tx-sender (get player game))))
                false
            )

            ;; CLOSE GAME
            (map-set spins spin-id (merge game { state: "CLOSED" }))
            
            ;; Return the Roulette Number so UI knows where ball landed
            (ok result)
        )
    )
)

;; --- WINNING LOGIC ENGINE ---
(define-private (calculate-winnings (type (string-ascii 20)) (choice uint) (wager uint) (result uint))
    (if (is-eq type "STRAIGHT")
        (if (is-eq choice result) (* wager PAYOUT-STRAIGHT) u0)
    
    (if (is-eq type "RED")
        (if (is-red result) (* wager PAYOUT-COLOR) u0)
    
    (if (is-eq type "BLACK")
        ;; Must be NOT Red AND NOT Zero (0 is Green)
        (if (and (not (is-red result)) (not (is-eq result u0))) (* wager PAYOUT-COLOR) u0)

    (if (is-eq type "EVEN")
        ;; Must be Even AND NOT Zero
        (if (and (is-eq (mod result u2) u0) (not (is-eq result u0))) (* wager PAYOUT-COLOR) u0)

    (if (is-eq type "ODD")
        (if (not (is-eq (mod result u2) u0)) (* wager PAYOUT-COLOR) u0)

    (if (is-eq type "1-12")
        (if (and (>= result u1) (<= result u12)) (* wager PAYOUT-DOZEN) u0)

    (if (is-eq type "13-24")
        (if (and (>= result u13) (<= result u24)) (* wager PAYOUT-DOZEN) u0)

    (if (is-eq type "25-36")
        (if (and (>= result u25) (<= result u36)) (* wager PAYOUT-DOZEN) u0)
        
        u0 ;; Invalid Bet Type returns 0
    ))))))))
)