# Set default target
.DEFAULT_GOAL := help

# Repository root (absolute)
REPO_ROOT := $(shell git rev-parse --show-toplevel 2>/dev/null || pwd)

# MLX Agent Names
MLX_4BIT_MEMORY_AGENT_NAME := mem-agent-mlx-4bit
MLX_8BIT_MEMORY_AGENT_NAME := mem-agent-mlx-8bit
MLX_MEMORY_AGENT_NAME := driaforall/mem-agent-mlx-bf16 
BF16_MEMORY_AGENT_SEARCH_NAME := mem-agent-mlx-bf16

# Help command
help:
	@echo "Usage: make <target>"
	@echo "Targets:"
	@echo "  1. help - Show this help message"
	@echo "  2. check-uv - Check if uv is installed and install if needed"
	@echo "  3. install - Install dependencies using uv"
	@echo "  4. setup - Choose memory directory via GUI and save to .memory_path"
	@echo "  5. add-filters - Add filters to .filters"
	@echo "  6. reset-filters - Reset filters in .filters"
	@echo "  7. run-agent - Run the agent"
	@echo "  8. generate-mcp-json - Generate the MCP.json file"
	@echo "  9. serve-mcp - Serve the MCP server"
	@echo "  10. chat-cli - Run interactive CLI to chat with the agent"
	@echo "  11. memory-wizard - Interactive wizard for connecting memory sources"  
	@echo "  12. connect-memory - Connect memory sources using new connector system"
	@echo "  13. convert-chatgpt - Convert ChatGPT export (legacy, use convert-memory instead)"
	@echo "  14. serve-http - Start HTTP server for ChatGPT integration (use with ngrok)"
	@echo "  15. serve-mcp-http - Start MCP-compliant HTTP server for ChatGPT (recommended)"

# Check if uv is installed and install if needed
check-uv:
	@echo "Checking if uv is installed..."
	@if ! command -v uv > /dev/null; then \
		echo "uv not found. Installing uv..."; \
		curl -LsSf https://astral.sh/uv/install.sh | sh; \
		echo "Please restart your shell or run 'source ~/.bashrc' (or ~/.zshrc) to use uv"; \
	else \
		echo "uv is already installed"; \
		uv --version; \
	fi

# Install dependencies using uv
install: check-uv
	@echo "Installing top-level workspace with uv..."
	uv sync
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		if ! command -v lms > /dev/null; then \
			echo "lms not found. Installing lms..."; \
			chmod +x mcp_server/scripts/install_lms.sh; \
			./mcp_server/scripts/install_lms.sh; \
		else \
			echo "lms is already installed"; \
		fi; \
	fi

setup:
	uv run python mcp_server/scripts/memory_setup.py && uv run python mcp_server/scripts/setup_scripts_and_json.py && chmod +x mcp_server/scripts/start_server.sh

add-filters:
	uv run python mcp_server/scripts/filters.py --add

reset-filters:
	uv run python mcp_server/scripts/filters.py --reset

run-agent:
	@if command -v lms > /dev/null; then \
		echo "LM Studio detected. Starting local server..."; \
		if lms ls | grep -q driaforall.mem-agent; then \
			echo "Model driaforall.mem-agent found. Loading..."; \
			lms load driaforall.mem-agent; \
			lms server start --port 8000; \
		else \
			echo "Model driaforall.mem-agent not found. Please download it first:"; \
			echo "  lms get driaforall/mem-agent"; \
		fi; \
	elif [ "$$(uname -s)" = "Darwin" ]; then \
		echo "Detected macOS (Darwin). Installing LM Studio..."; \
		chmod +x mcp_server/scripts/install_lms.sh; \
		./mcp_server/scripts/install_lms.sh; \
		echo "After installation, run 'make run-agent' again."; \
	elif [ -f /etc/NIXOS ]; then \
		echo "NixOS detected. Install LM Studio or use OpenRouter API:"; \
		echo "  Option 1: Install LM Studio and run 'make run-agent'"; \
		echo "  Option 2: Set OPENROUTER_API_KEY and run 'make chat-cli'"; \
	else \
		echo "Non-macOS detected. Trying vLLM server..."; \
		uv run vllm serve driaforall/mem-agent; \
	fi

generate-mcp-json:
	@echo "Generating mcp.json..."
	@echo '{"mcpServers": {"memory-agent-stdio": {"command": "bash", "args": ["-lc", "cd $(REPO_ROOT) && uv run python mcp_server/server.py"], "env": {"FASTMCP_LOG_LEVEL": "INFO", "MCP_TRANSPORT": "stdio"}, "timeout": 600000}}}' > mcp.json
	@echo "Wrote mcp.json the following contents:"
	@cat mcp.json

serve-mcp:
	@echo "Starting MCP server over STDIO"
	FASTMCP_LOG_LEVEL=INFO MCP_TRANSPORT=stdio uv run python -m mcp_server.server

chat-cli:
	uv run python chat_cli.py

# Interactive Memory Wizard
memory-wizard:
	@echo "🧙‍♂️ Starting Memory Connector Wizard..."
	uv run python -m memory_connectors.memory_wizard

# Memory Connectors (unified system)
connect-memory:
	@echo "Memory Connectors - Convert various sources to mem-agent format"
	@echo "Usage: make connect-memory CONNECTOR=<type> SOURCE=<path> [OUTPUT=<path>] [MAX_ITEMS=<num>] [TOKEN=<token>]"
	@echo ""
	@echo "Available connectors:"
	@uv run python -m memory_connectors.memory_connect --list
	@echo ""
	@if [ -z "$(CONNECTOR)" ] || [ -z "$(SOURCE)" ]; then \
		echo "Examples:"; \
		echo "  Export-based: make connect-memory CONNECTOR=chatgpt SOURCE=/path/to/export.zip"; \
		echo "  Live GitHub:  make connect-memory CONNECTOR=github SOURCE='owner/repo' TOKEN=github_token"; \
		echo "  Live Google:  make connect-memory CONNECTOR=google-docs SOURCE='folder_id' TOKEN=access_token"; \
		exit 1; \
	fi
	@if [ "$(CONNECTOR)" != "github" ] && [ "$(CONNECTOR)" != "google-docs" ] && [ ! -e "$(SOURCE)" ]; then \
		echo "Error: Source path does not exist: $(SOURCE)"; \
		exit 1; \
	fi
	@cmd="uv run python -m memory_connectors.memory_connect $(CONNECTOR) $(SOURCE)"; \
	if [ -n "$(OUTPUT)" ]; then cmd="$$cmd --output $(OUTPUT)"; fi; \
	if [ -n "$(MAX_ITEMS)" ]; then cmd="$$cmd --max-items $(MAX_ITEMS)"; fi; \
	if [ -n "$(TOKEN)" ]; then cmd="$$cmd --token $(TOKEN)"; fi; \
	echo "Running: $$cmd"; \
	$$cmd

# Legacy ChatGPT converter (kept for backwards compatibility)
convert-chatgpt:
	@echo "⚠️  Legacy ChatGPT converter (use 'make connect-memory CONNECTOR=chatgpt' instead)"
	@echo "Usage: make convert-chatgpt EXPORT_PATH=/path/to/chatgpt-export [MAX_CONVERSATIONS=100]"
	@echo ""
	@if [ -z "$(EXPORT_PATH)" ]; then \
		echo "Error: EXPORT_PATH is required"; \
		echo "Example: make convert-chatgpt EXPORT_PATH=/Users/username/Downloads/chatgpt-export"; \
		exit 1; \
	fi
	@if [ ! -e "$(EXPORT_PATH)" ]; then \
		echo "Error: Export path does not exist: $(EXPORT_PATH)"; \
		exit 1; \
	fi
	@cmd="uv run python -m memory_connectors.memory_connect chatgpt $(EXPORT_PATH)"; \
	if [ -n "$(MAX_CONVERSATIONS)" ]; then cmd="$$cmd --max-items $(MAX_CONVERSATIONS)"; fi; \
	echo "🔄 Redirecting to new connector system..."; \
	echo "Running: $$cmd"; \
	$$cmd

# HTTP Server for ChatGPT Integration
serve-http:
	@echo "🌐 Starting HTTP server for ChatGPT integration..."
	@echo "💡 This creates an HTTP wrapper around the existing stdio MCP server"
	@echo "🔗 Server will be available at: http://localhost:8080"
	@echo ""
	@echo "📋 Next steps:"
	@echo "   1. Make sure your memory server is properly configured (make setup)"
	@echo "   2. In another terminal, run: ngrok http 8080"
	@echo "   3. Use the ngrok URL in ChatGPT Developer Mode"
	@echo ""
	uv run python mcp_server/http_server.py

# MCP-Compliant HTTP Server for ChatGPT
serve-mcp-http:
	@echo "🌐 Starting MCP-compliant HTTP server for ChatGPT..."
	@echo "📋 This implements proper Model Context Protocol over HTTP"
	@echo "🔗 Server will be available at: http://localhost:8081"
	@echo "🔗 MCP endpoint: http://localhost:8081/mcp"
	@echo ""
	@echo "📋 Next steps:"
	@echo "   1. In another terminal, run: ngrok http 8081"
	@echo "   2. In ChatGPT, use: https://your-ngrok-url.ngrok.io/mcp"
	@echo "   3. Set protocol to 'HTTP' (not SSE)"
	@echo ""
	uv run python mcp_server/mcp_http_server.py