(define-constant ERR_NOT_AUTH (err u900))
(define-constant ERR_PARTICIPANT_NOT_FOUND (err u901))
(define-constant ERR_ALREADY_CLAIMED (err u902))
(define-constant ERR_INVALID_SHARE (err u903))
(define-constant ERR_NO_CURRENT_EPOCH (err u904))
(define-constant ERR_INVALID_EPOCH (err u905))
(define-constant ERR_NO_AVAILABLE_REBATES (err u906))
(define-constant ERR_PARTICIPANT_ALREADY_SET (err u907))
(define-constant ERR_INVALID_PARAMETERS (err u908))
(define-constant ERR_INVALID_BALANCE (err u909))
(define-constant ERR_INSUFFICIENT_BALANCE (err u910))
(define-constant ERR_INVALID_AGGREGATE_SHARE (err u911))
(define-constant ERR_LIST_OVERFLOW (err u912))

(define-constant ONE_HUNDRED_PERCENT u100000000)

;; Admin for managing the rebate contract
(define-data-var admin principal 'SP1W0BTVH2TASXZMG219X3Y6C2BE01KMQ6TT880YF)

;; Create a map to store the epoch info
(define-map epoch-info uint {epoch: uint, rebate-balance: uint, participants: (list 1000 principal)})

;; Complex map to store participant information for each epoch
(define-map epoch-participants-info 
    {epoch: uint, participant: principal}  
    { 
        share: uint, 
        balance: uint,
        claimed: bool,
    }
)

;; ************* Admin Methods *************
;; set admin
(define-public (set-admin (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTH)
        (ok (var-set admin new-admin))
    )
)

;; get admin
(define-read-only (get-admin)
    (ok (var-get admin))
)

;; privileged withdraw
(define-public (withdraw-admin (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTH)
        (as-contract (contract-call? .bsd-mock-vpv-17 transfer amount tx-sender (var-get admin) none))
    )
)

;; ************* Epoch Methods *************

;; get participant info for an epoch and participant
(define-read-only (get-participant-info (epoch uint) (participant principal))
    (ok (unwrap! (map-get? epoch-participants-info {epoch: epoch, participant: participant}) ERR_PARTICIPANT_NOT_FOUND))
)

;; get all participants for an epoch
(define-read-only (get-epoch-info (epoch uint))
    (ok (unwrap! (map-get? epoch-info epoch) ERR_INVALID_EPOCH))
)

;; batch set participant info for an epoch and participants
(define-public (batch-set-participant-info (epoch uint) (rebate-balance uint) (participants (list 100 principal)) (shares (list 100 uint)) (balances (list 100 uint)))
    (let 
        (
            (is-auth (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTH))
            (is-valid-epoch (asserts! (is-eq (contract-call? .registry-vpv-18 get-current-epoch) epoch) ERR_INVALID_EPOCH))
            (is-valid-balance (asserts! (> rebate-balance u0) ERR_NO_AVAILABLE_REBATES))
            (is-sufficient-balance (asserts! (>= (unwrap! (contract-call? .bsd-mock-vpv-17 get-balance (as-contract tx-sender)) ERR_NO_AVAILABLE_REBATES) rebate-balance) ERR_INSUFFICIENT_BALANCE))
            (info (default-to {epoch: epoch, rebate-balance: u0, participants: (list)} (map-get? epoch-info epoch)))
            (current-participants (get participants info))
            (update-response (try! (fold set-participant-info participants (ok {index: u0, current-share: u0, epoch: epoch, shares: shares, balances: balances, participants: current-participants}))))
            (new-participants (get participants update-response))
        )
        (map-set epoch-info epoch {epoch: epoch, rebate-balance: rebate-balance, participants: new-participants})
        (print {batch-set-participant-info-event: {epoch: epoch, rebate-balance: rebate-balance, participants: participants, shares: shares, balances: balances}})
        (ok true)
    )
)

;; set participant info for an epoch and participant
(define-private (set-participant-info (participant principal) (update-response (response { index: uint, current-share: uint, epoch: uint, shares: (list 100 uint), balances: (list 100 uint), participants: (list 1000 principal)} uint)))
    (match update-response
        helper-tuple
            (let 
                (
                    (index (get index helper-tuple))
                    (epoch (get epoch helper-tuple))
                    (current-share (get current-share helper-tuple))
                    (shares (get shares helper-tuple))
                    (share (unwrap-panic (element-at? shares index)))
                    (aggregate-share (+ current-share share))
                    (balances (get balances helper-tuple))
                    (balance (unwrap-panic (element-at? balances index)))
                    (participants (get participants helper-tuple))
                    (new-participants (unwrap! (as-max-len? (append participants participant) u1000) ERR_LIST_OVERFLOW))
                )

                (asserts! (<= aggregate-share ONE_HUNDRED_PERCENT) ERR_INVALID_AGGREGATE_SHARE)
                (asserts! (and (> share u0) (<= share ONE_HUNDRED_PERCENT)) ERR_INVALID_SHARE)
                (asserts! (> balance u0) ERR_INVALID_BALANCE)
                (asserts! (is-none (map-get? epoch-participants-info {epoch: epoch, participant: participant})) ERR_PARTICIPANT_ALREADY_SET)
                (map-set epoch-participants-info {epoch: epoch, participant: participant} {share: share, balance: balance, claimed: false})

                (ok {index: (+ index u1), current-share: aggregate-share, epoch: epoch, shares: shares, balances: balances, participants: new-participants})    
            )
        err-resp
        (err err-resp)
    )
)

;; ************* Participant Methods *************

;; claim rebate
(define-public (claim-rebate (epoch uint))
    (let 
        (
            (participant-info (unwrap! (map-get? epoch-participants-info {epoch: epoch, participant: tx-sender}) ERR_PARTICIPANT_NOT_FOUND))
            (share (get share participant-info))
            (balance (get balance participant-info))
            (claimed (get claimed participant-info))
            (current-epoch (contract-call? .registry-vpv-18 get-current-epoch))
            (total-rebate (get rebate-balance (unwrap! (map-get? epoch-info epoch) ERR_NO_AVAILABLE_REBATES)))
            (rebate-amount (/ (* share total-rebate) ONE_HUNDRED_PERCENT))
			(contract-balance (unwrap! (contract-call? .bsd-mock-vpv-17 get-balance (as-contract tx-sender)) ERR_NO_AVAILABLE_REBATES))
        )

        (asserts! (is-eq epoch current-epoch) ERR_INVALID_EPOCH)
        (asserts! (not claimed) ERR_ALREADY_CLAIMED)
        (asserts! (and (> share u0) (<= share ONE_HUNDRED_PERCENT)) ERR_INVALID_SHARE)
        (asserts! (> rebate-amount u0) ERR_NO_AVAILABLE_REBATES)
		(asserts! (>= contract-balance rebate-amount) ERR_INSUFFICIENT_BALANCE)
        (print 
            {
                claim-rebate-event: {
                    epoch: epoch,
                    participant: tx-sender,
                    share: share,
                    balance: balance,
                    claimed: claimed,
                    current-epoch: current-epoch,
                    total-rebate: total-rebate,
                    rebate-amount: rebate-amount,
                }
            }
        )
        (map-set epoch-participants-info {epoch: epoch, participant: tx-sender} {share: share, balance: balance, claimed: true})
        (try! (contract-call? .bsd-mock-vpv-17 transfer rebate-amount (as-contract tx-sender) tx-sender none))
        (ok true)
    )
)