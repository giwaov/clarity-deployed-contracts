;; NFT Rental Contract
;; Rent out NFTs for a specified duration

(define-constant err-not-owner (err u100))
(define-constant err-not-available (err u101))
(define-constant err-rental-active (err u102))
(define-constant err-rental-expired (err u103))

(define-data-var rental-nonce uint u0)

(define-map rentals
    uint
    {
        nft-contract: principal,
        token-id: uint,
        owner: principal,
        renter: (optional principal),
        price-per-block: uint,
        min-duration: uint,
        max-duration: uint,
        rental-start: (optional uint),
        rental-end: (optional uint),
        active: bool
    }
)

(define-public (list-for-rent
    (nft-contract principal)
    (token-id uint)
    (price-per-block uint)
    (min-duration uint)
    (max-duration uint))
    (let ((rental-id (var-get rental-nonce)))
        (map-set rentals rental-id {
            nft-contract: nft-contract,
            token-id: token-id,
            owner: tx-sender,
            renter: none,
            price-per-block: price-per-block,
            min-duration: min-duration,
            max-duration: max-duration,
            rental-start: none,
            rental-end: none,
            active: true
        })
        (var-set rental-nonce (+ rental-id u1))
        (ok rental-id)
    )
)

(define-public (rent-nft (rental-id uint) (duration uint))
    (let
        (
            (rental (unwrap! (map-get? rentals rental-id) err-not-available))
            (rental-cost (* (get price-per-block rental) duration))
            (rental-end (+ block-height duration))
        )
        (asserts! (get active rental) err-not-available)
        (asserts! (is-none (get renter rental)) err-rental-active)
        (asserts! (>= duration (get min-duration rental)) err-not-available)
        (asserts! (<= duration (get max-duration rental)) err-not-available)
        
        (try! (stx-transfer? rental-cost tx-sender (get owner rental)))
        
        (map-set rentals rental-id (merge rental {
            renter: (some tx-sender),
            rental-start: (some block-height),
            rental-end: (some rental-end)
        }))
        (ok rental-end)
    )
)

(define-public (return-nft (rental-id uint))
    (let ((rental (unwrap! (map-get? rentals rental-id) err-not-available)))
        (asserts! (is-eq (some tx-sender) (get renter rental)) err-not-owner)
        (map-set rentals rental-id (merge rental {
            renter: none,
            rental-start: none,
            rental-end: none
        }))
        (ok true)
    )
)

(define-read-only (get-rental (rental-id uint))
    (map-get? rentals rental-id)
)

(define-read-only (is-rental-active (rental-id uint))
    (match (map-get? rentals rental-id)
        rental (match (get rental-end rental)
            end-block (> end-block block-height)
            false)
        false)
)
