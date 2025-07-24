//
//  SecureConnectionManager.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 18/07/25.
//

import Foundation
import CryptoKit

/// Enhanced security layer for WiPeerKit with authentication and authorization
/// This manages device authentication, key exchange, and trust relationships
public actor SecureConnectionManager {
    
    // MARK: - Public Authentication Methods
    
    /// Available authentication methods for secure connections
    public enum AuthenticationMethod: Sendable {
        /// PIN-based authentication with a 6-digit code
        case pin(String)
        /// QR code containing signed authentication token
        case qrCode(Data)
        /// Proximity-based pairing (Bluetooth/NFC)
        case proximityPairing
        /// Manual approval for each connection
        case manualApproval
        /// Only allow pre-authorized trusted devices
        case trustedDevices([DeviceIdentity])
    }
    
    // MARK: - Public Device Identity
    
    /// Represents a device's cryptographic identity
    public struct DeviceIdentity: Codable, Hashable, Sendable {
        public let id: UUID
        public let publicKey: Data           // Long-term identity key
        public let name: String
        public let modelIdentifier: String   // iPhone14,2, iPad13,1, etc.
        public let certificateHash: Data?    // Optional certificate fingerprint
        
        /// Human-readable fingerprint for visual verification
        public var fingerprint: String {
            // Create human-readable fingerprint
            let hash = SHA256.hash(data: publicKey)
            return hash.compactMap { String(format: "%02x", $0) }
                .joined()
                .prefix(16)
                .chunks(of: 4)
                .joined(separator: "-")
                .uppercased()
        }
        
        /// Public initializer for creating device identities
        public init(
            id: UUID = UUID(),
            publicKey: Data,
            name: String,
            modelIdentifier: String,
            certificateHash: Data? = nil
        ) {
            self.id = id
            self.publicKey = publicKey
            self.name = name
            self.modelIdentifier = modelIdentifier
            self.certificateHash = certificateHash
        }
    }
    
    // MARK: - Public Connection Request
    
    /// Represents a connection request from a peer device
    public struct ConnectionRequest: Codable, Sendable {
        public let identity: DeviceIdentity
        public let timestamp: Date
        public let nonce: Data
        public var signature: Data          // Signs all above fields
        public let authProof: AuthProof?    // Proof of authentication (PIN hash, etc.)
    }
    
    /// Authentication proof for various auth methods
    public struct AuthProof: Codable, Sendable {
        public enum ProofType: String, Codable, Sendable {
            case pin
            case qrCode
            case certificate
        }
        
        public let type: ProofType
        public let data: Data
    }
    
    // MARK: - Private Callbacks
    
    /// Callback when a device requests connection - return true to accept
    private var onConnectionRequest: (@Sendable (DeviceIdentity) async -> Bool)?
    
    /// Callback when PIN input is needed from user
    private var onPinRequested: (@Sendable () async -> String?)?
    
    // MARK: - Private Properties
    
    private let myIdentity: DeviceIdentity
    private let signingKey: P256.Signing.PrivateKey
    private var trustedDevices: Set<DeviceIdentity> = []
    private var activeSessions: [UUID: SecureSession] = [:]
    private let authMethod: AuthenticationMethod
    
    // MARK: - Public Initialization
    
    /// Initialize with specified authentication method
    /// - Parameter authMethod: The authentication method to use
    public init(authMethod: AuthenticationMethod = .manualApproval) throws {
        self.authMethod = authMethod
        
        // Generate or load long-term identity key
        self.signingKey = try Self.loadOrGenerateIdentityKey()
        
        // Create device identity
        self.myIdentity = DeviceIdentity(
            id: UUID(),
            publicKey: signingKey.publicKey.rawRepresentation,
            name: ProcessInfo.processInfo.hostName,
            modelIdentifier: Self.getModelIdentifier(),
            certificateHash: nil
        )
    }
    
    // MARK: - Public Methods
    
    /// Get the current device's identity
    public func getMyIdentity() -> DeviceIdentity {
        return myIdentity
    }
    
    /// Add a device to the trusted list
    public func addTrustedDevice(_ device: DeviceIdentity) {
        trustedDevices.insert(device)
        // In production, persist to Keychain
    }
    
    /// Remove a device from the trusted list
    public func removeTrustedDevice(_ device: DeviceIdentity) {
        trustedDevices.remove(device)
    }
    
    /// Get all trusted devices
    public func getTrustedDevices() -> [DeviceIdentity] {
        Array(trustedDevices)
    }
    
    /// Check if a device is trusted
    public func isDeviceTrusted(_ device: DeviceIdentity) -> Bool {
        trustedDevices.contains(device)
    }
    
    /// Set the connection request callback
    public func setOnConnectionRequest(_ handler: (@Sendable (DeviceIdentity) async -> Bool)?) {
        onConnectionRequest = handler
    }
    
    /// Get the current connection request callback
    public func getOnConnectionRequest() -> (@Sendable (DeviceIdentity) async -> Bool)? {
        return onConnectionRequest
    }
    
    /// Set the connection request callback
    public func setPinRequest(_ handler: (@Sendable () async -> String?)?) {
        onPinRequested = handler
    }
    
    // MARK: - Internal Methods (used by WiPeerKit)
    
    /// Initiate a secure connection to a peer
    internal func initiateSecureConnection(to peer: WiPeerKit.DiscoveredPeer) async throws -> ConnectionApproval {
        // Create connection request
        let nonce = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        
        var request = ConnectionRequest(
            identity: myIdentity,
            timestamp: Date(),
            nonce: nonce,
            signature: Data(), // Will be set below
            authProof: try await createAuthProof()
        )
        
        // Sign the request
        let dataToSign = try JSONEncoder().encode(request)
        request.signature = try signingKey.signature(for: dataToSign).rawRepresentation
        
        return ConnectionApproval(
            request: request,
            isApproved: false,
            sessionKey: nil
        )
    }
    
    /// Validate an incoming connection request
    internal func validateConnectionRequest(_ requestData: Data) async throws -> ConnectionApproval {
        let request = try JSONDecoder().decode(ConnectionRequest.self, from: requestData)
        
        // 1. Verify timestamp (prevent replay attacks)
        let timeDiff = abs(request.timestamp.timeIntervalSinceNow)
        guard timeDiff < 30 else {
            throw SecurityError.expiredRequest
        }
        
        // 2. Verify signature
        var requestCopy = request
        requestCopy.signature = Data()
        let dataToVerify = try JSONEncoder().encode(requestCopy)
        
        let publicKey = try P256.Signing.PublicKey(rawRepresentation: request.identity.publicKey)
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: request.signature)
        
        guard publicKey.isValidSignature(signature, for: dataToVerify) else {
            throw SecurityError.invalidSignature
        }
        
        // 3. Check authentication based on method
        let isAuthenticated = try await verifyAuthentication(request)
        
        // 4. Check authorization
        let isAuthorized = try await checkAuthorization(request.identity)
        
        if isAuthenticated && isAuthorized {
            // Generate session key
            let sessionKey = SymmetricKey(size: .bits256)
            
            // Store session
            let session = SecureSession(
                peerIdentity: request.identity,
                sessionKey: sessionKey,
                establishedAt: Date()
            )
            activeSessions[request.identity.id] = session
            
            return ConnectionApproval(
                request: request,
                isApproved: true,
                sessionKey: sessionKey
            )
        }
        
        return ConnectionApproval(
            request: request,
            isApproved: false,
            sessionKey: nil
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func verifyAuthentication(_ request: ConnectionRequest) async throws -> Bool {
        switch authMethod {
        case .pin(let correctPin):
            guard let proof = request.authProof,
                  proof.type == .pin else {
                return false
            }
            
            // Verify PIN hash
            let pinHash = SHA256.hash(data: correctPin.data(using: .utf8)!)
            return proof.data == Data(pinHash)
            
        case .qrCode(let sharedSecret):
            guard let proof = request.authProof,
                  proof.type == .qrCode else {
                return false
            }
            
            // Verify HMAC of nonce with shared secret
            let key = SymmetricKey(data: sharedSecret)
            let hmac = HMAC<SHA256>.authenticationCode(for: request.nonce, using: key)
            return proof.data == Data(hmac)
            
        case .trustedDevices(let devices):
            // Check if device is in trusted list
            return devices.contains(request.identity)
            
        case .manualApproval:
            // Will be handled in authorization step
            return true
            
        case .proximityPairing:
            // Would require additional Bluetooth/NFC verification
            throw SecurityError.notImplemented
        }
    }
    
    private func checkAuthorization(_ identity: DeviceIdentity) async throws -> Bool {
        // Check if already trusted
        if trustedDevices.contains(identity) {
            return true
        }
        
        // Ask user for approval
        if let onConnectionRequest = onConnectionRequest {
            let approved = await onConnectionRequest(identity)
            
            if approved {
                // Optionally save as trusted device
                trustedDevices.insert(identity)
            }
            
            return approved
        }
        
        return false
    }
    
    private func createAuthProof() async throws -> AuthProof? {
        switch authMethod {
        case .pin:
            // Request PIN from user
            guard let pin = await onPinRequested?() else {
                throw SecurityError.authenticationCancelled
            }
            
            let pinHash = SHA256.hash(data: pin.data(using: .utf8)!)
            return AuthProof(type: .pin, data: Data(pinHash))
            
        case .qrCode(let sharedSecret):
            // Create HMAC proof
            let nonce = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
            let key = SymmetricKey(data: sharedSecret)
            let hmac = HMAC<SHA256>.authenticationCode(for: nonce, using: key)
            return AuthProof(type: .qrCode, data: Data(hmac))
            
        default:
            return nil
        }
    }
    
    private static func loadOrGenerateIdentityKey() throws -> P256.Signing.PrivateKey {
        // In production, load from Keychain
        // For now, generate new key
        return P256.Signing.PrivateKey()
    }
    
    private static func getModelIdentifier() -> String {
#if os(iOS)
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return modelCode
#else
        return "Mac"
#endif
    }
}
