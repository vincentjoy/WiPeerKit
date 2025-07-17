//
//  MockEncryption.swift
//  WiPeerKit
//
//  Created by Vincent Joy on 17/07/25.
//

import XCTest
@testable import WiPeerKit

actor MockEncryption: EncryptionProtocol {
    private var encryptCalled = false
    private var decryptCalled = false
    
    func encrypt(_ data: Data) throws -> Data {
        encryptCalled = true
        // Simple XOR encryption for testing
        return Data(data.map { $0 ^ 0xFF })
    }
    
    func decrypt(_ data: Data) throws -> Data {
        decryptCalled = true
        // Simple XOR decryption for testing
        return Data(data.map { $0 ^ 0xFF })
    }
    
    func setKey(_ key: Data) throws {}
    
    func wasEncryptCalled() -> Bool {
        encryptCalled
    }
    
    func wasDecryptCalled() -> Bool {
        decryptCalled
    }
}
