# Music Royalty Distribution Smart Contract

A Clarity smart contract for managing and distributing music royalty payments among artists, producers, and rights holders on the Stacks blockchain.

## Overview

This smart contract provides a transparent and automated system for:
- Registering songs and their primary artists
- Managing royalty share distributions
- Processing royalty payments
- Tracking revenue for each registered song
- Managing participant roles and permissions

## Features

- **Song Registration**: Register new songs with their primary artists
- **Royalty Management**: Set and update royalty share percentages for different participants
- **Payment Distribution**: Automatically distribute STX payments according to predefined shares
- **Revenue Tracking**: Track accumulated revenue for each registered song
- **Role-based Access**: Administrative controls for contract management
- **Status Management**: Ability to activate/deactivate songs in the registry

## Core Functions

### Administrative Functions

```clarity
(define-public (register-song (song-title (string-ascii 50)) (primary-artist-address principal)))
(define-public (transfer-admin-rights (new-admin-address principal)))
(define-public (update-song-status (song-unique-id uint) (new-status bool)))
```

### Participant Management

```clarity
(define-public (set-participant-royalty-share 
    (song-unique-id uint) 
    (participant-address principal) 
    (royalty-share-percentage uint) 
    (participant-role-type (string-ascii 20))))
```

### Payment Functions

```clarity
(define-public (submit-royalty-payment (song-unique-id uint) (payment-amount uint)))
```

### Read-Only Functions

```clarity
(define-read-only (get-song-details (song-unique-id uint)))
(define-read-only (get-participant-royalty-info (song-unique-id uint) (participant-address principal)))
(define-read-only (get-total-registered-song-count))
(define-read-only (get-song-royalty-distribution (song-unique-id uint)))
```

## Error Codes

- `ERROR-UNAUTHORIZED-CONTRACT-ACCESS (u100)`: Unauthorized access attempt
- `ERROR-ROYALTY-PERCENTAGE-OUT-OF-BOUNDS (u101)`: Invalid royalty percentage
- `ERROR-SONG-ALREADY-REGISTERED (u102)`: Duplicate song registration
- `ERROR-SONG-NOT-IN-REGISTRY (u103)`: Song not found
- `ERROR-INSUFFICIENT-STX-BALANCE (u104)`: Insufficient funds for payment
- `ERROR-INVALID-ROYALTY-RECIPIENT-ADDRESS (u105)`: Invalid recipient address
- `ERROR-ROYALTY-PAYMENT-DISTRIBUTION-FAILED (u106)`: Payment distribution failure
- `ERROR-STRING-LENGTH-EXCEEDS-LIMIT (u107)`: String length violation
- `ERROR-INVALID-SONG-TITLE-FORMAT (u108)`: Invalid song title format
- `ERROR-INVALID-PARTICIPANT-ROLE-FORMAT (u109)`: Invalid role format
- `ERROR-INVALID-PRIMARY-ARTIST-ADDRESS (u110)`: Invalid artist address
- `ERROR-INVALID-ADMINISTRATOR-ADDRESS (u111)`: Invalid admin address

## Data Structures

### SongRegistry

```clarity
{
    song-title: (string-ascii 50),
    primary-artist-address: principal,
    total-revenue-accumulated: uint,
    initial-registration-date: uint,
    is-song-active: bool
}
```

### RoyaltyParticipants

```clarity
{
    royalty-share-percentage: uint,
    participant-role-type: (string-ascii 20),
    total-earnings-to-date: uint
}
```

## Usage Examples

### Registering a New Song

```clarity
(contract-call? .music-royalty register-song "Song Title" 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Setting Royalty Shares

```clarity
(contract-call? .music-royalty set-participant-royalty-share 
    u1 
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
    u50 
    "producer")
```

### Submitting Payment

```clarity
(contract-call? .music-royalty submit-royalty-payment u1 u1000000)
```

## Security Considerations

- Only the contract administrator can register new songs and transfer admin rights
- Royalty percentages must be between 0 and 100
- All participant addresses are validated before registration
- Payment distribution requires sufficient STX balance
- String inputs have length restrictions to prevent overflow

## Limitations

- Song titles are limited to 50 ASCII characters
- Participant role types are limited to 20 ASCII characters
- Only supports STX token payments
- Single primary artist per song