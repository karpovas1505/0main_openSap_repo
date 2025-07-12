package com.example.mcp.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.Map;

/**
 * Represents an MCP request message
 */
public class MCPRequest extends MCPMessage {
    
    @JsonProperty("id")
    private Object id;
    
    @JsonProperty("params")
    private Map<String, Object> params;
    
    public MCPRequest() {}
    
    public MCPRequest(String method, Object id) {
        super(method);
        this.id = id;
    }
    
    public MCPRequest(String method, Object id, Map<String, Object> params) {
        super(method);
        this.id = id;
        this.params = params;
    }
    
    public Object getId() {
        return id;
    }
    
    public void setId(Object id) {
        this.id = id;
    }
    
    public Map<String, Object> getParams() {
        return params;
    }
    
    public void setParams(Map<String, Object> params) {
        this.params = params;
    }
    
    @Override
    public String toString() {
        return "MCPRequest{" +
                "id=" + id +
                ", params=" + params +
                ", method='" + getMethod() + '\'' +
                '}';
    }
}