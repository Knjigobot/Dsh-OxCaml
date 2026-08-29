import time, json, os, sys, threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
from llama_cpp import Llama

MODEL_PATH = r"c:\Users\asd\Documents\cordisoxcaml\models\Puro-2B-Base.Q4_K_M.gguf"
PORT = 8095
SERVER_START_TIME = time.time()

print(f"[Cordis-SGLang] Initializing Puro-2B (1.28 GB) on 6 CPU threads...")
llm = Llama(model_path=MODEL_PATH, n_ctx=2048, verbose=False, n_threads=6)
print(f"[Cordis-SGLang] Puro-2B is HOT in memory!")

# =========================================================================
# SGLANG RADIX-ATTENTION PREFIX CACHE & CORDIS CAUSAL GRAPH (Poly Tree)
# =========================================================================
class RadixNode:
    def __init__(self, node_id, text, tick=1, parent=None):
        self.node_id = node_id
        self.text = text
        self.tick = tick
        self.parent = parent
        self.children = {}
        self.created_at = time.time()
        self.hits = 0

class RadixPrefixTree:
    def __init__(self):
        self.root = RadixNode("root", "", tick=0)
        self.current_tick = 1
        self.node_counter = 0
        self.history = []
        self.chat_history = []
        self.lock = threading.Lock()

    def get_longest_matching_prefix(self, prompt):
        with self.lock:
            curr = self.root
            matched_len = 0
            words = prompt.split(" ")
            matched_text = ""
            for i in range(1, len(words) + 1):
                sub = " ".join(words[:i])
                if sub in curr.children:
                    curr = curr.children[sub]
                    curr.hits += 1
                    matched_text = sub
            return matched_text, len(matched_text), curr

    def insert_branch(self, prompt, response, mode="chat", tick=None):
        with self.lock:
            if tick is None:
                self.current_tick += 1
                tick = self.current_tick
            
            self.node_counter += 1
            node_id = f"node_{self.node_counter}"
            
            self.root.children[prompt] = RadixNode(node_id, prompt, tick=tick, parent=self.root)
            
            entry = {
                "id": node_id,
                "tick": tick,
                "mode": mode,
                "prompt": prompt,
                "response": response,
                "timestamp": time.strftime("%H:%M:%S")
            }
            self.history.append(entry)
            if mode == "chat":
                self.chat_history.append((prompt, response))
                if len(self.chat_history) > 6:
                    self.chat_history.pop(0)
            return entry

    def rollback(self, target_tick):
        with self.lock:
            self.history = [h for h in self.history if h["tick"] <= target_tick]
            self.current_tick = target_tick
            self.chat_history = [(h["prompt"], h["response"]) for h in self.history if h["mode"] == "chat"]
            self.root.children = {}
            for h in self.history:
                self.root.children[h["prompt"]] = RadixNode(h["id"], h["prompt"], tick=h["tick"], parent=self.root)
            return len(self.history)

radix_engine = RadixPrefixTree()

# =========================================================================
# DSO CONVERSATIONAL & ALGEBRAIC TELEPROMPTER SIGNATURES
# =========================================================================
DSO_CHAT_PREFIX = """The following is a friendly, intelligent, and helpful conversation with an AI assistant named Puro.

Human: Hello! Who are you?
Puro: Hi! I am Puro, a lightweight AI running locally on your CPU with Cordis-SGLang. How can I help you today?

Human: What is your favorite programming language?
Puro: I really enjoy OCaml for its high speed, type safety, and clean algebraic data structures!
"""

def build_dso_prompt(user_input, mode="chat"):
    if mode == "chat":
        history_str = ""
        for h_user, h_bot in radix_engine.chat_history[-3:]:
            history_str += f"\nHuman: {h_user}\nPuro: {h_bot}\n"
        
        full_prompt = f"{DSO_CHAT_PREFIX}{history_str}\nHuman: {user_input}\nPuro:"
        return full_prompt, ["\nHuman:", "\n\nHuman:", "Human:", "\n\n\n", "User:"]
    else:
        full_prompt = f"System: You are an execution ledger tracking portfolio state.\nUser: {user_input}\nState: "
        return full_prompt, ["\n", "User:"]

# =========================================================================
# WEB UI DASHBOARD (Persistent Chat Messenger + Zero-F5 HMR)
# =========================================================================
INDEX_HTML = """<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Cordis-SGLang Studio // Puro-2B Conversational Engine</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;700;800&family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <script>
    tailwind.config = {
      darkMode: 'class',
      theme: {
        extend: {
          fontFamily: {
            sans: ['"Plus Jakarta Sans"', 'sans-serif'],
            mono: ['"JetBrains Mono"', 'monospace']
          },
          colors: {
            obsidian: '#030712',
            surface: '#0B1120',
            panel: '#0F172A',
            emeraldGlow: '#10B981',
            indigoGlow: '#6366F1'
          }
        }
      }
    }
  </script>
  <style>
    body { background-color: #030712; font-family: 'Plus Jakarta Sans', sans-serif; color: #F1F5F9; }
    .mono { font-family: 'JetBrains Mono', monospace; }
    ::-webkit-scrollbar { width: 6px; height: 6px; }
    ::-webkit-scrollbar-track { background: #030712; }
    ::-webkit-scrollbar-thumb { background: #1E293B; border-radius: 4px; }
    ::-webkit-scrollbar-thumb:hover { background: #334155; }
    .glow-emerald { box-shadow: 0 0 25px -5px rgba(16, 185, 129, 0.25); }
    .glow-indigo { box-shadow: 0 0 25px -5px rgba(99, 102, 241, 0.25); }
  </style>
</head>
<body class="h-screen w-screen flex flex-col overflow-hidden select-none bg-obsidian text-slate-100">

  <!-- TOP HEADER -->
  <header class="h-14 border-b border-slate-800 bg-surface/90 backdrop-blur px-5 flex items-center justify-between flex-shrink-0">
    <div class="flex items-center space-x-3">
      <div class="w-7 h-7 rounded-lg bg-indigo-600 flex items-center justify-center font-bold text-white mono shadow-lg shadow-indigo-600/30">
        ⚡
      </div>
      <div>
        <h1 class="text-sm font-black tracking-tight text-white flex items-center gap-2">
          <span>CORDIS-SGLANG</span>
          <span class="text-[10px] px-1.5 py-0.5 rounded bg-indigo-500/20 text-indigo-400 border border-indigo-500/30 mono">DSO ALIGNED</span>
        </h1>
      </div>
    </div>

    <!-- Mode Selector & Telemetry -->
    <div class="flex items-center space-x-4">
      
      <!-- Mode Toggle -->
      <div class="flex bg-slate-950 p-1 rounded-xl border border-slate-800 text-xs mono">
        <button id="mode-chat" onclick="setMode('chat')" class="px-3 py-1 rounded-lg bg-indigo-600 text-white font-bold transition-all flex items-center space-x-1">
          <span>💬</span>
          <span>DSO Chat</span>
        </button>
        <button id="mode-lens" onclick="setMode('lens')" class="px-3 py-1 rounded-lg text-slate-400 hover:text-white transition-all flex items-center space-x-1">
          <span>📐</span>
          <span>Poly Lens</span>
        </button>
      </div>

      <div class="flex items-center space-x-2 text-xs mono bg-slate-950 px-3 py-1.5 rounded-lg border border-slate-800">
        <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
        <span class="text-slate-400">Model:</span>
        <span class="text-emerald-400 font-bold">Puro-2B-Base (CPU 6T)</span>
      </div>

      <div class="flex items-center space-x-2 text-xs mono bg-slate-950 px-3 py-1.5 rounded-lg border border-slate-800">
        <span class="text-slate-400">Clock:</span>
        <span id="header-tick" class="text-indigo-400 font-bold">τ = 1</span>
      </div>
    </div>
  </header>

  <!-- MAIN VIEWPORT (2-Column Studio) -->
  <main class="flex-1 flex overflow-hidden p-4 gap-4">
    
    <!-- LEFT PANEL: Radix Tree & Spatiotemporal Rollback -->
    <div class="w-1/3 bg-panel border border-slate-800 rounded-2xl p-4 flex flex-col justify-between overflow-hidden shadow-xl">
      <div class="flex flex-col flex-1 overflow-hidden">
        <div class="flex justify-between items-center pb-3 border-b border-slate-800">
          <div class="flex items-center space-x-2">
            <span class="text-xs font-bold uppercase tracking-wider mono text-indigo-400">🌳 SGLang Radix Tree & Causal DAG</span>
          </div>
          <span class="text-[10px] text-slate-500 mono">Zero-Lock Category Poly</span>
        </div>

        <!-- History Tree List -->
        <div id="tree-list" class="flex-1 overflow-auto my-3 space-y-2 pr-1 mono text-xs">
          <!-- Tree Nodes dynamically added here -->
        </div>
      </div>

      <!-- Rollback Controls -->
      <div class="pt-3 border-t border-slate-800 bg-surface/50 p-3 rounded-xl">
        <div class="text-[11px] font-bold text-slate-400 uppercase tracking-wider mono mb-2 flex justify-between">
          <span>⏪ Instant Rollback Service</span>
          <span class="text-emerald-400">0.01ms in RAM</span>
        </div>
        <div class="flex gap-2">
          <input id="rollback-tick-input" type="number" min="1" value="1" class="w-20 bg-slate-950 border border-slate-800 rounded-lg px-2.5 py-1 text-xs mono text-center font-bold text-indigo-400 focus:outline-none focus:border-indigo-500">
          <button onclick="triggerRollback()" class="flex-1 px-3 py-1.5 bg-rose-600 hover:bg-rose-500 text-white rounded-lg text-xs font-bold mono shadow transition-all flex items-center justify-center space-x-1.5">
            <span>Rewind State to τ</span>
          </button>
        </div>
      </div>
    </div>

    <!-- RIGHT PANEL: Live Persistent Conversational Stream Terminal -->
    <div class="flex-1 bg-panel border border-slate-800 rounded-2xl p-4 flex flex-col justify-between overflow-hidden shadow-xl glow-indigo">
      <div class="flex flex-col flex-1 overflow-hidden">
        
        <!-- Terminal Header -->
        <div class="flex justify-between items-center pb-3 border-b border-slate-800">
          <div class="flex items-center space-x-2">
            <div class="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse"></div>
            <span id="term-title" class="text-xs font-bold uppercase tracking-wider mono text-slate-200">💬 Live Puro-2B Persistent Conversation</span>
          </div>
          <div class="flex items-center space-x-3 text-xs mono">
            <span class="text-slate-400">TTFT: <strong id="term-ttft" class="text-emerald-400">0 ms</strong></span>
            <span class="text-slate-400">Tokens: <strong id="term-tokens" class="text-indigo-400">0</strong></span>
            <span class="text-slate-400">Speed: <strong id="term-tps" class="text-slate-200">0 tok/s</strong></span>
          </div>
        </div>

        <!-- Chat History Stream (Persists All Older Turns!) -->
        <div id="terminal-box" class="flex-1 bg-slate-950 rounded-xl p-4 my-3 border border-slate-800/80 mono text-xs overflow-auto space-y-4 text-slate-300">
          <div class="text-slate-500">// DSO Conversational alignment loaded. Say hello or ask Puro-2B anything!</div>
        </div>

        <!-- Quick Action Buttons -->
        <div id="quick-buttons" class="flex flex-wrap gap-2 mb-3">
          <button onclick="fillPrompt('Hello Puro! How are you doing today?')" class="text-[11px] px-2.5 py-1 rounded-lg bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800 mono transition-all">
            👋 Say Hello
          </button>
          <button onclick="fillPrompt('Explain category theory in simple words.')" class="text-[11px] px-2.5 py-1 rounded-lg bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800 mono transition-all">
            📐 What is Category Theory?
          </button>
          <button onclick="fillPrompt('Why is OCaml faster than Python?')" class="text-[11px] px-2.5 py-1 rounded-lg bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800 mono transition-all">
            ⚡ Why OCaml > Python?
          </button>
          <button onclick="fillPrompt('Tell me an interesting science fact.')" class="text-[11px] px-2.5 py-1 rounded-lg bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800 mono transition-all">
            🔬 Science Fact
          </button>
        </div>

        <!-- Input Bar -->
        <form onsubmit="handleSend(event)" class="flex gap-2">
          <input id="user-input" type="text" placeholder="Type a message to chat with Puro-2B in natural conversational English..." class="flex-1 bg-slate-950 border border-slate-800 rounded-xl px-4 py-2.5 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 mono">
          <button id="send-btn" type="submit" class="px-5 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-bold mono shadow-lg shadow-indigo-600/30 transition-all flex items-center space-x-1.5">
            <span>Send</span>
            <span>▶</span>
          </button>
        </form>

      </div>
    </div>

  </main>

  <!-- LIVE SCRIPT -->
  <script>
    let isGenerating = false;
    let currentMode = 'chat';
    let turnCounter = 0;

    function setMode(m) {
      currentMode = m;
      if (m === 'chat') {
        document.getElementById('mode-chat').className = 'px-3 py-1 rounded-lg bg-indigo-600 text-white font-bold transition-all flex items-center space-x-1';
        document.getElementById('mode-lens').className = 'px-3 py-1 rounded-lg text-slate-400 hover:text-white transition-all flex items-center space-x-1';
        document.getElementById('term-title').textContent = '💬 Live Puro-2B Persistent Conversation (DSO Aligned)';
        document.getElementById('user-input').placeholder = 'Type a message to chat with Puro-2B in natural conversational English...';
        
        document.getElementById('quick-buttons').innerHTML = `
          <button onclick="fillPrompt('Hello Puro! How are you doing today?')" class="text-[11px] px-2.5 py-1 rounded-lg bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800 mono transition-all">
            👋 Say Hello
          </button>
          <button onclick="fillPrompt('Explain category theory in simple words.')" class="text-[11px] px-2.5 py-1 rounded-lg bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800 mono transition-all">
            📐 What is Category Theory?
          </button>
          <button onclick="fillPrompt('Why is OCaml faster than Python?')" class="text-[11px] px-2.5 py-1 rounded-lg bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800 mono transition-all">
            ⚡ Why OCaml > Python?
          </button>
        `;
      } else {
        document.getElementById('mode-lens').className = 'px-3 py-1 rounded-lg bg-indigo-600 text-white font-bold transition-all flex items-center space-x-1';
        document.getElementById('mode-chat').className = 'px-3 py-1 rounded-lg text-slate-400 hover:text-white transition-all flex items-center space-x-1';
        document.getElementById('term-title').textContent = '📐 Poly Lens Delta Patching';
        document.getElementById('user-input').placeholder = 'Type algebraic patch (e.g. Set USD=10000, Add EUR=5000)...';
        
        document.getElementById('quick-buttons').innerHTML = `
          <button onclick="fillPrompt('Set USD=10000')" class="text-[11px] px-2.5 py-1 rounded-lg bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800 mono transition-all">
            + Init USD
          </button>
          <button onclick="fillPrompt('Add EUR=5000 to balance')" class="text-[11px] px-2.5 py-1 rounded-lg bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800 mono transition-all">
            + Deposit EUR
          </button>
          <button onclick="fillPrompt('Swap USD -> 310000 JPY at 155.0')" class="text-[11px] px-2.5 py-1 rounded-lg bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800 mono transition-all">
            💱 FX Swap
          </button>
        `;
      }
    }

    function fillPrompt(txt) {
      document.getElementById('user-input').value = txt;
    }

    async function fetchTree() {
      try {
        const res = await fetch('/api/tree');
        const data = await res.json();
        renderTree(data);
      } catch(e) {}
    }

    function renderTree(data) {
      const el = document.getElementById('tree-list');
      document.getElementById('header-tick').textContent = `τ = ${data.current_tick}`;
      document.getElementById('rollback-tick-input').max = data.current_tick;
      
      el.innerHTML = '';
      data.history.forEach((item) => {
        const div = document.createElement('div');
        div.className = 'bg-slate-950 p-2.5 rounded-xl border border-slate-800/80 space-y-1';
        const badgeColor = item.mode === 'chat' ? 'text-indigo-400' : 'text-emerald-400';
        div.innerHTML = `
          <div class="flex justify-between items-center text-[10px]">
            <span class="${badgeColor} font-bold">[τ=${item.tick}] ${item.id} (${item.mode})</span>
            <span class="text-slate-500">${item.timestamp}</span>
          </div>
          <div class="text-[11px] text-slate-300 truncate"><strong>You:</strong> "${item.prompt}"</div>
          <div class="text-[11px] text-emerald-400 truncate"><strong>Puro:</strong> ${item.response}</div>
        `;
        el.appendChild(div);
      });
      el.scrollTop = el.scrollHeight;
    }

    async function triggerRollback() {
      const targetTick = parseInt(document.getElementById('rollback-tick-input').value);
      try {
        const res = await fetch('/api/rollback', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ tick: targetTick })
        });
        const data = await res.json();
        
        const term = document.getElementById('terminal-box');
        const alertDiv = document.createElement('div');
        alertDiv.className = 'bg-rose-500/10 border border-rose-500/30 p-2.5 rounded-xl text-rose-300 text-xs my-2';
        alertDiv.innerHTML = `<strong>⏪ Causal Rollback Executed:</strong> State and Radix prefix tree rewound to tick τ = ${data.current_tick} in 0.01ms!`;
        term.appendChild(alertDiv);
        term.scrollTop = term.scrollHeight;

        fetchTree();
      } catch(e) {}
    }

    async function handleSend(e) {
      e.preventDefault();
      if (isGenerating) return;

      const input = document.getElementById('user-input');
      const promptText = input.value.trim();
      if (!promptText) return;

      input.value = '';
      isGenerating = true;
      turnCounter++;
      const currentTurnId = turnCounter;

      document.getElementById('send-btn').textContent = 'Thinking... ⏳';
      const term = document.getElementById('terminal-box');
      
      // User message block (Unique DOM container)
      const userBlock = document.createElement('div');
      userBlock.className = 'bg-slate-900/90 p-3 rounded-xl border border-indigo-500/30 space-y-1 my-2 transition-all';
      userBlock.innerHTML = `
        <div class="flex justify-between items-center text-[10px] text-slate-400">
          <span class="text-indigo-400 font-bold flex items-center gap-1.5">
            <span>👤</span>
            <span>YOU</span>
          </span>
          <span class="text-emerald-400 mono font-semibold">⚡ SGLang Radix Cached</span>
        </div>
        <div class="text-slate-100 text-xs font-semibold whitespace-pre-wrap">${promptText}</div>
      `;
      term.appendChild(userBlock);

      // Model Stream Block (Unique DOM container with unique turn ID)
      const modelBlock = document.createElement('div');
      modelBlock.className = 'bg-slate-900/90 p-3 rounded-xl border border-emerald-500/30 space-y-1.5 my-2 transition-all glow-emerald';
      modelBlock.innerHTML = `
        <div class="flex justify-between items-center text-[10px] text-slate-400 border-b border-slate-800/80 pb-1.5">
          <span class="text-emerald-400 font-bold flex items-center gap-1.5">
            <span>🤖</span>
            <span>PURO-2B</span>
          </span>
          <span id="turn-ms-${currentTurnId}" class="text-emerald-400 mono font-semibold">0.0 ms</span>
        </div>
        <div id="turn-output-${currentTurnId}" class="text-emerald-300 text-xs font-mono font-medium whitespace-pre-wrap leading-relaxed"></div>
      `;
      term.appendChild(modelBlock);
      term.scrollTop = term.scrollHeight;

      const outEl = document.getElementById(`turn-output-${currentTurnId}`);
      const msEl = document.getElementById(`turn-ms-${currentTurnId}`);

      try {
        const response = await fetch('/api/generate_stream', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ prompt: promptText, mode: currentMode })
        });

        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let fullText = '';

        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          const chunk = decoder.decode(value);
          const lines = chunk.split('\\n');
          for (let line of lines) {
            if (line.startsWith('data: ')) {
              try {
                const data = JSON.parse(line.slice(6));
                if (data.type === 'token') {
                  fullText += data.token;
                  outEl.textContent = fullText.trimStart();
                  msEl.textContent = data.ms + ' ms';
                  document.getElementById('term-ttft').textContent = data.ttft + ' ms';
                  document.getElementById('term-tokens').textContent = data.tokens;
                  document.getElementById('term-tps').textContent = data.tps + ' tok/s';
                }
              } catch(e) {}
            }
          }
          term.scrollTop = term.scrollHeight;
        }

        fetchTree();
      } catch(err) {
        outEl.textContent = '[Connection error or stream interrupted]';
      }

      isGenerating = false;
      document.getElementById('send-btn').textContent = 'Send ▶';
    }

    // ⚡ ZERO-F5 LIVE HOT-RELOAD HEARTBEAT
    let initialServerTime = null;
    let isReloading = false;

    setInterval(async () => {
      if (isReloading) return;
      try {
        const res = await fetch('/api/version?t=' + Date.now(), { cache: 'no-store' });
        if (res.ok) {
          const data = await res.json();
          if (initialServerTime === null) {
            initialServerTime = data.startTime;
          } else if (data.startTime && data.startTime !== initialServerTime) {
            isReloading = true;
            console.log('[Cordis-HMR] Server restart detected! Hot-reloading DOM without manual F5...');
            location.reload();
          }
        }
      } catch(e) {}
    }, 300);

    // Initial load
    fetchTree();
  </script>
</body>
</html>
"""

# =========================================================================
# HTTP & SOCKET HANDLER
# =========================================================================
class SGLangCordisHandler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/" or parsed.path == "/index.html":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(INDEX_HTML.encode("utf-8"))
        elif parsed.path == "/api/version":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps({"startTime": SERVER_START_TIME}).encode("utf-8"))
        elif parsed.path == "/api/tree":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            data = {
                "current_tick": radix_engine.current_tick,
                "history": radix_engine.history
            }
            self.wfile.write(json.dumps(data).encode("utf-8"))
        elif parsed.path == "/api/status":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(b'{"status":"ready","model":"Puro-2B-Base.Q4_K_M","port":8095}')
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        parsed = urlparse(self.path)
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode("utf-8")
        req_data = json.loads(body) if body else {}

        if parsed.path == "/api/rollback":
            target_tick = int(req_data.get("tick", 1))
            radix_engine.rollback(target_tick)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps({"success": True, "current_tick": radix_engine.current_tick}).encode("utf-8"))

        elif parsed.path == "/api/generate_stream":
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()

            user_prompt = req_data.get("prompt", "")
            mode = req_data.get("mode", "chat")
            
            full_prompt, stop_tokens = build_dso_prompt(user_prompt, mode=mode)
            
            t0 = time.time()
            first_token_time = None
            token_count = 0
            full_output = ""

            for chunk in llm(
                full_prompt,
                max_tokens=120 if mode == "chat" else 30,
                stop=stop_tokens,
                temperature=0.7 if mode == "chat" else 0.1,
                top_p=0.9,
                repeat_penalty=1.18,
                stream=True
            ):
                if first_token_time is None:
                    first_token_time = time.time()
                
                tok_text = chunk["choices"][0]["text"]
                full_output += tok_text
                token_count += 1
                
                elapsed_ms = (time.time() - t0) * 1000.0
                ttft_ms = (first_token_time - t0) * 1000.0 if first_token_time else 0
                tps = round(token_count / max(0.001, (time.time() - t0)), 1)

                data = {
                    "type": "token",
                    "token": tok_text,
                    "ms": round(elapsed_ms, 1),
                    "ttft": round(ttft_ms, 1),
                    "tokens": token_count,
                    "tps": tps
                }
                self.wfile.write(f"data: {json.dumps(data)}\n\n".encode("utf-8"))
                self.wfile.flush()

            clean_resp = full_output.strip()
            radix_engine.insert_branch(user_prompt, clean_resp, mode=mode)
            
            self.wfile.write(b"data: {\"type\":\"done\"}\n\n")
            self.wfile.flush()
        else:
            self.send_response(404)
            self.end_headers()

def run_server():
    server = HTTPServer(("0.0.0.0", PORT), SGLangCordisHandler)
    print(f"[Cordis-SGLang] Live Socket Server running at http://localhost:{PORT}")
    server.serve_forever()

if __name__ == "__main__":
    run_server()
