;; Performance Analytics Contract
;; Monitors and analyzes energy improvements across the smart city

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u500))
(define-constant err-invalid-data (err u501))
(define-constant err-report-not-found (err u502))

;; Performance metrics
(define-map performance-metrics
  { building-id: uint, metric-type: (string-ascii 30), period: uint }
  {
    value: uint,
    timestamp: uint,
    comparison-baseline: uint,
    improvement-percentage: uint,
    recorded-by: principal
  }
)

;; City-wide analytics
(define-map city-analytics
  uint ;; period (monthly)
  {
    total-consumption: uint,
    total-savings: uint,
    average-efficiency: uint,
    buildings-improved: uint,
    carbon-reduction: uint,
    renewable-percentage: uint
  }
)

;; Performance reports
(define-map performance-reports
  uint ;; report-id
  {
    report-type: (string-ascii 50),
    building-id: uint,
    period-start: uint,
    period-end: uint,
    summary: (string-ascii 500),
    recommendations: (string-ascii 500),
    created-at: uint,
    created-by: principal
  }
)

;; Report counter
(define-data-var report-counter uint u0)

;; Metric types
(define-constant ENERGY-CONSUMPTION "energy-consumption")
(define-constant EFFICIENCY-SCORE "efficiency-score")
(define-constant COST-SAVINGS "cost-savings")
(define-constant CARBON-FOOTPRINT "carbon-footprint")

;; Record performance metric
(define-public (record-metric
  (building-id uint)
  (metric-type (string-ascii 30))
  (period uint)
  (value uint)
  (comparison-baseline uint))
  (let ((improvement-percentage
         (if (and (> comparison-baseline u0) (< value comparison-baseline))
           (/ (* (- comparison-baseline value) u100) comparison-baseline)
           u0)))

    (asserts! (> value u0) err-invalid-data)

    (map-set performance-metrics
      { building-id: building-id, metric-type: metric-type, period: period }
      {
        value: value,
        timestamp: block-height,
        comparison-baseline: comparison-baseline,
        improvement-percentage: improvement-percentage,
        recorded-by: tx-sender
      })

    (ok improvement-percentage)))

;; Generate performance report
(define-public (generate-report
  (report-type (string-ascii 50))
  (building-id uint)
  (period-start uint)
  (period-end uint)
  (summary (string-ascii 500))
  (recommendations (string-ascii 500)))
  (let ((report-id (+ (var-get report-counter) u1)))

    (map-set performance-reports
      report-id
      {
        report-type: report-type,
        building-id: building-id,
        period-start: period-start,
        period-end: period-end,
        summary: summary,
        recommendations: recommendations,
        created-at: block-height,
        created-by: tx-sender
      })

    (var-set report-counter report-id)
    (ok report-id)))

;; Update city analytics
(define-public (update-city-analytics
  (period uint)
  (total-consumption uint)
  (total-savings uint)
  (average-efficiency uint)
  (buildings-improved uint)
  (carbon-reduction uint)
  (renewable-percentage uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)

    (map-set city-analytics
      period
      {
        total-consumption: total-consumption,
        total-savings: total-savings,
        average-efficiency: average-efficiency,
        buildings-improved: buildings-improved,
        carbon-reduction: carbon-reduction,
        renewable-percentage: renewable-percentage
      })

    (ok true)))

;; Get performance metric
(define-read-only (get-performance-metric
  (building-id uint)
  (metric-type (string-ascii 30))
  (period uint))
  (map-get? performance-metrics { building-id: building-id, metric-type: metric-type, period: period }))

;; Get city analytics
(define-read-only (get-city-analytics (period uint))
  (map-get? city-analytics period))

;; Get performance report
(define-read-only (get-performance-report (report-id uint))
  (map-get? performance-reports report-id))

;; Get total reports count
(define-read-only (get-reports-count)
  (var-get report-counter))

;; Calculate building efficiency trend
(define-read-only (calculate-efficiency-trend (building-id uint) (start-period uint) (end-period uint))
  (let ((start-metric (map-get? performance-metrics
                        { building-id: building-id, metric-type: EFFICIENCY-SCORE, period: start-period }))
        (end-metric (map-get? performance-metrics
                      { building-id: building-id, metric-type: EFFICIENCY-SCORE, period: end-period })))
    (match start-metric
      start-data
      (match end-metric
        end-data
        (let ((start-value (get value start-data))
              (end-value (get value end-data)))
          (if (> start-value u0)
            (some (/ (* (- end-value start-value) u100) start-value))
            none))
        none)
      none)))
