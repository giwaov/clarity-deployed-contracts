;; SPDX-License-Identifier: BUSL-1.1
(impl-trait 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.proposal-trait.proposal-trait)

;; Main execute function
(define-public (execute (sender principal))
  (begin
    ;; Create the vote
    (try! (contract-call? 'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.alex-voting-v1-01 create-vote
      u"ALEX Governance Vote: Quarterly Approval to Utilize Protocol Revenue Towards Operational Costs"
      u"![img](https://imagedelivery.net/Cf_H0cL_1lwKJtdaD6H5NQ/642d5085-d030-4e5f-a485-fb8d607cf300/public)\n\nThe ALEX Lab Foundation is seeking governance approval, to be renewed quarterly, to allocate protocol revenue toward essential operational costs.\n\n\u{1f4d6} Full Proposal: [Click here](https://medium.com/alexgobtc/alex-governance-vote-quarterly-approval-to-utilize-protocol-revenue-towards-operational-costs-a2930d5ce4f9)\n\n\u{23f3} Voting Opens: 28th November 2025 <br>\n\u{231b}\u{fe0f} Voting Closes: 5th December 2025\n\nMake your voice count, be sure to cast your vote \u{2705}"
      u1764308760
      u1764913560
      (list u"Approve" u"Disapprove" u"Abstain")
      none))

    (ok true)))
