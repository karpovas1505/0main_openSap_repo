package com.example.mcp;

import com.example.mcp.service.MCPService;
import com.example.mcp.model.MCPResponse;
import com.example.mcp.util.JsonUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.net.URI;
import java.util.HashMap;
import java.util.Map;
import java.util.Scanner;
import java.util.concurrent.CompletableFuture;

/**
 * Main application class demonstrating MCP usage
 */
public class MCPApplication {
    
    private static final Logger logger = LoggerFactory.getLogger(MCPApplication.class);
    
    public static void main(String[] args) {
        System.out.println("=== MCP Java Client Example ===\n");
        
        // Default server URI (you can change this to your MCP server)
        String serverUrl = "ws://localhost:8080/mcp";
        
        if (args.length > 0) {
            serverUrl = args[0];
        }
        
        try {
            URI serverUri = URI.create(serverUrl);
            MCPService mcpService = new MCPService(serverUri);
            
            System.out.println("Connecting to MCP server: " + serverUrl);
            
            // Connect to server
            if (!mcpService.connect(10)) {
                System.err.println("Failed to connect to MCP server");
                return;
            }
            
            System.out.println("Connected successfully!\n");
            
            // Initialize MCP connection
            CompletableFuture<MCPResponse> initResponse = mcpService.initialize("MCPJavaClient", "1.0.0");
            MCPResponse response = initResponse.get();
            
            if (response.isError()) {
                System.err.println("Failed to initialize MCP: " + response.getError());
                return;
            }
            
            System.out.println("MCP initialized successfully!");
            System.out.println("Server capabilities: " + JsonUtil.prettyPrint(JsonUtil.toJson(response.getResult())));
            System.out.println();
            
            // Interactive mode
            runInteractiveMode(mcpService);
            
        } catch (Exception e) {
            logger.error("Application error", e);
            System.err.println("Error: " + e.getMessage());
        }
    }
    
    private static void runInteractiveMode(MCPService mcpService) {
        Scanner scanner = new Scanner(System.in);
        
        System.out.println("=== Interactive MCP Client ===");
        System.out.println("Available commands:");
        System.out.println("  1. list-resources - List available resources");
        System.out.println("  2. list-tools - List available tools");
        System.out.println("  3. list-prompts - List available prompts");
        System.out.println("  4. read-resource <uri> - Read a resource");
        System.out.println("  5. call-tool <name> - Call a tool");
        System.out.println("  6. get-prompt <name> - Get a prompt");
        System.out.println("  7. custom <method> - Send custom request");
        System.out.println("  8. demo - Run demo examples");
        System.out.println("  9. exit - Exit application");
        System.out.println();
        
        while (true) {
            System.out.print("mcp> ");
            String input = scanner.nextLine().trim();
            
            if (input.isEmpty()) {
                continue;
            }
            
            String[] parts = input.split("\\s+", 2);
            String command = parts[0].toLowerCase();
            
            try {
                switch (command) {
                    case "1":
                    case "list-resources":
                        handleListResources(mcpService);
                        break;
                        
                    case "2":
                    case "list-tools":
                        handleListTools(mcpService);
                        break;
                        
                    case "3":
                    case "list-prompts":
                        handleListPrompts(mcpService);
                        break;
                        
                    case "4":
                    case "read-resource":
                        if (parts.length < 2) {
                            System.out.println("Usage: read-resource <uri>");
                        } else {
                            handleReadResource(mcpService, parts[1]);
                        }
                        break;
                        
                    case "5":
                    case "call-tool":
                        if (parts.length < 2) {
                            System.out.println("Usage: call-tool <name>");
                        } else {
                            handleCallTool(mcpService, parts[1]);
                        }
                        break;
                        
                    case "6":
                    case "get-prompt":
                        if (parts.length < 2) {
                            System.out.println("Usage: get-prompt <name>");
                        } else {
                            handleGetPrompt(mcpService, parts[1]);
                        }
                        break;
                        
                    case "7":
                    case "custom":
                        if (parts.length < 2) {
                            System.out.println("Usage: custom <method>");
                        } else {
                            handleCustomRequest(mcpService, parts[1]);
                        }
                        break;
                        
                    case "8":
                    case "demo":
                        runDemo(mcpService);
                        break;
                        
                    case "9":
                    case "exit":
                        System.out.println("Goodbye!");
                        mcpService.disconnect();
                        return;
                        
                    default:
                        System.out.println("Unknown command: " + command);
                }
            } catch (Exception e) {
                System.err.println("Error executing command: " + e.getMessage());
                logger.error("Command execution error", e);
            }
            
            System.out.println();
        }
    }
    
    private static void handleListResources(MCPService mcpService) throws Exception {
        System.out.println("Listing resources...");
        MCPResponse response = mcpService.listResources().get();
        printResponse(response);
    }
    
    private static void handleListTools(MCPService mcpService) throws Exception {
        System.out.println("Listing tools...");
        MCPResponse response = mcpService.listTools().get();
        printResponse(response);
    }
    
    private static void handleListPrompts(MCPService mcpService) throws Exception {
        System.out.println("Listing prompts...");
        MCPResponse response = mcpService.listPrompts().get();
        printResponse(response);
    }
    
    private static void handleReadResource(MCPService mcpService, String uri) throws Exception {
        System.out.println("Reading resource: " + uri);
        MCPResponse response = mcpService.readResource(uri).get();
        printResponse(response);
    }
    
    private static void handleCallTool(MCPService mcpService, String toolName) throws Exception {
        System.out.println("Calling tool: " + toolName);
        Map<String, Object> arguments = new HashMap<>();
        // Add sample arguments - in real app, these would come from user input
        arguments.put("input", "sample input");
        
        MCPResponse response = mcpService.callTool(toolName, arguments).get();
        printResponse(response);
    }
    
    private static void handleGetPrompt(MCPService mcpService, String promptName) throws Exception {
        System.out.println("Getting prompt: " + promptName);
        MCPResponse response = mcpService.getPrompt(promptName, null).get();
        printResponse(response);
    }
    
    private static void handleCustomRequest(MCPService mcpService, String method) throws Exception {
        System.out.println("Sending custom request: " + method);
        MCPResponse response = mcpService.sendCustomRequest(method, null).get();
        printResponse(response);
    }
    
    private static void runDemo(MCPService mcpService) throws Exception {
        System.out.println("Running demo...");
        
        // Demo 1: List resources
        System.out.println("\n--- Demo 1: List Resources ---");
        handleListResources(mcpService);
        
        // Demo 2: List tools
        System.out.println("\n--- Demo 2: List Tools ---");
        handleListTools(mcpService);
        
        // Demo 3: List prompts
        System.out.println("\n--- Demo 3: List Prompts ---");
        handleListPrompts(mcpService);
        
        System.out.println("\nDemo completed!");
    }
    
    private static void printResponse(MCPResponse response) {
        if (response.isError()) {
            System.err.println("Error: " + response.getError());
        } else {
            System.out.println("Response: " + JsonUtil.prettyPrint(JsonUtil.toJson(response.getResult())));
        }
    }
}