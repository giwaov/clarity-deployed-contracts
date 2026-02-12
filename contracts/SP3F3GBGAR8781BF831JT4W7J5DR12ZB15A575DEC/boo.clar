(use-trait ft 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait xpt 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)
(use-trait sft 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)
(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))
(define-public (jaka
(a1 (optional uint))
(a2 (optional uint))
(p1 (optional principal))
(sr1 (optional bool))
(xt1 (optional (tuple (a <ft>) (b <ft>))))
(xp1 (optional (tuple (a <xpt>))))
(vt1 (optional (tuple (a <ft>) (b <ft>) (c <ft>))))
(sf1 (optional <sft>))
(a3 (optional uint))
(p2 (optional principal))
(sr2 (optional bool))
(xt2 (optional (tuple (a <ft>) (b <ft>))))
(xp2 (optional (tuple (a <xpt>))))
(vt2 (optional (tuple (a <ft>) (b <ft>) (c <ft>))))
(sf2 (optional <sft>))
)
(let (
(r1
(if (and
(is-some a1)
(is-some a2)
(is-some sr1)
(is-some xt1)
(is-some xp1)
(is-some vt1)
(is-some sf1))
(some (try! (call-a
(unwrap! a1 e5)
(unwrap! a2 e5)
p1
(unwrap! sr1 e5)
(unwrap! xt1 e5)
(unwrap! xp1 e5)
(unwrap! vt1 e5)
(unwrap! sf1 e5))))
none))
(a-for-r2
(if (is-some r1)
(unwrap! r1 e3)
(unwrap! a1 e5)))
(r2
(if (and
(is-some a3)
(is-some sr2)
(is-some xt2)
(is-some xp2)
(is-some vt2)
(is-some sf2))
(some (try! (call-b
a-for-r2
(unwrap! a3 e5)
p2
(unwrap! sr2 e5)
(unwrap! xt2 e5)
(unwrap! xp2 e5)
(unwrap! vt2 e5)
(unwrap! sf2 e5))))
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
(a uint)
(m uint)
(p (optional principal))
(sr bool)
(xt (tuple (a <ft>) (b <ft>)))
(xp (tuple (a <xpt>)))
(vt (tuple (a <ft>) (b <ft>) (c <ft>)))
(sf <sft>)
)
(contract-call?
'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-xyk-velar-v-1-4
swap-helper-b
a
m
p
sr
xt
xp
vt
sf)
)
(define-private (call-b
(a uint)
(m uint)
(p (optional principal))
(sr bool)
(xt (tuple (a <ft>) (b <ft>)))
(xp (tuple (a <xpt>)))
(vt (tuple (a <ft>) (b <ft>) (c <ft>)))
(sf <sft>)
)
(contract-call?
'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-xyk-velar-v-1-4
swap-helper-b
a
m
p
sr
xt
xp
vt
sf)
)