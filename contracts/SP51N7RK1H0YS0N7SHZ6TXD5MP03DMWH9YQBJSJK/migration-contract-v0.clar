;; COFUND State Migration - USING MIGRATION FUNCTIONS
;; Generated: 2026-01-02T18:09:11.672Z
;; Source: SP3EDVXPRGV4QFAAKJSHN0MFD2T0DAFW9ZZMXJWKH

(if is-in-mainnet
  (begin
    (try! (contract-call? .cf-helpers-state-v0 set-migration-writer
      (as-contract tx-sender)
    ))

    ;; Usage: Deploy a migration contract that calls these functions

    ;; SETUP INSTRUCTIONS:
    ;; 1. Deploy this code as a migration contract
    ;; 2. Call cf-helpers-state-v0.set-migration-writer with this contract's address
    ;; 3. Call this migration contract to execute all the function calls below
    ;; 4. Migration will be automatically locked after complete-migration is called

    ;; CLIENT 1: cf-vault-setdevx-v0
    ;; ID: 0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
    ;; Users: 13 | Admins: 6 | Policies: 15

    ;; --- Client Registration ---
    (try! (contract-call? .cf-helpers-state-v0 migration-set-client
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      (some "BUSINESS") (some u6)
    ))

    ;; --- Users (13) ---
    ;; admin [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "7969df4c-4b21-4fd2-9bac-4a167b73ce38"
      'SPY9ZGWGXFPP3P4VP41GF1PJNSTGHF1PA457T95K
      0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
      "admin" true true
    ))
    ;; CTO [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "237c0633-6fb1-4f6e-9ef4-a5c1392c31c1"
      'SP3ASDZZ5CKTK48KY8JEKXW93CD9J28GXG6C2A86T
      0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
      "CTO" true true
    ))
    ;; Business Development Analyst [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "38ffd350-4e85-41d9-9aef-f7ae084e6ac9"
      'SP2E3GBVAYEHMBDZ8G58AYVJFT0H8NGZG22GFKDNQ
      0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4
      "Business Development Analyst" true true
    ))
    ;; Fullstack Engineer
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "3371ea4b-955f-445a-9589-0613a7629c68"
      'SP361WPGWE4G7V4YBE68RA6H4T62MVZ59KP7TV83S
      0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7
      "Fullstack Engineer" true false
    ))
    ;; Product Designer
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "a34a17b8-5142-4e27-8abb-5c6dc212b951"
      'SPCM39VTTFM1G1MHQQ3X5504BTZECBTET8EVHP58
      0x038b08f2985ad8dd8971daccda7ba4de7e31844b4172f5ed03e7a2ff64cf12258f
      "Product Designer" true false
    ))
    ;; Owner [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "e539116e-ac24-4364-ac1a-2c88966d6d67"
      'SP1BAVATC1KCYT1NVXXDY0G0CWJ1WRQGZ6N2ZZSH0
      0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b
      "Owner" true true
    ))
    ;; Bitcoin Engineer
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "3a637814-0f9a-484c-9e22-5a776137f4d7"
      'SP3TH7WKZCDJDPYZWMF5KCZ881K9AWRRG2DP7KXJQ
      0x03be23e1bc5ea3af7ade14ce0e664fdd172ff849b78f29219ba229a80227b092e4
      "Bitcoin Engineer" true false
    ))
    ;; Blockchain Engineer
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "e8ae226a-14e4-465c-9149-1903502d6788"
      'SP1M0XPQCCX02BT5AA5JR5RMJ098HYGND6FZAXAYH
      0x03495ba35af51bf9a7578e89af42a0e526a692f4f9c6b896d8b8e5203f52a7a03a
      "Blockchain Engineer" true false
    ))
    ;; Brand Director
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "4e11e8f0-2f29-4c39-ae90-8c261f315cc1"
      'SP33PJ63KJTP1MDDKYJEM02D7SKJP148YS97Y6S93
      0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c
      "Brand Director" true false
    ))
    ;; Marketing Specialist [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "27d6df91-86ac-4bca-ba3f-b755afc34fe5"
      'SP3XPQ93W05QMBR3FHVAV0E6VGWF0ZA4XZCK6SZ24
      0x036d77820314c8cf4742d8a48d87547e22ce98d7a9c19ddee40fcec2497fde74e5
      "Marketing Specialist" true true
    ))
    ;; Accountant [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "8725ee7e-952d-49f0-8313-10bdba540d02"
      'SP3KC624YG0QB45XVW302T6GTS69F18W3Q517CKF0
      0x0261d80ea65409d0b4d430351e79297d9fee8828f33b740e146c365690c73c5f85
      "Accountant" true true
    ))
    ;; Tester
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "c204c6ca-253b-4b23-a77a-974e77c4df64"
      'SP2MZJ2V90P4QYBWDDSNG6MJZGT3VPRYQYXKVRJAM
      0x02fc9857149fcc278f01267edc9f16361fba99441293255a6b3ec83eab0cab2f9e
      "Tester" true false
    ))
    ;; SetDev Engineer
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "b2934ec4-7b52-4f46-9a69-2b21b92705ac"
      'SP1YQR9EBHFRDYWYZ4T591GWVM0PRKJXTCW570FWZ
      0x03c2657685b87a2ea61fdebcef4e9e18ec7ccffb80ec45db689c3de924be2a65ab
      "SetDev Engineer" true false
    ))

    ;; --- Policies (15) ---
    ;; Stipend Deposit (STX) [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "83530861-224e-4880-a5f6-db44f65e4c07" true "Stipend Deposit (STX)"
      "Contractor_Stipend"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
      )
      u2 none none
    ))
    ;; Stipend Deposit Real (STX) [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "c4565041-e066-4aa4-a76b-6f4994128d45" true "Stipend Deposit Real (STX)"
      "Crypto_Onramp"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
      )
      u2 none none
    ))
    ;; Hz Biweekly Stipend (STX) [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "aa6bed3a-be93-42d7-8243-fb4f564ebc44" true "Hz Biweekly Stipend (STX)"
      "Contractor_Stipend"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
      )
      u2 none none
    ))
    ;; Chigala Biweekly Stipend (STX) [TRANSACTION] - Threshold: 2/3
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "194f39cd-1080-4a8a-9bb7-975131913d4c" true
      "Chigala Biweekly Stipend (STX)" "Contractor_Stipend"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7
      )
      u2 none none
    ))
    ;; Bitflow Stacks DEX [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "68b7aa2f-2276-4579-8d7b-22c27706dd99" true "Bitflow Stacks DEX"
      "Treasury_Management"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
      )
      u2 none none
    ))
    ;; Test Expense [TRANSACTION] - Threshold: 2/5
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "9ff5d94e-b85b-4cfe-8b2f-3da03210d114" true "Test Expense"
      "Operational_Expense"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4
        0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b
        0x03be23e1bc5ea3af7ade14ce0e664fdd172ff849b78f29219ba229a80227b092e4
      )
      u2 none none
    ))
    ;; Test STX Deposit [TRANSACTION] - Threshold: 2/7
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "aa3c2fb2-acf2-46d6-bc20-034989fbe74c" true "Test STX Deposit"
      "Crypto_Onramp"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4
        0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b
        0x03be23e1bc5ea3af7ade14ce0e664fdd172ff849b78f29219ba229a80227b092e4
        0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7
        0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c
      )
      u2 none none
    ))
    ;; Test Reimbursement [TRANSACTION] - Threshold: 2/6
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "7143977e-04a8-4ee0-84ab-3c391d4862c6" true "Test Reimbursement"
      "Operational_Expense"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b
        0x03be23e1bc5ea3af7ade14ce0e664fdd172ff849b78f29219ba229a80227b092e4
        0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7
        0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c
      )
      u2 none none
    ))
    ;; Shakti Test Deposit [TRANSACTION] - Threshold: 2/7
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "55d19e12-c345-4b37-bff4-1e5b78251f7b" true "Shakti Test Deposit"
      "Crypto_Onramp"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4
        0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b
        0x03495ba35af51bf9a7578e89af42a0e526a692f4f9c6b896d8b8e5203f52a7a03a
        0x03be23e1bc5ea3af7ade14ce0e664fdd172ff849b78f29219ba229a80227b092e4
        0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7
      )
      u2 none none
    ))
    ;; Shakti Test [TRANSACTION] - Threshold: 2/8
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "7dc12649-ff07-47c4-92a9-642b4399823b" true "Shakti Test"
      "Operational_Expense"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4
        0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b
        0x03be23e1bc5ea3af7ade14ce0e664fdd172ff849b78f29219ba229a80227b092e4
        0x03495ba35af51bf9a7578e89af42a0e526a692f4f9c6b896d8b8e5203f52a7a03a
        0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7
        0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c
      )
      u2 none none
    ))
    ;; Quick Deposit Test [TRANSACTION] - Threshold: 4/5
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "e305f478-a399-4ab7-b284-e1c23fe54544" true "Quick Deposit Test"
      "Crypto_Onramp"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4
        0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b
        0x03be23e1bc5ea3af7ade14ce0e664fdd172ff849b78f29219ba229a80227b092e4
      )
      u4 none none
    ))
    ;; Stipend Jake STX [TRANSACTION] - Threshold: 2/3
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "02b33fd1-9952-4843-b04a-506f4cde38f7" true "Stipend Jake STX"
      "Contractor_Stipend"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c
      )
      u2 none none
    ))
    ;; Hackathon Winner Test [TRANSACTION] - Threshold: 2/6
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "6b4458f7-d18f-45e3-998d-ec97eed5a524" true "Hackathon Winner Test"
      "Operational_Expense"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4
        0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b
        0x03be23e1bc5ea3af7ade14ce0e664fdd172ff849b78f29219ba229a80227b092e4
        0x03495ba35af51bf9a7578e89af42a0e526a692f4f9c6b896d8b8e5203f52a7a03a
      )
      u2 none none
    ))
    ;; Gina Test Example [TRANSACTION] - Threshold: 2/3
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "789ac960-b3b9-4620-b7e9-793e25a30377" true "Gina Test Example"
      "Operational_Expense"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4
      )
      u2 none none
    ))
    ;; Q1 - 26' Grants [TRANSACTION] - Threshold: 2/6
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6671160fef5a456034fe2053e45faef2c78a1432ac09d3aa945e94f73ada475e
      "646e5a3b-06c4-487a-b904-2228b489553f" true "Q1 - 26' Grants"
      "Operational_Expense"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x02bdf7fe05a9fb9b82e7b38dab3781bc4cbe3c594edf48b5be155b75051d6fe4f4
        0x03993c60ec21483462225c83d8156b9ed901f6ff4544044afe427ec68fb5dfb89b
        0x03495ba35af51bf9a7578e89af42a0e526a692f4f9c6b896d8b8e5203f52a7a03a
        0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7
      )
      u2 none none
    ))

    ;; CLIENT 2: cf-vault-stacks-labs-v1
    ;; ID: 0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81
    ;; Users: 2 | Admins: 2 | Policies: 5

    ;; --- Client Registration ---
    (try! (contract-call? .cf-helpers-state-v0 migration-set-client
      0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81
      (some "BUSINESS") (some u2)
    ))

    ;; --- Users (2) ---
    ;; admin [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81
      "314bba3e-c725-4604-8cdd-032e6712a14f"
      'SP26P9FZDQ8BP056FVQCEKFNKMWKNVBK9E0NJD9G9
      0x038d7bf5b05d93124721bb3c06dfa2b2d8160586f69d37314a4abf8d01dabaa055
      "admin" true true
    ))
    ;; Chief of Staff [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81
      "a242301f-1437-469f-94bc-67c88b97d36e"
      'SP18H0DSF6820PWR8REEHFY84NT2PGNQK2NPJNA3Y
      0x025de5a5a3415b06a4ba7db4cd83f01138e5364252e592b82ee19e43a89207198d
      "Chief of Staff" true true
    ))

    ;; --- Policies (5) ---
    ;; Test Deposit [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81
      "7c79eb9e-b16c-4939-8be6-71721c1f1a81" true "Test Deposit"
      "Crypto_Onramp"
      (list
        0x038d7bf5b05d93124721bb3c06dfa2b2d8160586f69d37314a4abf8d01dabaa055
        0x025de5a5a3415b06a4ba7db4cd83f01138e5364252e592b82ee19e43a89207198d
      )
      u2 none none
    ))
    ;; Test Spend [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81
      "ff86a7b9-b37a-4d73-a526-6bd3934cdc67" true "Test Spend"
      "Operational_Expense"
      (list
        0x038d7bf5b05d93124721bb3c06dfa2b2d8160586f69d37314a4abf8d01dabaa055
        0x025de5a5a3415b06a4ba7db4cd83f01138e5364252e592b82ee19e43a89207198d
      )
      u2 none none
    ))
    ;; General Onramping [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81
      "299c4a6a-2230-4add-a00c-6884b74420c0" true "General Onramping"
      "Crypto_Onramp"
      (list
        0x038d7bf5b05d93124721bb3c06dfa2b2d8160586f69d37314a4abf8d01dabaa055
        0x025de5a5a3415b06a4ba7db4cd83f01138e5364252e592b82ee19e43a89207198d
      )
      u2 none none
    ))
    ;; STX Spend [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81
      "b7863cae-06c2-496c-974c-d9d481ded65c" true "STX Spend"
      "Contractor_Stipend"
      (list
        0x038d7bf5b05d93124721bb3c06dfa2b2d8160586f69d37314a4abf8d01dabaa055
        0x025de5a5a3415b06a4ba7db4cd83f01138e5364252e592b82ee19e43a89207198d
      )
      u2 none none
    ))
    ;; sBTC Spend [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6dff2a941fbd4b880a2c98d541beb6a0b54661e314286b298f8118ddce00de81
      "0c005fdf-7d28-4d65-9dae-2c679d62fde5" true "sBTC Spend"
      "Contractor_Stipend"
      (list
        0x038d7bf5b05d93124721bb3c06dfa2b2d8160586f69d37314a4abf8d01dabaa055
        0x025de5a5a3415b06a4ba7db4cd83f01138e5364252e592b82ee19e43a89207198d
      )
      u2 none none
    ))

    ;; COMPLETE MIGRATION
    (try! (contract-call? .cf-helpers-state-v0 complete-migration))
  )

  false
)
