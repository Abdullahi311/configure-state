;; configuration-manager
;; 
;; A secure, decentralized state configuration system for IoT networks.
;; Provides immutable and verifiable state management for distributed device configurations.

;; Error constants
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-MANAGER-ALREADY-REGISTERED (err u101))
(define-constant ERR-MANAGER-NOT-REGISTERED (err u102))
(define-constant ERR-CONFIG-ALREADY-EXISTS (err u103))
(define-constant ERR-CONFIG-NOT-FOUND (err u104))
(define-constant ERR-INVALID-CONFIG-ACTION (err u105))

;; Data space definitions

;; Maps each network's configuration manager to its owner's principal
(define-map network-managers
  principal  ;; owner
  {
    manager-id: (string-ascii 64),
    registration-time: uint
  }
)

;; Stores configuration states for registered networks
(define-map network-configurations
  {
    owner: principal,
    config-id: (string-ascii 64)
  }
  {
    config-name: (string-ascii 64),
    config-type: (string-ascii 32),
    config-data: (string-ascii 256),
    last-updated: uint
  }
)

;; Tracks all configurations registered to a particular network manager
(define-map manager-configurations
  principal  ;; manager
  (list 50 (string-ascii 64))  ;; list of config-ids, max 50 configs
)

;; Private functions

;; Checks if the network configuration manager is registered to the caller
(define-private (is-network-manager-owner (owner principal))
  (is-some (map-get? network-managers owner))
)

;; Adds a configuration to the manager's configuration list
(define-private (add-config-to-manager-list (owner principal) (config-id (string-ascii 64)))
  (let (
    (current-configs (default-to (list) (map-get? manager-configurations owner)))
  )
    (map-set manager-configurations owner (append current-configs config-id))
  )
)

;; Validates if a configuration is registered to the manager
(define-private (is-config-registered (owner principal) (config-id (string-ascii 64)))
  (is-some (map-get? network-configurations {owner: owner, config-id: config-id}))
)

;; Public functions

;; Registers a new network configuration manager
(define-public (register-network-manager (manager-id (string-ascii 64)))
  (let (
    (caller tx-sender)
  )
    (asserts! (is-none (map-get? network-managers caller)) ERR-MANAGER-ALREADY-REGISTERED)
    
    (map-set network-managers caller {
      manager-id: manager-id,
      registration-time: block-height
    })
    
    (ok true)
  )
)

;; Creates a new network configuration
(define-public (create-network-configuration 
    (config-id (string-ascii 64))
    (config-name (string-ascii 64))
    (config-type (string-ascii 32))
    (config-data (string-ascii 256)))
  (let (
    (caller tx-sender)
  )
    ;; Check that caller has a registered network configuration manager
    (asserts! (is-network-manager-owner caller) ERR-MANAGER-NOT-REGISTERED)
    
    ;; Check that configuration isn't already registered
    (asserts! (not (is-config-registered caller config-id)) ERR-CONFIG-ALREADY-EXISTS)
    
    ;; Create the configuration
    (map-set network-configurations 
      {owner: caller, config-id: config-id}
      {
        config-name: config-name,
        config-type: config-type,
        config-data: config-data,
        last-updated: block-height
      }
    )
    
    ;; Add configuration to manager's configuration list
    (add-config-to-manager-list caller config-id)
    
    (ok true)
  )
)

;; Updates an existing network configuration
(define-public (update-network-configuration 
    (config-id (string-ascii 64))
    (new-config-data (string-ascii 256)))
  (let (
    (caller tx-sender)
  )
    ;; Check that caller has a registered network configuration manager
    (asserts! (is-network-manager-owner caller) ERR-MANAGER-NOT-REGISTERED)
    
    ;; Check that configuration is registered
    (asserts! (is-config-registered caller config-id) ERR-CONFIG-NOT-FOUND)
    
    ;; Retrieve existing configuration
    (let ((existing-config (unwrap-panic (map-get? network-configurations {owner: caller, config-id: config-id}))))
      (map-set network-configurations 
        {owner: caller, config-id: config-id}
        (merge existing-config {
          config-data: new-config-data,
          last-updated: block-height
        })
      )
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Gets details of a registered network configuration manager
(define-read-only (get-network-manager-info (owner principal))
  (map-get? network-managers owner)
)

;; Gets details of a registered network configuration
(define-read-only (get-network-configuration (owner principal) (config-id (string-ascii 64)))
  (map-get? network-configurations {owner: owner, config-id: config-id})
)

;; Gets all configurations registered to a network manager
(define-read-only (get-manager-configurations (owner principal))
  (default-to (list) (map-get? manager-configurations owner))
)

;; Verifies the last update time of a configuration
(define-read-only (get-configuration-last-updated (owner principal) (config-id (string-ascii 64)))
  (match (map-get? network-configurations {owner: owner, config-id: config-id})
    config (some (get last-updated config))
    none
  )
)