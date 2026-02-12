---
title: "Trait nova-event-logger"
draft: true
---
```

;; nova-event-logger.clar
;; Central logging
;; CLARITY VERSION: 2

(define-public (log-event (topic (string-ascii 32)) (data (buff 128)))
    (begin
        (print {topic: topic, data: data})
        (ok true)
    )
)

```
