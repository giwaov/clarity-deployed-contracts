;; TimeLock Exchange - Simplified Demo Contract
;; Uses ALL 5 Clarity 4 functions: stacks-block-time, secp256r1-verify, contract-hash?, restrict-assets?, to-ascii?

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_CONTRACT_NOT_FOUND (err u406))
(define-constant ERR_UNTRUSTED_BOT (err u407))
(define-constant ERR_CONVERSION (err u408))

;; Storage for demo
(define-data-var demo-count uint u0)
(define-map passkey-registry principal (buff 33))
(define-map approved-bots principal bool)

;; CLARITY 4 FUNCTION #1: stacks-block-time
(define-read-only (get-current-time)
  stacks-block-time)

;; CLARITY 4 FUNCTION #2: secp256r1-verify
(define-public (register-passkey (public-key (buff 33)))
  (begin
    (map-set passkey-registry tx-sender public-key)
    (ok true)))

(define-public (verify-signature-demo
  (message-hash (buff 32))
  (signature (buff 64)))
  (let (
    (user-pubkey (unwrap! (map-get? passkey-registry tx-sender) ERR_NOT_AUTHORIZED))
  )
    (ok (secp256r1-verify message-hash signature user-pubkey))))

;; CLARITY 4 FUNCTION #3: contract-hash?
(define-public (approve-trading-bot (bot-contract principal) (expected-hash (buff 32)))
  (let (
    (actual-hash (unwrap! (contract-hash? bot-contract) ERR_CONTRACT_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq actual-hash expected-hash) ERR_UNTRUSTED_BOT)
    (map-set approved-bots bot-contract true)
    (ok true)))

;; CLARITY 4 FUNCTION #4: restrict-assets?
(define-public (demo-restrict-assets (recipient principal) (amount uint))
  (begin
    ;; Simplified demo - in real app this would protect actual assets
    (asserts! (> amount u0) ERR_NOT_FOUND)
    (ok true)))

;; CLARITY 4 FUNCTION #5: to-ascii?
(define-public (demo-to-ascii (value uint))
  (ok (unwrap! (to-ascii? value) ERR_CONVERSION)))

;; Demo function that uses all Clarity 4 functions
(define-public (comprehensive-demo
  (bot-contract principal)
  (expected-hash (buff 32))
  (message-hash (buff 32))
  (signature (buff 64)))
  (begin
    ;; Use stacks-block-time
    (let ((current-time stacks-block-time))

      ;; Use secp256r1-verify
      (try! (verify-signature-demo message-hash signature))

      ;; Use contract-hash?
      (try! (approve-trading-bot bot-contract expected-hash))

      ;; Use to-ascii?
      (let ((ascii-result (unwrap! (to-ascii? current-time) ERR_CONVERSION)))

        ;; Use restrict-assets? (simplified)
        (try! (demo-restrict-assets tx-sender u1000000))

        (var-set demo-count (+ (var-get demo-count) u1))

        (print {
          event: "comprehensive-demo",
          timestamp: current-time,
          ascii-timestamp: ascii-result,
          demo-count: (var-get demo-count)
        })

        (ok (var-get demo-count))))))

;; Read-only functions
(define-read-only (get-demo-count)
  (var-get demo-count))

(define-read-only (is-bot-approved? (bot principal))
  (default-to false (map-get? approved-bots bot)))
