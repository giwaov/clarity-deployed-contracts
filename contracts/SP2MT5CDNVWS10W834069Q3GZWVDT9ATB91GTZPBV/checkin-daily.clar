;; Stacks Checkin Contract
;; Requires 0.1 STX fee to check in
;; Stores checkin data per address

(define-constant CHECKIN_FEE u100000) ;; 0.1 STX in micro-STX (0.1 * 1,000,000)

(define-map checkin-data
  {who: principal}
  {
    last-checkin: uint,
    total-checkins: uint
  }
)

;; Public function to check in
;; The user pays 0.1 STX fee which is transferred to the contract address
(define-public (checkin)
  (let (
        (sender tx-sender)
        (current-block stacks-block-height)
        (existing-data (default-to {last-checkin: u0, total-checkins: u0} (map-get? checkin-data {who: sender})))
       )
    ;; Transfer the fee from the user to the contract
    (try! (stx-transfer? CHECKIN_FEE sender (as-contract tx-sender)))
    
    ;; Store or update checkin data
    (ok (map-set checkin-data 
      {who: sender} 
      {
        last-checkin: current-block,
        total-checkins: (+ (get total-checkins existing-data) u1)
      }
    )))
)

;; Read-only functions to query checkin data
(define-read-only (get-checkin-data (who principal))
  (ok (default-to {last-checkin: u0, total-checkins: u0} (map-get? checkin-data {who: who})))
)

(define-read-only (get-last-checkin (who principal))
  (ok (get last-checkin (default-to {last-checkin: u0, total-checkins: u0} (map-get? checkin-data {who: who}))))
)

(define-read-only (get-total-checkins (who principal))
  (ok (get total-checkins (default-to {last-checkin: u0, total-checkins: u0} (map-get? checkin-data {who: who}))))
)
