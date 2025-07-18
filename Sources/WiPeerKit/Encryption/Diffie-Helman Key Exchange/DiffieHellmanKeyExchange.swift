//
//  DiffieHellmanKeyExchange.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 18/07/25.
//

import Foundation
import CryptoKit

/// Diffie-Hellman key exchange implementation
struct DiffieHellmanKeyExchange: KeyExchangeProtocol {
    
    func generateKeyPair() throws -> (publicKey: Data, privateKey: Data) {
        let privateKey = P256.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey
        
        return (
            publicKey: publicKey.rawRepresentation,
            privateKey: privateKey.rawRepresentation
        )
    }
    
    func deriveSharedSecret(publicKey: Data, privateKey: Data) throws -> Data {
        let privateKeyObj = try P256.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
        let publicKeyObj = try P256.KeyAgreement.PublicKey(rawRepresentation: publicKey)
        
        let sharedSecret = try privateKeyObj.sharedSecretFromKeyAgreement(with: publicKeyObj)
        
        // Derive symmetric key from shared secret using HKDF
            let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: Data(),
                sharedInfo: Data("WiPeerKit-AES-Key".utf8),
                outputByteCount: 32
            )
        
        return symmetricKey.withUnsafeBytes { Data($0) }
    }
}
