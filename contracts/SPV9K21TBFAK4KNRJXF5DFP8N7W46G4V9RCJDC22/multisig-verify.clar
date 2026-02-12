;; multisig-verify.clar
;; A contract for verifying both P2SH and P2WSH Bitcoin multisig addresses
;; by calling the existing sbtc-bootstrap-signers contract

;; Error codes
(define-constant ERR-INVALID-PUBKEY u1)
(define-constant ERR-INVALID-SIG-THRESHOLD u2)
(define-constant ERR-TOO-MANY-PUBKEYS u3)
(define-constant ERR-TOO-FEW-PUBKEYS u4)
(define-constant ERR-INVALID-SCRIPT u5)

;; Bitcoin script constants
(define-constant OP-0 0x00)
(define-constant OP-HASH160 0xa9)
(define-constant OP-EQUAL 0x87)
(define-constant PUSH-20 0x14)  ;; Push 20 bytes onto the stack
(define-constant PUSH-32 0x20)  ;; Push 32 bytes onto the stack

;; Create P2SH scriptPubKey from a script hash
;; Format: OP_HASH160 <20-byte-hash> OP_EQUAL
(define-read-only (script-hash-to-p2sh (script-hash (buff 20)))
  (concat 
    (concat 
      (concat 
        OP-HASH160 
        PUSH-20
      )
      script-hash
    )
    OP-EQUAL
  )
)

;; Create P2WSH scriptPubKey from a witness program
;; Format: 0 <32-byte-hash>
(define-read-only (witness-program-to-p2wsh (witness-program (buff 32)))
  (concat 
    OP-0
    (concat 
      PUSH-32
      witness-program
    )
  )
)

;; Verify a Legacy P2SH multisig address (starting with '3')
(define-read-only (verify-p2sh-multisig
    (pubkeys (list 128 (buff 33)))
    (m uint)
    (script-pub-key (buff 23))
  )
  (let (
      ;; Get the script hash using the sBTC bootstrap signers contract
      (script-hash (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-bootstrap-signers pubkeys-to-hash pubkeys m))
      ;; Create the expected P2SH script
      (expected-script-pub-key (script-hash-to-p2sh script-hash))
    )
    ;; Compare with the provided script
    (ok (is-eq script-pub-key expected-script-pub-key))
  )
)

;; Verify a SegWit P2WSH multisig address (starting with 'bc1q')
(define-read-only (verify-p2wsh-multisig
    (pubkeys (list 128 (buff 33)))
    (m uint)
    (script-pub-key (buff 34))  ;; P2WSH is 34 bytes: 0x0020 + 32-byte SHA256 hash
  )
  (let (
      ;; First get the redeem script
      (redeem-script (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-bootstrap-signers pubkeys-to-spend-script pubkeys m))
      ;; For P2WSH, hash the redeem script with SHA256 (not HASH160)
      (witness-program (sha256 redeem-script))
      ;; Create the expected P2WSH script
      (expected-script-pub-key (witness-program-to-p2wsh witness-program))
    )
    ;; Compare with the provided script
    (ok (is-eq script-pub-key expected-script-pub-key))
  )
)

;; Main verification function that handles both P2SH and P2WSH addresses
(define-public (verify-multisig-address
    (pubkeys (list 128 (buff 33)))
    (m uint)
    (is-segwit bool)  
    (script-pub-key (optional (buff 34)))  ;; Optional buffer for flexibility
  )
  (if is-segwit
      ;; For SegWit P2WSH addresses (34 bytes)
      (verify-p2wsh-multisig pubkeys m 
        (default-to 
          (witness-program-to-p2wsh (sha256 (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-bootstrap-signers pubkeys-to-spend-script pubkeys m)))
          script-pub-key
        )
      )
      ;; For Legacy P2SH addresses (23 bytes)
      (verify-p2sh-multisig pubkeys m 
        (unwrap-panic (as-max-len? 
          (default-to 
            (script-hash-to-p2sh (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-bootstrap-signers pubkeys-to-hash pubkeys m))
            script-pub-key
          )
          u23
        ))
      )
  )
)

;; Helper function to detect address type from scriptPubKey length
(define-read-only (is-segwit-script (script-pub-key (buff 34)))
  ;; P2WSH is 34 bytes, P2SH is 23 bytes
  (is-eq (len script-pub-key) u34)
)

;; Auto-detect the address type and verify if it matches the expected pubkeys
(define-public (generate-and-verify-p2sh
    (pubkeys (list 128 (buff 33)))
    (m uint)
  )
  (ok (script-hash-to-p2sh 
    (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-bootstrap-signers pubkeys-to-hash pubkeys m)
  ))
)

;; Generate and return a P2WSH scriptPubKey for given pubkeys
(define-public (generate-and-verify-p2wsh
    (pubkeys (list 128 (buff 33)))
    (m uint)
  )
  (ok (witness-program-to-p2wsh 
    (sha256 (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-bootstrap-signers pubkeys-to-spend-script pubkeys m))
  ))
)


;; (define-read-only (btc-to-stx (input (string-ascii 60)))
;;   (let (
;;     ;; Decode base58 string to numbers
;;     (b58-numbers (map unwrap-uint (filter is-some-uint (map b58-to-uint input))))
;;     ;; Validate all characters are valid base58
;;     (t1 (asserts! (>= (len b58-numbers) (len input)) ERR_INVALID_CHAR))
;;     ;; Count leading '1's (zeros in base58)
;;     (leading-ones-count (default-to (len input) (index-of? (map is-zero b58-numbers) false)))
;;     ;; Convert to bytes
;;     (decoded (concat (fold decode-outer to-decode LST) leading-zeros))
;;     (decoded-hex (fold to-hex-rev decoded 0x))
;;     ;; Verify checksum
;;     (actual-checksum (unwrap-panic (slice? (sha256 (sha256 (unwrap-panic (slice? decoded-hex u0 (- decoded-hex-len u4))))) u0 u4)))
;;     (expected-checksum (unwrap-panic (slice? decoded-hex (- decoded-hex-len u4) decoded-hex-len)))
;;     (t3 (asserts! (is-eq actual-checksum expected-checksum) ERR_BAD_CHECKSUM))
;;     ;; Extract version and construct principal
;;     (version (unwrap-panic (element-at? STX_VER (unwrap! (index-of? BTC_VER (unwrap-panic (element-at? decoded-hex u0))) ERR_INVALID_VERSION))))
;;     )
;;     (principal-construct? version (unwrap-panic (as-max-len? (unwrap-panic (slice? decoded-hex u1 (- decoded-hex-len u4))) u20)))
;;   )
;; )


(define-public (verify-user-in-multisig
    (multisig-script-pub-key (buff 34))
    (pubkeys (list 128 (buff 33)))
    (m uint)
  )
  (let (
      ;; Get the pubkey hash directly from tx-sender (user's Stacks address)
      ;; (user-pubkey-hash (get hash-bytes (unwrap-panic (principal-destruct? tx-sender))))
      ;; perhaps use a helper var instead of defining it in checkpubkey
      
      ;; Check if any pubkey in the multisig list hashes to the user's pubkey hash
      (user-is-signer (fold check-pubkey pubkeys false))
      
      ;; Verify the multisig itself is valid
      (multisig-valid (unwrap-panic (verify-multisig-address pubkeys m true (some multisig-script-pub-key))))
    )
    ;; Only return true if both conditions are met
    (ok (and user-is-signer multisig-valid))
  )
)

;; Closure function that checks if the user's pubkey hash matches any pubkey in the list
(define-private (check-pubkey 
    (pubkey (buff 33)) 
    (found bool)
  )
  (let
    (
      ;; Get the pubkey hash directly from tx-sender (user's Stacks address)
      (user-pubkey-hash (get hash-bytes (unwrap-panic (principal-destruct? tx-sender))))
    )
    (if found
        true  ;; Already found a match, short-circuit
        (is-eq (hash160 pubkey) user-pubkey-hash)  ;; Check current pubkey
    )
  )
)

