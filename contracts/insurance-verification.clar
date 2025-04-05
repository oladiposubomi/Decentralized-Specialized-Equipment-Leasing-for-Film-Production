;; Insurance Verification Contract
;; Ensures appropriate coverage during rental

(define-data-var last-insurance-id uint u0)

;; Insurance status: 0 = pending, 1 = active, 2 = expired, 3 = cancelled
(define-map insurance-policies
  { insurance-id: uint }
  {
    policy-number: (string-utf8 50),
    policy-holder: principal,
    coverage-amount: uint,
    start-date: uint,
    end-date: uint,
    status: uint,
    provider: (string-utf8 100),
    creation-date: uint
  }
)

;; User insurance tracking - limited to 20 policies per user
(define-map user-insurance
  { user: principal }
  { insurance-ids: (list 20 uint) }
)

;; Admin list for insurance verifiers
(define-map insurance-admins
  { admin: principal }
  { active: bool }
)

;; Initialize contract with deployer as admin
(define-data-var contract-owner principal tx-sender)

;; Register a new insurance policy
(define-public (register-insurance
    (policy-number (string-utf8 50))
    (coverage-amount uint)
    (start-date uint)
    (end-date uint)
    (provider (string-utf8 100)))
  (let
    (
      (new-id (+ (var-get last-insurance-id) u1))
      (policy-holder tx-sender)
      (user-insurance-data (default-to { insurance-ids: (list) } (map-get? user-insurance { user: policy-holder })))
      (insurance-list (get insurance-ids user-insurance-data))
    )
    ;; Verify dates are valid
    (asserts! (> end-date start-date) (err u400))
    (asserts! (>= start-date block-height) (err u400))

    ;; Check if user has reached insurance policy limit
    (asserts! (< (len insurance-list) u20) (err u1))

    ;; Update last insurance ID
    (var-set last-insurance-id new-id)

    ;; Create insurance policy
    (map-set insurance-policies
      { insurance-id: new-id }
      {
        policy-number: policy-number,
        policy-holder: policy-holder,
        coverage-amount: coverage-amount,
        start-date: start-date,
        end-date: end-date,
        status: u0, ;; Pending by default
        provider: provider,
        creation-date: block-height
      }
    )

    ;; Create a new list with the new ID added
    (let
      (
        (new-insurance-list (unwrap! (as-max-len? (concat insurance-list (list new-id)) u20) (err u1)))
      )
      ;; Update user insurance list
      (map-set user-insurance
        { user: policy-holder }
        { insurance-ids: new-insurance-list }
      )
    )

    (ok new-id)
  )
)

;; Verify insurance policy (admin only)
(define-public (verify-insurance (insurance-id uint) (status uint))
  (let
    (
      (insurance (unwrap! (map-get? insurance-policies { insurance-id: insurance-id }) (err u404)))
      (is-admin (default-to { active: false } (map-get? insurance-admins { admin: tx-sender })))
    )
    ;; Only admin can verify
    (asserts! (get active is-admin) (err u403))
    ;; Status must be valid (1 = active, 2 = expired, 3 = cancelled)
    (asserts! (and (> status u0) (<= status u3)) (err u400))

    (map-set insurance-policies
      { insurance-id: insurance-id }
      (merge insurance { status: status })
    )

    (ok true)
  )
)

;; Add an admin (contract owner only)
(define-public (add-admin (admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
    (map-set insurance-admins { admin: admin } { active: true })
    (ok true)
  )
)

;; Remove an admin (contract owner only)
(define-public (remove-admin (admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
    (map-delete insurance-admins { admin: admin })
    (ok true)
  )
)

;; Get insurance details
(define-read-only (get-insurance (insurance-id uint))
  (map-get? insurance-policies { insurance-id: insurance-id })
)

;; Get user insurance policies
(define-read-only (get-user-insurance (user principal))
  (map-get? user-insurance { user: user })
)

;; Check if insurance is valid
(define-read-only (is-insurance-valid (insurance-id uint))
  (let
    (
      (insurance-data (map-get? insurance-policies { insurance-id: insurance-id }))
    )
    (match insurance-data
      insurance-info (and
                 (is-eq (get status insurance-info) u1)
                 (>= (get end-date insurance-info) block-height))
      false
    )
  )
)

