(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-forecasted (err u102))
(define-constant err-invalid-probability (err u103))

(define-map forecasters
  principal
  {
    total-forecasts: uint,
    correct-forecasts: uint,
    accuracy-score: uint,
    reputation: uint
  })

(define-map forecast-questions
  uint
  {
    question: (string-ascii 256),
    resolution-block: uint,
    resolved: bool,
    actual-outcome: bool,
    total-forecasts: uint
  })

(define-map user-forecasts
  {question-id: uint, forecaster: principal}
  {predicted-probability: uint, confidence: uint, timestamp: uint})

(define-data-var next-question-id uint u0)

(define-read-only (get-forecaster (user principal))
  (ok (map-get? forecasters user)))

(define-read-only (get-question (question-id uint))
  (ok (map-get? forecast-questions question-id)))

(define-read-only (get-forecast (question-id uint) (forecaster principal))
  (ok (map-get? user-forecasts {question-id: question-id, forecaster: forecaster})))

(define-public (create-question (question (string-ascii 256)) (resolution-time uint))
  (let ((question-id (var-get next-question-id)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set forecast-questions question-id
      {question: question, resolution-block: (+ stacks-block-height resolution-time),
       resolved: false, actual-outcome: false, total-forecasts: u0})
    (var-set next-question-id (+ question-id u1))
    (ok question-id)))

(define-public (submit-forecast (question-id uint) (probability uint) (confidence uint))
  (let ((question (unwrap! (map-get? forecast-questions question-id) err-not-found)))
    (asserts! (<= probability u100) err-invalid-probability)
    (asserts! (< stacks-block-height (get resolution-block question)) err-not-found)
    (asserts! (is-none (map-get? user-forecasts {question-id: question-id, forecaster: tx-sender})) err-already-forecasted)
    (map-set user-forecasts {question-id: question-id, forecaster: tx-sender}
      {predicted-probability: probability, confidence: confidence, timestamp: stacks-block-height})
    (map-set forecast-questions question-id
      (merge question {total-forecasts: (+ (get total-forecasts question) u1)}))
    (ok true)))

(define-public (resolve-question (question-id uint) (outcome bool))
  (let ((question (unwrap! (map-get? forecast-questions question-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (>= stacks-block-height (get resolution-block question)) err-not-found)
    (ok (map-set forecast-questions question-id
      (merge question {resolved: true, actual-outcome: outcome})))))

(define-public (update-forecaster-score (forecaster principal) (was-correct bool))
  (let ((info (default-to {total-forecasts: u0, correct-forecasts: u0, accuracy-score: u0, reputation: u0}
                          (map-get? forecasters forecaster)))
        (new-correct (if was-correct (+ (get correct-forecasts info) u1) (get correct-forecasts info)))
        (new-total (+ (get total-forecasts info) u1))
        (new-accuracy (/ (* new-correct u100) new-total)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set forecasters forecaster
      {total-forecasts: new-total, correct-forecasts: new-correct,
       accuracy-score: new-accuracy, reputation: new-accuracy}))))
