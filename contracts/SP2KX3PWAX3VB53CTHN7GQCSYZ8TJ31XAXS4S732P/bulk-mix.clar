;; author: eriq.btc
;; description: activate sweep with different tokens and stx in a single tx
;; license MIT

;; This contract use the SIP-010 community-standard Fungible Token trait
(use-trait sip-010-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait) ;; 

;; Helper to loop bulk actions
(define-private (check-err (result (response bool uint)) (prior (response bool uint)))
  (match prior ok-value result err-value (err err-value))
)

;; Marketplace commission trait
(use-trait commission-trait 'SP3D6PV2ACBPEKYJTCMH7HEN02KP87QSP8KTEH335.commission-trait.commission) ;; 
(use-trait market-trait .advanced-market-trait.market-trait)

;; bulk listing
(define-public (bulk-list 
    (listings (list 100 {
        contract: <market-trait>, 
        id: uint, 
        price: uint, 
        commission: <commission-trait>,
        ft: (optional <sip-010-trait>)
        })))
    (fold check-err (map list-single listings) (ok true))
)

;; helper for single list
(define-private (list-single (listing {
        contract: <market-trait>, 
        id: uint, 
        price: uint, 
        commission: <commission-trait>,
        ft: (optional <sip-010-trait>)
        }))
  (let (
    (contract (get contract listing))
    (id (get id listing))
    (price (get price listing))
    (commission (get commission listing))
    (ft (get ft listing))
  )
    (if (is-some ft)
      (contract-call? contract list-in-ft id price commission (unwrap-panic ft))
      (contract-call? contract list-in-ustx id price commission)
    )
  )
)

;; bulk buy
(define-public (bulk-buy 
  (listings (list 100 {
        contract: <market-trait>, 
        id: uint, 
        commission: <commission-trait>,
        ft: (optional <sip-010-trait>)
    })))
  (fold check-err (map buy-single listings) (ok true))
)

;; helper for single buy
(define-private (buy-single (listing {
        contract: <market-trait>, 
        id: uint, 
        commission: <commission-trait>,
        ft: (optional <sip-010-trait>)
        }))
  (let (
    (contract (get contract listing))
    (id (get id listing))
    (commission (get commission listing))
    (ft (get ft listing))
  )
    (if (is-some ft)
      (contract-call? contract buy-in-ft id commission (unwrap-panic ft))
      (contract-call? contract buy-in-ustx id commission)
    )
  )
)


