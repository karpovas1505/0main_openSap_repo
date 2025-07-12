package com.example.mcp.client;

import com.example.mcp.model.MCPMessage;
import com.example.mcp.model.MCPRequest;
import com.example.mcp.model.MCPResponse;
import com.example.mcp.model.MCPNotification;
import com.example.mcp.util.JsonUtil;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.java_websocket.client.WebSocketClient;
import org.java_websocket.handshake.ServerHandshake;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.net.URI;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * WebSocket client for MCP (Model Context Protocol) communication
 */
public class MCPClient {
    
    private static final Logger logger = LoggerFactory.getLogger(MCPClient.class);
    
    private final WebSocketClient webSocketClient;
    private final ObjectMapper objectMapper;
    private final Map<Object, CompletableFuture<MCPResponse>> pendingRequests;
    private final AtomicLong requestIdGenerator;
    
    private MCPMessageHandler messageHandler;
    
    public MCPClient(URI serverUri) {
        this.objectMapper = JsonUtil.createObjectMapper();
        this.pendingRequests = new ConcurrentHashMap<>();
        this.requestIdGenerator = new AtomicLong(1);
        
        this.webSocketClient = new WebSocketClient(serverUri) {
            @Override
            public void onOpen(ServerHandshake handshake) {
                logger.info("Connected to MCP server: {}", serverUri);
                if (messageHandler != null) {
                    messageHandler.onConnected();
                }
            }
            
            @Override
            public void onMessage(String message) {
                logger.debug("Received message: {}", message);
                handleMessage(message);
            }
            
            @Override
            public void onClose(int code, String reason, boolean remote) {
                logger.info("Disconnected from MCP server. Code: {}, Reason: {}", code, reason);
                if (messageHandler != null) {
                    messageHandler.onDisconnected(code, reason);
                }
            }
            
            @Override
            public void onError(Exception ex) {
                logger.error("WebSocket error", ex);
                if (messageHandler != null) {
                    messageHandler.onError(ex);
                }
            }
        };
    }
    
    public void setMessageHandler(MCPMessageHandler handler) {
        this.messageHandler = handler;
    }
    
    public void connect() {
        webSocketClient.connect();
    }
    
    public void disconnect() {
        webSocketClient.close();
    }
    
    public boolean isConnected() {
        return webSocketClient.isOpen();
    }
    
    /**
     * Send a request and wait for response
     */
    public CompletableFuture<MCPResponse> sendRequest(String method, Map<String, Object> params) {
        Long requestId = requestIdGenerator.getAndIncrement();
        MCPRequest request = new MCPRequest(method, requestId, params);
        
        CompletableFuture<MCPResponse> future = new CompletableFuture<>();
        pendingRequests.put(requestId, future);
        
        try {
            String json = objectMapper.writeValueAsString(request);
            webSocketClient.send(json);
            logger.debug("Sent request: {}", json);
        } catch (Exception e) {
            pendingRequests.remove(requestId);
            future.completeExceptionally(e);
        }
        
        return future;
    }
    
    /**
     * Send a notification (no response expected)
     */
    public void sendNotification(String method, Map<String, Object> params) {
        MCPNotification notification = new MCPNotification(method, params);
        
        try {
            String json = objectMapper.writeValueAsString(notification);
            webSocketClient.send(json);
            logger.debug("Sent notification: {}", json);
        } catch (Exception e) {
            logger.error("Failed to send notification", e);
        }
    }
    
    private void handleMessage(String message) {
        try {
            MCPMessage mcpMessage = objectMapper.readValue(message, MCPMessage.class);
            
            if (mcpMessage instanceof MCPResponse) {
                handleResponse((MCPResponse) mcpMessage);
            } else if (mcpMessage instanceof MCPNotification) {
                handleNotification((MCPNotification) mcpMessage);
            } else if (mcpMessage instanceof MCPRequest) {
                handleRequest((MCPRequest) mcpMessage);
            }
        } catch (Exception e) {
            logger.error("Failed to parse message: {}", message, e);
        }
    }
    
    private void handleResponse(MCPResponse response) {
        CompletableFuture<MCPResponse> future = pendingRequests.remove(response.getId());
        if (future != null) {
            future.complete(response);
        } else {
            logger.warn("Received response for unknown request: {}", response.getId());
        }
    }
    
    private void handleNotification(MCPNotification notification) {
        if (messageHandler != null) {
            messageHandler.onNotification(notification);
        }
    }
    
    private void handleRequest(MCPRequest request) {
        if (messageHandler != null) {
            messageHandler.onRequest(request);
        }
    }
    
    public interface MCPMessageHandler {
        void onConnected();
        void onDisconnected(int code, String reason);
        void onError(Exception ex);
        void onNotification(MCPNotification notification);
        void onRequest(MCPRequest request);
    }
}