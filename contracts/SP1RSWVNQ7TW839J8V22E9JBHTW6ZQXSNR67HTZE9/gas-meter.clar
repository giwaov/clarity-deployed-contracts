;; Gas Meter Contract
;; Mini-game of paid actions with small fees
;; Allows repeatable actions like "cast spell", "upgrade", "claim daily"
;; Generates many small transactions to measure usage and fees

(define-constant ERR-INVALID-ACTION (err u1001))
(define-constant ERR-INSUFFICIENT-FEE (err u1002))
(define-constant ERR-INVALID-AMOUNT (err u1003))

;; Taxas para cada acao (em micro-STX)
(define-constant FEE-CAST-SPELL u10000)      ;; 0.01 STX
(define-constant FEE-UPGRADE u50000)          ;; 0.05 STX
(define-constant FEE-CLAIM-DAILY u20000)     ;; 0.02 STX

;; Contador de acoes totais
(define-data-var total-actions uint u0)

;; Contador de usuarios unicos
(define-data-var user-count uint u0)

;; Lista de usuarios unicos
(define-map user-list uint principal)

;; Map para rastrear se usuario ja esta na lista
(define-map user-index principal (optional uint))

;; Estatisticas por usuario: user -> {total-actions, total-spent, last-action-time}
(define-map user-stats principal {
    total-actions: uint,
    total-spent: uint,
    last-action-time: uint
})

;; Estatisticas por acao: action-name -> {count, total-fees}
(define-map action-stats (string-ascii 20) {
    count: uint,
    total-fees: uint
})

;; Historico de acoes: (user, action-id) -> {action, fee, timestamp}
(define-map action-history (tuple (user principal) (action-id uint)) {
    action: (string-ascii 20),
    fee: uint,
    timestamp: uint
})

;; Contador de acoes por usuario
(define-map user-action-counter principal uint)

;; Helper para adicionar usuario a lista se for novo
(define-private (add-user-if-new (user principal))
    (let ((existing-index (map-get? user-index user)))
        (if (is-none existing-index)
            ;; Novo usuario, adicionar a lista
            (let ((new-index (var-get user-count)))
                (var-set user-count (+ new-index u1))
                (map-set user-list new-index user)
                (map-set user-index user (some new-index))
                true
            )
            ;; Ja esta na lista
            false
        )
    )
)

;; Helper para atualizar estatisticas do usuario
(define-private (update-user-stats (user principal) (fee uint) (action-time uint))
    (let ((current-stats (map-get? user-stats user)))
        (if (is-none current-stats)
            ;; Primeira acao do usuario
            (map-set user-stats user {
                total-actions: u1,
                total-spent: fee,
                last-action-time: action-time
            })
            ;; Atualizar estatisticas existentes
            (let ((stats (unwrap-panic current-stats)))
                (map-set user-stats user {
                    total-actions: (+ (get total-actions stats) u1),
                    total-spent: (+ (get total-spent stats) fee),
                    last-action-time: action-time
                })
            )
        )
    )
)

;; Helper para atualizar estatisticas da acao
(define-private (update-action-stats (action-name (string-ascii 20)) (fee uint))
    (let ((current-stats (map-get? action-stats action-name)))
        (if (is-none current-stats)
            ;; Primeira vez que esta acao e executada
            (map-set action-stats action-name {
                count: u1,
                total-fees: fee
            })
            ;; Atualizar estatisticas existentes
            (let ((stats (unwrap-panic current-stats)))
                (map-set action-stats action-name {
                    count: (+ (get count stats) u1),
                    total-fees: (+ (get total-fees stats) fee)
                })
            )
        )
    )
)

;; Funcao principal para executar uma acao
;; @param action: Nome da acao ("cast-spell", "upgrade", "claim-daily")
;; @param fee-amount: Quantidade de STX a pagar (em micro-STX)
(define-public (execute-action (action (string-ascii 20)) (fee-amount uint))
    (let ((sender tx-sender)
          (action-time (var-get total-actions)))
        
        ;; Validar acao e fee
        (asserts! (> fee-amount u0) ERR-INVALID-AMOUNT)
        
        ;; Verificar se a acao e valida e se o fee e suficiente
        (let ((required-fee 
            (if (is-eq action "cast-spell")
                FEE-CAST-SPELL
                (if (is-eq action "upgrade")
                    FEE-UPGRADE
                    (if (is-eq action "claim-daily")
                        FEE-CLAIM-DAILY
                        u0
                    )
                )
            )))
            (asserts! (> required-fee u0) ERR-INVALID-ACTION)
            (asserts! (>= fee-amount required-fee) ERR-INSUFFICIENT-FEE)
            
            ;; Adicionar usuario a lista se for novo
            (add-user-if-new sender)
            
            ;; Obter contador de acoes do usuario
            (let ((user-action-id (default-to u0 (map-get? user-action-counter sender))))
                ;; Incrementar contador de acoes do usuario
                (map-set user-action-counter sender (+ user-action-id u1))
                
                ;; Incrementar contador total de acoes
                (var-set total-actions (+ action-time u1))
                
                ;; Armazenar no historico
                (map-set action-history (tuple (user sender) (action-id user-action-id)) {
                    action: action,
                    fee: fee-amount,
                    timestamp: action-time
                })
                
                ;; Atualizar estatisticas
                (update-user-stats sender fee-amount action-time)
                (update-action-stats action fee-amount)
                
                ;; Transfer fee - the STX is sent with the transaction
                ;; The contract receives the fee automatically
                (ok true)
            )
        )
    )
)

;; Acao: Cast Spell (0.01 STX)
(define-public (cast-spell)
    (execute-action "cast-spell" FEE-CAST-SPELL)
)

;; Acao: Upgrade (0.05 STX)
(define-public (upgrade)
    (execute-action "upgrade" FEE-UPGRADE)
)

;; Acao: Claim Daily (0.02 STX)
(define-public (claim-daily)
    (execute-action "claim-daily" FEE-CLAIM-DAILY)
)

;; Read-only: Obter estatisticas do usuario
(define-read-only (get-user-stats (user principal))
    (map-get? user-stats user)
)

;; Read-only: Obter estatisticas de uma acao
(define-read-only (get-action-stats (action-name (string-ascii 20)))
    (map-get? action-stats action-name)
)

;; Read-only: Obter total de acoes
(define-read-only (get-total-actions)
    (var-get total-actions)
)

;; Read-only: Obter total de usuarios
(define-read-only (get-user-count)
    (var-get user-count)
)

;; Read-only: Obter usuario por indice
(define-read-only (get-user-at-index (index uint))
    (map-get? user-list index)
)

;; Read-only: Obter usuario com stats por indice
(define-read-only (get-user-at-index-with-stats (index uint))
    (match (map-get? user-list index) address
        (let ((stats (map-get? user-stats address)))
            (match stats stats-value
                (some {
                    address: address,
                    total-actions: (get total-actions stats-value),
                    total-spent: (get total-spent stats-value),
                    last-action-time: (get last-action-time stats-value)
                })
                none
            )
        )
        none
    )
)

;; Read-only: Obter historico de acao do usuario
(define-read-only (get-user-action (user principal) (action-id uint))
    (map-get? action-history (tuple (user user) (action-id action-id)))
)

;; Read-only: Obter contador de acoes do usuario
(define-read-only (get-user-action-count (user principal))
    (default-to u0 (map-get? user-action-counter user))
)

