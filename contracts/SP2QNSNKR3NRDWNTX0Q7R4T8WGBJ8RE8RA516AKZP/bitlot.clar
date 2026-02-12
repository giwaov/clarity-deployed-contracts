
;; title: bitlot
;; summary: A simple lottery/spinner contract
;; description: Allows users to pay to spin and get a random result.

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_TRANSFER_FAILED (err u100))
(define-constant TICKET_PRICE u1000000) ;; 1 STX

;; data vars
(define-data-var total-spins uint u0)

;; public functions
(define-public (play)
    (let
        (
            (sender tx-sender)
            (current-spins (var-get total-spins))
            ;; Simple pseudo-randomness: hash of block-height + sender + nonce
            ;; Note: This is not secure for high-stakes lotteries but sufficient for this demo.
            ;; In production, use Chainlink VRF or Stacks VRF if available/appropriate.
            (random-source (sha256 (unwrap-panic (to-consensus-buff? { height: block-height, player: sender, nonce: current-spins }))))
            (random-val (buff-to-uint-be (unwrap-panic (element-at? random-source u0))))
            ;; Modulo 8 for 8 slots in the spinner
            (result (mod random-val u8))
        )
        ;; Transfer STX from user to contract
        (try! (stx-transfer? TICKET_PRICE sender (as-contract tx-sender)))
        
        ;; Update state
        (var-set total-spins (+ current-spins u1))
        
        ;; Emit event for Chainhook
        (print {
            event: "spin-result",
            player: sender,
            result: result,
            amount: TICKET_PRICE
        })
        
        (ok result)
    )
)

(define-read-only (get-total-spins)
    (ok (var-get total-spins))
)
