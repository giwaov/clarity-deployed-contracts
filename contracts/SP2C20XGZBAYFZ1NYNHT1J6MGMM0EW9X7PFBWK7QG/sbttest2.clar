;; title: Soulbound NFT Contract
;; version: 1.1.0
;; summary: A non-transferrable (soulbound) NFT with IPFS metadata
;; description: Gas-optimized soulbound NFT. Cannot be transferred after minting.

;; traits
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; token definition
(define-non-fungible-token soulbound-nft uint)

;; constants
(define-constant DEPLOYER tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-MINT-PAUSED (err u402))
(define-constant ERR-TRANSFER-NOT-ALLOWED (err u403))
(define-constant ERR-TOKEN-NOT-FOUND (err u404))
(define-constant ERR-INVALID-CALLER (err u406))
(define-constant ERR-ALREADY-MINTED (err u407))
(define-constant ERR-INVALID-RECIPIENT (err u408))

;; data vars
(define-data-var next-id uint u1)
(define-data-var ipfs-root (string-ascii 80) "ipfs://bafkreibaiuvndmx7zgiseheqjqcvkwmoz5jhxnovmvp3sy466eflkzord4")
(define-data-var minting-paused bool false)

;; data maps
(define-map has-minted principal bool)
(define-map admins principal bool)

;; ============================================
;; GAS OPTIMIZATION: Cache standard-caller once
;; ============================================
(define-private (get-standard-caller)
  (let ((d (unwrap-panic (principal-destruct? contract-caller))))
    (unwrap-panic (principal-construct? (get version d) (get hash-bytes d)))
  )
)

;; Check if given principal is admin (deployer or added admin)
(define-private (check-is-admin (caller principal))
  (or (is-eq caller DEPLOYER) (default-to false (map-get? admins caller)))
)

;; ============================================
;; READ-ONLY FUNCTIONS (SIP-009 + helpers)
;; ============================================

(define-read-only (get-last-token-id)
  (ok (- (var-get next-id) u1))
)

;; Returns metadata URI - all tokens share the same metadata (single image soulbound)
(define-read-only (get-token-uri (id uint))
  (ok (some (var-get ipfs-root)))
)

(define-read-only (get-owner (id uint))
  (ok (nft-get-owner? soulbound-nft id))
)

(define-read-only (get-ipfs-root)
  (ok (var-get ipfs-root))
)

(define-read-only (has-user-minted (user principal))
  (ok (default-to false (map-get? has-minted user)))
)

(define-read-only (is-minting-paused)
  (ok (var-get minting-paused))
)

(define-read-only (is-address-admin (address principal))
  (ok (check-is-admin address))
)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; SOULBOUND: Transfer always fails - core soulbound functionality
(define-public (transfer (id uint) (from principal) (to principal))
  ERR-TRANSFER-NOT-ALLOWED
)

;; Mint to caller - ONE per address maximum
(define-public (mint)
  (let ((token-id (var-get next-id)) (caller tx-sender))
    (asserts! (not (var-get minting-paused)) ERR-MINT-PAUSED)
    (asserts! (not (is-eq caller DEPLOYER)) ERR-INVALID-CALLER)
    (asserts! (is-none (map-get? has-minted caller)) ERR-ALREADY-MINTED)
    (try! (nft-mint? soulbound-nft token-id caller))
    (map-set has-minted caller true)
    (var-set next-id (+ token-id u1))
    (ok token-id)
  )
)

;; Admin mint to third party - still enforces 1 per address
(define-public (mint-to (recipient principal))
  (let ((token-id (var-get next-id)) (caller (get-standard-caller)))
    (asserts! (check-is-admin caller) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq recipient DEPLOYER)) ERR-INVALID-RECIPIENT)
    (asserts! (is-none (map-get? has-minted recipient)) ERR-ALREADY-MINTED)
    (try! (nft-mint? soulbound-nft token-id recipient))
    (map-set has-minted recipient true)
    (var-set next-id (+ token-id u1))
    (ok token-id)
  )
)

;; Batch airdrop - admin only, skips duplicates
(define-public (airdrop 
  (recipients-1 (list 200 principal)) 
  (recipients-2 (list 200 principal)) 
  (recipients-3 (list 200 principal))
)
  (let ((caller (get-standard-caller)))
    (asserts! (check-is-admin caller) ERR-NOT-AUTHORIZED)
    (ok (var-set next-id 
      (fold airdrop-mint recipients-3
        (fold airdrop-mint recipients-2
          (fold airdrop-mint recipients-1 (var-get next-id))))))
  )
)

;; Private airdrop helper - skips already-minted addresses
(define-private (airdrop-mint (recipient principal) (id uint))
  (if (is-some (map-get? has-minted recipient))
    id
    (match (nft-mint? soulbound-nft id recipient)
      ok-val (begin (map-set has-minted recipient true) (+ id u1))
      err-val id
    )
  )
)

;; Burn - owner only
(define-public (burn (id uint))
  (let ((owner (unwrap! (nft-get-owner? soulbound-nft id) ERR-TOKEN-NOT-FOUND)))
    (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
    (try! (nft-burn? soulbound-nft id owner))
    (ok true)
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

(define-public (set-ipfs-root (new-root (string-ascii 80)))
  (begin
    (asserts! (check-is-admin (get-standard-caller)) ERR-NOT-AUTHORIZED)
    (ok (var-set ipfs-root new-root))
  )
)

(define-public (pause-minting)
  (begin
    (asserts! (check-is-admin (get-standard-caller)) ERR-NOT-AUTHORIZED)
    (ok (var-set minting-paused true))
  )
)

(define-public (unpause-minting)
  (begin
    (asserts! (check-is-admin (get-standard-caller)) ERR-NOT-AUTHORIZED)
    (ok (var-set minting-paused false))
  )
)

;; Only deployer can manage admins
(define-public (add-admin (new-admin principal))
  (begin
    (asserts! (is-eq (get-standard-caller) DEPLOYER) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq new-admin DEPLOYER)) ERR-INVALID-RECIPIENT)
    (ok (map-set admins new-admin true))
  )
)

(define-public (remove-admin (admin principal))
  (begin
    (asserts! (is-eq (get-standard-caller) DEPLOYER) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq admin DEPLOYER)) ERR-INVALID-RECIPIENT)
    (ok (map-delete admins admin))
  )
)