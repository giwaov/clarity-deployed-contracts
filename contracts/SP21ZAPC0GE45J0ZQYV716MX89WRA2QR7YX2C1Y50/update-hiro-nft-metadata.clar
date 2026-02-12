(use-trait nft-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

(define-public (update-hiro-api (collection <nft-trait>)) 
    (begin 
    
    (print {
        notification: "token-metadata-update",
        payload: {
            contract-id: (contract-of collection),
            token-class: "nft"
        }
        })
        (ok collection)
    )
)