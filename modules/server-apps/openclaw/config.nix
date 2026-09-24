{
  "commands" = {
    "native" = "auto";
    "nativeSkills" = "auto";
    "restart" = true;
    "ownerAllowFrom" = [ "matrix:@joshan-kana:beeper.com" ];
  };
  "gateway" = {
    "port" = 18789;
    "mode" = "local";
    "bind" = "loopback";
    "controlUi" = {
      "allowedOrigins" = [
        "http://127.0.0.1:18789"
        "http://192.168.1.3:18789"
        "http://localhost:18789"
        "http://nixos-server.local:18789"
        "http://nixos-server:18789"
      ];
    };
    "auth" = {
      "mode" = "trusted-proxy";
      "identityScopes" = {
        "joshan" = [ "operator.admin" ];
      };
      "trustedProxy" = {
        "userHeader" = "x-forwarded-user";
        "allowUsers" = [ "joshan" ];
        "requiredHeaders" = [
          "x-forwarded-proto"
          "x-forwarded-host"
        ];
        "allowLoopback" = true;
      };
    };
    "trustedProxies" = [
      "127.0.0.1"
      "::1"
    ];
    "nodes" = {
      "commands" = {
        "allow" = [
          "calendar.add"
          "camera.clip"
          "camera.snap"
          "contacts.add"
          "health.summary"
          "reminders.add"
          "screen.record"
        ];
        "deny" = [ ];
      };
    };
  };
  "messages" = {
    "ackReactionScope" = "group-mentions";
  };
  "agents" = {
    "defaults" = {
      "workspace" = "/var/lib/apps/openclaw/workspace";
      "maxConcurrent" = 4;
      "subagents" = {
        "maxConcurrent" = 8;
        "archiveAfterMinutes" = 60;
      };
      "model" = {
        "primary" = "openrouter-zdr/minimax/minimax-m3";
        "fallbacks" = [ ];
      };
      "models" = {
        "openai/*" = {
          "agentRuntime" = {
            "id" = "codex";
          };
        };
        "ollama/*" = { };
        "openai/gpt-5.5" = { };
        "together/*" = { };
        "deepseek/*" = { };
        "openrouter-zdr/minimax/minimax-m3" = {
          "alias" = "OR ZDR MiniMax M3";
        };
        "openrouter-zdr/z-ai/glm-5.2" = {
          "alias" = "OR ZDR GLM 5.2";
        };
        "openrouter-deepseek/deepseek/deepseek-v4-flash" = {
          "alias" = "OR DeepSeek V4 Flash (non-ZDR)";
        };
        "openrouter-deepseek/deepseek/deepseek-v4-pro" = {
          "alias" = "OR DeepSeek V4 Pro (non-ZDR)";
        };
        "openrouter-free/google/gemma-4-31b-it:free" = {
          "alias" = "OR Free Gemma 4 31B (FREE / NON-SENSITIVE)";
        };
        "openrouter-free/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free" = {
          "alias" = "OR Free Nemotron 3 Nano Omni (FREE / NON-SENSITIVE)";
        };
        "openrouter-free/nvidia/nemotron-3-ultra-550b-a55b:free" = {
          "alias" = "OR Free Nemotron 3 Ultra (FREE / NON-SENSITIVE)";
        };
        "openrouter-free/nvidia/nemotron-3-super-120b-a12b:free" = {
          "alias" = "OR Free Nemotron 3 Super (FREE / NON-SENSITIVE)";
        };
        "openrouter-free/openai/gpt-oss-20b:free" = {
          "alias" = "OR Free GPT-OSS 20B (FREE / NON-SENSITIVE)";
        };
        "openrouter-deepseek/deepseek/deepseek-v4-flash-latest" = {
          "alias" = "OR DeepSeek V4 Flash (latest, non-ZDR)";
        };
        "openai/gpt-5.6-luna" = { };
      };
      "thinkingDefault" = "low";
      "reasoningDefault" = "stream";
      "modelPolicy" = {
        "allow" = [
          "openai/*"
          "ollama/*"
          "openai/gpt-5.5"
          "together/*"
          "deepseek/*"
          "openrouter-zdr/minimax/minimax-m3"
          "openrouter-zdr/z-ai/glm-5.2"
          "openrouter-deepseek/deepseek/deepseek-v4-flash"
          "openrouter-deepseek/deepseek/deepseek-v4-pro"
          "openrouter-free/google/gemma-4-31b-it:free"
          "openrouter-free/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free"
          "openrouter-free/nvidia/nemotron-3-ultra-550b-a55b:free"
          "openrouter-free/nvidia/nemotron-3-super-120b-a12b:free"
          "openrouter-free/openai/gpt-oss-20b:free"
          "openrouter-deepseek/deepseek/deepseek-v4-flash-latest"
        ];
      };
    };
    "entries" = {
      "main" = {
        "name" = "Main";
        "description" = "Default personal agent";
      };
    };
  };
  "skills" = {
    "entries" = {
      "1password" = {
        "enabled" = false;
      };
      "apple-notes" = {
        "enabled" = false;
      };
      "apple-reminders" = {
        "enabled" = false;
      };
      "bear-notes" = {
        "enabled" = false;
      };
      "blogwatcher" = {
        "enabled" = false;
      };
      "blucli" = {
        "enabled" = false;
      };
      "camsnap" = {
        "enabled" = false;
      };
      "clawhub" = {
        "enabled" = false;
      };
      "coding-agent" = {
        "enabled" = false;
      };
      "discord" = {
        "enabled" = false;
      };
      "eightctl" = {
        "enabled" = false;
      };
      "gemini" = {
        "enabled" = false;
      };
      "gh-issues" = {
        "enabled" = false;
      };
      "gifgrep" = {
        "enabled" = false;
      };
      "github" = {
        "enabled" = false;
      };
      "gog" = {
        "enabled" = false;
      };
      "goplaces" = {
        "enabled" = false;
      };
      "himalaya" = {
        "enabled" = false;
      };
      "imsg" = {
        "enabled" = false;
      };
      "mcporter" = {
        "enabled" = false;
      };
      "model-usage" = {
        "enabled" = false;
      };
      "nano-pdf" = {
        "enabled" = false;
      };
      "obsidian" = {
        "enabled" = false;
      };
      "openai-whisper" = {
        "enabled" = false;
      };
      "openai-whisper-api" = {
        "enabled" = false;
      };
      "openhue" = {
        "enabled" = false;
      };
      "oracle" = {
        "enabled" = false;
      };
      "ordercli" = {
        "enabled" = false;
      };
      "peekaboo" = {
        "enabled" = false;
      };
      "sag" = {
        "enabled" = false;
      };
      "session-logs" = {
        "enabled" = false;
      };
      "sherpa-onnx-tts" = {
        "enabled" = false;
      };
      "slack" = {
        "enabled" = false;
      };
      "songsee" = {
        "enabled" = false;
      };
      "sonoscli" = {
        "enabled" = false;
      };
      "spotify-player" = {
        "enabled" = false;
      };
      "summarize" = {
        "enabled" = false;
      };
      "things-mac" = {
        "enabled" = false;
      };
      "tmux" = {
        "enabled" = false;
      };
      "trello" = {
        "enabled" = false;
      };
      "video-frames" = {
        "enabled" = false;
      };
      "voice-call" = {
        "enabled" = false;
      };
      "wacli" = {
        "enabled" = false;
      };
      "xurl" = {
        "enabled" = false;
      };
    };
  };
  "plugins" = {
    "entries" = {
      "openai" = {
        "enabled" = true;
      };
      "ollama" = {
        "enabled" = true;
      };
      "device-pair" = {
        "config" = {
          "publicUrl" = "ws://192.168.1.3:18789";
        };
        "enabled" = true;
      };
      "together" = {
        "enabled" = true;
      };
      "memory-core" = {
        "subagent" = {
          "allowModelOverride" = true;
        };
        "config" = {
          "dreaming" = {
            "model" = "openai/gpt-5.6-luna";
          };
        };
        "enabled" = true;
      };
    };
    "allow" = [
      "codex"
      "deepseek"
      "device-pair"
      "matrix"
      "memory-core"
      "ollama"
      "openai"
      "together"
    ];
    "deny" = [ ];
  };
  "auth" = {
    "order" = {
      "openai" = [ "openai:joshansocool@gmail.com" ];
    };
  };
  "models" = {
    "providers" = {
      "openai" = {
        "agentRuntime" = {
          "id" = "codex";
        };
      };
      "ollama" = {
        "api" = "ollama";
        "baseUrl" = "http://127.0.0.1:11434";
        "apiKey" = "ollama-local";
        "timeoutSeconds" = 300;
        "models" = [
          {
            "id" = "qwen3:4b";
            "name" = "qwen3:4b";
            "input" = [ "text" ];
            "reasoning" = true;
            "contextWindow" = 32768;
            "maxTokens" = 4096;
            "params" = {
              "keep_alive" = "15m";
              "num_ctx" = 32768;
              "num_predict" = 1024;
              "temperature" = 0.1;
            };
          }
          {
            "id" = "qwen2.5-coder:14b";
            "name" = "qwen2.5-coder:14b";
            "input" = [ "text" ];
            "contextWindow" = 32768;
            "maxTokens" = 4096;
            "params" = {
              "keep_alive" = "15m";
              "num_ctx" = 32768;
              "num_predict" = 512;
              "temperature" = 0.1;
            };
          }
          {
            "id" = "llama3.1:8b";
            "name" = "llama3.1:8b";
            "input" = [ "text" ];
            "contextWindow" = 32768;
            "maxTokens" = 4096;
            "params" = {
              "keep_alive" = "15m";
              "num_ctx" = 32768;
              "num_predict" = 1024;
              "temperature" = 0.2;
            };
          }
        ];
      };
      "together" = {
        "apiKey" = {
          "source" = "env";
          "provider" = "default";
          "id" = "TOGETHER_API_KEY";
        };
        "models" = [
          {
            "id" = "MiniMaxAI/MiniMax-M3";
            "name" = "MiniMax M3";
            "reasoning" = true;
            "input" = [
              "text"
              "image"
            ];
            "contextWindow" = 1000000;
            "maxTokens" = 8192;
          }
        ];
        "baseUrl" = "https://api.together.xyz/v1";
        "api" = "openai-completions";
      };
      "deepseek" = {
        "api" = "openai-completions";
        "baseUrl" = "https://api.deepseek.com";
        "apiKey" = {
          "source" = "env";
          "provider" = "default";
          "id" = "DEEPSEEK_API_KEY";
        };
      };
      "openrouter-zdr" = {
        "baseUrl" = "https://openrouter.ai/api/v1";
        "api" = "openai-completions";
        "apiKey" = {
          "source" = "env";
          "provider" = "default";
          "id" = "OPENROUTER_ZDR_API_KEY";
        };
        "timeoutSeconds" = 300;
        "models" = [
          {
            "id" = "minimax/minimax-m3";
            "name" = "MiniMax M3 — OpenRouter ZDR";
            "reasoning" = true;
            "input" = [
              "text"
              "image"
            ];
            "contextWindow" = 1048576;
            "maxTokens" = 131072;
          }
          {
            "id" = "z-ai/glm-5.2";
            "name" = "GLM 5.2 — OpenRouter ZDR";
            "reasoning" = true;
            "input" = [ "text" ];
            "contextWindow" = 1048576;
            "maxTokens" = 131072;
          }
        ];
      };
      "openrouter-deepseek" = {
        "baseUrl" = "https://openrouter.ai/api/v1";
        "api" = "openai-completions";
        "apiKey" = {
          "source" = "env";
          "provider" = "default";
          "id" = "OPENROUTER_DEEPSEEK_API_KEY";
        };
        "timeoutSeconds" = 300;
        "models" = [
          {
            "id" = "deepseek/deepseek-v4-flash-latest";
            "name" = "DeepSeek V4 Flash (latest) — OpenRouter non-ZDR";
            "reasoning" = true;
            "input" = [ "text" ];
            "contextWindow" = 1048576;
            "maxTokens" = 65536;
          }
          {
            "id" = "deepseek/deepseek-v4-pro";
            "name" = "DeepSeek V4 Pro — OpenRouter non-ZDR";
            "reasoning" = true;
            "input" = [ "text" ];
            "contextWindow" = 1048576;
            "maxTokens" = 393216;
          }
        ];
      };
      "openrouter-free" = {
        "baseUrl" = "https://openrouter.ai/api/v1";
        "api" = "openai-completions";
        "apiKey" = {
          "source" = "env";
          "provider" = "default";
          "id" = "OPENROUTER_FREE_API_KEY";
        };
        "timeoutSeconds" = 300;
        "models" = [
          {
            "id" = "google/gemma-4-31b-it:free";
            "name" = "Gemma 4 31B (free) — FREE / NON-SENSITIVE";
            "reasoning" = true;
            "input" = [ "text" ];
            "contextWindow" = 262144;
            "maxTokens" = 16384;
          }
          {
            "id" = "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free";
            "name" = "Nemotron 3 Nano Omni (free) — FREE / NON-SENSITIVE";
            "reasoning" = true;
            "input" = [ "text" ];
            "contextWindow" = 256000;
            "maxTokens" = 65536;
          }
          {
            "id" = "nvidia/nemotron-3-ultra-550b-a55b:free";
            "name" = "Nemotron 3 Ultra (free) — FREE / NON-SENSITIVE";
            "reasoning" = true;
            "input" = [ "text" ];
            "contextWindow" = 1000000;
            "maxTokens" = 65536;
          }
          {
            "id" = "nvidia/nemotron-3-super-120b-a12b:free";
            "name" = "Nemotron 3 Super (free) — FREE / NON-SENSITIVE";
            "reasoning" = true;
            "input" = [ "text" ];
            "contextWindow" = 262144;
            "maxTokens" = 65536;
          }
          {
            "id" = "openai/gpt-oss-20b:free";
            "name" = "GPT-OSS 20B (free) — FREE / NON-SENSITIVE";
            "reasoning" = true;
            "input" = [ "text" ];
            "contextWindow" = 131072;
            "maxTokens" = 16384;
          }
        ];
      };
      "openrouter-openai" = {
        "baseUrl" = "https://openrouter.ai/api/v1";
        "api" = "openai-completions";
        "apiKey" = {
          "source" = "env";
          "provider" = "default";
          "id" = "OPENROUTER_OPENAI_API_KEY";
        };
        "timeoutSeconds" = 300;
        "models" = [
          {
            "id" = "openai/gpt-5.5";
            "name" = "GPT-5.5 — OpenRouter OpenAI";
            "reasoning" = true;
            "input" = [
              "text"
              "image"
            ];
            "contextWindow" = 1048576;
            "maxTokens" = 131072;
          }
          {
            "id" = "openai/gpt-5.6-luna";
            "name" = "GPT-5.6 Luna — OpenRouter OpenAI";
            "reasoning" = true;
            "input" = [
              "text"
              "image"
            ];
            "contextWindow" = 1048576;
            "maxTokens" = 131072;
          }
          {
            "id" = "openai/gpt-5.6-luna-pro";
            "name" = "GPT-5.6 Luna Pro — OpenRouter OpenAI";
            "reasoning" = true;
            "input" = [
              "text"
              "image"
            ];
            "contextWindow" = 1048576;
            "maxTokens" = 131072;
          }
          {
            "id" = "openai/gpt-5.6-sol";
            "name" = "GPT-5.6 Sol — OpenRouter OpenAI";
            "reasoning" = true;
            "input" = [
              "text"
              "image"
            ];
            "contextWindow" = 1048576;
            "maxTokens" = 131072;
          }
          {
            "id" = "openai/gpt-5.6-sol-pro";
            "name" = "GPT-5.6 Sol Pro — OpenRouter OpenAI";
            "reasoning" = true;
            "input" = [
              "text"
              "image"
            ];
            "contextWindow" = 1048576;
            "maxTokens" = 131072;
          }
        ];
      };
    };
  };
  "channels" = {
    "matrix" = {
      "enabled" = true;
      "homeserver" = "https://matrix.org";
      "userId" = "@joshans-bot:matrix.org";
      "deviceName" = "OpenClaw Gateway";
      "network" = {
        "dangerouslyAllowPrivateNetwork" = false;
      };
      "encryption" = true;
    };
  };
  "tools" = {
    "alsoAllow" = [ ];
    "sandbox" = {
      "tools" = {
        "alsoAllow" = [ ];
      };
    };
    "exec" = {
      "host" = "gateway";
      "mode" = "full";
    };
  };
  "memory" = {
    "search" = {
      "rememberAcrossConversations" = true;
    };
  };
}
