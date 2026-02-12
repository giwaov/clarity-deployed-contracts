---
title: "Trait byth"
draft: true
---
```
(use-trait ft 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait spt1 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-2.stableswap-pool-trait)
(use-trait xpt1 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-1.xyk-pool-trait)
(use-trait spt2 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-4.stableswap-pool-trait)
(use-trait xpt2 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)
(define-constant e1 (err u5001))
(define-constant e2 (err u5002))
(define-constant e3 (err u5003))
(define-constant e4 (err u5004))
(define-constant e5 (err u5005))
(define-public (grisuri
(a1 (optional uint))
(a2 (optional uint))
(p1 (optional principal))
(sr1 (optional bool))
(st1 (optional (tuple (a <ft>) (b <ft>))))
(sp1 (optional (tuple (a <spt1>))))
(xt1 (optional (tuple (a <ft>) (b <ft>))))
(xp1 (optional (tuple (a <xpt1>))))
(a3 (optional uint))
(p2 (optional principal))
(sr2 (optional bool))
(st2 (optional (tuple (a <ft>) (b <ft>) (c <ft>) (d <ft>))))
(sp2 (optional (tuple (a <spt2>) (b <spt2>))))
(xt2 (optional (tuple (a <ft>) (b <ft>))))
(xp2 (optional (tuple (a <xpt2>))))
)
(let (
(r1
(if (and
(is-some a1)
(is-some a2)
(is-some sr1)
(is-some st1)
(is-some sp1)
(is-some xt1)
(is-some xp1))
(some (try! (call-a
(unwrap! a1 e5)
(unwrap! a2 e5)
p1
(unwrap! sr1 e5)
(unwrap! st1 e5)
(unwrap! sp1 e5)
(unwrap! xt1 e5)
(unwrap! xp1 e5))))
none))
(a-for-r2
(if (is-some r1)
(unwrap! r1 e3)
(unwrap! a1 e5)))
(r2
(if (and
(is-some a3)
(is-some sr2)
(is-some st2)
(is-some sp2)
(is-some xt2)
(is-some xp2))
(some (try! (call-b
a-for-r2
(unwrap! a3 e5)
p2
(unwrap! sr2 e5)
(unwrap! st2 e5)
(unwrap! sp2 e5)
(unwrap! xt2 e5)
(unwrap! xp2 e5))))
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
(st (tuple (a <ft>) (b <ft>)))
(sp (tuple (a <spt1>)))
(xt (tuple (a <ft>) (b <ft>)))
(xp (tuple (a <xpt1>)))
)
(contract-call?
'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-v-1-3
swap-helper-a
a
m
p
sr
st
sp
xt
xp)
)
(define-private (call-b
(a uint)
(m uint)
(p (optional principal))
(sr bool)
(st (tuple (a <ft>) (b <ft>) (c <ft>) (d <ft>)))
(sp (tuple (a <spt2>) (b <spt2>)))
(xt (tuple (a <ft>) (b <ft>)))
(xp (tuple (a <xpt2>)))
)
(contract-call?
'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2
swap-helper-d
a
m
p
sr
st
sp
xt
xp)
)
```
