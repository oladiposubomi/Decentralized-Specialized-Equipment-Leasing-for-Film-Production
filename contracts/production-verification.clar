;; Production Company Verification Contract
;; Validates legitimate film production companies

(define-data-var last-company-id uint u0)

;; Verification status: 0 = pending, 1 = verified, 2 = rejected, 3 = suspended
(define-map production-companies
  { company-id: uint }
  {
    name: (string-utf8 100),
    registration-number: (string-utf8 50),
    contact-info: (string-utf8 200),
    owner: principal,
    verification-status: uint,
    registration-date: uint
  }
)

;; Map of principals to company IDs
(define-map principal-to-company
  { owner: principal }
  { company-id: uint }
)

;; Admin list for verification authority
(define-map admins
  { admin: principal }
  { active: bool }
)

;; Initialize contract with deployer as admin
(define-data-var contract-owner principal tx-sender)

;; Register a new production company (pending verification)
(define-public (register-company
    (name (string-utf8 100))
    (registration-number (string-utf8 50))
    (contact-info (string-utf8 200)))
  (let
    (
      (new-id (+ (var-get last-company-id) u1))
      (owner tx-sender)
    )
    ;; Check if principal already has a company
    (asserts! (is-none (map-get? principal-to-company { owner: owner })) (err u409))

    ;; Update last company ID
    (var-set last-company-id new-id)

    ;; Add company to registry
    (map-set production-companies
      { company-id: new-id }
      {
        name: name,
        registration-number: registration-number,
        contact-info: contact-info,
        owner: owner,
        verification-status: u0, ;; Pending by default
        registration-date: block-height
      }
    )

    ;; Map principal to company ID
    (map-set principal-to-company
      { owner: owner }
      { company-id: new-id }
    )

    (ok new-id)
  )
)

;; Verify a production company (admin only)
(define-public (verify-company (company-id uint) (status uint))
  (let
    (
      (company-data (unwrap! (map-get? production-companies { company-id: company-id }) (err u404)))
      (is-admin (default-to { active: false } (map-get? admins { admin: tx-sender })))
    )
    ;; Only admin can verify
    (asserts! (get active is-admin) (err u403))
    ;; Status must be valid (1 = verified, 2 = rejected, 3 = suspended)
    (asserts! (and (> status u0) (<= status u3)) (err u400))

    (map-set production-companies
      { company-id: company-id }
      (merge company-data { verification-status: status })
    )

    (ok true)
  )
)

;; Add an admin (contract owner only)
(define-public (add-admin (admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
    (map-set admins { admin: admin } { active: true })
    (ok true)
  )
)

;; Remove an admin (contract owner only)
(define-public (remove-admin (admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
    (map-delete admins { admin: admin })
    (ok true)
  )
)

;; Get company details
(define-read-only (get-company (company-id uint))
  (map-get? production-companies { company-id: company-id })
)

;; Get company by principal
(define-read-only (get-company-by-principal (owner principal))
  (let
    (
      (company-id-entry (map-get? principal-to-company { owner: owner }))
    )
    (match company-id-entry
      entry (map-get? production-companies { company-id: (get company-id entry) })
      none
    )
  )
)

;; Check if company is verified
(define-read-only (is-company-verified (company-id uint))
  (let
    (
      (company-data (map-get? production-companies { company-id: company-id }))
    )
    (match company-data
      company-info (is-eq (get verification-status company-info) u1)
      false
    )
  )
)

