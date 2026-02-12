;; dispute-resolver-trait.clar
;; Trait for dispute resolution mechanisms
;; Allows pluggable dispute resolution strategies

(define-trait dispute-resolver-trait
  (
    ;; Create a new dispute
    (create-dispute (
      uint
      principal
      principal
      (string-utf8 512)
      uint
    ) (response uint uint))

    ;; Submit evidence to dispute
    (submit-evidence (uint principal (string-ascii 256)) (response bool uint))

    ;; Resolve dispute (arbitrator decision)
    (resolve-dispute (uint (string-ascii 20) (string-utf8 512)) (response bool uint))

    ;; Accept resolution (party accepts outcome)
    (accept-resolution (uint) (response bool uint))

    ;; Appeal resolution
    (appeal-resolution (uint (string-utf8 512)) (response bool uint))

    ;; Get dispute details
    (get-dispute (uint) (response {
      escrow-id: uint,
      initiator: principal,
      respondent: principal,
      reason: (string-utf8 512),
      status: (string-ascii 20),
      resolution: (optional (string-ascii 20)),
      created-at: uint,
      resolved-at: (optional uint)
    } uint))

    ;; Check if dispute is resolved
    (is-resolved (uint) (response bool uint))

    ;; Get resolution outcome (buyer, seller, split)
    (get-resolution-outcome (uint) (response (string-ascii 20) uint))
  )
)
