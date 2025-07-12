package com.example.mcp.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;

/**
 * Base class for all MCP (Model Context Protocol) messages
 */
@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, property = "method", visible = true)
@JsonSubTypes({
    @JsonSubTypes.Type(value = MCPRequest.class, name = "request"),
    @JsonSubTypes.Type(value = MCPResponse.class, name = "response"),
    @JsonSubTypes.Type(value = MCPNotification.class, name = "notification")
})
public abstract class MCPMessage {
    
    @JsonProperty("jsonrpc")
    private String jsonrpc = "2.0";
    
    @JsonProperty("method")
    private String method;
    
    public MCPMessage() {}
    
    public MCPMessage(String method) {
        this.method = method;
    }
    
    public String getJsonrpc() {
        return jsonrpc;
    }
    
    public void setJsonrpc(String jsonrpc) {
        this.jsonrpc = jsonrpc;
    }
    
    public String getMethod() {
        return method;
    }
    
    public void setMethod(String method) {
        this.method = method;
    }
    
    @Override
    public String toString() {
        return "MCPMessage{" +
                "jsonrpc='" + jsonrpc + '\'' +
                ", method='" + method + '\'' +
                '}';
    }
}