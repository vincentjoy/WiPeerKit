@preconcurrency import XCTest
@preconcurrency import Combine
@testable import WiPeerKit

@MainActor
final class WiPeerKitTests: XCTestCase {
    
    var sut: WiPeerKit!
    var mockServiceDiscovery: MockServiceDiscovery!
    var mockTCPTransport: MockTCPTransport!
    var mockEncryption: MockEncryption!
    var messageProtocol: MessageProtocolActor!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockServiceDiscovery = MockServiceDiscovery()
        mockTCPTransport = MockTCPTransport()
        mockEncryption = MockEncryption()
        messageProtocol = MessageProtocolActor()
        cancellables = Set<AnyCancellable>()
        
        sut = WiPeerKit(
            serviceDiscovery: mockServiceDiscovery,
            tcpTransport: mockTCPTransport,
            encryption: mockEncryption,
            messageProtocol: messageProtocol
        )
        
        // Allow time for bindings to setup
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }
    
    override func tearDown() async throws {
        sut = nil
        mockServiceDiscovery = nil
        mockTCPTransport = nil
        mockEncryption = nil
        messageProtocol = nil
        cancellables = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Service Discovery Tests
    
    func testStartAdvertising() async throws {
        // When
        sut.startAdvertising(serviceName: "TestDevice")
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Then
        let isAdvertising = await mockServiceDiscovery.isAdvertising()
        XCTAssertTrue(isAdvertising)
    }
    
    func testStopAdvertising() async throws {
        // Given
        sut.startAdvertising()
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // When
        sut.stopAdvertising()
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Then
        let isAdvertising = await mockServiceDiscovery.isAdvertising()
        XCTAssertFalse(isAdvertising)
    }
    
    func testStartBrowsing() async throws {
        // When
        sut.startBrowsing()
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Then
        let isBrowsing = await mockServiceDiscovery.isBrowsing()
        XCTAssertTrue(isBrowsing)
    }
    
    func testPeerDiscovery() async throws {
        let expectation = expectation(description: "Peer discovered")
        
        // Given
        sut.$discoveredPeers
            .dropFirst()
            .sink { peers in
                XCTAssertEqual(peers.count, 1)
                XCTAssertEqual(peers.first?.name, "TestPeer")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        await mockServiceDiscovery.simulatePeerDiscovery(
            WiPeerKit.DiscoveredPeer(
                id: "test-id",
                name: "TestPeer",
                host: "192.168.1.100",
                port: 8888
            )
        )
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Connection Tests
    
    func testConnectToPeer() async throws {
        // Given
        let peer = WiPeerKit.DiscoveredPeer(
            id: "test-id",
            name: "TestPeer",
            host: "192.168.1.100",
            port: 8888
        )
        
        // When
        try await sut.connect(to: peer)
        
        // Then
        let connectCalled = await mockTCPTransport.wasConnectCalled()
        XCTAssertTrue(connectCalled)
        if case WiPeerKit.ConnectionState.connected = sut.connectionState {
            // Pass
        } else {
            XCTFail()
        }
    }
    
    func testConnectToPeerWithoutHost() async {
        // Given
        let peer = WiPeerKit.DiscoveredPeer(
            id: "test-id",
            name: "TestPeer"
        )
        
        // When/Then
        do {
            try await sut.connect(to: peer)
            XCTFail("Should throw error")
        } catch {
            XCTAssertTrue(error is WiPeerKit.WiPeerKitError)
        }
    }
    
    func testDisconnect() async throws {
        // Given
        try await sut.connect(to: WiPeerKit.DiscoveredPeer(
            id: "test",
            name: "Test",
            host: "localhost",
            port: 8888
        ))
        
        // When
        sut.disconnect()
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Then
        if case WiPeerKit.ConnectionState.disconnected = sut.connectionState {
            // Pass
        } else {
            XCTFail()
        }
    }
    
    // MARK: - Data Transfer Tests
    
    func testSendData() async throws {
        // Given
        try await sut.connect(to: WiPeerKit.DiscoveredPeer(
            id: "test",
            name: "Test",
            host: "localhost",
            port: 8888
        ))
        let testData = "Hello, WiPeerKit!".data(using: .utf8)!
        
        // When
        try await sut.send(data: testData)
        
        // Then
        let encryptCalled = await mockEncryption.wasEncryptCalled()
        XCTAssertTrue(encryptCalled)
        
        let sentData = await mockTCPTransport.getSentData()
        XCTAssertEqual(sentData.count, 1)
        XCTAssertTrue(sentData[0].count > 4) // Has length prefix
    }
    
    func testSendDataWhenNotConnected() async {
        // Given
        let testData = Data([1, 2, 3, 4])
        
        // When/Then
        do {
            try await sut.send(data: testData)
            XCTFail("Should throw error")
        } catch {
            XCTAssertTrue(error is WiPeerKit.WiPeerKitError)
        }
    }
    
    func testReceiveData() async throws {
        let expectation = expectation(description: "Data received")
        
        // Given
        let originalData = "Test message".data(using: .utf8)!
        let encryptedData = Data(originalData.map { $0 ^ 0xFF }) // Mock encryption
        let framedData = await messageProtocol.frameMessage(encryptedData)
        
        var receivedData: Data?
        sut.onDataReceived = { data in
            Task { @MainActor in
                receivedData = data
                expectation.fulfill()
            }
        }
        
        // When
        await mockTCPTransport.simulateDataReception(framedData)
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        let decryptCalled = await mockEncryption.wasDecryptCalled()
        XCTAssertTrue(decryptCalled)
        XCTAssertEqual(receivedData, originalData)
    }
}
