;; Rental Agreement Contract
;; Manages terms and conditions for equipment use

(define-data-var last-rental-id uint u0)

;; Rental status: 0 = pending, 1 = active, 2 = completed, 3 = cancelled, 4 = disputed
(define-map rental-agreements
  { rental-id: uint }
  {
    equipment-id: uint,
    renter: principal,
    owner: principal,
    start-date: uint,
    end-date: uint,
    daily-rate: uint,
    total-amount: uint,
    status: uint,
    creation-date: uint
  }
)

;; Equipment rentals tracking - limited to 100 rentals per equipment
(define-map equipment-rentals
  { equipment-id: uint }
  { rental-ids: (list 100 uint) }
)

;; User rentals tracking - limited to 100 rentals per user
(define-map user-rentals
  { user: principal }
  { rental-ids: (list 100 uint) }
)

;; Create a rental agreement
(define-public (create-rental-agreement
    (equipment-id uint)
    (owner principal)
    (daily-rate uint)
    (start-date uint)
    (end-date uint))
  (let
    (
      (new-id (+ (var-get last-rental-id) u1))
      (renter tx-sender)
      (rental-days (+ u1 (- end-date start-date)))
      (total-cost (* rental-days daily-rate))
      (equipment-rentals-data (default-to { rental-ids: (list) } (map-get? equipment-rentals { equipment-id: equipment-id })))
      (renter-rentals-data (default-to { rental-ids: (list) } (map-get? user-rentals { user: renter })))
      (equipment-rental-list (get rental-ids equipment-rentals-data))
      (renter-rental-list (get rental-ids renter-rentals-data))
    )
    ;; Verify dates are valid
    (asserts! (> end-date start-date) (err u400))
    (asserts! (>= start-date block-height) (err u400))

    ;; Check if equipment or renter has reached rental limit
    (asserts! (< (len equipment-rental-list) u100) (err u1))
    (asserts! (< (len renter-rental-list) u100) (err u1))

    ;; Update last rental ID
    (var-set last-rental-id new-id)

    ;; Create rental agreement
    (map-set rental-agreements
      { rental-id: new-id }
      {
        equipment-id: equipment-id,
        renter: renter,
        owner: owner,
        start-date: start-date,
        end-date: end-date,
        daily-rate: daily-rate,
        total-amount: total-cost,
        status: u0, ;; Pending by default
        creation-date: block-height
      }
    )

    ;; Create new lists with the new ID added
    (let
      (
        (new-equipment-rental-list (unwrap! (as-max-len? (concat equipment-rental-list (list new-id)) u100) (err u1)))
        (new-renter-rental-list (unwrap! (as-max-len? (concat renter-rental-list (list new-id)) u100) (err u1)))
      )
      ;; Update equipment rentals list
      (map-set equipment-rentals
        { equipment-id: equipment-id }
        { rental-ids: new-equipment-rental-list }
      )

      ;; Update renter rentals list
      (map-set user-rentals
        { user: renter }
        { rental-ids: new-renter-rental-list }
      )
    )

    (ok new-id)
  )
)

;; Approve rental agreement (equipment owner only)
(define-public (approve-rental (rental-id uint))
  (let
    (
      (rental (unwrap! (map-get? rental-agreements { rental-id: rental-id }) (err u404)))
    )
    ;; Only owner can approve
    (asserts! (is-eq (get owner rental) tx-sender) (err u403))
    ;; Must be in pending status
    (asserts! (is-eq (get status rental) u0) (err u400))

    ;; Update rental status
    (map-set rental-agreements
      { rental-id: rental-id }
      (merge rental { status: u1 })
    )

    (ok true)
  )
)

;; Complete rental agreement
(define-public (complete-rental (rental-id uint))
  (let
    (
      (rental (unwrap! (map-get? rental-agreements { rental-id: rental-id }) (err u404)))
    )
    ;; Only owner can complete
    (asserts! (is-eq (get owner rental) tx-sender) (err u403))
    ;; Must be in active status
    (asserts! (is-eq (get status rental) u1) (err u400))

    ;; Update rental status
    (map-set rental-agreements
      { rental-id: rental-id }
      (merge rental { status: u2 })
    )

    (ok true)
  )
)

;; Cancel rental agreement (either party can cancel if pending)
(define-public (cancel-rental (rental-id uint))
  (let
    (
      (rental (unwrap! (map-get? rental-agreements { rental-id: rental-id }) (err u404)))
    )
    ;; Only owner or renter can cancel
    (asserts! (or (is-eq (get owner rental) tx-sender)
                 (is-eq (get renter rental) tx-sender))
             (err u403))
    ;; Must be in pending status
    (asserts! (is-eq (get status rental) u0) (err u400))

    ;; Update rental status
    (map-set rental-agreements
      { rental-id: rental-id }
      (merge rental { status: u3 })
    )

    (ok true)
  )
)

;; Get rental details
(define-read-only (get-rental (rental-id uint))
  (map-get? rental-agreements { rental-id: rental-id })
)

;; Get equipment rentals
(define-read-only (get-equipment-rentals (equipment-id uint))
  (map-get? equipment-rentals { equipment-id: equipment-id })
)

;; Get user rentals
(define-read-only (get-user-rentals (user principal))
  (map-get? user-rentals { user: user })
)

