;; service-agreement-trait.clar
;; Trait for service agreement management in ClearDeal
;; Defines standard interface for service terms and lifecycle

(define-trait service-agreement-trait
  (
    ;; Create a new service agreement
    (create-agreement (
      principal
      principal
      (string-utf8 256)
      uint
      uint
      uint
    ) (response uint uint))

    ;; Accept agreement (buyer accepts terms)
    (accept-agreement (uint) (response bool uint))

    ;; Start work on agreement
    (start-work (uint) (response bool uint))

    ;; Submit deliverable
    (submit-deliverable (uint (string-ascii 256)) (response bool uint))

    ;; Request revision
    (request-revision (uint (string-utf8 512)) (response bool uint))

    ;; Complete agreement
    (complete-agreement (uint) (response bool uint))

    ;; Cancel agreement
    (cancel-agreement (uint (string-utf8 256)) (response bool uint))

    ;; Get agreement details
    (get-agreement (uint) (response {
      seller: principal,
      buyer: (optional principal),
      title: (string-utf8 256),
      price: uint,
      deadline: uint,
      revisions-allowed: uint,
      revisions-used: uint,
      status: (string-ascii 20),
      created-at: uint
    } uint))

    ;; Check if agreement is active
    (is-active (uint) (response bool uint))
  )
)
