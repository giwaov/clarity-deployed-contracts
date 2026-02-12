(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.extension-trait.extension-trait)

(define-constant ERR-INVALID-PAYLOAD (err u5001))
(define-constant ERR-INVALID-OPERATION (err u5002))

(define-constant OP-BUY u0)
(define-constant OP-SELL u1)
(define-constant OP-ADD-LIQUIDITY u2)
(define-constant OP-REMOVE-LIQUIDITY u3)

(define-constant OPCODE-BUY (some 0x00))
(define-constant OPCODE-SELL (some 0x01))
(define-constant OPCODE-ADD-LIQ (some 0x02))
(define-constant OPCODE-REMOVE-LIQ (some 0x03))

(define-public (call (payload (buff 2048)))
  (let (
      (decoded (unwrap! (from-consensus-buff? { amount: uint, operation: uint } payload) ERR-INVALID-PAYLOAD))
      (amount (get amount decoded))
      (operation (get operation decoded))
      (opcode (if (is-eq operation OP-BUY)
                  OPCODE-BUY
                  (if (is-eq operation OP-SELL)
                      OPCODE-SELL
                      (if (is-eq operation OP-ADD-LIQUIDITY)
                          OPCODE-ADD-LIQ
                          (if (is-eq operation OP-REMOVE-LIQUIDITY)
                              OPCODE-REMOVE-LIQ
                              none)))))
    )
    (asserts! (is-some opcode) ERR-INVALID-OPERATION)
    (try! (contract-call?
      'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.faktory-core-v2
      execute
      'SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ.pepe-faktory-pool-v2
      amount
      opcode
    ))
    (ok true)
  )
)

(define-read-only (create-payload (amount uint) (operation uint))
  (to-consensus-buff? { amount: amount, operation: operation })
)

(define-read-only (create-buy-payload (amount uint))
  (create-payload amount OP-BUY)
)

(define-read-only (create-sell-payload (amount uint))
  (create-payload amount OP-SELL)
)

(define-read-only (create-add-liquidity-payload (amount uint))
  (create-payload amount OP-ADD-LIQUIDITY)
)

(define-read-only (create-remove-liquidity-payload (amount uint))
  (create-payload amount OP-REMOVE-LIQUIDITY)
)

(define-read-only (get-op-buy) OP-BUY)
(define-read-only (get-op-sell) OP-SELL)
(define-read-only (get-op-add-liquidity) OP-ADD-LIQUIDITY)
(define-read-only (get-op-remove-liquidity) OP-REMOVE-LIQUIDITY)