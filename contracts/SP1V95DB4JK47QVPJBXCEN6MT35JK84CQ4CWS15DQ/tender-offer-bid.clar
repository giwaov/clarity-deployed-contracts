(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-offer-expired (err u102))
(define-constant err-insufficient-shares (err u103))

(define-map tender-offers
  uint
  {
    acquirer: principal,
    target-company: (string-ascii 128),
    offer-price-per-share: uint,
    total-shares-sought: uint,
    shares-tendered: uint,
    minimum-acceptance: uint,
    offer-expiry: uint,
    premium-percentage: uint,
    status: (string-ascii 32),
    successful: bool
  })

(define-map shareholder-tenders
  {offer-id: uint, shareholder: principal}
  {shares-tendered: uint, accepted: bool, payment-received: bool})

(define-map target-shareholders
  {company: (string-ascii 128), shareholder: principal}
  {total-shares: uint, shares-available: uint})

(define-data-var next-offer-id uint u0)

(define-read-only (get-tender-offer (offer-id uint))
  (ok (map-get? tender-offers offer-id)))

(define-read-only (get-shareholder-tender (offer-id uint) (shareholder principal))
  (ok (map-get? shareholder-tenders {offer-id: offer-id, shareholder: shareholder})))

(define-public (launch-tender-offer (target (string-ascii 128)) (price uint) (total-shares uint) (min-accept uint) (expiry uint) (premium uint))
  (let ((offer-id (var-get next-offer-id)))
    (map-set tender-offers offer-id
      {acquirer: tx-sender, target-company: target, offer-price-per-share: price,
       total-shares-sought: total-shares, shares-tendered: u0, minimum-acceptance: min-accept,
       offer-expiry: (+ stacks-block-height expiry), premium-percentage: premium,
       status: "active", successful: false})
    (var-set next-offer-id (+ offer-id u1))
    (ok offer-id)))

(define-public (tender-shares (offer-id uint) (shares uint))
  (let ((offer (unwrap! (map-get? tender-offers offer-id) err-not-found))
        (holdings (unwrap! (map-get? target-shareholders 
                                    {company: (get target-company offer), shareholder: tx-sender}) 
                           err-not-found)))
    (asserts! (< stacks-block-height (get offer-expiry offer)) err-offer-expired)
    (asserts! (<= shares (get shares-available holdings)) err-insufficient-shares)
    (map-set shareholder-tenders {offer-id: offer-id, shareholder: tx-sender}
      {shares-tendered: shares, accepted: false, payment-received: false})
    (map-set tender-offers offer-id
      (merge offer {shares-tendered: (+ (get shares-tendered offer) shares)}))
    (ok true)))

(define-public (accept-tender (offer-id uint))
  (let ((offer (unwrap! (map-get? tender-offers offer-id) err-not-found))
        (tender (unwrap! (map-get? shareholder-tenders {offer-id: offer-id, shareholder: tx-sender}) err-not-found))
        (payment (* (get shares-tendered tender) (get offer-price-per-share offer))))
    (asserts! (is-eq tx-sender (get acquirer offer)) err-owner-only)
    (try! (stx-transfer? payment (get acquirer offer) tx-sender))
    (ok (map-set shareholder-tenders {offer-id: offer-id, shareholder: tx-sender}
      (merge tender {accepted: true, payment-received: true})))))

(define-public (close-tender-offer (offer-id uint))
  (let ((offer (unwrap! (map-get? tender-offers offer-id) err-not-found))
        (success (>= (get shares-tendered offer) (get minimum-acceptance offer))))
    (asserts! (is-eq tx-sender (get acquirer offer)) err-owner-only)
    (asserts! (>= stacks-block-height (get offer-expiry offer)) err-offer-expired)
    (ok (map-set tender-offers offer-id
      (merge offer {status: "closed", successful: success})))))
