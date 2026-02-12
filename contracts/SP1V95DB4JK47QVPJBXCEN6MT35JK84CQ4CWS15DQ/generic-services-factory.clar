(define-map services {contract: principal, service-id: uint} 
  {implementation: principal, linked-contract: principal, linked-id: uint, mode: uint})

(define-data-var service-nonce uint u0)

(define-constant contract-owner tx-sender)
(define-constant mode-linked-id u0)
(define-constant mode-no-linked-id u1)
(define-constant err-not-owner (err u100))
(define-constant err-service-not-found (err u101))

(define-read-only (get-service (contract principal) (service-id uint))
  (ok (unwrap! (map-get? services {contract: contract, service-id: service-id}) err-service-not-found)))

(define-public (create 
  (implementation principal)
  (salt (buff 32))
  (svc-chain-id uint)
  (mode uint)
  (linked-contract principal)
  (linked-id uint))
  (let ((new-service-id (+ (var-get service-nonce) u1)))
    (map-set services {contract: tx-sender, service-id: new-service-id} 
      {implementation: implementation, linked-contract: linked-contract, 
       linked-id: linked-id, mode: mode})
    (var-set service-nonce new-service-id)
    (ok new-service-id)))

(define-read-only (get-contract-hash)
  (contract-hash? .generic-services-factory))

(define-read-only (get-block-time)
  stacks-block-time)
