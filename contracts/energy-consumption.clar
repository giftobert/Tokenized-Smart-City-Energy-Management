;; Energy Consumption Contract
;; Tracks energy usage patterns for buildings

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-building-not-found (err u201))
(define-constant err-invalid-consumption (err u202))
(define-constant err-unauthorized (err u203))

;; Energy consumption data
(define-map energy-consumption
  { building-id: uint, period: uint }
  {
    kwh-consumed: uint,
    cost: uint,
    timestamp: uint,
    meter-reading: uint,
    reported-by: principal
  }
)

;; Monthly consumption totals
(define-map monthly-totals
  { building-id: uint, year: uint, month: uint }
  { total-kwh: uint, total-cost: uint, readings-count: uint }
)

;; Authorized meter readers
(define-map authorized-readers principal bool)

;; Period counter for each building
(define-map building-periods uint uint)

;; Add authorized meter reader
(define-public (add-meter-reader (reader principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set authorized-readers reader true)
    (ok true)))

;; Record energy consumption
(define-public (record-consumption
  (building-id uint)
  (kwh-consumed uint)
  (cost uint)
  (meter-reading uint))
  (let ((period (+ (default-to u0 (map-get? building-periods building-id)) u1))
        (current-year (/ block-height u52560)) ;; Approximate blocks per year
        (current-month (mod (/ block-height u4380) u12))) ;; Approximate blocks per month

    (asserts! (default-to false (map-get? authorized-readers tx-sender)) err-unauthorized)
    (asserts! (> kwh-consumed u0) err-invalid-consumption)

    ;; Record consumption
    (map-set energy-consumption
      { building-id: building-id, period: period }
      {
        kwh-consumed: kwh-consumed,
        cost: cost,
        timestamp: block-height,
        meter-reading: meter-reading,
        reported-by: tx-sender
      })

    ;; Update period counter
    (map-set building-periods building-id period)

    ;; Update monthly totals
    (match (map-get? monthly-totals { building-id: building-id, year: current-year, month: current-month })
      existing-total
      (map-set monthly-totals
        { building-id: building-id, year: current-year, month: current-month }
        {
          total-kwh: (+ (get total-kwh existing-total) kwh-consumed),
          total-cost: (+ (get total-cost existing-total) cost),
          readings-count: (+ (get readings-count existing-total) u1)
        })
      (map-set monthly-totals
        { building-id: building-id, year: current-year, month: current-month }
        {
          total-kwh: kwh-consumed,
          total-cost: cost,
          readings-count: u1
        }))

    (ok period)))

;; Get consumption data
(define-read-only (get-consumption (building-id uint) (period uint))
  (map-get? energy-consumption { building-id: building-id, period: period }))

;; Get monthly total
(define-read-only (get-monthly-total (building-id uint) (year uint) (month uint))
  (map-get? monthly-totals { building-id: building-id, year: year, month: month }))

;; Get current period for building
(define-read-only (get-current-period (building-id uint))
  (default-to u0 (map-get? building-periods building-id)))

;; Check if user is authorized meter reader
(define-read-only (is-authorized-reader (reader principal))
  (default-to false (map-get? authorized-readers reader)))
