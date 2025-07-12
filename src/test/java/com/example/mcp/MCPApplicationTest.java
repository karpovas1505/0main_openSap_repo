package com.example.mcp;

import com.example.mcp.model.MCPRequest;
import com.example.mcp.model.MCPResponse;
import com.example.mcp.model.MCPNotification;
import com.example.mcp.util.JsonUtil;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Test class for MCP application components
 */
public class MCPApplicationTest {
    
    @Test
    @DisplayName("Test MCPRequest serialization")
    public void testMCPRequestSerialization() {
        Map<String, Object> params = new HashMap<>();
        params.put("method", "test");
        params.put("value", 42);
        
        MCPRequest request = new MCPRequest("test/method", 1, params);
        
        String json = JsonUtil.toJson(request);
        assertNotNull(json);
        assertTrue(json.contains("test/method"));
        assertTrue(json.contains("\"id\" : 1"));
        
        System.out.println("Request JSON:");
        System.out.println(json);
    }
    
    @Test
    @DisplayName("Test MCPResponse serialization")
    public void testMCPResponseSerialization() {
        Map<String, Object> result = new HashMap<>();
        result.put("status", "success");
        result.put("data", "test data");
        
        MCPResponse response = new MCPResponse(1, result);
        
        String json = JsonUtil.toJson(response);
        assertNotNull(json);
        assertTrue(json.contains("\"id\" : 1"));
        assertTrue(json.contains("success"));
        
        System.out.println("Response JSON:");
        System.out.println(json);
    }
    
    @Test
    @DisplayName("Test MCPNotification serialization")
    public void testMCPNotificationSerialization() {
        Map<String, Object> params = new HashMap<>();
        params.put("type", "update");
        params.put("message", "Resource updated");
        
        MCPNotification notification = new MCPNotification("notifications/resource/updated", params);
        
        String json = JsonUtil.toJson(notification);
        assertNotNull(json);
        assertTrue(json.contains("notifications/resource/updated"));
        assertTrue(json.contains("Resource updated"));
        
        System.out.println("Notification JSON:");
        System.out.println(json);
    }
    
    @Test
    @DisplayName("Test JSON deserialization")
    public void testJsonDeserialization() {
        String requestJson = """
            {
              "jsonrpc": "2.0",
              "method": "test/method",
              "id": 1,
              "params": {
                "key": "value"
              }
            }
            """;
        
        MCPRequest request = JsonUtil.fromJson(requestJson, MCPRequest.class);
        assertNotNull(request);
        assertEquals("test/method", request.getMethod());
        assertEquals(1, request.getId());
        assertNotNull(request.getParams());
        assertEquals("value", request.getParams().get("key"));
        
        System.out.println("Deserialized request: " + request);
    }
    
    @Test
    @DisplayName("Test error response")
    public void testErrorResponse() {
        MCPResponse.MCPError error = new MCPResponse.MCPError(-32601, "Method not found");
        MCPResponse response = new MCPResponse(1, error);
        
        assertTrue(response.isError());
        assertEquals(-32601, response.getError().getCode());
        assertEquals("Method not found", response.getError().getMessage());
        
        String json = JsonUtil.toJson(response);
        System.out.println("Error response JSON:");
        System.out.println(json);
    }
}