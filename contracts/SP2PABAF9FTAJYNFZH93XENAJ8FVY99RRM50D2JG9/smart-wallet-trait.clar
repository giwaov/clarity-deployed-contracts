;; title: smart-wallet-trait
;; version:
;; summary:
;; description:

(use-trait extension-trait .extension-trait.extension-trait)

(define-trait smart-wallet-trait (
  (extension-call
    (
      ;; Extension contract.
      <extension-trait>
      ;; Serialized extension call payload.
      (buff 2048)
      ;; Optional signature authentication tuple.
      (optional {
      auth-id: uint,
      signature: (buff 64),
      pubkey: (buff 33),
    })
    )
    (response bool uint)
  )
))
