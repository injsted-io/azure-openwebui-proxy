
# Azure Open WebUI Proxy

This repository allows you to use your Azure OpenAI deployments inside Open WebUI by routing through a LiteLLM proxy.

It uses Docker Compose to spin up:
- LiteLLM (proxy server)
- Open WebUI

---

## Quick Start

Clone the repository:

```bash
git clone https://github.com/yourusername/azure-openwebui-proxy.git
cd azure-openwebui-proxy
```

Update `litellm/config.yaml`:

- Replace `YOUR_AZURE_API_KEY` with your Azure API Key
- Replace `YOUR_RESOURCE_NAME` with your Azure resource name

Start the services:

```bash
docker compose up -d
```

Access:

- LiteLLM Proxy: http://localhost:4000
- Open WebUI: http://localhost:3020

---

## Project Structure

```     
azure-openwebui-proxy/
├── docker-compose.yaml
├── litellm/
│   └── config.yaml
└── scripts/
    └── start.sh (optional helper)
```

- `docker-compose.yaml` runs LiteLLM and Open WebUI together.
- `litellm/config.yaml` contains your Azure model mappings.
- `scripts/start.sh` is an optional helper script to start everything.

---

## Notes

- Open WebUI will connect to `http://localhost:4000/v1/chat/completions` and use LiteLLM as if it were the OpenAI API.
- LiteLLM will translate and forward all requests to your Azure deployments.
- The environment variable `ENABLE_WEBSOCKET_SUPPORT=false` is set because Open WebUI currently has issues with streaming over WebSocket in this setup.

---

## Stopping Services

To stop and remove the containers:

```bash
docker compose down
```

---

## Troubleshooting

- If you see "Resource not found" errors, double-check the model name and deployment name in Azure.
- You can inspect detailed LiteLLM logs because `detailed_debug` is enabled.
