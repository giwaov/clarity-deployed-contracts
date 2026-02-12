;; author: eriq.btc
;; description: activate sweep with different tokens and stx in a single tx
;; license MIT

;; This contract use the SIP-010 community-standard Fungible Token trait
(use-trait sip-010-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait) ;; 

;; Marketplace commission trait
(use-trait commission-trait 'SP3D6PV2ACBPEKYJTCMH7HEN02KP87QSP8KTEH335.commission-trait.commission) ;; 
(use-trait commission-ft-trait 'SP39WYZ7BCDD4E7XSKDFVQSERXYTT9MEFE5683JGR.commission-ft-trait.commission-ft) ;; 

;; Helper to loop bulk actions
(define-private (check-err (result (response bool uint)) (prior (response bool uint)))
  (match prior ok-value result err-value (err err-value))
)

;; Errors handling
(define-constant TOO_MANY_LISTINGS (err u1000)) ;; too many listings

;; bulk listing
(define-public (bulk-list 
    (listings (list 100 {
        id: uint, 
        price: uint, 
        commission: <commission-trait>,
        }))
    (listingsFT (list 100 {
        commission: <commission-ft-trait>,
        id: uint, 
        price: uint, 
        token: <sip-010-trait>,
        }))    
        )
        
    (begin 
        (asserts! (<= (+ (len listings) (len listingsFT)) u100) TOO_MANY_LISTINGS)
        (try! (contract-call? 'SP1AQ0YQEXE9VADX3TY7H1K9767ZD1KCPXAD3J489.drone-wars-uaps list-many listings))
        (contract-call? 'SP1AQ0YQEXE9VADX3TY7H1K9767ZD1KCPXAD3J489.drone-wars-uaps list-many-ft listingsFT)
    )
)

(define-public (bulk-buy 
    (listings (list 100 {
        id: uint, 
        commission: <commission-trait>,
        }))
    (listingsFT (list 100 {
        commission: <commission-ft-trait>,
        id: uint, 
        token: <sip-010-trait>,
        }))    
        )
    (begin 
        (asserts! (<= (+ (len listings) (len listingsFT)) u100) TOO_MANY_LISTINGS)
        (try! (contract-call? 'SP1AQ0YQEXE9VADX3TY7H1K9767ZD1KCPXAD3J489.drone-wars-uaps buy-many listings))
        (contract-call? 'SP1AQ0YQEXE9VADX3TY7H1K9767ZD1KCPXAD3J489.drone-wars-uaps buy-many-ft listingsFT)
    )
    
)


