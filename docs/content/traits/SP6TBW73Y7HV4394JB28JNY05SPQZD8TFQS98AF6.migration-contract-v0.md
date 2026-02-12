---
title: "Trait migration-contract-v0"
draft: true
---
```
;; COFUND State Migration - USING MIGRATION FUNCTIONS
;; Generated: 2026-01-02T15:28:09.240Z
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

    ;; CLIENT 1: cf-vault-setdevv6-v0
    ;; ID: 0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
    ;; Users: 20 | Admins: 5 | Policies: 24

    ;; --- Client Registration ---
    (try! (contract-call? .cf-helpers-state-v0 migration-set-client
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      (some "BUSINESS") (some u5)
    ))

    ;; --- Users (20) ---
    ;; admin [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "41d29cd6-c178-4329-bab2-d2cca72e6f4f"
      'SPY9ZGWGXFPP3P4VP41GF1PJNSTGHF1PA457T95K
      0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
      "admin" true true
    ))
    ;; Lead Engineer [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "7396c57d-142b-4347-8180-0c0b088c0cfc"
      'SP3ASDZZ5CKTK48KY8JEKXW93CD9J28GXG6C2A86T
      0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
      "Lead Engineer" true true
    ))
    ;; Frontend Engineer
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "e0503057-61f5-445d-9c36-30949002389b"
      'SPBG14D0PB8AW404D9HV2T8MTNTZ7TWGVNHGPC51
      0x0268a54270b0853683a82fd296c4eba7f8d026dfe1f0cef8501ab5326ed52c7da2
      "Frontend Engineer" true false
    ))
    ;; Founder [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "095007f6-1d21-409f-8ab8-ccfe7d50fb2a"
      'SP13C2S8A51CM80V0D6KKMAJBQ6H85ZG05XD8FSDD
      0x03eb66f287acce5e54b947773f9749f4f1b1db05c2a1c911b0ce11d29b1949edf7
      "Founder" true true
    ))
    ;; Software Engineer
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "9447d49f-c0d5-4531-af68-e5b393619fe0"
      'SP361WPGWE4G7V4YBE68RA6H4T62MVZ59KP7TV83S
      0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7
      "Software Engineer" true false
    ))
    ;; Bitcoin Engineer
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "c0f9af8c-d6c1-4917-ab69-04d39c3801f9"
      'SPSEWYZPPNBNYSATD6NX39DA9D741RPY3DQ62H38
      0x0389b7269733631ee0bbb1a8fedb1b697fde2db82c5897b2df5bee799369594f85
      "Bitcoin Engineer" true false
    ))
    ;; Business Analyst
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "4bf86105-b1a8-4045-bf9f-ae180f5fe3c5"
      'SP12MYRAZ3AMT5DRYEGR6TCHHZYAJ38NW362W821K
      0x024627db4edbcb542f34fd08abdc3ef8b451030f176efba4dce1eb055d6fad7ff1
      "Business Analyst" true false
    ))
    ;; Software Engineer
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "805052fa-a009-4243-a82d-93fcdba68132"
      'SP2RBX2BSCRFRCC5G6H7ESSK9M9JZZEC7ANKKKXC
      0x030fcee6b52058c589458c4b95d886985202cc6be9b6fa3d3d4d8bc947cab7ba1c
      "Software Engineer" true false
    ))
    ;; Tester
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "0ab51ca7-48bb-4aec-84f2-c880eed8e6a4"
      'SP1FTZ7DTK7K3C28F63D6W1TVF5P7TDWHR69D6K2H
      0x02da41c589793234b59861bc2f607bf1d268384762a568b2e6fb48127615cc3e30
      "Tester" true false
    ))
    ;; Bitcoin Engineer
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "7b57dd34-ca7c-4cb6-b31a-60c89398d1d8"
      'SP2K1ZPKB5J1DYYW0SYJQQ5MF4EZQKES2Q056673K
      0x020471d94d1876bb256bb897e3ff369000d9698fbe767c46e7f92827e40bc3c9b2
      "Bitcoin Engineer" true false
    ))
    ;; Tester
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "9501201a-6d55-4b19-8697-927026d6d19c"
      'SP33PJ63KJTP1MDDKYJEM02D7SKJP148YS97Y6S93
      0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c
      "Tester" true false
    ))
    ;; Tester
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "5420d656-e72a-4af6-b221-08bb1a41de24"
      'SP17A0ND1QF0YY2G77NGZRWCKAP9RGTSCBH9H87ZM
      0x029326adc1c69b92c2101ba44c5d8cacdffa29f534e017b3f7a8f3e06351524a10
      "Tester" true false
    ))
    ;; Tester
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "335ba3f7-fa4d-481a-ac48-36eadb1c81d0"
      'SP20F2DEMEV7VCDQD3Q3E4PFZ44NRW86833DBKEVE
      0x027a794d285733aa672657e808213930d0fc410c41952e014df299ee6e94ff2f43
      "Tester" true false
    ))
    ;; Smart Contract Engineer
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "6dba8d80-534e-439c-b375-fb4bf7d3402c"
      'SP3RG4WRZKKD51JYS8R3JZFGCKE4D8NFYNF6CP7T6
      0x0315f9bd5dbcee6b166bac1f90eef0326aac6e1f9161bcc857647f49409e29ff96
      "Smart Contract Engineer" true false
    ))
    ;; Business Analyst
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "2e3c609b-ead8-4003-8fdf-f11267ecf243"
      'SP2AR14D4DK2B8XCV9TYY5RRAE7JTKXF8NB614EZV
      0x03c009052c203d8c3eb605067e7956373a6cd94e1ce94e8e00efdc1ed14ffd2103
      "Business Analyst" true false
    ))
    ;; Tester
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "848ebbab-79ce-4d22-8e36-d4324b8a8d6a"
      'SPWNGYG35C5PDD2VQMTAC4R3QWRH7SYS29H26M45
      0x0270a962de549b589f958335816ba5e31963a75c81bb1f91b3e31002dd9ed8dedd
      "Tester" true false
    ))
    ;; Accountant [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "bcff2432-3f23-490d-8431-e43d0a664da3"
      'SP1QXXDDC3SCSZ79QS31VNBDAMP0NWW8PCTBBAYJY
      0x02171bd62c7aa710d110c786fd613f13b8793332719f3efdf9cfb4f0536f78f69c
      "Accountant" true true
    ))
    ;; testing Sspecialist
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "4e2ad508-9827-41ae-9dc0-35c588ffe45f"
      'SP1QXXDDC3SCSZ79QS31VNBDAMP0NWW8PCTBBAYJY
      0x02171bd62c7aa710d110c786fd613f13b8793332719f3efdf9cfb4f0536f78f69c
      "testing Sspecialist" true false
    ))
    ;; Marketing Specialist [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "56461f7c-04e6-459b-849f-c330093e730c"
      'SP3CXGZ7RFQXEWRS18AKS6PJK1BEGH0DFXDM9FR52
      0x02e76eabaa2745e2c6fdab2ca19e176d278dadde2dba7ab576e0b52df556129448
      "Marketing Specialist" true true
    ))
    ;; Brand Director
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "016ffdc6-2673-4173-9f43-0a189fae3a28"
      'SP33PJ63KJTP1MDDKYJEM02D7SKJP148YS97Y6S93
      0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c
      "Brand Director" true false
    ))

    ;; --- Policies (24) ---
    ;; STX Test Deposit [TRANSACTION] - Threshold: 2/7
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "a2e6ae25-3f4b-4251-885b-7aebfb832393" true "STX Test Deposit"
      "Crypto_Onramp"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x03eb66f287acce5e54b947773f9749f4f1b1db05c2a1c911b0ce11d29b1949edf7
        0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7
        0x0389b7269733631ee0bbb1a8fedb1b697fde2db82c5897b2df5bee799369594f85
        0x024627db4edbcb542f34fd08abdc3ef8b451030f176efba4dce1eb055d6fad7ff1
        0x030fcee6b52058c589458c4b95d886985202cc6be9b6fa3d3d4d8bc947cab7ba1c
      )
      u2 none none
    ))
    ;; Test Operational Expense [TRANSACTION] - Threshold: 2/5
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "d99f014d-047c-48e8-aeb1-282fa4acbb7a" true "Test Operational Expense"
      "Operational_Expense"
      (list
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x024627db4edbcb542f34fd08abdc3ef8b451030f176efba4dce1eb055d6fad7ff1
        0x030fcee6b52058c589458c4b95d886985202cc6be9b6fa3d3d4d8bc947cab7ba1c
        0x03eb66f287acce5e54b947773f9749f4f1b1db05c2a1c911b0ce11d29b1949edf7
        0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7
      )
      u2 none none
    ))
    ;; Rijdael Reimbursement [TRANSACTION] - Threshold: 2/3
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "05c20e74-78ab-47e5-8bbe-6848697968c0" true "Rijdael Reimbursement"
      "Operational_Expense"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x02da41c589793234b59861bc2f607bf1d268384762a568b2e6fb48127615cc3e30
      )
      u2 none none
    ))
    ;; Tiny Text Expense [TRANSACTION] - Threshold: 2/4
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "dcdcd474-b111-4a7e-b6a7-61512a8846ae" true "Tiny Text Expense"
      "Operational_Expense"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x03eb66f287acce5e54b947773f9749f4f1b1db05c2a1c911b0ce11d29b1949edf7
        0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7
        0x024627db4edbcb542f34fd08abdc3ef8b451030f176efba4dce1eb055d6fad7ff1
      )
      u2 none none
    ))
    ;; Jake Deposit Test [TRANSACTION] - Threshold: 2/4
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "af9287c8-0ab9-49cb-bf00-e7494117bd83" true "Jake Deposit Test"
      "Crypto_Onramp"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x03eb66f287acce5e54b947773f9749f4f1b1db05c2a1c911b0ce11d29b1949edf7
        0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c
      )
      u2 none none
    ))
    ;; Jake Test Expense [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "74eaee08-8acf-4c85-85f0-30b28bb0fbb9" true "Jake Test Expense"
      "Operational_Expense"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c
      )
      u2 none none
    ))
    ;; Pete Deposit Test [TRANSACTION] - Threshold: 2/4
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "0f6dc8a7-168b-4e36-ae98-dd880271b796" true "Pete Deposit Test"
      "Crypto_Onramp"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x03eb66f287acce5e54b947773f9749f4f1b1db05c2a1c911b0ce11d29b1949edf7
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x029326adc1c69b92c2101ba44c5d8cacdffa29f534e017b3f7a8f3e06351524a10
      )
      u2 none none
    ))
    ;; Intern Stipend [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "151afd1d-6e2e-4260-8df5-39f6c89d2e47" true "Intern Stipend"
      "Contractor_Stipend"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x029326adc1c69b92c2101ba44c5d8cacdffa29f534e017b3f7a8f3e06351524a10
      )
      u2 none none
    ))
    ;; Liquidium Test [TRANSACTION] - Threshold: 2/4
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "afdd53be-088f-49a5-bb01-b0b17fa7ab17" true "Liquidium Test"
      "Crypto_Onramp"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x03eb66f287acce5e54b947773f9749f4f1b1db05c2a1c911b0ce11d29b1949edf7
        0x027a794d285733aa672657e808213930d0fc410c41952e014df299ee6e94ff2f43
      )
      u2 none none
    ))
    ;; Liquidium Conference Expenses [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "492ce8b0-f859-4190-98bd-84c334757f89" true
      "Liquidium Conference Expenses" "Operational_Expense"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x027a794d285733aa672657e808213930d0fc410c41952e014df299ee6e94ff2f43
      )
      u2 none none
    ))
    ;; CoreDAO Test [TRANSACTION] - Threshold: 2/6
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "a2e3a19b-cd0a-409a-bf9a-95f2739f3c10" true "CoreDAO Test"
      "Crypto_Onramp"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x03eb66f287acce5e54b947773f9749f4f1b1db05c2a1c911b0ce11d29b1949edf7
        0x024627db4edbcb542f34fd08abdc3ef8b451030f176efba4dce1eb055d6fad7ff1
        0x030fcee6b52058c589458c4b95d886985202cc6be9b6fa3d3d4d8bc947cab7ba1c
        0x020471d94d1876bb256bb897e3ff369000d9698fbe767c46e7f92827e40bc3c9b2
      )
      u2 none none
    ))
    ;; Hermetica Test [TRANSACTION] - Threshold: 2/4
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "1b20c90e-f1b2-40c5-9c9a-2d6068e9b36d" true "Hermetica Test"
      "Crypto_Onramp"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x0270a962de549b589f958335816ba5e31963a75c81bb1f91b3e31002dd9ed8dedd
        0x020471d94d1876bb256bb897e3ff369000d9698fbe767c46e7f92827e40bc3c9b2
      )
      u2 none none
    ))
    ;; Hermetica Expense Test [TRANSACTION] - Threshold: 2/3
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "e2e72674-07ea-4b57-8a7b-50707913c578" true "Hermetica Expense Test"
      "Operational_Expense"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x0270a962de549b589f958335816ba5e31963a75c81bb1f91b3e31002dd9ed8dedd
      )
      u2 none none
    ))
    ;; Bitflow Signup Discount [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "ce8ebdfc-9955-45c5-b5a7-3f8c7adca7a9" true "Bitflow Signup Discount"
      "Business_Invoice"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
      )
      u2 none none
    ))
    ;; Metalend Testing [TRANSACTION] - Threshold: 3/4
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "466c0723-9331-47ed-beac-75ce4597eed6" true "Metalend Testing"
      "Operational_Expense"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x0270a962de549b589f958335816ba5e31963a75c81bb1f91b3e31002dd9ed8dedd
        0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7
      )
      u3 none none
    ))
    ;; Client Small Reimbursement [TRANSACTION] - Threshold: 2/5
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "bdad55ba-9ba9-4684-be3a-a9ce01ee3392" true "Client Small Reimbursement"
      "Operational_Expense"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7
        0x020471d94d1876bb256bb897e3ff369000d9698fbe767c46e7f92827e40bc3c9b2
        0x0315f9bd5dbcee6b166bac1f90eef0326aac6e1f9161bcc857647f49409e29ff96
      )
      u2 none none
    ))
    ;; Office Supplies [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "69c78237-f088-4d8c-ab8a-c1124d3b85e5" true "Office Supplies"
      "Operational_Expense"
      (list
        0x02171bd62c7aa710d110c786fd613f13b8793332719f3efdf9cfb4f0536f78f69c
        0x02e76eabaa2745e2c6fdab2ca19e176d278dadde2dba7ab576e0b52df556129448
      )
      u2 none none
    ))
    ;; Rootstock Test [TRANSACTION] - Threshold: 4/5
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "adca5284-6529-429c-b935-cb30b2444b17" true "Rootstock Test"
      "Operational_Expense"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x0270a962de549b589f958335816ba5e31963a75c81bb1f91b3e31002dd9ed8dedd
        0x03c009052c203d8c3eb605067e7956373a6cd94e1ce94e8e00efdc1ed14ffd2103
        0x029326adc1c69b92c2101ba44c5d8cacdffa29f534e017b3f7a8f3e06351524a10
      )
      u4 none none
    ))
    ;; Stephen Davis Stipend [TRANSACTION] - Threshold: 2/4
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "2b5abd27-ff65-4e75-9c4c-75abc0ab5d54" true "Stephen Davis Stipend"
      "Contractor_Stipend"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x020471d94d1876bb256bb897e3ff369000d9698fbe767c46e7f92827e40bc3c9b2
        0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7
      )
      u2 none none
    ))
    ;; STX Biweekly Stipend [TRANSACTION] - Threshold: 2/7
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "6f560e20-3b48-4309-8da5-182db2abd507" true "STX Biweekly Stipend"
      "Crypto_Onramp"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7
        0x020471d94d1876bb256bb897e3ff369000d9698fbe767c46e7f92827e40bc3c9b2
        0x0315f9bd5dbcee6b166bac1f90eef0326aac6e1f9161bcc857647f49409e29ff96
        0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c
        0x03c009052c203d8c3eb605067e7956373a6cd94e1ce94e8e00efdc1ed14ffd2103
      )
      u2 none none
    ))
    ;; Hz Stipend Biweekly - STX [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "a5e52202-8935-4f8b-8ae4-c73af4a65157" true "Hz Stipend Biweekly - STX"
      "Contractor_Stipend"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
      )
      u2 none none
    ))
    ;; Chigala Stipend Biweekly - STX [TRANSACTION] - Threshold: 2/3
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "bc357e77-2f63-4d8c-b022-334e661b409c" true
      "Chigala Stipend Biweekly - STX" "Contractor_Stipend"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7
      )
      u2 none none
    ))
    ;; STX Deposit Test Rapha [TRANSACTION] - Threshold: 2/7
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "b94aff39-8b49-43ad-82c4-a08c28fdf37d" true "STX Deposit Test Rapha"
      "Crypto_Onramp"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x02a6f97a43951bf7a01df1e22dd17dc26c98fc422dc965a0e995cd8a78f9ebbbe7
        0x0315f9bd5dbcee6b166bac1f90eef0326aac6e1f9161bcc857647f49409e29ff96
        0x03c009052c203d8c3eb605067e7956373a6cd94e1ce94e8e00efdc1ed14ffd2103
        0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c
        0x020471d94d1876bb256bb897e3ff369000d9698fbe767c46e7f92827e40bc3c9b2
      )
      u2 none none
    ))
    ;; ClarityWG Expenses [TRANSACTION] - Threshold: 2/4
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x7b2ec266289e8e7012f18d805d012d72b709625eade12699b7f3b66b23b0e4cc
      "27f4b6d5-5cf1-40a7-8087-0d1e32a3f76c" true "ClarityWG Expenses"
      "Operational_Expense"
      (list
        0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
        0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
        0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c
        0x0315f9bd5dbcee6b166bac1f90eef0326aac6e1f9161bcc857647f49409e29ff96
      )
      u2 none none
    ))

    ;; CLIENT 2: cf-vault-setdevx-v0
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
    ;; Q1 - 26\' Grants [TRANSACTION] - Threshold: 2/6
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

    ;; CLIENT 3: cf-vault-mainneteer-sep-v0
    ;; ID: 0x116e3be46f3288a45b8216c4ba197e4cfa47867b3ab535a2e07aa5bab0a4e933
    ;; Users: 3 | Admins: 2 | Policies: 0

    ;; --- Client Registration ---
    (try! (contract-call? .cf-helpers-state-v0 migration-set-client
      0x116e3be46f3288a45b8216c4ba197e4cfa47867b3ab535a2e07aa5bab0a4e933
      (some "BUSINESS") (some u2)
    ))

    ;; --- Users (3) ---
    ;; admin [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x116e3be46f3288a45b8216c4ba197e4cfa47867b3ab535a2e07aa5bab0a4e933
      "fd10f058-472b-4a67-8af9-1808969c85cf"
      'SP3ASDZZ5CKTK48KY8JEKXW93CD9J28GXG6C2A86T
      0x024c4a3f178e2a811d299ed1915c5f2df26ec2bad133418fa5afb5761bd67b06d9
      "admin" true true
    ))
    ;; test helper
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x116e3be46f3288a45b8216c4ba197e4cfa47867b3ab535a2e07aa5bab0a4e933
      "ca6fda56-0b68-479c-829e-33116be63e1d"
      'SP1E3EHX70RRZASSSSFDZ6HY334HFY4A5JZMAH5QK
      0x02b6c2ec6c6bae67df8d7a0c76549581d0c2df1db803b1863c3781e25e00cba5f2
      "test helper" true false
    ))
    ;; CEO [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x116e3be46f3288a45b8216c4ba197e4cfa47867b3ab535a2e07aa5bab0a4e933
      "28507383-1134-41ab-8982-4268d797ead3"
      'SPY9ZGWGXFPP3P4VP41GF1PJNSTGHF1PA457T95K
      0x037942b278c501aae9cdc5ad3112bc176fee26c0be3f2ec9bd3d5561a1615a71ba
      "CEO" true true
    ))

    ;; CLIENT 4: cf-vault-bff-pool-test-9-25-v0
    ;; ID: 0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5
    ;; Users: 3 | Admins: 3 | Policies: 4

    ;; --- Client Registration ---
    (try! (contract-call? .cf-helpers-state-v0 migration-set-client
      0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5
      (some "BUSINESS") (some u3)
    ))

    ;; --- Users (3) ---
    ;; admin [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5
      "6e9b8d19-4fce-407b-b71d-29a9aa7d7320"
      'SP1F0SRJBWK10VYAFXGADEK0JCJGW6CF6N1G46NYJ
      0x02b2755a3b842fb5d9dbb2a509fe43b43abb4352ba4add8560f10f59541dbea75c
      "admin" true true
    ))
    ;; rsar [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5
      "5d8a0e81-616d-4f3c-b566-55789191d960"
      'SPMM93EWFYEMGFYC2C32VY2W4J8XARHB25JE8BR
      0x02e3734f53c46b574386c3d5aa176fe77385b4d2d1d7d18b8bd657a5ed92b1d732
      "rsar" true true
    ))
    ;; rsar [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5
      "03075972-d8db-4bb5-b9ec-24ce928b4638"
      'SPMM93EWFYEMGFYC2C32VY2W4J8XARHB25JE8BR
      0x02e3734f53c46b574386c3d5aa176fe77385b4d2d1d7d18b8bd657a5ed92b1d732
      "rsar" true true
    ))

    ;; --- Policies (4) ---
    ;; Bitflow Stacks Pool [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5
      "5432a7e3-d602-494f-988c-bf40fd7e7127" true "Bitflow Stacks Pool"
      "Treasury_Management"
      (list
        0x02b2755a3b842fb5d9dbb2a509fe43b43abb4352ba4add8560f10f59541dbea75c
        0x02e3734f53c46b574386c3d5aa176fe77385b4d2d1d7d18b8bd657a5ed92b1d732
      )
      u2 none none
    ))
    ;; Bitflow Stacks DEX [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5
      "542d7e24-2dcd-482f-bf13-966a15c9b9fa" true "Bitflow Stacks DEX"
      "Treasury_Management"
      (list
        0x02b2755a3b842fb5d9dbb2a509fe43b43abb4352ba4add8560f10f59541dbea75c
        0x02e3734f53c46b574386c3d5aa176fe77385b4d2d1d7d18b8bd657a5ed92b1d732
      )
      u2 none none
    ))
    ;; usdh send [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5
      "b0eddc56-d3c2-49b1-b7e6-f79683893342" true "usdh send"
      "Contractor_Stipend"
      (list
        0x02b2755a3b842fb5d9dbb2a509fe43b43abb4352ba4add8560f10f59541dbea75c
        0x02e3734f53c46b574386c3d5aa176fe77385b4d2d1d7d18b8bd657a5ed92b1d732
      )
      u2 none none
    ))
    ;; usdh send [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0xd95bfb3f29c6125348c1c4001f0c2304dfd5cc4bb865151c6948e19ac9ba52a5
      "c0c55cfe-b400-472c-b8dc-fe3800657924" true "usdh send"
      "Contractor_Stipend"
      (list
        0x02b2755a3b842fb5d9dbb2a509fe43b43abb4352ba4add8560f10f59541dbea75c
        0x02e3734f53c46b574386c3d5aa176fe77385b4d2d1d7d18b8bd657a5ed92b1d732
      )
      u2 none none
    ))

    ;; CLIENT 5: cf-vault-bitflow-v0
    ;; ID: 0x6b06827743347d7d6366b7239bdfc9203bd9a643d34ad847ad6d0cf6a11fd05b
    ;; Users: 2 | Admins: 1 | Policies: 2

    ;; --- Client Registration ---
    (try! (contract-call? .cf-helpers-state-v0 migration-set-client
      0x6b06827743347d7d6366b7239bdfc9203bd9a643d34ad847ad6d0cf6a11fd05b
      (some "BUSINESS") (some u1)
    ))

    ;; --- Users (2) ---
    ;; admin [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x6b06827743347d7d6366b7239bdfc9203bd9a643d34ad847ad6d0cf6a11fd05b
      "b9674850-c69f-4fad-b9cf-03022901506c"
      'SPCC08PD8PD6CYCJN41SWB6C9KZHE1F9A68E35P8
      0x02901e15611a16f38cb38bea48ae301fd52558bb6ae59026586251548ab1d18406
      "admin" true true
    ))
    ;; Entity
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x6b06827743347d7d6366b7239bdfc9203bd9a643d34ad847ad6d0cf6a11fd05b
      "32680492-a2ce-4ca1-b483-5737a0583a9a"
      'SP331EPPKGZJT7KRX16TM0TVYZVQZ36ZD71BJZT29
      0x03273de779d1a94c5c217091fdf56e8d928d814595f6e3529f66ab2f4c515234a9
      "Entity" true false
    ))

    ;; --- Policies (2) ---
    ;; STX 1  [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6b06827743347d7d6366b7239bdfc9203bd9a643d34ad847ad6d0cf6a11fd05b
      "7643e79c-7372-4823-8a7e-8b9154e32991" true "STX 1 " "Crypto_Onramp"
      (list
        0x02901e15611a16f38cb38bea48ae301fd52558bb6ae59026586251548ab1d18406
        0x03273de779d1a94c5c217091fdf56e8d928d814595f6e3529f66ab2f4c515234a9
      )
      u2 none none
    ))
    ;; Marketing Rewards Distribution [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x6b06827743347d7d6366b7239bdfc9203bd9a643d34ad847ad6d0cf6a11fd05b
      "caf2d033-d42a-4371-a253-a7937f36ca90" true
      "Marketing Rewards Distribution" "Operational_Expense"
      (list
        0x02901e15611a16f38cb38bea48ae301fd52558bb6ae59026586251548ab1d18406
        0x03273de779d1a94c5c217091fdf56e8d928d814595f6e3529f66ab2f4c515234a9
      )
      u2 none none
    ))

    ;; CLIENT 6: cf-vault-gazma-v0
    ;; ID: 0xb10ea53cbbb2a5f0e83186e3b034f75fce1c177b3acbb316e565f32525bffe21
    ;; Users: 2 | Admins: 2 | Policies: 2

    ;; --- Client Registration ---
    (try! (contract-call? .cf-helpers-state-v0 migration-set-client
      0xb10ea53cbbb2a5f0e83186e3b034f75fce1c177b3acbb316e565f32525bffe21
      (some "BUSINESS") (some u2)
    ))

    ;; --- Users (2) ---
    ;; admin [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0xb10ea53cbbb2a5f0e83186e3b034f75fce1c177b3acbb316e565f32525bffe21
      "d2630753-bd95-4f8d-8f47-fd4d6b70d14d"
      'SP3KRHRR4NA3K188DEKTCZC6BE1Z8YY36P0SY5W4
      0x030b1c1431f0686d04ef78cecb68e33e70ee4181ddc9e24766aec79048047f0d84
      "admin" true true
    ))
    ;; sub [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0xb10ea53cbbb2a5f0e83186e3b034f75fce1c177b3acbb316e565f32525bffe21
      "0bd6b659-2f1f-4b7f-83f2-af3afe352136"
      'SPT5ZYYSY8ZEVHHHWH6RVK4GT47ZMFRY5PPQCMPR
      0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67
      "sub" true true
    ))

    ;; --- Policies (2) ---
    ;; stx [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0xb10ea53cbbb2a5f0e83186e3b034f75fce1c177b3acbb316e565f32525bffe21
      "e7acd027-358f-421a-a38d-86fdfcd81c72" true "stx" "Crypto_Onramp"
      (list
        0x030b1c1431f0686d04ef78cecb68e33e70ee4181ddc9e24766aec79048047f0d84
        0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67
      )
      u2 none none
    ))
    ;; Bitflow Swap v2 [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0xb10ea53cbbb2a5f0e83186e3b034f75fce1c177b3acbb316e565f32525bffe21
      "c814d380-beab-4a60-9c75-6f399dbd6789" true "Bitflow Swap v2"
      "Operational_Expense"
      (list
        0x030b1c1431f0686d04ef78cecb68e33e70ee4181ddc9e24766aec79048047f0d84
        0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67
      )
      u2 none none
    ))

    ;; CLIENT 7: cf-vault-vdsfvre-v0
    ;; ID: 0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4
    ;; Users: 2 | Admins: 2 | Policies: 4

    ;; --- Client Registration ---
    (try! (contract-call? .cf-helpers-state-v0 migration-set-client
      0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4
      (some "BUSINESS") (some u2)
    ))

    ;; --- Users (2) ---
    ;; admin [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4
      "0932ba39-8e81-4e47-8bc9-302af4e898a5"
      'SP3KRHRR4NA3K188DEKTCZC6BE1Z8YY36P0SY5W4
      0x030b1c1431f0686d04ef78cecb68e33e70ee4181ddc9e24766aec79048047f0d84
      "admin" true true
    ))
    ;; asdgasdt [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4
      "132d75ca-9a77-47e3-89ad-cedf3d555db3"
      'SPT5ZYYSY8ZEVHHHWH6RVK4GT47ZMFRY5PPQCMPR
      0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67
      "asdgasdt" true true
    ))

    ;; --- Policies (4) ---
    ;; Bitflow Stacks DEX [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4
      "0b0bdfc4-9947-4dce-82d4-c75c2408d7ad" true "Bitflow Stacks DEX"
      "Treasury_Management"
      (list
        0x030b1c1431f0686d04ef78cecb68e33e70ee4181ddc9e24766aec79048047f0d84
        0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67
      )
      u2 none none
    ))
    ;; onramp stx [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4
      "cc2ac5cc-5c16-4ea7-a683-d9d76a259eba" true "onramp stx" "Crypto_Onramp"
      (list
        0x030b1c1431f0686d04ef78cecb68e33e70ee4181ddc9e24766aec79048047f0d84
        0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67
      )
      u2 none none
    ))
    ;; Bitflow Stacks DEX [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4
      "66f87402-7a9e-4050-8c60-1e7cbe4d0c0e" true "Bitflow Stacks DEX"
      "Treasury_Management"
      (list
        0x030b1c1431f0686d04ef78cecb68e33e70ee4181ddc9e24766aec79048047f0d84
        0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67
      )
      u2 none none
    ))
    ;; Bitflow Stacks Pool [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x72f59d10b521849f22e60791429ace2f54980e37f80c847ae36bfb61b92ab0f4
      "bd09b870-8c8d-4699-943c-dc44ea00bc28" true "Bitflow Stacks Pool"
      "Treasury_Management"
      (list
        0x030b1c1431f0686d04ef78cecb68e33e70ee4181ddc9e24766aec79048047f0d84
        0x03bd199370c01d119ea15624050bf5575eb3e7a55e5b9b149ee042cc57ffecef67
      )
      u2 none none
    ))

    ;; CLIENT 8: cf-vault-bern-v0
    ;; ID: 0x323ffa49fe23683712e89c19c1247ab948d2cad411f11e76b83d7c6ca3855b08
    ;; Users: 2 | Admins: 2 | Policies: 2

    ;; --- Client Registration ---
    (try! (contract-call? .cf-helpers-state-v0 migration-set-client
      0x323ffa49fe23683712e89c19c1247ab948d2cad411f11e76b83d7c6ca3855b08
      (some "BUSINESS") (some u2)
    ))

    ;; --- Users (2) ---
    ;; admin [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x323ffa49fe23683712e89c19c1247ab948d2cad411f11e76b83d7c6ca3855b08
      "5aed2afd-bfa6-4e01-a840-6e69a1e52d4a"
      'SP1PHRH3ZKY4AF2Z4GMJHDNK2JCSMV7WR8VKW640Z
      0x03dc307626ee8a3325c84792ee42053e1131846501d9d744d43b657e080f23df80
      "admin" true true
    ))
    ;; CEO [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x323ffa49fe23683712e89c19c1247ab948d2cad411f11e76b83d7c6ca3855b08
      "8753cbc7-d17c-459f-91f2-eb3d86d7217e"
      'SP3E9KREM0AZ289XFM1N763XP2MMK70ER8V01F4GV
      0x0356ae5fdffcf403798f37bd7f74bfe06074a83a372cc525b672d97c900028bc9c
      "CEO" true true
    ))

    ;; --- Policies (2) ---
    ;; Onramp [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x323ffa49fe23683712e89c19c1247ab948d2cad411f11e76b83d7c6ca3855b08
      "73ac18b6-e140-4c3c-9d33-e156332fd96b" true "Onramp" "Crypto_Onramp"
      (list
        0x03dc307626ee8a3325c84792ee42053e1131846501d9d744d43b657e080f23df80
        0x0356ae5fdffcf403798f37bd7f74bfe06074a83a372cc525b672d97c900028bc9c
      )
      u2 none none
    ))
    ;; Contractor Pizza party [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x323ffa49fe23683712e89c19c1247ab948d2cad411f11e76b83d7c6ca3855b08
      "ec8f8779-57c6-480a-9e3a-8a54ce7e3861" true "Contractor Pizza party"
      "Contractor_Stipend"
      (list
        0x0356ae5fdffcf403798f37bd7f74bfe06074a83a372cc525b672d97c900028bc9c
        0x03dc307626ee8a3325c84792ee42053e1131846501d9d744d43b657e080f23df80
      )
      u2 none none
    ))

    ;; CLIENT 9: cf-vault-stackslabs-v0
    ;; ID: 0x67237a2fa68610e811b956fe9cf5588bd0f4da958231d76ae00ba7de529f3fca
    ;; Users: 2 | Admins: 2 | Policies: 2

    ;; --- Client Registration ---
    (try! (contract-call? .cf-helpers-state-v0 migration-set-client
      0x67237a2fa68610e811b956fe9cf5588bd0f4da958231d76ae00ba7de529f3fca
      (some "BUSINESS") (some u2)
    ))

    ;; --- Users (2) ---
    ;; admin [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x67237a2fa68610e811b956fe9cf5588bd0f4da958231d76ae00ba7de529f3fca
      "e0df27ec-c058-4722-82d7-e763b58c9765"
      'SP33PJ63KJTP1MDDKYJEM02D7SKJP148YS97Y6S93
      0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c
      "admin" true true
    ))
    ;; Chief of Staff [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x67237a2fa68610e811b956fe9cf5588bd0f4da958231d76ae00ba7de529f3fca
      "7bef551d-db03-4a99-9be2-381740b8130a"
      'SP2J647E7HX31YP9N9VFM2M3T2Y426E0DR8VZWG9S
      0x03c0ebc8ab9079a18e5807b7aa544f43b02d0b5627b5ecdc37b4b5e1dcf9ded0e4
      "Chief of Staff" true true
    ))

    ;; --- Policies (2) ---
    ;; AsignaDeposit [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x67237a2fa68610e811b956fe9cf5588bd0f4da958231d76ae00ba7de529f3fca
      "2a29d35b-5972-49ec-a5b4-86980d1a99dc" true "AsignaDeposit"
      "Crypto_Onramp"
      (list
        0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c
        0x03c0ebc8ab9079a18e5807b7aa544f43b02d0b5627b5ecdc37b4b5e1dcf9ded0e4
      )
      u2 none none
    ))
    ;; Contractor Stipend Test [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0x67237a2fa68610e811b956fe9cf5588bd0f4da958231d76ae00ba7de529f3fca
      "06e65460-b61b-433a-8e0f-10380ccfa60b" true "Contractor Stipend Test"
      "Contractor_Stipend"
      (list
        0x03d250023f173ae729662c95f67d66af50d1d1b81a9f0c106d2adddc1e26fbfd0c
        0x03c0ebc8ab9079a18e5807b7aa544f43b02d0b5627b5ecdc37b4b5e1dcf9ded0e4
      )
      u2 none none
    ))

    ;; CLIENT 10: cf-vault-slacklabso-v0
    ;; ID: 0xd99c4f2b986e9c8077a7e3d3323badb3cacded1f44f3a2f6397b3e61a2153f41
    ;; Users: 2 | Admins: 2 | Policies: 2

    ;; --- Client Registration ---
    (try! (contract-call? .cf-helpers-state-v0 migration-set-client
      0xd99c4f2b986e9c8077a7e3d3323badb3cacded1f44f3a2f6397b3e61a2153f41
      (some "BUSINESS") (some u2)
    ))

    ;; --- Users (2) ---
    ;; admin [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0xd99c4f2b986e9c8077a7e3d3323badb3cacded1f44f3a2f6397b3e61a2153f41
      "611d9305-497c-449a-a980-67672a16b8fb"
      'SP1C1PVWCHFKZBTHE3TY55V2SMTVXQZRYB76MPNW2
      0x026ea2bce965881ada6cf223cb8bb714dea1025cce1d9b52bb4fad02c0fa6c91ff
      "admin" true true
    ))
    ;; CTO [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0xd99c4f2b986e9c8077a7e3d3323badb3cacded1f44f3a2f6397b3e61a2153f41
      "8ba53135-68b0-4f28-87f1-fb470b3528a9"
      'SP372JN80DAFF88A1M5WWK6W4Z3C09J2QCC58V40X
      0x0381a3620f2d6270a2ca4f64dc23e7b1f65145622c159bdecf87ceed9f83ea8f54
      "CTO" true true
    ))

    ;; --- Policies (2) ---
    ;; First Fund [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0xd99c4f2b986e9c8077a7e3d3323badb3cacded1f44f3a2f6397b3e61a2153f41
      "2f79f283-0a5e-4434-ab6b-7d6b1e866be3" true "First Fund" "Crypto_Onramp"
      (list
        0x026ea2bce965881ada6cf223cb8bb714dea1025cce1d9b52bb4fad02c0fa6c91ff
        0x0381a3620f2d6270a2ca4f64dc23e7b1f65145622c159bdecf87ceed9f83ea8f54
      )
      u2 none none
    ))
    ;; Hackathon Winner [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0xd99c4f2b986e9c8077a7e3d3323badb3cacded1f44f3a2f6397b3e61a2153f41
      "6e86ec9f-a5ad-4d56-a965-fbbb9d1e3160" true "Hackathon Winner"
      "Operational_Expense"
      (list
        0x026ea2bce965881ada6cf223cb8bb714dea1025cce1d9b52bb4fad02c0fa6c91ff
        0x0381a3620f2d6270a2ca4f64dc23e7b1f65145622c159bdecf87ceed9f83ea8f54
      )
      u2 none none
    ))

    ;; CLIENT 11: cf-vault-thecompany-v1
    ;; ID: 0xe63d87a47c506c6af71526f3d207eb2a0899d3d25481dcd70c88ca3fc68fe767
    ;; Users: 2 | Admins: 2 | Policies: 2

    ;; --- Client Registration ---
    (try! (contract-call? .cf-helpers-state-v0 migration-set-client
      0xe63d87a47c506c6af71526f3d207eb2a0899d3d25481dcd70c88ca3fc68fe767
      (some "BUSINESS") (some u2)
    ))

    ;; --- Users (2) ---
    ;; admin [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0xe63d87a47c506c6af71526f3d207eb2a0899d3d25481dcd70c88ca3fc68fe767
      "fb35e9ab-3ea6-4afb-8315-159dd64c4b97"
      'SP2K1C03APAKDXH64WXE9TP8TWYDH3YF6GZBTG8K6
      0x032920ce1196cf15be5469036a790d1d07ca3cb80dec71d2c42fc61cd648446d46
      "admin" true true
    ))
    ;; CFO [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0xe63d87a47c506c6af71526f3d207eb2a0899d3d25481dcd70c88ca3fc68fe767
      "8c6ac39a-f5c0-44d0-85de-e69cf39bcbdc"
      'SP1PAZR29JZV186AN8TBTCAHB0MSSKQ3B5VS7MVG5
      0x037bd95193ceea1a1e8640ed17ee42f0ded6014916ff8f0c4a83bd18c5cb60cf6b
      "CFO" true true
    ))

    ;; --- Policies (2) ---
    ;; Initial Onramp [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0xe63d87a47c506c6af71526f3d207eb2a0899d3d25481dcd70c88ca3fc68fe767
      "9413a0ce-504a-4c82-88cc-fc3025624d4d" true "Initial Onramp"
      "Crypto_Onramp"
      (list
        0x032920ce1196cf15be5469036a790d1d07ca3cb80dec71d2c42fc61cd648446d46
        0x037bd95193ceea1a1e8640ed17ee42f0ded6014916ff8f0c4a83bd18c5cb60cf6b
      )
      u2 none none
    ))
    ;; test Send demo  [TRANSACTION] - Threshold: 2/2
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy
      0xe63d87a47c506c6af71526f3d207eb2a0899d3d25481dcd70c88ca3fc68fe767
      "e05f5a17-943a-4cc8-bc82-4c1b5ec5c728" true "test Send demo "
      "Operational_Expense"
      (list
        0x032920ce1196cf15be5469036a790d1d07ca3cb80dec71d2c42fc61cd648446d46
        0x037bd95193ceea1a1e8640ed17ee42f0ded6014916ff8f0c4a83bd18c5cb60cf6b
      )
      u2 none none
    ))

    ;; CLIENT 12: cf-vault-stacks-labs-v1
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

    ;; CLIENT 13: unknown-vault
    ;; ID: 0xbb28ede8de3c53837e0f8219d409f72016cf4fce1e1306c18331e8aa876799b6
    ;; Users: 1 | Admins: 1 | Policies: 0

    ;; --- Client Registration ---
    (try! (contract-call? .cf-helpers-state-v0 migration-set-client
      0xbb28ede8de3c53837e0f8219d409f72016cf4fce1e1306c18331e8aa876799b6
      (some "BUSINESS") (some u1)
    ))

    ;; --- Users (1) ---
    ;; admin [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0xbb28ede8de3c53837e0f8219d409f72016cf4fce1e1306c18331e8aa876799b6
      "e15ef974-5872-4a1a-9f18-d8562c315ab2"
      'SPRE5T1EHBBJCQ6NQ0P6KXZR4844FKDZJSY1XR94
      0x02cf6896b2d1123b00ed1231e4b7c2e3b43b1ce1ce38240788bf76daead1a032ee
      "admin" true true
    ))

    ;; CLIENT 14: unknown-vault
    ;; ID: 0xd64bd927487212f67d16bb3730be888a13c263d9e95bde1a6caabf9c19aca042
    ;; Users: 1 | Admins: 1 | Policies: 0

    ;; --- Client Registration ---
    (try! (contract-call? .cf-helpers-state-v0 migration-set-client
      0xd64bd927487212f67d16bb3730be888a13c263d9e95bde1a6caabf9c19aca042
      (some "BUSINESS") (some u1)
    ))

    ;; --- Users (1) ---
    ;; admin [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0xd64bd927487212f67d16bb3730be888a13c263d9e95bde1a6caabf9c19aca042
      "b284f810-3ebf-423b-8dd9-96d99a6a8db1"
      'SP2GPX7XK9EWBREX9S2BMAKCZ2JFRQG71K2D6ZF36
      0x02184ffe0fcbfe8cad92e05db79389eabca4dff754fbc3fa187d4e8893e2eaf1d6
      "admin" true true
    ))

    ;; CLIENT 15: unknown-vault
    ;; ID: 0x98740df51ad4051bcfaaf388b578797ebd1034fec0af526878154477c3f9a11a
    ;; Users: 1 | Admins: 1 | Policies: 0

    ;; --- Client Registration ---
    (try! (contract-call? .cf-helpers-state-v0 migration-set-client
      0x98740df51ad4051bcfaaf388b578797ebd1034fec0af526878154477c3f9a11a
      (some "BUSINESS") (some u1)
    ))

    ;; --- Users (1) ---
    ;; admin [ADMIN]
    (try! (contract-call? .cf-helpers-state-v0 migration-set-user
      0x98740df51ad4051bcfaaf388b578797ebd1034fec0af526878154477c3f9a11a
      "cab956be-7079-4aaa-84a0-09a08bf87da7"
      'SP2GARQJY0343047WZBJ7D1SVVPGGZSSKZXYZ0QYX
      0x03ca235f2837af63a385bef804a24599245c20dd8d232a87889b38a587cb58e3e7
      "admin" true true
    ))

    ;; GLOBAL POLICY TYPES
    (try! (contract-call? .cf-helpers-state-v0 migration-set-policy-type
      "Treasury_Management"
    ))

    ;; COMPLETE MIGRATION
    (try! (contract-call? .cf-helpers-state-v0 complete-migration))
  )

  false
)

```
