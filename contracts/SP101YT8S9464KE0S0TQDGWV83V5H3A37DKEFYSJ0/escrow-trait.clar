;; escrow-trait.clar
;; Standardized escrow interface for ClearDeal marketplace
;; Implements Clarity 2.0 trait definitions

(define-trait escrow-trait
  (
    ;; Create a new escrow with buyer, seller, amount, and deadline
    (create-escrow (principal principal uint uint) (response uint uint))

    ;; Fund an escrow (buyer deposits funds)
    (fund-escrow (uint) (response bool uint))

    ;; Mark work as delivered by seller
    (mark-delivered (uint (string-ascii 256)) (response bool uint))

    ;; Approve delivery and release funds (buyer action)
    (approve-delivery (uint) (response bool uint))

    ;; Initiate a dispute
    (dispute-escrow (uint (string-ascii 256)) (response bool uint))

    ;; Release funds to seller
    (release-to-seller (uint) (response bool uint))

    ;; Refund funds to buyer
    (refund-to-buyer (uint) (response bool uint))

    ;; Cancel escrow (only if not funded)
    (cancel-escrow (uint) (response bool uint))

    ;; Get escrow details
    (get-escrow-details (uint) (response {
      buyer: principal,
      seller: principal,
      amount: uint,
      status: (string-ascii 20),
      deadline: uint,
      funded-at: (optional uint),
      delivered-at: (optional uint)
    } uint))

    ;; Check if escrow is expired
    (is-expired (uint) (response bool uint))
  )
)
