(define-trait treasury-trait
  (
    (execute-stx-transfer (uint principal) (response bool uint))
    (execute-ft-transfer (principal uint principal (optional (buff 34))) (response bool uint))
  )
)
