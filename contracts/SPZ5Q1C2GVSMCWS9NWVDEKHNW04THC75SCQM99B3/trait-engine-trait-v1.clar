(define-trait trait-engine
  (
    (get-full-traits (uint) (response 
      {
        bitsign: (string-ascii 20),
        element: (string-ascii 10),
        energy: (string-ascii 10),
        power-number: uint,
        lucky-sat: uint,
        trait-hash: (buff 32)
      }
      uint
    ))
  )
)