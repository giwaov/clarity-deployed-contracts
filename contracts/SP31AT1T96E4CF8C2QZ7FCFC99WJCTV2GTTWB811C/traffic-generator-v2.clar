;; traffic-generator-v2.clar
;; A utility contract to generate high volume internal activity (100 ops) per transaction
;; Clarity Version: 4
;; Epoch: 3.3

;; A simple list of 10 items to iterate over
(define-constant BATCH-10 (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10))

;; A counter to track total operations performed
(define-data-var action-counter uint u0)

;; Public function to trigger 100 internal operations in one go
;; This generates 100 events and 100 state writes
(define-public (generate-100-actions)
    (begin
        ;; Outer loop (10x)
        (map loop-10 BATCH-10)
        ;; Return the new counter value
        (ok (var-get action-counter))
    )
)

;; Private function for the outer loop
(define-private (loop-10 (idx uint))
    ;; Inner loop (10x) -> Total 10 * 10 = 100
    (map perform-action BATCH-10)
)

;; The core action: Writes state and emits an event
(define-private (perform-action (idx uint))
    (let
        (
            (current-val (var-get action-counter))
        )
        ;; 1. Write to state (increment counter)
        (var-set action-counter (+ current-val u1))
        
        ;; 2. Emit an event (useful for indexers/explorers)
        (print {
            event: "traffic-generated", 
            index: idx, 
            total-count: (+ current-val u1),
            timestamp: stacks-block-height
        })
        
        ;; Return value for the map (required)
        true
    )
)
