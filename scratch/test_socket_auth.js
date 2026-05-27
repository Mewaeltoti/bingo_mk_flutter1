const { io } = require("socket.io-client");

console.log("=== Socket.IO Client Authentication & Connection Test ===");
console.log("Connecting to http://localhost:3000 ...");

// 1. Test Connection Without Token (Should fail)
const socketNoToken = io("http://localhost:3000", {
    transports: ["websocket"],
    autoConnect: false
});

socketNoToken.on("connect_error", (err) => {
    console.log("\n[Test 1 PASS] Connection without token rejected as expected!");
    console.log("Error message from server:", err.message);
    socketNoToken.disconnect();
    
    // Trigger test 2 after test 1 completes
    testWithInvalidToken();
});

socketNoToken.on("connect", () => {
    console.error("\n[Test 1 FAIL] Connection without token succeeded unexpectedly!");
    socketNoToken.disconnect();
});

socketNoToken.connect();

// 2. Test Connection With Invalid Token (Should fail)
function testWithInvalidToken() {
    console.log("\nConnecting with an invalid token...");
    const socketInvalidToken = io("http://localhost:3000", {
        transports: ["websocket"],
        auth: {
            token: "invalid_mock_token_12345"
        },
        autoConnect: false
    });

    socketInvalidToken.on("connect_error", (err) => {
        console.log("[Test 2 PASS] Connection with invalid token rejected as expected!");
        console.log("Error message from server:", err.message);
        socketInvalidToken.disconnect();
        console.log("\nLocal Socket.IO auth verification tests completed successfully!");
        process.exit(0);
    });

    socketInvalidToken.on("connect", () => {
        console.error("[Test 2 FAIL] Connection with invalid token succeeded unexpectedly!");
        socketInvalidToken.disconnect();
        process.exit(1);
    });

    socketInvalidToken.connect();
}
