package com.example.mcp.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.Map;

/**
 * Represents an MCP response message
 */
public class MCPResponse extends MCPMessage {
    
    @JsonProperty("id")
    private Object id;
    
    @JsonProperty("result")
    private Object result;
    
    @JsonProperty("error")
    private MCPError error;
    
    public MCPResponse() {}
    
    public MCPResponse(Object id, Object result) {
        this.id = id;
        this.result = result;
    }
    
    public MCPResponse(Object id, MCPError error) {
        this.id = id;
        this.error = error;
    }
    
    public Object getId() {
        return id;
    }
    
    public void setId(Object id) {
        this.id = id;
    }
    
    public Object getResult() {
        return result;
    }
    
    public void setResult(Object result) {
        this.result = result;
    }
    
    public MCPError getError() {
        return error;
    }
    
    public void setError(MCPError error) {
        this.error = error;
    }
    
    public boolean isError() {
        return error != null;
    }
    
    @Override
    public String toString() {
        return "MCPResponse{" +
                "id=" + id +
                ", result=" + result +
                ", error=" + error +
                '}';
    }
    
    public static class MCPError {
        @JsonProperty("code")
        private int code;
        
        @JsonProperty("message")
        private String message;
        
        @JsonProperty("data")
        private Object data;
        
        public MCPError() {}
        
        public MCPError(int code, String message) {
            this.code = code;
            this.message = message;
        }
        
        public MCPError(int code, String message, Object data) {
            this.code = code;
            this.message = message;
            this.data = data;
        }
        
        public int getCode() {
            return code;
        }
        
        public void setCode(int code) {
            this.code = code;
        }
        
        public String getMessage() {
            return message;
        }
        
        public void setMessage(String message) {
            this.message = message;
        }
        
        public Object getData() {
            return data;
        }
        
        public void setData(Object data) {
            this.data = data;
        }
        
        @Override
        public String toString() {
            return "MCPError{" +
                    "code=" + code +
                    ", message='" + message + '\'' +
                    ", data=" + data +
                    '}';
        }
    }
}