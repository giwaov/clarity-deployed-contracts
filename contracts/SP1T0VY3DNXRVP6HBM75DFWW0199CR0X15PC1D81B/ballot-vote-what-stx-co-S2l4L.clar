
    ;; ballot
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Constants
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    (define-constant CONTRACT-OWNER tx-sender)
    ;; Errors
    (define-constant ERR-NOT-STARTED (err u1001))
    (define-constant ERR-ENDED (err u1002))
    (define-constant ERR-ALREADY-VOTED (err u1003))
    (define-constant ERR-FAILED-STRATEGY (err u1004))
    (define-constant ERR-NOT-VOTED (err u1005))
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; data maps and vars
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    (define-data-var title (string-utf8 512) u"")
    (define-data-var description (string-utf8 512) u"")
    (define-data-var voting-system (string-ascii 512) "")
    (define-data-var start uint u0)
    (define-data-var end uint u0)
    (define-map token-ids-map {token-id: uint} {user: principal, vote-id: uint})
    (define-map btc-holder-map {domain: (buff 20), namespace: (buff 48)} {user: principal, vote-id: uint})
    (define-map results {id: (string-ascii 36)} {count: uint, name: (string-utf8 256), locked-stx: uint, unlocked-stx: uint} )
    (define-map users {id: principal} {id: uint, vote: (list 9 (string-ascii 36)), volume: (list 9 uint), voting-power: uint, locked-stx: uint, unlocked-stx: uint})
    (define-map register {id: uint} {user: principal, vote: (list 9 (string-ascii 36)), volume: (list 9 uint), voting-power: uint, locked-stx: uint, unlocked-stx: uint})
    (define-data-var total uint u0)
    (define-data-var total-votes uint u0)
    (define-data-var options (list 9 (string-ascii 36)) (list))
    (define-data-var temp-voting-power uint u0)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; private functions
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    
        (define-private (get-voting-power-by-ft-holdings)
            (at-block (unwrap-panic (get-stacks-block-info? id-header-hash u4679105))
                (let
                    (
                        (ft-balance (unwrap-panic (contract-call? 'SP1T0VY3DNXRVP6HBM75DFWW0199CR0X15PC1D81B.teiko-token-stxcity get-balance tx-sender)))
                        (ft-decimals (unwrap-panic (contract-call? 'SP1T0VY3DNXRVP6HBM75DFWW0199CR0X15PC1D81B.teiko-token-stxcity get-decimals)))
                    )

                    (if (> ft-balance u0)
                        (if (> ft-decimals u0)
                            (/ ft-balance (pow u10 ft-decimals))
                            ft-balance
                        )
                        ft-balance
                    )
                )
            )
        )
    
    (define-private (have-i-voted)
        (match (map-get? users {id: tx-sender})
            success true
            false
        )
    )
    
    (define-private (fold-boolean (left bool) (right bool))
        (and (is-eq left true) (is-eq right true))
    )

    (define-private (check-volume (each-volume uint))
        (> each-volume u0)
    )

    (define-private (validate-vote-volume (volume (list 9 uint)))
        (begin
            (fold fold-boolean (map check-volume volume) true)
        )
    )

    (define-private (get-volume-by-voting-power (volume uint))
        (var-get temp-voting-power)
    )

    (define-private (get-pow-value (volume uint))
        (pow volume u2)
    )
    
    (define-private (process-my-vote (option-id (string-ascii 36)) (volume uint))
        (match (map-get? results {id: option-id})
            result (let
                    (
                        (new-count-tuple {count: (+ volume (get count result))})
                    )

                    ;; Capture the vote
                    (map-set results {id: option-id} (merge result new-count-tuple))

                    ;; Return
                    true
                )
            false
        )
    )
    
    (define-private (get-single-result (option-id (string-ascii 36)))
        (let 
            (
                (volume (default-to u0 (get count (map-get? results {id: option-id}))))
            )
    
            ;; Return volume
            volume
        )
    )

    (define-private (get-single-result-with-locked-and-unlocked-stx (option-id (string-ascii 36)))
        (let 
            (
                (locked-stx (default-to u0 (get locked-stx (map-get? results {id: option-id}))))
                (unlocked-stx (default-to u0 (get unlocked-stx (map-get? results {id: option-id}))))
            )

            ;; Return locked-stx and unlocked-stx
            {locked-stx: locked-stx, unlocked-stx: unlocked-stx}
        )
    )

    
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; public functions for all
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    (define-public (cast-my-vote (vote (list 9 (string-ascii 36))) (volume (list 9 uint))
        (bns (string-ascii 256)) (domain (buff 20)) (namespace (buff 48)) (token-ids (list 60000 uint))
        )
        (let
            (
                (vote-id (+ u1 (var-get total)))
                (voting-power (get-voting-power-by-ft-holdings))
                
                ;; FPTP and Block voting
                (temp (var-set temp-voting-power voting-power))
                (volume-by-voting-power (map get-volume-by-voting-power volume))
            
                
                ;; FPTP and Block voting - Number of votes
                (my-votes voting-power)

                ;; Get the stx balance with locked and unlocked
                
            )
            ;; Validation
            (asserts! (and (> (len vote) u0) (is-eq (len vote) (len volume-by-voting-power)) (validate-vote-volume volume-by-voting-power)) ERR-NOT-VOTED)
            (asserts! (>= burn-block-height (var-get start)) ERR-NOT-STARTED)
            (asserts! (<= burn-block-height (var-get end)) ERR-ENDED)        
            (asserts! (not (have-i-voted)) ERR-ALREADY-VOTED)
            
                ;; FPTP and Block voting
                (asserts! (> voting-power u0) ERR-FAILED-STRATEGY)
            
            ;; Business logic
            ;; Process my vote
            (map process-my-vote vote volume-by-voting-power)

            
            
            ;; Register for reference
            (map-set users {id: tx-sender} {id: vote-id, vote: vote, volume: volume-by-voting-power, voting-power: voting-power , locked-stx: u0, unlocked-stx: u0})
            (map-set register {id: vote-id} {user: tx-sender, vote: vote, volume: volume-by-voting-power, voting-power: voting-power , locked-stx: u0, unlocked-stx: u0})

            ;; Increase the total votes
            (var-set total-votes (+ my-votes (var-get total-votes)))

            ;; Increase the total
            (var-set total vote-id)
    
            ;; Return
            (ok true)
        )
    )
    
    (define-read-only (get-results)
        (begin
            (ok {
                    total: (var-get total), 
                    total-votes: (var-get total-votes),
                    options: (var-get options), 
                    results: (map get-single-result (var-get options)),
                    results-with-locked-and-unlocked-stx: (map get-single-result-with-locked-and-unlocked-stx (var-get options))
                })
        )
    )
    
    (define-read-only (get-result-at-position (position uint))
        (ok (map-get? register {id: position}))
    )
        
    (define-read-only (get-result-by-user (user principal))
        (ok (map-get? users {id: user}))
    )
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Default assignments
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    (var-set title u"Vote%20What%20STX%20Community%20we%20should%20airdrop%20100k%20%24TEIKO%20")
    (var-set description u"")
    (var-set voting-system "block")
    (var-set options (list "d28956c3-a65d-45dc-b9cd-59a0474684a8" "3d11e9ab-7445-40b6-8cb3-eca624c84424" "56a9cafb-6dbf-43c4-9afe-bbf3f93920b7" "86284fd8-6c89-48ec-a9f4-ab915604fafb" "a6620448-29f0-4592-ab7e-2679b345a015" "1911761f-0470-4a8e-9eb3-6b6103f5641a" "014de34d-9d1c-438a-be49-a5b884c24e9c" "6a407a52-1f76-4a28-abec-83a1a67ba597" "fced2ea4-3680-475a-915e-9c6519cc09d8"))
    (var-set start u922923)
    (var-set end u923622)
    (map-set results {id: "d28956c3-a65d-45dc-b9cd-59a0474684a8"} {count: u0, name: u"LEO", locked-stx: u0, unlocked-stx: u0}) (map-set results {id: "3d11e9ab-7445-40b6-8cb3-eca624c84424"} {count: u0, name: u"Welsh", locked-stx: u0, unlocked-stx: u0}) (map-set results {id: "56a9cafb-6dbf-43c4-9afe-bbf3f93920b7"} {count: u0, name: u"Flat%20Earth%20", locked-stx: u0, unlocked-stx: u0}) (map-set results {id: "86284fd8-6c89-48ec-a9f4-ab915604fafb"} {count: u0, name: u"Velar%20", locked-stx: u0, unlocked-stx: u0}) (map-set results {id: "a6620448-29f0-4592-ab7e-2679b345a015"} {count: u0, name: u"Roo", locked-stx: u0, unlocked-stx: u0}) (map-set results {id: "1911761f-0470-4a8e-9eb3-6b6103f5641a"} {count: u0, name: u"Droid", locked-stx: u0, unlocked-stx: u0}) (map-set results {id: "014de34d-9d1c-438a-be49-a5b884c24e9c"} {count: u0, name: u"Dog", locked-stx: u0, unlocked-stx: u0}) (map-set results {id: "6a407a52-1f76-4a28-abec-83a1a67ba597"} {count: u0, name: u"UAP", locked-stx: u0, unlocked-stx: u0}) (map-set results {id: "fced2ea4-3680-475a-915e-9c6519cc09d8"} {count: u0, name: u"Stone", locked-stx: u0, unlocked-stx: u0})