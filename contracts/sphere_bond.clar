;; SphereBond - Relationship tracking contract

;; Constants
(define-constant ERR-NOT-BONDED (err u100))
(define-constant ERR-ALREADY-BONDED (err u101)) 
(define-constant ERR-UNAUTHORIZED (err u102))
(define-constant ERR-DATE-IN-PAST (err u103))
(define-constant ERR-INVALID-TIER (err u104))
(define-constant ERR-INSUFFICIENT-POINTS (err u105))

;; Data variables
(define-map bonds 
  { bond-id: uint } 
  { 
    partner1: principal,
    partner2: principal,
    bond-date: uint,
    status: (string-ascii 10),
    points: uint,
    tier: (string-ascii 20)
  }
)

(define-map date-nights
  { bond-id: uint, date-id: uint }
  {
    scheduled-date: uint,
    completed: bool,
    description: (string-ascii 256),
    points-earned: uint
  }
)

(define-map milestones 
  { bond-id: uint, milestone-id: uint }
  {
    date: uint,
    title: (string-ascii 64),
    description: (string-ascii 256),
    points-earned: uint
  }
)

(define-map rewards
  { reward-id: uint }
  {
    name: (string-ascii 64),
    description: (string-ascii 256),
    points-cost: uint,
    tier-required: (string-ascii 20)
  }
)

(define-data-var last-bond-id uint u0)
(define-data-var last-date-id uint u0)
(define-data-var last-milestone-id uint u0)
(define-data-var last-reward-id uint u0)

;; Private functions
(define-private (is-bond-member (bond-id uint) (member principal))
  (let ((bond (unwrap! (map-get? bonds {bond-id: bond-id}) false)))
    (or
      (is-eq member (get partner1 bond))
      (is-eq member (get partner2 bond))
    )
  )
)

(define-private (calculate-tier (points uint))
  (if (>= points u1000)
    "platinum"
    (if (>= points u500)
      "gold"
      (if (>= points u200)
        "silver"
        "bronze"
      )
    )
  )
)

(define-private (update-bond-tier (bond-id uint))
  (let (
    (bond (unwrap! (map-get? bonds {bond-id: bond-id}) ERR-NOT-BONDED))
    (new-tier (calculate-tier (get points bond)))
  )
    (map-set bonds
      {bond-id: bond-id}
      (merge bond {tier: new-tier})
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
        status: "active",
        points: u0,
        tier: "bronze"
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
        description: description,
        points-earned: u0
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
      (bond (unwrap! (map-get? bonds {bond-id: bond-id}) ERR-NOT-BONDED))
      (points-earned u50)
    )
    (asserts! (is-bond-member bond-id tx-sender) ERR-UNAUTHORIZED)
    (map-set date-nights
      {bond-id: bond-id, date-id: date-id}
      (merge date-night {completed: true, points-earned: points-earned})
    )
    (map-set bonds
      {bond-id: bond-id}
      (merge bond {points: (+ (get points bond) points-earned)})
    )
    (update-bond-tier bond-id)
    (ok true)
  )
)

(define-public (add-milestone (bond-id uint) (title (string-ascii 64)) (description (string-ascii 256)))
  (let
    (
      (new-id (+ (var-get last-milestone-id) u1))
      (bond (unwrap! (map-get? bonds {bond-id: bond-id}) ERR-NOT-BONDED))
      (points-earned u100)
    )
    (asserts! (is-bond-member bond-id tx-sender) ERR-UNAUTHORIZED)
    (map-set milestones
      {bond-id: bond-id, milestone-id: new-id}
      {
        date: block-height,
        title: title,
        description: description,
        points-earned: points-earned
      }
    )
    (map-set bonds
      {bond-id: bond-id}
      (merge bond {points: (+ (get points bond) points-earned)})
    )
    (var-set last-milestone-id new-id)
    (update-bond-tier bond-id)
    (ok new-id)
  )
)

(define-public (create-reward (name (string-ascii 64)) (description (string-ascii 256)) (points-cost uint) (tier-required (string-ascii 20)))
  (let
    (
      (new-id (+ (var-get last-reward-id) u1))
    )
    (map-set rewards
      {reward-id: new-id}
      {
        name: name,
        description: description,
        points-cost: points-cost,
        tier-required: tier-required
      }
    )
    (var-set last-reward-id new-id)
    (ok new-id)
  )
)

(define-public (redeem-reward (bond-id uint) (reward-id uint))
  (let
    (
      (bond (unwrap! (map-get? bonds {bond-id: bond-id}) ERR-NOT-BONDED))
      (reward (unwrap! (map-get? rewards {reward-id: reward-id}) ERR-NOT-BONDED))
    )
    (asserts! (is-bond-member bond-id tx-sender) ERR-UNAUTHORIZED)
    (asserts! (>= (get points bond) (get points-cost reward)) ERR-INSUFFICIENT-POINTS)
    (asserts! (string-ascii-equal? (get tier bond) (get tier-required reward)) ERR-INVALID-TIER)
    (map-set bonds
      {bond-id: bond-id}
      (merge bond {points: (- (get points bond) (get points-cost reward))})
    )
    (update-bond-tier bond-id)
    (ok true)
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

(define-read-only (get-reward (reward-id uint))
  (ok (map-get? rewards {reward-id: reward-id}))
)
