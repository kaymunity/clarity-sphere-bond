;; SphereBond - Relationship tracking contract

;; Constants
(define-constant ERR-NOT-BONDED (err u100))
(define-constant ERR-ALREADY-BONDED (err u101))
(define-constant ERR-UNAUTHORIZED (err u102))
(define-constant ERR-DATE-IN-PAST (err u103))

;; Data variables
(define-map bonds 
  { bond-id: uint } 
  { 
    partner1: principal,
    partner2: principal,
    bond-date: uint,
    status: (string-ascii 10)
  }
)

(define-map date-nights
  { bond-id: uint, date-id: uint }
  {
    scheduled-date: uint,
    completed: bool,
    description: (string-ascii 256)
  }
)

(define-map milestones 
  { bond-id: uint, milestone-id: uint }
  {
    date: uint,
    title: (string-ascii 64),
    description: (string-ascii 256)
  }
)

(define-data-var last-bond-id uint u0)
(define-data-var last-date-id uint u0)
(define-data-var last-milestone-id uint u0)

;; Private functions
(define-private (is-bond-member (bond-id uint) (member principal))
  (let ((bond (unwrap! (map-get? bonds {bond-id: bond-id}) false)))
    (or
      (is-eq member (get partner1 bond))
      (is-eq member (get partner2 bond))
    )
  )
)

;; Public functions
(define-public (create-bond (partner principal))
  (let 
    (
      (new-id (+ (var-get last-bond-id) u1))
    )
    (asserts! (not (is-some (map-get? bonds {bond-id: new-id}))) ERR-ALREADY-BONDED)
    (map-set bonds 
      {bond-id: new-id}
      {
        partner1: tx-sender,
        partner2: partner,
        bond-date: block-height,
        status: "active"
      }
    )
    (var-set last-bond-id new-id)
    (ok new-id)
  )
)

(define-public (schedule-date-night (bond-id uint) (scheduled-date uint) (description (string-ascii 256)))
  (let
    (
      (new-id (+ (var-get last-date-id) u1))
    )
    (asserts! (is-bond-member bond-id tx-sender) ERR-UNAUTHORIZED)
    (asserts! (> scheduled-date block-height) ERR-DATE-IN-PAST)
    (map-set date-nights
      {bond-id: bond-id, date-id: new-id}
      {
        scheduled-date: scheduled-date,
        completed: false,
        description: description
      }
    )
    (var-set last-date-id new-id)
    (ok new-id)
  )
)

(define-public (complete-date-night (bond-id uint) (date-id uint))
  (let
    (
      (date-night (unwrap! (map-get? date-nights {bond-id: bond-id, date-id: date-id}) ERR-NOT-BONDED))
    )
    (asserts! (is-bond-member bond-id tx-sender) ERR-UNAUTHORIZED)
    (map-set date-nights
      {bond-id: bond-id, date-id: date-id}
      (merge date-night {completed: true})
    )
    (ok true)
  )
)

(define-public (add-milestone (bond-id uint) (title (string-ascii 64)) (description (string-ascii 256)))
  (let
    (
      (new-id (+ (var-get last-milestone-id) u1))
    )
    (asserts! (is-bond-member bond-id tx-sender) ERR-UNAUTHORIZED)
    (map-set milestones
      {bond-id: bond-id, milestone-id: new-id}
      {
        date: block-height,
        title: title,
        description: description
      }
    )
    (var-set last-milestone-id new-id)
    (ok new-id)
  )
)

;; Read only functions
(define-read-only (get-bond (bond-id uint))
  (ok (map-get? bonds {bond-id: bond-id}))
)

(define-read-only (get-date-night (bond-id uint) (date-id uint))
  (ok (map-get? date-nights {bond-id: bond-id, date-id: date-id}))
)

(define-read-only (get-milestone (bond-id uint) (milestone-id uint))
  (ok (map-get? milestones {bond-id: bond-id, milestone-id: milestone-id}))
)