(impl-trait .sm-dao-traits.proposal-script)

;; Oracle configuration
(define-constant STSTXBTC-FEED-ID 0xec7a775f46379b5e943c3526b1c8d54cd49749176b0b98e02dde68d1bd335c17)
(define-constant MAX-STALENESS u120)

;; Token reference
(define-constant STSTXBTC-TOKEN 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststxbtc-token-v2)

;; Oracle type constant
(define-constant TYPE-PYTH 0x00)

(define-constant CALLCODE-ZSTSTXBTC 0x06)

(define-public (execute)
  (begin
    ;; Update price feed identifier to STX for both stSTXbtc and zstSTXbtc
    (try! (contract-call? .sm-assets update 
      STSTXBTC-TOKEN
      {
        type: TYPE-PYTH,
        ident: STSTXBTC-FEED-ID,
        callcode: none,
        max-staleness: MAX-STALENESS
      }))

    (try! (contract-call? .sm-assets update 
      .sm-vault-ststxbtc
      {
        type: TYPE-PYTH,
        ident: STSTXBTC-FEED-ID,
        callcode: (some CALLCODE-ZSTSTXBTC),
        max-staleness: MAX-STALENESS
      }))
    
    (ok true)))
