//
//  DiffieHellmanTests.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 24/07/25.
//

@preconcurrency import XCTest
@preconcurrency import CryptoKit
@testable import WiPeerKit

// MARK: - Diffie-Hellman Key Exchange Tests

final class DiffieHellmanTests: XCTestCase {
    
    func testKeyPairGeneration() throws {
        // Given
        let keyExchange = DiffieHellmanKeyExchange()
        
        // When
        let (publicKey, privateKey) = try keyExchange.generateKeyPair()
        
        // Then
        XCTAssertEqual(publicKey.count, 64) // P-256 public key size
        XCTAssertEqual(privateKey.count, 32) // P-256 private key size
        
        // Verify keys are valid
        let _ = try P256.KeyAgreement.PublicKey(rawRepresentation: publicKey)
        let _ = try P256.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
    }
    
    func testSharedSecretDerivation() throws {
        // Given
        let alice = DiffieHellmanKeyExchange()
        let bob = DiffieHellmanKeyExchange()
        
        // When - Generate key pairs
        let (alicePublic, alicePrivate) = try alice.generateKeyPair()
        let (bobPublic, bobPrivate) = try bob.generateKeyPair()
        
        // Then - Derive shared secrets
        let aliceSecret = try alice.deriveSharedSecret(
            publicKey: bobPublic,
            privateKey: alicePrivate
        )
        
        let bobSecret = try bob.deriveSharedSecret(
            publicKey: alicePublic,
            privateKey: bobPrivate
        )
        
        // Verify both derive the same secret
        XCTAssertEqual(aliceSecret, bobSecret)
        XCTAssertEqual(aliceSecret.count, 32) // 256-bit key
    }
    
    func testKeyUniqueness() throws {
        // Given
        let keyExchange = DiffieHellmanKeyExchange()
        
        // When - Generate multiple key pairs
        let keyPairs = try (0..<10).map { _ in
            try keyExchange.generateKeyPair()
        }
        
        // Then - Verify all keys are unique
        let publicKeys = Set(keyPairs.map { $0.publicKey })
        let privateKeys = Set(keyPairs.map { $0.privateKey })
        
        XCTAssertEqual(publicKeys.count, 10)
        XCTAssertEqual(privateKeys.count, 10)
    }
}
