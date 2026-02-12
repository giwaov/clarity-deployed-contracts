;; hapa

(use-trait ft-trait-sm 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait ft-trait-sp 'SPQC38PW542EQJ5M11CR25P7BS1CA6QT4TBXGB3M.sip-010-trait-ft-standard.sip-010-trait)
(use-trait stableswap-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-4.stableswap-pool-trait)
(use-trait lp-trait 'SPQC38PW542EQJ5M11CR25P7BS1CA6QT4TBXGB3M.lp-trait.lp-trait)

(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))

(define-public (dollapa
(a1 (optional uint))
(mr1 (optional uint))
(p1 (optional principal))
(st1 (optional {
a: <ft-trait-sm>,
b: <ft-trait-sm>,
}))
(sp1 (optional { a: <stableswap-pool-trait> }))
(yt2 (optional <ft-trait-sp>))
(lt2 (optional <lp-trait>))
(ya2 (optional uint))
(mx2 (optional uint))
)
(let (
(r1 (if (and
(is-some a1)
(is-some mr1)
(is-some st1)
(is-some sp1)
)
(some (unwrap!
(call-a
(unwrap!
a1
e5
)
(unwrap!
mr1
e5
)
p1
(unwrap!
st1
e5
)
(unwrap!
sp1
e5
))
e3
))
none
))
(a-for-r2 (if (is-some r1)
(unwrap!
r1
e3
)
(unwrap!
a1
e5
)
))
(r2 (if (and
(is-some yt2)
(is-some lt2)
(is-some mx2)
)
(some (unwrap!
(call-b
(unwrap!
yt2
e5
)
(unwrap!
lt2
e5
)
a-for-r2
(unwrap!
mx2
e5
))
e4
))
none
))
)
(begin
(asserts!
(or (is-some r1) (is-some r2))
e5
)
(ok {
r1: r1,
r2: r2,
})
)
)
)

(define-private (call-a
(amount uint)
(min-received uint)
(provider (optional principal))
(stableswap-tokens {
a: <ft-trait-sm>,
b: <ft-trait-sm>,
})
(stableswap-pools { a: <stableswap-pool-trait> })
)
(contract-call?
'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-swap-helper-v-1-5
swap-helper-a
amount
min-received
provider
stableswap-tokens
stableswap-pools
)
)

(define-private (call-b
(y-token <ft-trait-sp>)
(lp-token <lp-trait>)
(y-amount uint)
(min-x-amount uint)
)
(contract-call?
'SPQC38PW542EQJ5M11CR25P7BS1CA6QT4TBXGB3M.stableswap-stx-ststx-v-1-2
swap-y-for-x
y-token
lp-token
y-amount
min-x-amount
)
)
