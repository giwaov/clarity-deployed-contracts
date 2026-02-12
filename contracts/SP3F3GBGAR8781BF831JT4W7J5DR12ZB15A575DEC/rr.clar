(use-trait ft 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait xp 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-1.xyk-pool-trait)
(use-trait sf 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)
(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))
(define-public (ot
(a1 (optional <ft>))
(a2 (optional <ft>))
(a3 (optional uint))
(a4 (optional uint))
(p1 (optional principal))
(a5 (optional uint))
(a6 (optional uint))
(p2 (optional principal))
(pt (optional <xp>))
(xt2 (optional (tuple (a <ft>) (b <ft>))))
(xr (optional bool))
(id (optional uint))
(vt (optional (tuple (a <ft>) (b <ft>))))
(iot (optional (tuple (a <ft>) (b <ft>))))
(st (optional <sf>))
)
(let (
(r1
(if (and
(is-some a1)
(is-some a2)
(is-some a3)
(is-some a4))
(some (unwrap! (element-at (try! (call-a
(unwrap! a1 e5)
(unwrap! a2 e5)
(unwrap! a3 e5)
(unwrap! a4 e5)
p1)) u1) e2))
none))
(a-for-r2
(if (is-some r1)
(unwrap! r1 e3)
(unwrap! a5 e5)))
(r2
(if (and
(is-some a6)
(is-some pt)
(is-some xt2)
(is-some xr)
(is-some id)
(is-some vt)
(is-some iot)
(is-some st))
(some (try! (call-b
a-for-r2
(unwrap! a6 e5)
p2
(unwrap! pt e5)
(unwrap! xt2 e5)
(unwrap! xr e5)
(unwrap! id e5)
(unwrap! vt e5)
(unwrap! iot e5)
(unwrap! st e5))))
none))
)
(begin
(asserts! (or (is-some r1) (is-some r2)) e5)
(ok {
r1: r1,
r2: r2
})
)
)
)
(define-private (call-a
(tx <ft>)
(ty <ft>)
(dx uint)
(min-dy uint)
(p (optional principal))
)
(contract-call?
'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.wrapper-arkadiko-v-1-2
swap-x-for-y
tx
ty
dx
min-dy
p)
)
(define-private (call-b
(a uint)
(m uint)
(p (optional principal))
(pt <xp>)
(xt (tuple (a <ft>) (b <ft>)))
(xr bool)
(id uint)
(vt (tuple (a <ft>) (b <ft>)))
(iot (tuple (a <ft>) (b <ft>)))
(st <sf>)
)
(contract-call?
'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-xyk-velar-v-1-2
swap-helper-b
a
m
p
pt
(get a xt)
(get b xt)
xr
id
(get a vt)
(get b vt)
(get a iot)
(get b iot)
st)
)