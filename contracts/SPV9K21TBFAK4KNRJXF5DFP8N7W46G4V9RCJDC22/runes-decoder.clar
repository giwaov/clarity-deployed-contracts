;; ============================================================================
;; LEB128 Decoder - With improved Tag 11 (0x0b) handling
;; ============================================================================

(define-constant ERR-LEB128-OUT-OF-BOUNDS u1000)
(define-constant ERR-NOT-A-RUNESTONE u101)
(define-constant ERR-UNSUPPORTED-TAG u102)
(define-constant ERR-WRONG-RUNE u103)
(define-constant ERR-WRONG-OUTPUT u104)

;; Read a single byte as uint8, returning the value and updated offset
(define-read-only (read-byte (data (buff 4096)) (offset uint))
  (if (>= offset (len data))
    (err ERR-LEB128-OUT-OF-BOUNDS)
    (ok {
      byte: (buff-to-uint-le (unwrap-panic (as-max-len?
        (unwrap! (slice? data offset (+ offset u1)) (err ERR-LEB128-OUT-OF-BOUNDS))
        u1
      ))),
      next-offset: (+ offset u1)
    })
  )
)

;; Decode a LEB128 integer
;; Decode a LEB128 integer with support for 5 bytes (larger numbers)
;; Decode a LEB128 integer with support for up to 8 bytes (64-bit numbers)
;; Decode a LEB128 integer with support for up to 16 bytes (128-bit numbers)
(define-read-only (decode-leb128 (data (buff 4096)) (start-offset uint))
  ;; Read first byte
  (let (
      (byte1-result (try! (read-byte data start-offset)))
      (byte1 (get byte byte1-result))
      (offset1 (get next-offset byte1-result))
      (data-bits1 (bit-and byte1 u127))
      (has-more1 (> (bit-and byte1 u128) u0))
    )
    (if (not has-more1)
      (ok { value: data-bits1, next-offset: offset1 })
      
      ;; Read second byte
      (let (
          (byte2-result (try! (read-byte data offset1)))
          (byte2 (get byte byte2-result))
          (offset2 (get next-offset byte2-result))
          (data-bits2 (bit-and byte2 u127))
          (has-more2 (> (bit-and byte2 u128) u0))
          (value12 (+ data-bits1 (* data-bits2 (pow u2 u7))))
        )
        (if (not has-more2)
          (ok { value: value12, next-offset: offset2 })
          
          ;; Read third byte
          (let (
              (byte3-result (try! (read-byte data offset2)))
              (byte3 (get byte byte3-result))
              (offset3 (get next-offset byte3-result))
              (data-bits3 (bit-and byte3 u127))
              (has-more3 (> (bit-and byte3 u128) u0))
              (value123 (+ value12 (* data-bits3 (pow u2 u14))))
            )
            (if (not has-more3)
              (ok { value: value123, next-offset: offset3 })
              
              ;; Read fourth byte
              (let (
                  (byte4-result (try! (read-byte data offset3)))
                  (byte4 (get byte byte4-result))
                  (offset4 (get next-offset byte4-result))
                  (data-bits4 (bit-and byte4 u127))
                  (has-more4 (> (bit-and byte4 u128) u0))
                  (value1234 (+ value123 (* data-bits4 (pow u2 u21))))
                )
                (if (not has-more4)
                  (ok { value: value1234, next-offset: offset4 })
                  
                  ;; Read fifth byte
                  (let (
                      (byte5-result (try! (read-byte data offset4)))
                      (byte5 (get byte byte5-result))
                      (offset5 (get next-offset byte5-result))
                      (data-bits5 (bit-and byte5 u127))
                      (has-more5 (> (bit-and byte5 u128) u0))
                      (value12345 (+ value1234 (* data-bits5 (pow u2 u28))))
                    )
                    (if (not has-more5)
                      (ok { value: value12345, next-offset: offset5 })
                      
                      ;; Read sixth byte
                      (let (
                          (byte6-result (try! (read-byte data offset5)))
                          (byte6 (get byte byte6-result))
                          (offset6 (get next-offset byte6-result))
                          (data-bits6 (bit-and byte6 u127))
                          (has-more6 (> (bit-and byte6 u128) u0))
                          (value123456 (+ value12345 (* data-bits6 (pow u2 u35))))
                        )
                        (if (not has-more6)
                          (ok { value: value123456, next-offset: offset6 })
                          
                          ;; Read seventh byte
                          (let (
                              (byte7-result (try! (read-byte data offset6)))
                              (byte7 (get byte byte7-result))
                              (offset7 (get next-offset byte7-result))
                              (data-bits7 (bit-and byte7 u127))
                              (has-more7 (> (bit-and byte7 u128) u0))
                              (value1234567 (+ value123456 (* data-bits7 (pow u2 u42))))
                            )
                            (if (not has-more7)
                              (ok { value: value1234567, next-offset: offset7 })
                              
                              ;; Read eighth byte
                              (let (
                                  (byte8-result (try! (read-byte data offset7)))
                                  (byte8 (get byte byte8-result))
                                  (offset8 (get next-offset byte8-result))
                                  (data-bits8 (bit-and byte8 u127))
                                  (has-more8 (> (bit-and byte8 u128) u0))
                                  (value12345678 (+ value1234567 (* data-bits8 (pow u2 u49))))
                                )
                                (if (not has-more8)
                                  (ok { value: value12345678, next-offset: offset8 })
                                
                                  ;; Read ninth byte
                                  (let (
                                      (byte9-result (try! (read-byte data offset8)))
                                      (byte9 (get byte byte9-result))
                                      (offset9 (get next-offset byte9-result))
                                      (data-bits9 (bit-and byte9 u127))
                                      (has-more9 (> (bit-and byte9 u128) u0))
                                      (value123456789 (+ value12345678 (* data-bits9 (pow u2 u56))))
                                    )
                                    (if (not has-more9)
                                      (ok { value: value123456789, next-offset: offset9 })
                                    
                                      ;; Read tenth byte
                                      (let (
                                          (byte10-result (try! (read-byte data offset9)))
                                          (byte10 (get byte byte10-result))
                                          (offset10 (get next-offset byte10-result))
                                          (data-bits10 (bit-and byte10 u127))
                                          (has-more10 (> (bit-and byte10 u128) u0))
                                          (value12345678910 (+ value123456789 (* data-bits10 (pow u2 u63))))
                                        )
                                        (if (not has-more10)
                                          (ok { value: value12345678910, next-offset: offset10 })
                                        
                                          ;; Read eleventh byte
                                          (let (
                                              (byte11-result (try! (read-byte data offset10)))
                                              (byte11 (get byte byte11-result))
                                              (offset11 (get next-offset byte11-result))
                                              (data-bits11 (bit-and byte11 u127))
                                              (has-more11 (> (bit-and byte11 u128) u0))
                                              (value1234567891011 (+ value12345678910 (* data-bits11 (pow u2 u70))))
                                            )
                                            (if (not has-more11)
                                              (ok { value: value1234567891011, next-offset: offset11 })
                                            
                                              ;; Read twelfth byte
                                              (let (
                                                  (byte12-result (try! (read-byte data offset11)))
                                                  (byte12 (get byte byte12-result))
                                                  (offset12 (get next-offset byte12-result))
                                                  (data-bits12 (bit-and byte12 u127))
                                                  (has-more12 (> (bit-and byte12 u128) u0))
                                                  (value123456789101112 (+ value1234567891011 (* data-bits12 (pow u2 u77))))
                                                )
                                                (if (not has-more12)
                                                  (ok { value: value123456789101112, next-offset: offset12 })
                                                
                                                  ;; Read thirteenth byte
                                                  (let (
                                                      (byte13-result (try! (read-byte data offset12)))
                                                      (byte13 (get byte byte13-result))
                                                      (offset13 (get next-offset byte13-result))
                                                      (data-bits13 (bit-and byte13 u127))
                                                      (has-more13 (> (bit-and byte13 u128) u0))
                                                      (value12345678910111213 (+ value123456789101112 (* data-bits13 (pow u2 u84))))
                                                    )
                                                    (if (not has-more13)
                                                      (ok { value: value12345678910111213, next-offset: offset13 })
                                                    
                                                      ;; Read fourteenth byte
                                                      (let (
                                                          (byte14-result (try! (read-byte data offset13)))
                                                          (byte14 (get byte byte14-result))
                                                          (offset14 (get next-offset byte14-result))
                                                          (data-bits14 (bit-and byte14 u127))
                                                          (has-more14 (> (bit-and byte14 u128) u0))
                                                          (value1234567891011121314 (+ value12345678910111213 (* data-bits14 (pow u2 u91))))
                                                        )
                                                        (if (not has-more14)
                                                          (ok { value: value1234567891011121314, next-offset: offset14 })
                                                        
                                                          ;; Read fifteenth byte
                                                          (let (
                                                              (byte15-result (try! (read-byte data offset14)))
                                                              (byte15 (get byte byte15-result))
                                                              (offset15 (get next-offset byte15-result))
                                                              (data-bits15 (bit-and byte15 u127))
                                                              (has-more15 (> (bit-and byte15 u128) u0))
                                                              (value123456789101112131415 (+ value1234567891011121314 (* data-bits15 (pow u2 u98))))
                                                            )
                                                            (if (not has-more15)
                                                              (ok { value: value123456789101112131415, next-offset: offset15 })
                                                            
                                                              ;; Read sixteenth byte
                                                              (let (
                                                                  (byte16-result (try! (read-byte data offset15)))
                                                                  (byte16 (get byte byte16-result))
                                                                  (offset16 (get next-offset byte16-result))
                                                                  (data-bits16 (bit-and byte16 u127))
                                                                  (value12345678910111213141516 (+ value123456789101112131415 (* data-bits16 (pow u2 u105))))
                                                                )
                                                                ;; Sixteen byte value (max 128-bit unsigned integer)
                                                                (ok { value: value12345678910111213141516, next-offset: offset16 })
                                                              )
                                                            )
                                                          )
                                                        )
                                                      )
                                                    )
                                                  )
                                                )
                                              )
                                            )
                                          )
                                        )
                                      )
                                    )
                                  )
                                )
                              )
                            )
                          )
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

;; Check if a buffer starts with OP_RETURN (0x6a) + OP_13 (0x5d)
(define-read-only (is-runestone (script (buff 1376)))
  (and
    (>= (len script) u3)
    (is-eq (unwrap! (element-at script u0) false) 0x6a)
    (is-eq (unwrap! (element-at script u1) false) 0x5d)
  )
)

;; Parse Tag 11 (0x0b) transfer operation
(define-read-only (parse-tag11-transfer
    (script (buff 1376))
    (start-offset uint)
    (expected-rune-id uint)
    (expected-output uint)
  )
  ;; For Tag 11, format is: [Rune ID] [Amount] [Output]
  ;; Parse Rune ID (param1)
  (let (
      (id-result (try! (decode-leb128 script start-offset)))
      (rune-id (get value id-result))
      (offset1 (get next-offset id-result))
    )
    (print { msg: "Tag 11 Rune ID parsed", rune-id: rune-id, expected-rune-id: expected-rune-id })
    
    ;; Verify Rune ID matches expected
    (if (not (is-eq rune-id expected-rune-id))
      (err ERR-WRONG-RUNE)
      
      ;; Attempt to find the amount by reading to the end except last byte
      ;; This is a simplification - in reality we'd need a more complex decoder
      ;; to find the exact amount field in the complex middle section
      (let (
          (remaining-data (- (len script) offset1))
          ;; Assuming the output is the last byte
          (output-offset (- (len script) u1))
          (output-result (try! (decode-leb128 script output-offset)))
          (output (get value output-result))
          
          ;; Read as much data as possible for the amount (complex middle section)
          ;; For real implementation, this would need to be refined
          (amount-offset offset1)
          (amount-result (try! (decode-leb128 script amount-offset)))
          (amount (get value amount-result))
        )
        (print {
          msg: "Tag 11 transfer parsed",
          rune-id: rune-id,
          amount: amount,
          output: output,
          expected-output: expected-output
        })
        
        ;; Verify output matches expected
        (if (not (is-eq output expected-output))
          (err ERR-WRONG-OUTPUT)
          
          ;; Return the amount
          (ok amount)
        )
      )
    )
  )
)

(define-read-only (parse-tag22-transfer
    (script (buff 1376))
    (start-offset uint)
    (expected-rune-block uint)
    (expected-rune-tx uint)
    (expected-output uint)
  )
  ;; Parse protocol params 1 and 2
  (let (
      (param1-result (try! (decode-leb128 script start-offset)))
      (param1 (get value param1-result))
      (offset1 (get next-offset param1-result))
      
      (param2-result (try! (decode-leb128 script offset1)))
      (param2 (get value param2-result))
      (offset2 (get next-offset param2-result))
      
      ;; Parse the Rune block and tx index
      (block-result (try! (decode-leb128 script offset2)))
      (rune-block (get value block-result))
      (offset3 (get next-offset block-result))
      
      (tx-result (try! (decode-leb128 script offset3)))
      (rune-tx (get value tx-result))
      (offset4 (get next-offset tx-result))
      
      ;; Parse amount (param5)
      (amount-result (try! (decode-leb128 script offset4)))
      (amount (get value amount-result))
      (offset5 (get next-offset amount-result))
      
      ;; Parse the output index (last byte)
      (output-offset (- (len script) u1))
      (output-result (try! (decode-leb128 script output-offset)))
      (output (get value output-result))
    )
    
    (print { 
      msg: "Tag 22 transfer decoded", 
      protocol_param1: param1, 
      protocol_param2: param2, 
      rune_block: rune-block, 
      expected_block: expected-rune-block,
      rune_tx: rune-tx,
      expected_tx: expected-rune-tx,
      amount: amount,
      output: output,
      expected_output: expected-output
    })
    
    ;; Verify Rune block and tx match expected
    (if (or 
          (not (is-eq rune-block expected-rune-block))
          (not (is-eq rune-tx expected-rune-tx))
        )
      (err ERR-WRONG-RUNE)
      
      ;; Verify output matches expected
      (if (not (is-eq output expected-output))
        (err ERR-WRONG-OUTPUT)
        
        ;; Return the amount to match other functions' return types
        (ok amount)
      )
    )
  )
)

(define-read-only (parse-xverse-transfer (script (buff 1376)) (expected-output uint))
  (if (not (is-runestone script))
    (err ERR-NOT-A-RUNESTONE)
    
    (let (
        (tag-result (try! (decode-leb128 script u3)))
        (tag (get value tag-result))
      )
      (if (not (is-eq tag u22))
        (err ERR-UNSUPPORTED-TAG)
        
        ;; For Xverse transactions, decode the structure
        (let (
            (offset1 (get next-offset tag-result))
            (rune-block-result (try! (decode-leb128 script offset1)))
            (rune-block (get value rune-block-result))
            (offset2 (get next-offset rune-block-result))
            
            (rune-tx-result (try! (decode-leb128 script offset2)))
            (rune-tx (get value rune-tx-result))
            (offset3 (get next-offset rune-tx-result))
            
            ;; Parse parameters for amount calculation
            (amount-p1-result (try! (decode-leb128 script offset3)))
            (amount-p1 (get value amount-p1-result))
            (offset4 (get next-offset amount-p1-result))
            
            ;; Use a combined formula based on the specific LEB128 encoding pattern
            ;; This formula will need adjustment based on actual encoding
            (amount (* amount-p1 u256))
            
            ;; Check output (last byte)
            (output-offset (- (len script) u1))
            (output-result (try! (decode-leb128 script output-offset)))
            (output (get value output-result))
          )
          
          (print {
            msg: "Xverse transfer",
            rune-block: rune-block,
            rune-tx: rune-tx,
            amount: amount,
            output: output
          })
          
          (if (not (is-eq output expected-output))
            (err ERR-WRONG-OUTPUT)
            (ok {
              rune-block: rune-block,
              rune-tx: rune-tx,
              amount: amount,
              output: output
            })
          )
        )
      )
    )
  )
)

(define-read-only (extract-tag22-amount (script (buff 1376)))
  (if (not (is-runestone script))
    (err ERR-NOT-A-RUNESTONE)
    
    (let (
        (tag-result (try! (decode-leb128 script u3)))
        (tag (get value tag-result))
      )
      (if (not (is-eq tag u22))
        (err ERR-UNSUPPORTED-TAG)
        
        ;; For Xverse transactions (6a5d160200f7a538c60a80e8922601)
        (let (
            (offset1 (get next-offset tag-result))
            (param1-result (try! (decode-leb128 script offset1)))
            (offset2 (get next-offset param1-result))
            (param2-result (try! (decode-leb128 script offset2)))
            (offset3 (get next-offset param2-result))
            (param3-result (try! (decode-leb128 script offset3)))
            (offset4 (get next-offset param3-result))
          )
          ;; Try to parse the amount parameter
          (if (>= (len script) offset4)
            (match (decode-leb128 script offset4)
              success (ok (get value success))
              error (err u1005) ;; Error reading amount
            )
            (err u1006) ;; Not enough data for amount
          )
        )
      )
    )
  )
)

;; Parse a Runes transfer from scriptPubKey - supports both Tag 0 and Tag 11 (0x0b)
(define-read-only (parse-runes-transfer 
    (script (buff 1376))
    (expected-rune-block uint)
    (expected-rune-tx uint)
    (expected-output uint)
  )
  ;; Check for OP_RETURN (0x6a) + OP_13 (0x5d)
  (if (not (is-runestone script))
    (err ERR-NOT-A-RUNESTONE) ;; Not a runestone
    
    ;; Parse the tag
    (let (
        (tag-result (try! (decode-leb128 script u3)))
        (tag (get value tag-result))
        (next-offset (get next-offset tag-result))
      )
      (print { msg: "Tag parsed", tag: tag, next-offset: next-offset })
      
      ;; Handle different tag types using if/else instead of cond
      (if (is-eq tag u0)
        ;; Tag 0 (standard edict/transfer)
        (let (
            (block-result (try! (decode-leb128 script next-offset)))
            (rune-block (get value block-result))
            (next-offset2 (get next-offset block-result))
          )
          (print { msg: "Block parsed", rune-block: rune-block, expected-block: expected-rune-block, next-offset: next-offset2 })
          
          ;; Verify block matches expected
          (if (not (is-eq rune-block expected-rune-block))
            (err ERR-WRONG-RUNE)
            
            ;; Parse tx index
            (let (
                (tx-result (try! (decode-leb128 script next-offset2)))
                (rune-tx (get value tx-result))
                (next-offset3 (get next-offset tx-result))
              )
              (print { msg: "TX parsed", rune-tx: rune-tx, expected-tx: expected-rune-tx, next-offset: next-offset3 })
              
              ;; Verify tx index matches expected
              (if (not (is-eq rune-tx expected-rune-tx))
                (err ERR-WRONG-RUNE)
                
                ;; Parse amount
                (let (
                    (amount-result (try! (decode-leb128 script next-offset3)))
                    (amount (get value amount-result))
                    (next-offset4 (get next-offset amount-result))
                  )
                  (print { msg: "Amount parsed", amount: amount, next-offset: next-offset4 })
                  
                  ;; Parse output
                  (let (
                      (output-result (try! (decode-leb128 script next-offset4)))
                      (output (get value output-result))
                    )
                    (print { msg: "Output parsed", output: output, expected-output: expected-output })
                    
                    ;; Verify output matches expected
                    (if (not (is-eq output expected-output))
                      (err ERR-WRONG-OUTPUT)
                      
                      ;; Return the amount
                      (ok amount)
                    )
                  )
                )
              )
            )
          )
        )
        
        ;; Check if it's Tag 11
        (if (is-eq tag u11)
          ;; Tag 11 (0x0b) specialized transfer
          ;; For Tag 11, expected_rune_block is treated as the Rune ID directly
          (parse-tag22-transfer script next-offset expected-rune-block expected-rune-tx expected-output)
          
          ;; Check if it's Tag 22
          (if (is-eq tag u22) ;; Decimal 22 (0x16)
            ;; Add Tag 22 parsing similar to Tag 11
            (parse-tag22-transfer script next-offset expected-rune-block expected-rune-tx expected-output)

            ;; Unsupported tag
            (err ERR-UNSUPPORTED-TAG))
        )
      )
    )
  )
)

;; Extract the amount from a Tag 11 transfer - specialized function for Magic Eden style transactions
(define-read-only (extract-tag11-amount (script (buff 1376)))
  (if (not (is-runestone script))
    (err ERR-NOT-A-RUNESTONE)
    
    (let (
        (tag-result (try! (decode-leb128 script u3)))
        (tag (get value tag-result))
      )
      (if (not (is-eq tag u11))
        (err ERR-UNSUPPORTED-TAG)
        
        ;; For Magic Eden transactions (6a5d0b00caa2338b0788e0ea0101),
        ;; param4 contains the amount (u3846152)
        (let (
            (offset1 (get next-offset tag-result))
            (param1-result (try! (decode-leb128 script offset1)))
            (offset2 (get next-offset param1-result))
            (param2-result (try! (decode-leb128 script offset2)))
            (offset3 (get next-offset param2-result))
            (param3-result (try! (decode-leb128 script offset3)))
            (offset4 (get next-offset param3-result))
          )
          ;; Try to read param4 if it exists - this should be the amount
          (if (>= (len script) offset4)
            (match (decode-leb128 script offset4)
              success (ok (get value success))
              error (err u1005) ;; Error reading amount
            )
            (err u1006) ;; Not enough data for param4
          )
        )
      )
    )
  )
)

;; Test function to decode any runestone regardless of tag
(define-read-only (decode-any-runestone (script (buff 1376)))
  (if (not (is-runestone script))
    (err ERR-NOT-A-RUNESTONE)
    
    (let (
        ;; Parse tag
        (tag-result (try! (decode-leb128 script u3)))
        (tag (get value tag-result))
        (next-offset1 (get next-offset tag-result))
        
        ;; Parse first parameter
        (param1-result (try! (decode-leb128 script next-offset1)))
        (param1 (get value param1-result))
        (next-offset2 (get next-offset param1-result))
        
        ;; Parse second parameter
        (param2-result (try! (decode-leb128 script next-offset2)))
        (param2 (get value param2-result))
        (next-offset3 (get next-offset param2-result))
        
        ;; Parse third parameter
        (param3-result (try! (decode-leb128 script next-offset3)))
        (param3 (get value param3-result))
        (next-offset4 (get next-offset param3-result))
        
        ;; Try to parse fourth parameter if it exists
        (param4-maybe (if (>= (len script) next-offset4)
                   (match (decode-leb128 script next-offset4)
                     success (some { value: (get value success), offset: (get next-offset success) })
                     error none)
                   none))
        (param4 (match param4-maybe some-val (some (get value some-val)) none))
        (next-offset5 (match param4-maybe some-val (get offset some-val) next-offset4))
        
        ;; Try to parse fifth parameter if it exists
        (param5-maybe (if (>= (len script) next-offset5)
                   (match (decode-leb128 script next-offset5)
                     success (some { value: (get value success), offset: (get next-offset success) })
                     error none)
                   none))
        (param5 (match param5-maybe some-val (some (get value some-val)) none))
        (next-offset6 (match param5-maybe some-val (get offset some-val) next-offset5))
        
        ;; Try to parse sixth parameter if it exists
        (param6 (if (>= (len script) next-offset6)
                   (match (decode-leb128 script next-offset6)
                     success (some (get value success))
                     error none)
                   none))
      )
      
      (ok {
        tag: tag,
        pointer-output: (if (is-eq tag u22) (some param1) none),
        edict-tag: (if (is-eq tag u22) (some param2) none),
        rune-block: (if (is-eq tag u22) param3 param1),
        rune-tx: (if (is-eq tag u22) (default-to u0 param4) param2),
        amount: (if (is-eq tag u22) (default-to u0 param5) param3),
        edict-output: (if (is-eq tag u22) param6 param4)
      })
    )
  )
)

;; Check if a script is a valid runestone and determine its tag
(define-read-only (get-runestone-tag (script (buff 1376)))
  (if (not (is-runestone script))
    (err ERR-NOT-A-RUNESTONE)
    
    (match (decode-leb128 script u3)
      success (ok (get value success))
      error (err error)
    )
  )
)

;; Test function specifically for Magic Eden transactions
;; This handles the format 6a5d0b00caa2338b0788e0ea0101
(define-read-only (parse-magic-eden-transfer (script (buff 1376)) (expected-output uint))
  (if (not (is-runestone script))
    (err ERR-NOT-A-RUNESTONE)
    
    (let (
        (tag-result (try! (decode-leb128 script u3)))
        (tag (get value tag-result))
      )
      (if (not (is-eq tag u11))
        (err ERR-UNSUPPORTED-TAG)
        
        ;; For Magic Eden transactions, extract param1 (Rune ID) and param4 (amount)
        (let (
            (offset1 (get next-offset tag-result))
            (id-result (try! (decode-leb128 script offset1)))
            (rune-id (get value id-result))
            
            ;; Extract amount (param4)
            (amount-result (try! (extract-tag11-amount script)))
            (amount amount-result)
            
            ;; Check output (last byte)
            (output-offset (- (len script) u1))
            (output-result (try! (decode-leb128 script output-offset)))
            (output (get value output-result))
          )
          
          (print {
            msg: "Magic Eden transfer",
            rune-id: rune-id,
            amount: amount,
            output: output
          })
          
          (if (not (is-eq output expected-output))
            (err ERR-WRONG-OUTPUT)
            (ok {
              rune-id: rune-id,
              amount: amount,
              output: output
            })
          )
        )
      )
    )
  )
)

(define-read-only (decode-amount-from-tag22 (script (buff 1376)))
     ;; Skip tag and first 4 parameters to get to where the amount should be
     (let (
         (tag-result (try! (decode-leb128 script u3)))
         (offset1 (get next-offset tag-result))
         (param1-result (try! (decode-leb128 script offset1)))
         (offset2 (get next-offset param1-result))
         (param2-result (try! (decode-leb128 script offset2)))
         (offset3 (get next-offset param2-result))
         (param3-result (try! (decode-leb128 script offset3)))
         (offset4 (get next-offset param3-result))
         (param4-result (try! (decode-leb128 script offset4)))
         (offset5 (get next-offset param4-result))
       )
       ;; Try to decode remaining bytes as amount
       (if (>= (len script) offset5)
         (match (decode-leb128 script offset5)
           success (ok (get value success))
           error (err u1005))
         (err u1006))
     )
   )

   (define-read-only (extract-raw-bytes (script (buff 1376)) (start uint) (end uint))
     (if (or (>= start (len script)) (> end (len script)) (> start end))
       (err u1000)
       (ok (unwrap! (slice? script start end) (err u1000)))
     )
   )

   (define-read-only (parse-xverse-transfer-full (script (buff 1376)))
  (if (not (is-runestone script))
    (err ERR-NOT-A-RUNESTONE)
    
    (let (
        (tag-result (try! (decode-leb128 script u3)))
        (tag (get value tag-result))
      )
      (if (not (is-eq tag u22))
        (err ERR-UNSUPPORTED-TAG)
        
        ;; For Xverse transactions, decode all parameters
        (let (
            (offset1 (get next-offset tag-result))
            (param1-result (try! (decode-leb128 script offset1)))
            (param1 (get value param1-result))
            (offset2 (get next-offset param1-result))
            
            (param2-result (try! (decode-leb128 script offset2)))
            (param2 (get value param2-result))
            (offset3 (get next-offset param2-result))
            
            (rune-block-result (try! (decode-leb128 script offset3)))
            (rune-block (get value rune-block-result))
            (offset4 (get next-offset rune-block-result))
            
            (rune-tx-result (try! (decode-leb128 script offset4)))
            (rune-tx (get value rune-tx-result))
            (offset5 (get next-offset rune-tx-result))
            
            (amount-result (try! (decode-leb128 script offset5)))
            (amount (get value amount-result))
            
            ;; Check output (last byte)
            (output-offset (- (len script) u1))
            (output-result (try! (decode-leb128 script output-offset)))
            (output (get value output-result))
          )
          
          (ok {
            protocol_param1: param1,
            protocol_param2: param2,
            rune_block: rune-block,
            rune_tx: rune-tx,
            amount: amount,
            output: output
          })
        )
      )
    )
  )
)