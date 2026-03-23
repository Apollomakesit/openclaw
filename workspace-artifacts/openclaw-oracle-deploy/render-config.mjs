#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const home = os.homedir();
const stateDir = process.env.OPENCLAW_STATE_DIR || path.join(home, ".openclaw");
const configPath = process.env.OPENCLAW_CONFIG_PATH || path.join(stateDir, "openclaw.json");

const requireEnv = (name) => {
  const value = process.env[name];
  if (!value || !value.trim()) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value.trim();
};

const optionalEnv = (name, fallback = "") => {
  const value = process.env[name];
  return value && value.trim() ? value.trim() : fallback;
};

const parseNumber = (value) => {
  if (!value) {
    return undefined;
  }
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw new Error(`Invalid numeric value: ${value}`);
  }
  return parsed;
};

const openRouterApiKey = requireEnv("OPENROUTER_API_KEY");
const openRouterModel = requireEnv("OPENROUTER_MODEL");
const enableWhatsApp = optionalEnv("ENABLE_WHATSAPP", "0") === "1";
const whatsAppDmPolicy = optionalEnv("WHATSAPP_DM_POLICY", "pairing");
const whatsAppAllowFrom = optionalEnv("WHATSAPP_ALLOW_FROM", "");
const enableMemoryLanceDb = optionalEnv("ENABLE_MEMORY_LANCEDB", "0") === "1";
const memoryCaptureMaxChars = parseNumber(optionalEnv("MEMORY_CAPTURE_MAX_CHARS", "500"));

const config = {
  env: {
    OPENROUTER_API_KEY: openRouterApiKey,
  },
  gateway: {
    bind: "loopback",
    auth: {
      mode: "token",
    },
    tailscale: {
      mode: "serve",
    },
    trustedProxies: ["127.0.0.1"],
  },
  agents: {
    defaults: {
      model: {
        primary: openRouterModel,
      },
      memorySearch: {
        provider: "local",
      },
    },
  },
  plugins: {
    enabled: true,
  },
};

// WhatsApp channel config
if (enableWhatsApp) {
  config.channels = {
    whatsapp: {
      dmPolicy: whatsAppDmPolicy,
    },
  };
  if (whatsAppAllowFrom) {
    config.channels.whatsapp.allowFrom = [whatsAppAllowFrom];
  }
  if (whatsAppDmPolicy === "allowlist" || whatsAppDmPolicy === "open") {
    config.channels.whatsapp.groupPolicy = "allowlist";
    if (whatsAppAllowFrom) {
      config.channels.whatsapp.groupAllowFrom = [whatsAppAllowFrom];
    }
  }
}

if (enableMemoryLanceDb) {
  const memoryApiKey = requireEnv("MEMORY_EMBEDDINGS_API_KEY");
  const memoryModel = optionalEnv("MEMORY_EMBEDDINGS_MODEL", "text-embedding-3-small");
  const memoryBaseUrl = optionalEnv("MEMORY_EMBEDDINGS_BASE_URL");
  const memoryDimensions = parseNumber(optionalEnv("MEMORY_EMBEDDINGS_DIMENSIONS"));

  const embedding = {
    apiKey: memoryApiKey,
    model: memoryModel,
  };

  if (memoryBaseUrl) {
    embedding.baseUrl = memoryBaseUrl;
  }
  if (typeof memoryDimensions === "number") {
    embedding.dimensions = memoryDimensions;
  }

  config.plugins.slots = {
    memory: "memory-lancedb",
  };
  config.plugins.entries = {
    "memory-lancedb": {
      enabled: true,
      config: {
        embedding,
        autoCapture: true,
        autoRecall: true,
        captureMaxChars: memoryCaptureMaxChars,
      },
    },
  };
}

fs.mkdirSync(path.dirname(configPath), { recursive: true });
fs.writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`, { mode: 0o600 });

console.log(`Wrote OpenClaw config to ${configPath}`);
