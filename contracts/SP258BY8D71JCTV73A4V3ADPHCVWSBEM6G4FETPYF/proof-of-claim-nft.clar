;; clarity-version 4
;; proof-of-claim-nft.clar
;; Simple SIP-009 NFT that serves as proof of deadman vault claim
;; Each NFT is a certificate showing the beneficiary claimed the funds

(define-constant ERR-NOT-AUTHORIZED u401)
(define-constant ERR-NOT-FOUND u404)

(define-non-fungible-token proof-of-claim uint)

(define-data-var last-token-id uint u0)
(define-data-var contract-owner principal tx-sender)

;; Authorized minters (vault contracts that can mint)
(define-map authorized-minters principal bool)

;; Token metadata - who claimed and when
(define-map token-data uint {
  beneficiary: principal,
  claimed-at: uint
})

;; ===== SIP-009 FUNCTIONS =====

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id)))

(define-read-only (get-token-uri (token-id uint))
  (ok (some (generate-token-uri token-id))))

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? proof-of-claim token-id)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR-NOT-AUTHORIZED))
    (nft-transfer? proof-of-claim token-id sender recipient)))

;; ===== ADMIN FUNCTIONS =====

(define-public (set-authorized-minter (minter principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (ok (map-set authorized-minters minter authorized))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

;; ===== MINTING FUNCTIONS =====

(define-public (mint (recipient principal))
  (let (
    (token-id (+ (var-get last-token-id) u1))
    (is-authorized (default-to false (map-get? authorized-minters tx-sender)))
  )
    (asserts! (or is-authorized (is-eq tx-sender (var-get contract-owner))) (err ERR-NOT-AUTHORIZED))
    
    ;; Mint NFT
    (try! (nft-mint? proof-of-claim token-id recipient))
    
    ;; Store metadata
    (map-set token-data token-id {
      beneficiary: recipient,
      claimed-at: burn-block-height
    })
    
    ;; Update counter
    (var-set last-token-id token-id)
    (ok token-id)))

;; ===== SVG GENERATION =====

(define-read-only (generate-token-uri (token-id uint))
  (match (map-get? token-data token-id)
    data (concat "data:application/json;charset=utf-8,{\"name\":\"Proof of Claim Certificate\",\"description\":\"This NFT certifies that the beneficiary has claimed funds from a deadman vault\",\"image\":\"data:image/svg+xml;charset=utf-8,"
           (concat (generate-svg)
           "\"}"))
    ""))

(define-read-only (generate-svg)
  "<svg xmlns='http://www.w3.org/2000/svg' width='400' height='400'><rect width='400' height='400' fill='%23111'/><rect x='20' y='20' width='360' height='360' fill='none' stroke='%23FFD700' stroke-width='4'/><text x='200' y='100' text-anchor='middle' fill='%23FFD700' font-size='24' font-weight='bold'>PROOF OF CLAIM</text><text x='200' y='180' text-anchor='middle' fill='%23FFF' font-size='16'>This certificate confirms that</text><text x='200' y='210' text-anchor='middle' fill='%23FFF' font-size='16'>the beneficiary has successfully</text><text x='200' y='240' text-anchor='middle' fill='%23FFF' font-size='16'>claimed funds from a</text><text x='200' y='270' text-anchor='middle' fill='%23FFF' font-size='16'>Deadman Savings Vault</text><circle cx='200' cy='320' r='30' fill='none' stroke='%23FFD700' stroke-width='3'/><text x='200' y='330' text-anchor='middle' fill='%23FFD700' font-size='18' font-weight='bold'>OK</text></svg>")

;; ===== READ-ONLY QUERIES =====

(define-read-only (get-token-metadata (token-id uint))
  (map-get? token-data token-id))

(define-read-only (is-authorized-minter (minter principal))
  (default-to false (map-get? authorized-minters minter)))
