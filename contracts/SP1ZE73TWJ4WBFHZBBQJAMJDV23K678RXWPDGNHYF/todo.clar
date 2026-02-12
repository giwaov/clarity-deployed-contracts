;; title: todo
;; version:
;; summary:
;; description:

;; traits
;;

;; definitions
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_NOT_OWNER (err u403))

;; data vars
(define-data-var next-id uint u0)

;; data maps
(define-map tasks 
    uint 
    {
        name: (string-ascii 50),
        completed: bool,
        owner: principal
    }
)

;; public functions
(define-public (create-task (name (string-ascii 50)))
    (let 
        (
            (id (var-get next-id))
        )
        (map-insert tasks id {
            name: name,
            completed: false,
            owner: tx-sender
        })
        (var-set next-id (+ id u1))
        (ok id)
    )
)

(define-public (complete-task (id uint))
    (let
        (
            (task (unwrap! (map-get? tasks id) ERR_NOT_FOUND))
        )
        (asserts! (is-eq (get owner task) tx-sender) ERR_NOT_OWNER)
        (ok (map-set tasks id (merge task { completed: true })))
    )
)

(define-public (delete-task (id uint))
    (let
        (
            (task (unwrap! (map-get? tasks id) ERR_NOT_FOUND))
        )
        (asserts! (is-eq (get owner task) tx-sender) ERR_NOT_OWNER)
        (ok (map-delete tasks id))
    )
)

;; read only functions
(define-read-only (get-task (id uint))
    (map-get? tasks id)
)

