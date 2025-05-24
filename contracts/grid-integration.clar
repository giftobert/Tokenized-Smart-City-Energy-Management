;; Grid Integration Contract
;; Coordinates with utility systems and manages grid connections

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u400))
(define-constant err-building-not-connected (err u401))
(define-constant err-invalid-capacity (err u402))
(define-constant err-grid-overload (err u403))

;; Grid connection data
(define-map grid-connections
  uint ;; building-id
  {
    connected: bool,
    connection-type: (string-ascii 20),
    max-capacity: uint,
    current-load: uint,
    grid-zone: uint,
    connection-date: uint,
    smart-meter-id: (string-ascii 50)
  }
)

;; Grid zones and their capacity
(define-map grid-zones
  uint ;; zone-id
  {
    total-capacity: uint,
    current-usage: uint,
    buildings-count: uint,
    zone-name: (string-ascii 50),
    status: (string-ascii 20)
  }
)

;; Load balancing data
(define-map load-balancing
  { zone-id: uint, timestamp: uint }
  {
    peak-demand: uint,
    average-load: uint,
    efficiency-rating: uint,
    renewable-percentage: uint
  }
)

;; Energy trading between buildings
(define-map energy-trades
  { seller-building: uint, buyer-building: uint, trade-id: uint }
  {
    energy-amount: uint,
    price-per-kwh: uint,
    trade-timestamp: uint,
    status: (string-ascii 20)
  }
)

;; Trade counter
(define-data-var trade-counter uint u0)

;; Connect building to grid
(define-public (connect-to-grid
  (building-id uint)
  (connection-type (string-ascii 20))
  (max-capacity uint)
  (grid-zone uint)
  (smart-meter-id (string-ascii 50)))
  (begin
    (asserts! (> max-capacity u0) err-invalid-capacity)

    ;; Update grid zone capacity
    (match (map-get? grid-zones grid-zone)
      zone-data
      (map-set grid-zones
        grid-zone
        (merge zone-data { buildings-count: (+ (get buildings-count zone-data) u1) }))
      (map-set grid-zones
        grid-zone
        {
          total-capacity: u10000, ;; Default zone capacity
          current-usage: u0,
          buildings-count: u1,
          zone-name: "Zone",
          status: "active"
        }))

    (map-set grid-connections
      building-id
      {
        connected: true,
        connection-type: connection-type,
        max-capacity: max-capacity,
        current-load: u0,
        grid-zone: grid-zone,
        connection-date: block-height,
        smart-meter-id: smart-meter-id
      })

    (ok true)))

;; Update building load
(define-public (update-building-load (building-id uint) (new-load uint))
  (match (map-get? grid-connections building-id)
    connection-data
    (begin
      (asserts! (get connected connection-data) err-building-not-connected)
      (asserts! (<= new-load (get max-capacity connection-data)) err-invalid-capacity)

      (let ((old-load (get current-load connection-data))
            (zone-id (get grid-zone connection-data)))

        ;; Update building load
        (map-set grid-connections
          building-id
          (merge connection-data { current-load: new-load }))

        ;; Update zone usage
        (match (map-get? grid-zones zone-id)
          zone-data
          (map-set grid-zones
            zone-id
            (merge zone-data {
              current-usage: (+ (- (get current-usage zone-data) old-load) new-load)
            }))
          false)

        (ok true)))
    err-building-not-connected))

;; Create energy trade
(define-public (create-energy-trade
  (seller-building uint)
  (buyer-building uint)
  (energy-amount uint)
  (price-per-kwh uint))
  (let ((trade-id (+ (var-get trade-counter) u1)))

    (map-set energy-trades
      { seller-building: seller-building, buyer-building: buyer-building, trade-id: trade-id }
      {
        energy-amount: energy-amount,
        price-per-kwh: price-per-kwh,
        trade-timestamp: block-height,
        status: "pending"
      })

    (var-set trade-counter trade-id)
    (ok trade-id)))

;; Get grid connection
(define-read-only (get-grid-connection (building-id uint))
  (map-get? grid-connections building-id))

;; Get grid zone info
(define-read-only (get-grid-zone (zone-id uint))
  (map-get? grid-zones zone-id))

;; Get energy trade
(define-read-only (get-energy-trade (seller-building uint) (buyer-building uint) (trade-id uint))
  (map-get? energy-trades { seller-building: seller-building, buyer-building: buyer-building, trade-id: trade-id }))

;; Check if building is connected
(define-read-only (is-building-connected (building-id uint))
  (match (map-get? grid-connections building-id)
    connection-data (get connected connection-data)
    false))
