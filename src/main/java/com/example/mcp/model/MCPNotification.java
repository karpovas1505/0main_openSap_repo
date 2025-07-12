package com.example.mcp.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.Map;

/**
 * Represents an MCP notification message
 */
public class MCPNotification extends MCPMessage {
    
    @JsonProperty("params")
    private Map<String, Object> params;
    
    public MCPNotification() {}
    
    public MCPNotification(String method) {
        super(method);
    }
    
    public MCPNotification(String method, Map<String, Object> params) {
        super(method);
        this.params = params;
    }
    
    public Map<String, Object> getParams() {
        return params;
    }
    
    public void setParams(Map<String, Object> params) {
        this.params = params;
    }
    
    @Override
    public String toString() {
        return "MCPNotification{" +
                "params=" + params +
                ", method='" + getMethod() + '\'' +
                '}';
    }
}