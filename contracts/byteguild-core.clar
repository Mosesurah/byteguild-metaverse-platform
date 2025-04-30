;; byteguild-core
;; Manages guild creation, membership, and governance for the ByteGuild Metaverse Platform
;;
;; This contract serves as the primary hub for all ByteGuild functionality, handling guild lifecycle 
;; from creation to dissolution. It enables users to create and join virtual guilds, contribute to
;; guild treasuries, and participate in governance within the metaverse.

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-GUILD-NOT-FOUND (err u101))
(define-constant ERR-GUILD-EXISTS (err u102))
(define-constant ERR-ALREADY-MEMBER (err u103))
(define-constant ERR-NOT-MEMBER (err u104))
(define-constant ERR-TREASURY-OPERATION-FAILED (err u105))
(define-constant ERR-INVALID-PARAMS (err u106))
(define-constant ERR-MEMBERSHIP-CLOSED (err u107))
(define-constant ERR-APPLICATION-EXISTS (err u108))
(define-constant ERR-NO-APPLICATION (err u109))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u110))
(define-constant ERR-ALREADY-VOTED (err u111))
(define-constant ERR-PROPOSAL-ENDED (err u112))
(define-constant ERR-PROPOSAL-ACTIVE (err u113))
(define-constant ERR-ALLIANCE-EXISTS (err u114))
(define-constant ERR-ALLIANCE-NOT-FOUND (err u115))

;; Guild membership types
(define-constant MEMBERSHIP-OPEN u1)
(define-constant MEMBERSHIP-APPLICATION u2)
(define-constant MEMBERSHIP-INVITE u3)

;; Proposal status
(define-constant PROPOSAL-ACTIVE u1)
(define-constant PROPOSAL-PASSED u2)
(define-constant PROPOSAL-REJECTED u3)
(define-constant PROPOSAL-EXECUTED u4)

;; Guild data structures
(define-map guilds
  { guild-id: uint }
  {
    name: (string-ascii 50),
    description: (string-utf8 500),
    founder: principal,
    created-at: uint,
    membership-type: uint,
    treasury-stx: uint,
    member-count: uint,
    active: bool
  }
)

;; Guild membership
(define-map guild-members
  { guild-id: uint, member: principal }
  {
    joined-at: uint,
    role: (string-ascii 20),
    contributions-stx: uint
  }
)

;; Guild membership applications
(define-map membership-applications
  { guild-id: uint, applicant: principal }
  {
    statement: (string-utf8 200),
    applied-at: uint
  }
)

;; Guild membership invitations
(define-map membership-invitations
  { guild-id: uint, invitee: principal }
  {
    inviter: principal,
    invited-at: uint
  }
)

;; Guild governance proposals
(define-map proposals
  { guild-id: uint, proposal-id: uint }
  {
    title: (string-ascii 100),
    description: (string-utf8 1000),
    proposer: principal,
    created-at: uint,
    expires-at: uint,
    status: uint,
    yes-votes: uint,
    no-votes: uint,
    executed-at: uint,
    action-data: (optional (buff 1024))
  }
)

;; Proposal votes
(define-map proposal-votes
  { guild-id: uint, proposal-id: uint, voter: principal }
  {
    vote: bool,
    voted-at: uint
  }
)

;; Guild alliances
(define-map guild-alliances
  { guild-id-1: uint, guild-id-2: uint }
  {
    created-at: uint,
    alliance-type: (string-ascii 20)
  }
)

;; NFT assets owned by guilds
(define-map guild-nfts
  { guild-id: uint, asset-contract: principal, token-id: uint }
  { 
    acquired-at: uint
  }
)

;; Data variables
(define-data-var guild-id-nonce uint u0)
(define-data-var proposal-id-nonce uint u0)

;; ========================================
;; Private functions
;; ========================================

;; Increments and returns a new guild ID
(define-private (get-next-guild-id)
  (let ((next-id (+ (var-get guild-id-nonce) u1)))
    (var-set guild-id-nonce next-id)
    next-id
  )
)

;; Increments and returns a new proposal ID
(define-private (get-next-proposal-id)
  (let ((next-id (+ (var-get proposal-id-nonce) u1)))
    (var-set proposal-id-nonce next-id)
    next-id
  )
)

;; Check if a principal is a guild member
(define-private (is-guild-member (guild-id uint) (user principal))
  (map-has? guild-members { guild-id: guild-id, member: user })
)

;; Check if a principal is a guild founder
(define-private (is-guild-founder (guild-id uint) (user principal))
  (let ((guild-data (unwrap! (map-get? guilds { guild-id: guild-id }) false)))
    (is-eq (get founder guild-data) user)
  )
)

;; Check if guild exists and is active
(define-private (is-guild-active (guild-id uint))
  (match (map-get? guilds { guild-id: guild-id })
    guild (get active guild)
    false
  )
)

;; Validate guild creation parameters
(define-private (validate-guild-params (name (string-ascii 50)) (membership-type uint))
  (and 
    (> (len name) u0)
    (or 
      (is-eq membership-type MEMBERSHIP-OPEN)
      (is-eq membership-type MEMBERSHIP-APPLICATION)
      (is-eq membership-type MEMBERSHIP-INVITE)
    )
  )
)

;; ========================================
;; Read-only functions
;; ========================================

;; Get guild details
(define-read-only (get-guild (guild-id uint))
  (map-get? guilds { guild-id: guild-id })
)

;; Get guild member details
(define-read-only (get-guild-member (guild-id uint) (member principal))
  (map-get? guild-members { guild-id: guild-id, member: member })
)

;; Check if principal is a member of guild
(define-read-only (check-guild-member (guild-id uint) (member principal))
  (is-guild-member guild-id member)
)

;; Get membership application
(define-read-only (get-membership-application (guild-id uint) (applicant principal))
  (map-get? membership-applications { guild-id: guild-id, applicant: applicant })
)

;; Get membership invitation
(define-read-only (get-membership-invitation (guild-id uint) (invitee principal))
  (map-get? membership-invitations { guild-id: guild-id, invitee: invitee })
)

;; Get proposal details
(define-read-only (get-proposal (guild-id uint) (proposal-id uint))
  (map-get? proposals { guild-id: guild-id, proposal-id: proposal-id })
)

;; Get vote for a proposal
(define-read-only (get-vote (guild-id uint) (proposal-id uint) (voter principal))
  (map-get? proposal-votes { guild-id: guild-id, proposal-id: proposal-id, voter: voter })
)

;; Check if guilds are allied
(define-read-only (check-guild-alliance (guild-id-1 uint) (guild-id-2 uint))
  (or
    (map-has? guild-alliances { guild-id-1: guild-id-1, guild-id-2: guild-id-2 })
    (map-has? guild-alliances { guild-id-1: guild-id-2, guild-id-2: guild-id-1 })
  )
)

;; ========================================
;; Public functions
;; ========================================

;; Create a new guild
(define-public (create-guild
    (name (string-ascii 50))
    (description (string-utf8 500))
    (membership-type uint))
  (let 
    (
      (new-guild-id (get-next-guild-id))
      (caller tx-sender)
      (current-time block-height)
    )
    
    ;; Validate parameters
    (asserts! (validate-guild-params name membership-type) ERR-INVALID-PARAMS)
    
    ;; Create the guild
    (map-set guilds
      { guild-id: new-guild-id }
      {
        name: name,
        description: description,
        founder: caller,
        created-at: current-time,
        membership-type: membership-type,
        treasury-stx: u0,
        member-count: u1,
        active: true
      }
    )
    
    ;; Add founder as first member
    (map-set guild-members
      { guild-id: new-guild-id, member: caller }
      {
        joined-at: current-time,
        role: "founder",
        contributions-stx: u0
      }
    )
    
    (ok new-guild-id)
  )
)

;; Update guild details (only founder)
(define-public (update-guild
    (guild-id uint) 
    (name (string-ascii 50))
    (description (string-utf8 500))
    (membership-type uint))
  (let
    (
      (caller tx-sender)
    )
    
    ;; Check if guild exists
    (asserts! (is-guild-active guild-id) ERR-GUILD-NOT-FOUND)
    
    ;; Verify caller is founder
    (asserts! (is-guild-founder guild-id caller) ERR-NOT-AUTHORIZED)
    
    ;; Validate parameters
    (asserts! (validate-guild-params name membership-type) ERR-INVALID-PARAMS)
    
    ;; Update guild details
    (match (map-get? guilds { guild-id: guild-id })
      guild-data (map-set guilds
        { guild-id: guild-id }
        (merge guild-data {
          name: name,
          description: description,
          membership-type: membership-type
        })
      )
      ERR-GUILD-NOT-FOUND
    )
    
    (ok true)
  )
)

;; Join a guild (for open membership guilds)
(define-public (join-guild (guild-id uint))
  (let
    (
      (caller tx-sender)
      (current-time block-height)
    )
    
    ;; Check if guild exists and is active
    (asserts! (is-guild-active guild-id) ERR-GUILD-NOT-FOUND)
    
    ;; Check if already a member
    (asserts! (not (is-guild-member guild-id caller)) ERR-ALREADY-MEMBER)
    
    ;; Get guild data
    (let ((guild-data (unwrap! (map-get? guilds { guild-id: guild-id }) ERR-GUILD-NOT-FOUND)))
      
      ;; Check if membership is open
      (asserts! (is-eq (get membership-type guild-data) MEMBERSHIP-OPEN) ERR-MEMBERSHIP-CLOSED)
      
      ;; Add as member
      (map-set guild-members
        { guild-id: guild-id, member: caller }
        {
          joined-at: current-time,
          role: "member",
          contributions-stx: u0
        }
      )
      
      ;; Update member count
      (map-set guilds
        { guild-id: guild-id }
        (merge guild-data {
          member-count: (+ (get member-count guild-data) u1)
        })
      )
      
      (ok true)
    )
  )
)

;; Apply to join a guild
(define-public (apply-to-guild
    (guild-id uint)
    (statement (string-utf8 200)))
  (let
    (
      (caller tx-sender)
      (current-time block-height)
    )
    
    ;; Check if guild exists and is active
    (asserts! (is-guild-active guild-id) ERR-GUILD-NOT-FOUND)
    
    ;; Check if already a member
    (asserts! (not (is-guild-member guild-id caller)) ERR-ALREADY-MEMBER)
    
    ;; Check if application already exists
    (asserts! (not (map-has? membership-applications { guild-id: guild-id, applicant: caller })) ERR-APPLICATION-EXISTS)
    
    ;; Get guild data
    (let ((guild-data (unwrap! (map-get? guilds { guild-id: guild-id }) ERR-GUILD-NOT-FOUND)))
      
      ;; Check if guild accepts applications
      (asserts! (is-eq (get membership-type guild-data) MEMBERSHIP-APPLICATION) ERR-MEMBERSHIP-CLOSED)
      
      ;; Store application
      (map-set membership-applications
        { guild-id: guild-id, applicant: caller }
        {
          statement: statement,
          applied-at: current-time
        }
      )
      
      (ok true)
    )
  )
)

;; Approve or reject a guild application
(define-public (process-application
    (guild-id uint)
    (applicant principal)
    (approve bool))
  (let
    (
      (caller tx-sender)
      (current-time block-height)
    )
    
    ;; Check if guild exists and is active
    (asserts! (is-guild-active guild-id) ERR-GUILD-NOT-FOUND)
    
    ;; Verify caller is founder
    (asserts! (is-guild-founder guild-id caller) ERR-NOT-AUTHORIZED)
    
    ;; Check if application exists
    (asserts! (map-has? membership-applications { guild-id: guild-id, applicant: applicant }) ERR-NO-APPLICATION)
    
    ;; Delete application regardless of approval decision
    (map-delete membership-applications { guild-id: guild-id, applicant: applicant })
    
    ;; If approved, add as member
    (if approve
      (let ((guild-data (unwrap! (map-get? guilds { guild-id: guild-id }) ERR-GUILD-NOT-FOUND)))
        (map-set guild-members
          { guild-id: guild-id, member: applicant }
          {
            joined-at: current-time,
            role: "member",
            contributions-stx: u0
          }
        )
        
        ;; Update member count
        (map-set guilds
          { guild-id: guild-id }
          (merge guild-data {
            member-count: (+ (get member-count guild-data) u1)
          })
        )
      )
      true
    )
    
    (ok approve)
  )
)

;; Invite a user to join a guild
(define-public (invite-to-guild
    (guild-id uint)
    (invitee principal))
  (let
    (
      (caller tx-sender)
      (current-time block-height)
    )
    
    ;; Check if guild exists and is active
    (asserts! (is-guild-active guild-id) ERR-GUILD-NOT-FOUND)
    
    ;; Verify caller is a member
    (asserts! (is-guild-member guild-id caller) ERR-NOT-MEMBER)
    
    ;; Check if invitee is already a member
    (asserts! (not (is-guild-member guild-id invitee)) ERR-ALREADY-MEMBER)
    
    ;; Get guild data
    (let ((guild-data (unwrap! (map-get? guilds { guild-id: guild-id }) ERR-GUILD-NOT-FOUND)))
      
      ;; Check if guild allows invitations
      (asserts! (is-eq (get membership-type guild-data) MEMBERSHIP-INVITE) ERR-MEMBERSHIP-CLOSED)
      
      ;; Create invitation
      (map-set membership-invitations
        { guild-id: guild-id, invitee: invitee }
        {
          inviter: caller,
          invited-at: current-time
        }
      )
      
      (ok true)
    )
  )
)

;; Accept a guild invitation
(define-public (accept-invitation (guild-id uint))
  (let
    (
      (caller tx-sender)
      (current-time block-height)
    )
    
    ;; Check if guild exists and is active
    (asserts! (is-guild-active guild-id) ERR-GUILD-NOT-FOUND)
    
    ;; Check if invitation exists
    (asserts! (map-has? membership-invitations { guild-id: guild-id, invitee: caller }) ERR-NOT-AUTHORIZED)
    
    ;; Delete invitation
    (map-delete membership-invitations { guild-id: guild-id, invitee: caller })
    
    ;; Get guild data
    (let ((guild-data (unwrap! (map-get? guilds { guild-id: guild-id }) ERR-GUILD-NOT-FOUND)))
      
      ;; Add as member
      (map-set guild-members
        { guild-id: guild-id, member: caller }
        {
          joined-at: current-time,
          role: "member",
          contributions-stx: u0
        }
      )
      
      ;; Update member count
      (map-set guilds
        { guild-id: guild-id }
        (merge guild-data {
          member-count: (+ (get member-count guild-data) u1)
        })
      )
      
      (ok true)
    )
  )
)

;; Leave a guild
(define-public (leave-guild (guild-id uint))
  (let
    (
      (caller tx-sender)
    )
    
    ;; Check if guild exists and is active
    (asserts! (is-guild-active guild-id) ERR-GUILD-NOT-FOUND)
    
    ;; Check if member
    (asserts! (is-guild-member guild-id caller) ERR-NOT-MEMBER)
    
    ;; Prevent founder from leaving
    (asserts! (not (is-guild-founder guild-id caller)) ERR-NOT-AUTHORIZED)
    
    ;; Remove membership
    (map-delete guild-members { guild-id: guild-id, member: caller })
    
    ;; Update member count
    (match (map-get? guilds { guild-id: guild-id })
      guild-data (map-set guilds
        { guild-id: guild-id }
        (merge guild-data {
          member-count: (- (get member-count guild-data) u1)
        })
      )
      ERR-GUILD-NOT-FOUND
    )
    
    (ok true)
  )
)

;; Contribute STX to guild treasury
(define-public (contribute-to-treasury (guild-id uint) (amount uint))
  (let
    (
      (caller tx-sender)
    )
    
    ;; Check if guild exists and is active
    (asserts! (is-guild-active guild-id) ERR-GUILD-NOT-FOUND)
    
    ;; Check if member
    (asserts! (is-guild-member guild-id caller) ERR-NOT-MEMBER)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount caller (as-contract tx-sender)))
    
    ;; Update guild treasury
    (match (map-get? guilds { guild-id: guild-id })
      guild-data (map-set guilds
        { guild-id: guild-id }
        (merge guild-data {
          treasury-stx: (+ (get treasury-stx guild-data) amount)
        })
      )
      ERR-GUILD-NOT-FOUND
    )
    
    ;; Update member contributions
    (match (map-get? guild-members { guild-id: guild-id, member: caller })
      member-data (map-set guild-members
        { guild-id: guild-id, member: caller }
        (merge member-data {
          contributions-stx: (+ (get contributions-stx member-data) amount)
        })
      )
      ERR-NOT-MEMBER
    )
    
    (ok true)
  )
)

;; Create a guild governance proposal
(define-public (create-proposal
    (guild-id uint)
    (title (string-ascii 100))
    (description (string-utf8 1000))
    (duration uint)
    (action-data (optional (buff 1024))))
  (let
    (
      (caller tx-sender)
      (current-time block-height)
      (proposal-id (get-next-proposal-id))
      (expires-at (+ current-time duration))
    )
    
    ;; Check if guild exists and is active
    (asserts! (is-guild-active guild-id) ERR-GUILD-NOT-FOUND)
    
    ;; Check if member
    (asserts! (is-guild-member guild-id caller) ERR-NOT-MEMBER)
    
    ;; Validate parameters
    (asserts! (and (> (len title) u0) (> duration u0)) ERR-INVALID-PARAMS)
    
    ;; Create proposal
    (map-set proposals
      { guild-id: guild-id, proposal-id: proposal-id }
      {
        title: title,
        description: description,
        proposer: caller,
        created-at: current-time,
        expires-at: expires-at,
        status: PROPOSAL-ACTIVE,
        yes-votes: u0,
        no-votes: u0,
        executed-at: u0,
        action-data: action-data
      }
    )
    
    (ok proposal-id)
  )
)

;; Vote on a proposal
(define-public (vote-on-proposal (guild-id uint) (proposal-id uint) (support bool))
  (let
    (
      (caller tx-sender)
      (current-time block-height)
    )
    
    ;; Check if guild exists and is active
    (asserts! (is-guild-active guild-id) ERR-GUILD-NOT-FOUND)
    
    ;; Check if member
    (asserts! (is-guild-member guild-id caller) ERR-NOT-MEMBER)
    
    ;; Get proposal
    (let ((proposal (unwrap! (map-get? proposals { guild-id: guild-id, proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND)))
      
      ;; Check if proposal is active
      (asserts! (is-eq (get status proposal) PROPOSAL-ACTIVE) ERR-PROPOSAL-ENDED)
      
      ;; Check if proposal hasn't expired
      (asserts! (<= current-time (get expires-at proposal)) ERR-PROPOSAL-ENDED)
      
      ;; Check if already voted
      (asserts! (not (map-has? proposal-votes { guild-id: guild-id, proposal-id: proposal-id, voter: caller })) ERR-ALREADY-VOTED)
      
      ;; Record vote
      (map-set proposal-votes
        { guild-id: guild-id, proposal-id: proposal-id, voter: caller }
        {
          vote: support,
          voted-at: current-time
        }
      )
      
      ;; Update proposal vote counts
      (if support
        (map-set proposals
          { guild-id: guild-id, proposal-id: proposal-id }
          (merge proposal {
            yes-votes: (+ (get yes-votes proposal) u1)
          })
        )
        (map-set proposals
          { guild-id: guild-id, proposal-id: proposal-id }
          (merge proposal {
            no-votes: (+ (get no-votes proposal) u1)
          })
        )
      )
      
      (ok true)
    )
  )
)

;; Finalize a proposal after expiry
(define-public (finalize-proposal (guild-id uint) (proposal-id uint))
  (let
    (
      (current-time block-height)
    )
    
    ;; Check if guild exists and is active
    (asserts! (is-guild-active guild-id) ERR-GUILD-NOT-FOUND)
    
    ;; Get proposal
    (let ((proposal (unwrap! (map-get? proposals { guild-id: guild-id, proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND)))
      
      ;; Check if proposal is active
      (asserts! (is-eq (get status proposal) PROPOSAL-ACTIVE) ERR-PROPOSAL-ENDED)
      
      ;; Check if proposal has expired
      (asserts! (> current-time (get expires-at proposal)) ERR-PROPOSAL-ACTIVE)
      
      ;; Determine result
      (let 
        (
          (yes-votes (get yes-votes proposal))
          (no-votes (get no-votes proposal))
          (passed (> yes-votes no-votes))
          (new-status (if passed PROPOSAL-PASSED PROPOSAL-REJECTED))
        )
        
        ;; Update proposal status
        (map-set proposals
          { guild-id: guild-id, proposal-id: proposal-id }
          (merge proposal {
            status: new-status
          })
        )
        
        (ok passed)
      )
    )
  )
)

;; Execute a passed proposal
(define-public (execute-proposal (guild-id uint) (proposal-id uint))
  (let
    (
      (caller tx-sender)
      (current-time block-height)
    )
    
    ;; Check if guild exists and is active
    (asserts! (is-guild-active guild-id) ERR-GUILD-NOT-FOUND)
    
    ;; Verify caller is founder
    (asserts! (is-guild-founder guild-id caller) ERR-NOT-AUTHORIZED)
    
    ;; Get proposal
    (let ((proposal (unwrap! (map-get? proposals { guild-id: guild-id, proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND)))
      
      ;; Check if proposal has passed
      (asserts! (is-eq (get status proposal) PROPOSAL-PASSED) ERR-NOT-AUTHORIZED)
      
      ;; Mark as executed (actual execution logic would depend on the action in a complete system)
      (map-set proposals
        { guild-id: guild-id, proposal-id: proposal-id }
        (merge proposal {
          status: PROPOSAL-EXECUTED,
          executed-at: current-time
        })
      )
      
      (ok true)
    )
  )
)

;; Form an alliance between guilds
(define-public (form-alliance (guild-id-1 uint) (guild-id-2 uint) (alliance-type (string-ascii 20)))
  (let
    (
      (caller tx-sender)
      (current-time block-height)
    )
    
    ;; Check if both guilds exist and are active
    (asserts! (and (is-guild-active guild-id-1) (is-guild-active guild-id-2)) ERR-GUILD-NOT-FOUND)
    
    ;; Verify caller is founder of first guild
    (asserts! (is-guild-founder guild-id-1 caller) ERR-NOT-AUTHORIZED)
    
    ;; Check guilds are different
    (asserts! (not (is-eq guild-id-1 guild-id-2)) ERR-INVALID-PARAMS)
    
    ;; Check alliance doesn't already exist
    (asserts! (not (check-guild-alliance guild-id-1 guild-id-2)) ERR-ALLIANCE-EXISTS)
    
    ;; Create alliance
    (map-set guild-alliances
      { guild-id-1: guild-id-1, guild-id-2: guild-id-2 }
      {
        created-at: current-time,
        alliance-type: alliance-type
      }
    )
    
    (ok true)
  )
)

;; Dissolve a guild (founder only)
(define-public (dissolve-guild (guild-id uint))
  (let
    (
      (caller tx-sender)
    )
    
    ;; Check if guild exists
    (asserts! (is-guild-active guild-id) ERR-GUILD-NOT-FOUND)
    
    ;; Verify caller is founder
    (asserts! (is-guild-founder guild-id caller) ERR-NOT-AUTHORIZED)
    
    ;; Mark guild as inactive
    (match (map-get? guilds { guild-id: guild-id })
      guild-data (map-set guilds
        { guild-id: guild-id }
        (merge guild-data {
          active: false
        })
      )
      ERR-GUILD-NOT-FOUND
    )
    
    (ok true)
  )
)