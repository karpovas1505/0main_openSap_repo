package com.example.mcp.service;

import com.example.mcp.client.MCPClient;
import com.example.mcp.model.MCPRequest;
import com.example.mcp.model.MCPResponse;
import com.example.mcp.model.MCPNotification;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.net.URI;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * High-level service for MCP operations
 */
public class MCPService implements MCPClient.MCPMessageHandler {
    
    private static final Logger logger = LoggerFactory.getLogger(MCPService.class);
    
    private final MCPClient client;
    private final CountDownLatch connectionLatch;
    private boolean connected;
    
    public MCPService(URI serverUri) {
        this.client = new MCPClient(serverUri);
        this.client.setMessageHandler(this);
        this.connectionLatch = new CountDownLatch(1);
        this.connected = false;
    }
    
    /**
     * Connect to MCP server and wait for connection
     */
    public boolean connect(int timeoutSeconds) {
        try {
            client.connect();
            return connectionLatch.await(timeoutSeconds, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return false;
        }
    }
    
    /**
     * Disconnect from MCP server
     */
    public void disconnect() {
        client.disconnect();
    }
    
    /**
     * Check if connected to server
     */
    public boolean isConnected() {
        return connected && client.isConnected();
    }
    
    /**
     * Initialize MCP connection with capabilities
     */
    public CompletableFuture<MCPResponse> initialize(String clientName, String clientVersion) {
        Map<String, Object> params = new HashMap<>();
        params.put("protocolVersion", "2024-11-05");
        params.put("capabilities", Map.of(
            "roots", Map.of("listChanged", true),
            "sampling", Map.of()
        ));
        
        Map<String, Object> clientInfo = new HashMap<>();
        clientInfo.put("name", clientName);
        clientInfo.put("version", clientVersion);
        params.put("clientInfo", clientInfo);
        
        return client.sendRequest("initialize", params);
    }
    
    /**
     * List available resources
     */
    public CompletableFuture<MCPResponse> listResources() {
        return client.sendRequest("resources/list", null);
    }
    
    /**
     * Read a specific resource
     */
    public CompletableFuture<MCPResponse> readResource(String uri) {
        Map<String, Object> params = new HashMap<>();
        params.put("uri", uri);
        return client.sendRequest("resources/read", params);
    }
    
    /**
     * List available tools
     */
    public CompletableFuture<MCPResponse> listTools() {
        return client.sendRequest("tools/list", null);
    }
    
    /**
     * Call a tool
     */
    public CompletableFuture<MCPResponse> callTool(String toolName, Map<String, Object> arguments) {
        Map<String, Object> params = new HashMap<>();
        params.put("name", toolName);
        params.put("arguments", arguments);
        return client.sendRequest("tools/call", params);
    }
    
    /**
     * List available prompts
     */
    public CompletableFuture<MCPResponse> listPrompts() {
        return client.sendRequest("prompts/list", null);
    }
    
    /**
     * Get a prompt
     */
    public CompletableFuture<MCPResponse> getPrompt(String promptName, Map<String, Object> arguments) {
        Map<String, Object> params = new HashMap<>();
        params.put("name", promptName);
        if (arguments != null) {
            params.put("arguments", arguments);
        }
        return client.sendRequest("prompts/get", params);
    }
    
    /**
     * Send a custom request
     */
    public CompletableFuture<MCPResponse> sendCustomRequest(String method, Map<String, Object> params) {
        return client.sendRequest(method, params);
    }
    
    /**
     * Send a notification
     */
    public void sendNotification(String method, Map<String, Object> params) {
        client.sendNotification(method, params);
    }
    
    // MCPMessageHandler implementation
    
    @Override
    public void onConnected() {
        logger.info("Connected to MCP server");
        connected = true;
        connectionLatch.countDown();
    }
    
    @Override
    public void onDisconnected(int code, String reason) {
        logger.info("Disconnected from MCP server: {} - {}", code, reason);
        connected = false;
    }
    
    @Override
    public void onError(Exception ex) {
        logger.error("MCP client error", ex);
    }
    
    @Override
    public void onNotification(MCPNotification notification) {
        logger.info("Received notification: {}", notification);
        // Handle specific notifications here
        switch (notification.getMethod()) {
            case "notifications/resources/list_changed":
                logger.info("Resources list changed");
                break;
            case "notifications/tools/list_changed":
                logger.info("Tools list changed");
                break;
            case "notifications/prompts/list_changed":
                logger.info("Prompts list changed");
                break;
            default:
                logger.debug("Unknown notification method: {}", notification.getMethod());
        }
    }
    
    @Override
    public void onRequest(MCPRequest request) {
        logger.info("Received request: {}", request);
        // Handle server requests here (if server can send requests to client)
    }
}