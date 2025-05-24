;; Building Verification Contract
;; Validates and manages urban structures in the smart city

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-building-exists (err u101))
(define-constant err-building-not-found (err u102))
(define-constant err-invalid-building-type (err u103))

;; Building types
(define-constant RESIDENTIAL u1)
(define-constant COMMERCIAL u2)
(define-constant INDUSTRIAL u3)
(define-constant PUBLIC u4)

;; Building data structure
(define-map buildings
  { building-id: uint }
  {
    owner: principal,
    building-type: uint,
    address: (string-ascii 100),
    square-footage: uint,
    construction-year: uint,
    verified: bool,
    energy-rating: uint,
    created-at: uint
  }
)

;; Building counter
(define-data-var building-counter uint u0)

;; Verified buildings list
(define-map verified-buildings uint bool)

;; Register a new building
(define-public (register-building
  (building-type uint)
  (address (string-ascii 100))
  (square-footage uint)
  (construction-year uint))
  (let ((building-id (+ (var-get building-counter) u1)))
    (asserts! (or (is-eq building-type RESIDENTIAL)
                  (is-eq building-type COMMERCIAL)
                  (is-eq building-type INDUSTRIAL)
                  (is-eq building-type PUBLIC)) err-invalid-building-type)
    (asserts! (is-none (map-get? buildings { building-id: building-id })) err-building-exists)

    (map-set buildings
      { building-id: building-id }
      {
        owner: tx-sender,
        building-type: building-type,
        address: address,
        square-footage: square-footage,
        construction-year: construction-year,
        verified: false,
        energy-rating: u0,
        created-at: block-height
      })

    (var-set building-counter building-id)
    (ok building-id)))

;; Verify a building (admin only)
(define-public (verify-building (building-id uint) (energy-rating uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (match (map-get? buildings { building-id: building-id })
      building-data
      (begin
        (map-set buildings
          { building-id: building-id }
          (merge building-data { verified: true, energy-rating: energy-rating }))
        (map-set verified-buildings building-id true)
        (ok true))
      err-building-not-found)))

;; Get building info
(define-read-only (get-building (building-id uint))
  (map-get? buildings { building-id: building-id }))

;; Check if building is verified
(define-read-only (is-building-verified (building-id uint))
  (default-to false (map-get? verified-buildings building-id)))

;; Get total buildings count
(define-read-only (get-building-count)
  (var-get building-counter))
