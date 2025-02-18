;; Music Royalty Distribution Smart Contract

;; Error codes
(define-constant ERROR-UNAUTHORIZED-CONTRACT-ACCESS (err u100))
(define-constant ERROR-ROYALTY-PERCENTAGE-OUT-OF-BOUNDS (err u101))
(define-constant ERROR-SONG-ALREADY-REGISTERED (err u102))
(define-constant ERROR-SONG-NOT-IN-REGISTRY (err u103))
(define-constant ERROR-INSUFFICIENT-STX-BALANCE (err u104))
(define-constant ERROR-INVALID-ROYALTY-RECIPIENT-ADDRESS (err u105))
(define-constant ERROR-ROYALTY-PAYMENT-DISTRIBUTION-FAILED (err u106))
(define-constant ERROR-STRING-LENGTH-EXCEEDS-LIMIT (err u107))
(define-constant ERROR-INVALID-SONG-TITLE-FORMAT (err u108))
(define-constant ERROR-INVALID-PARTICIPANT-ROLE-FORMAT (err u109))
(define-constant ERROR-INVALID-PRIMARY-ARTIST-ADDRESS (err u110))
(define-constant ERROR-INVALID-ADMINISTRATOR-ADDRESS (err u111))

;; Data structures
(define-map SongRegistry
    { song-unique-id: uint }
    {
        song-title: (string-ascii 50),
        primary-artist-address: principal,
        total-revenue-accumulated: uint,
        initial-registration-date: uint,
        is-song-active: bool
    }
)

(define-map RoyaltyParticipants
    { song-unique-id: uint, participant-address: principal }
    {
        royalty-share-percentage: uint,
        participant-role-type: (string-ascii 20),
        total-earnings-to-date: uint
    }
)

;; Track total registered songs
(define-data-var total-songs-in-registry uint u0)

;; Track contract administrator
(define-data-var contract-admin-address principal tx-sender)

;; Read-only functions
(define-read-only (get-song-details (song-unique-id uint))
    (map-get? SongRegistry { song-unique-id: song-unique-id })
)

(define-read-only (get-participant-royalty-info (song-unique-id uint) (participant-address principal))
    (map-get? RoyaltyParticipants { song-unique-id: song-unique-id, participant-address: participant-address })
)

(define-read-only (get-total-registered-song-count)
    (var-get total-songs-in-registry)
)

;; Get royalty shares for a song
(define-read-only (get-song-royalty-distribution (song-unique-id uint))
    (let (
        (song-details (get-song-details song-unique-id))
        (primary-artist-address (match song-details record (get primary-artist-address record) tx-sender))
    )
    (let ((participant-info (get-participant-royalty-info song-unique-id primary-artist-address)))
        (match participant-info share-info
            (list {
                participant-address: primary-artist-address,
                royalty-share-percentage: (get royalty-share-percentage share-info)
            })
            (list))))
)

;; Helper functions
(define-private (is-valid-royalty-distribution (distribution-info {
    royalty-share-percentage: uint,
    participant-role-type: (string-ascii 20),
    total-earnings-to-date: uint
}))
    (> (get royalty-share-percentage distribution-info) u0)
)

(define-private (is-contract-admin)
    (is-eq tx-sender (var-get contract-admin-address))
)

(define-private (is-valid-percentage-range (percentage-value uint))
    (and (>= percentage-value u0) (<= percentage-value u100))
)

(define-private (is-valid-ascii-string (input-string (string-ascii 50)))
    (let ((string-length (len input-string)))
        (and (> string-length u0) (<= string-length u50))))

(define-private (is-valid-role-string (role-string (string-ascii 20)))
    (let ((role-length (len role-string)))
        (and (> role-length u0) (<= role-length u20))))

(define-private (is-valid-principal-address (address-to-validate principal))
    (and 
        (not (is-eq address-to-validate tx-sender))
        (not (is-eq address-to-validate (var-get contract-admin-address)))
    ))

;; Process royalty distribution
(define-private (process-individual-royalty-share
    (share-info {participant-address: principal, royalty-share-percentage: uint}) 
    (total-payment-amount uint))
    (let (
        (participant-payment-amount (/ (* total-payment-amount (get royalty-share-percentage share-info)) u100))
    )
    (if (> participant-payment-amount u0)
        (match (stx-transfer? participant-payment-amount tx-sender (get participant-address share-info))
            success-response total-payment-amount
            error-response u0)
        u0))
)

;; Updated distribute payment function
(define-private (distribute-royalty-payments (song-unique-id uint) (total-payment-amount uint))
    (let (
        (royalty-distribution-details (get-song-royalty-distribution song-unique-id))
        (total-amount-distributed (fold process-individual-royalty-share 
                               royalty-distribution-details 
                               total-payment-amount))
    )
    (begin
        (asserts! (> (len royalty-distribution-details) u0) ERROR-SONG-NOT-IN-REGISTRY)
        (asserts! (> total-amount-distributed u0) ERROR-ROYALTY-PAYMENT-DISTRIBUTION-FAILED)
        (ok total-amount-distributed)))
)

;; Public functions
(define-public (register-song (song-title (string-ascii 50)) (primary-artist-address principal))
    (let (
        (new-song-unique-id (+ (var-get total-songs-in-registry) u1))
    )
    (begin
        (asserts! (is-contract-admin) ERROR-UNAUTHORIZED-CONTRACT-ACCESS)
        (asserts! (is-valid-ascii-string song-title) ERROR-INVALID-SONG-TITLE-FORMAT)
        (asserts! (is-valid-principal-address primary-artist-address) ERROR-INVALID-PRIMARY-ARTIST-ADDRESS)
        
        (map-set SongRegistry
            { song-unique-id: new-song-unique-id }
            {
                song-title: song-title,
                primary-artist-address: primary-artist-address,
                total-revenue-accumulated: u0,
                initial-registration-date: block-height,
                is-song-active: true
            }
        )
        (var-set total-songs-in-registry new-song-unique-id)
        (ok new-song-unique-id)))
)

(define-public (set-participant-royalty-share 
    (song-unique-id uint) 
    (participant-address principal) 
    (royalty-share-percentage uint) 
    (participant-role-type (string-ascii 20)))
    (let (
        (song-record (get-song-details song-unique-id))
    )
    (begin
        (asserts! (is-some song-record) ERROR-SONG-NOT-IN-REGISTRY)
        (asserts! (is-valid-percentage-range royalty-share-percentage) ERROR-ROYALTY-PERCENTAGE-OUT-OF-BOUNDS)
        (asserts! (is-valid-role-string participant-role-type) ERROR-INVALID-PARTICIPANT-ROLE-FORMAT)
        (asserts! (is-valid-principal-address participant-address) ERROR-INVALID-ROYALTY-RECIPIENT-ADDRESS)
        
        (map-set RoyaltyParticipants
            { song-unique-id: song-unique-id, participant-address: participant-address }
            {
                royalty-share-percentage: royalty-share-percentage,
                participant-role-type: participant-role-type,
                total-earnings-to-date: u0
            }
        )
        (ok true)))
)

(define-public (submit-royalty-payment (song-unique-id uint) (payment-amount uint))
    (let (
        (song-record (get-song-details song-unique-id))
    )
    (begin
        (asserts! (is-some song-record) ERROR-SONG-NOT-IN-REGISTRY)
        (asserts! (>= (stx-get-balance tx-sender) payment-amount) ERROR-INSUFFICIENT-STX-BALANCE)
        
        (try! (distribute-royalty-payments song-unique-id payment-amount))
        (map-set SongRegistry
            { song-unique-id: song-unique-id }
            (merge (unwrap-panic song-record)
                { total-revenue-accumulated: (+ (get total-revenue-accumulated (unwrap-panic song-record)) payment-amount) }
            )
        )
        (ok true)))
)

(define-public (update-song-status (song-unique-id uint) (new-status bool))
    (let (
        (song-record (get-song-details song-unique-id))
    )
    (begin
        (asserts! (is-contract-admin) ERROR-UNAUTHORIZED-CONTRACT-ACCESS)
        (asserts! (is-some song-record) ERROR-SONG-NOT-IN-REGISTRY)
        
        (map-set SongRegistry
            { song-unique-id: song-unique-id }
            (merge (unwrap-panic song-record)
                { is-song-active: new-status }
            )
        )
        (ok true)))
)

(define-public (transfer-admin-rights (new-admin-address principal))
    (begin
        (asserts! (is-contract-admin) ERROR-UNAUTHORIZED-CONTRACT-ACCESS)
        (asserts! (is-valid-principal-address new-admin-address) ERROR-INVALID-ADMINISTRATOR-ADDRESS)
        
        (var-set contract-admin-address new-admin-address)
        (ok true))
)

;; Contract initialization
(begin
    (var-set total-songs-in-registry u0))