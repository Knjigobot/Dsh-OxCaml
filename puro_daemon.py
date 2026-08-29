import time, json, os, sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from llama_cpp import Llama

MODEL_PATH = r"c:\Users\asd\Documents\cordisoxcaml\models\Puro-2B-Base.Q4_K_M.gguf"
PORT = 8091

print(f"[Puro-Daemon] Loading Puro-2B (1.28 GB) into RAM with 6 CPU threads...")
llm = Llama(model_path=MODEL_PATH, n_ctx=2048, verbose=False, n_threads=6)
print(f"[Puro-Daemon] Puro-2B-Base is HOT in RAM and ready on port {PORT}!")

STEPS = [
    ("Step 1: Init Portfolio", "Init portfolio with USD: 10000, EUR: 0, JPY: 0, Stock: 0", "InitLedger(USD=10000, EUR=0, JPY=0, Stock=0)", "Set USD=10000"),
    ("Step 2: Deposit EUR", "Deposit 5000 EUR into account.", "Deposit(EUR, 5000) -> State Updated", "Add EUR=5000"),
    ("Step 3: FX Swap USD->JPY", "Convert 2000 USD to JPY at 155.0 rate.", "SwapFx(from=USD, to=JPY, amt=2000, rate=155.0)", "USD-=2000, JPY+=310000"),
    ("Step 4: Broker Fee Deduction", "Deduct 0.15% fee on USD balance ($12.00).", "DeductFee(USD, 12.00)", "USD-=12"),
    ("Step 5: Buy Stock", "Buy 10 shares of TechCorp at $180/share ($1800).", "BuyAsset(symbol=TechCorp, qty=10, price=180)", "USD-=1800, Stock+=10"),
    ("Step 6: Dividend Credit", "Credit dividend of $45 USD.", "CreditDividend(USD, 45.00)", "USD+=45"),
    ("Step 7: Sell Stock", "Sell 5 shares of TechCorp at $195/share ($975).", "SellAsset(symbol=TechCorp, qty=5, price=195)", "USD+=975, Stock-=5"),
    ("Step 8: Calculate Equity", "Calculate total portfolio equity in USD.", "ComputeEquity(rates=[1.08, 155.0, 195.0]) = 15583", "Equity = USD + EUR*1.08 + JPY/155 + Stock*195"),
    ("Step 9: Risk Check", "Assert cash ratio is under 75% threshold.", "RiskCheck(ratio=0.584, limit=0.75) -> PASSED", "Check cash_ratio < 0.75"),
    ("Step 10: Invariant Checksum", "Verify final invariant state and seal ledger.", "LockLedger(state=Valid, hash=0x9FA1)", "Seal ledger at tick 10")
]

class LiveInferenceHandler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

    def do_GET(self):
        if self.path.startswith("/api/live_run_stream") or self.path.startswith("/stream"):
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()

            self.wfile.write(b"data: {\"type\":\"status\",\"msg\":\"Model HOT in RAM. Starting Sequential Real Inference (1 -> 2 -> 3)...\"}\n\n")
            self.wfile.flush()

            # PHASE 1: ARM A (LangChain Flat Accumulation)
            self.wfile.write(b"data: {\"type\":\"phase\",\"arm\":\"A\",\"name\":\"Arm A: LangChain Flat Loop\"}\n\n")
            self.wfile.flush()

            lc_history = "System: You are an execution ledger tracking portfolio state.\n"
            for i, (name, prompt_lc, _, _) in enumerate(STEPS, 1):
                t0 = time.time()
                lc_prompt = lc_history + f"User: {prompt_lc}\nState: "
                res = llm(lc_prompt, max_tokens=30, stop=["\n", "User:"])
                t_ms = (time.time() - t0) * 1000.0
                out_text = res["choices"][0]["text"].strip()
                in_tok = res["usage"]["prompt_tokens"]
                out_tok = res["usage"]["completion_tokens"]
                lc_history += f"User: {prompt_lc}\nState: {out_text}\n"

                payload = {
                    "type": "step",
                    "arm": "A",
                    "step": i,
                    "name": name,
                    "prompt": prompt_lc,
                    "text": out_text,
                    "inTok": in_tok,
                    "outTok": out_tok,
                    "ms": round(t_ms, 1)
                }
                self.wfile.write(f"data: {json.dumps(payload)}\n\n".encode("utf-8"))
                self.wfile.flush()

            # PHASE 2: ARM B (Dsh-OxCaml Alone)
            self.wfile.write(b"data: {\"type\":\"phase\",\"arm\":\"B\",\"name\":\"Arm B: Dsh-OxCaml Alone (In-Memory RAM)\"}\n\n")
            self.wfile.flush()

            for i, (name, _, tool_call, _) in enumerate(STEPS, 1):
                t0 = time.time()
                dsh_prompt = f"Tool Execution: {tool_call}\nResult: "
                res = llm(dsh_prompt, max_tokens=25, stop=["\n", "]"])
                t_ms = (time.time() - t0) * 1000.0
                out_text = res["choices"][0]["text"].strip()
                in_tok = res["usage"]["prompt_tokens"]
                out_tok = res["usage"]["completion_tokens"]

                payload = {
                    "type": "step",
                    "arm": "B",
                    "step": i,
                    "name": name,
                    "prompt": tool_call,
                    "text": out_text,
                    "inTok": in_tok,
                    "outTok": out_tok,
                    "ms": round(t_ms, 1)
                }
                self.wfile.write(f"data: {json.dumps(payload)}\n\n".encode("utf-8"))
                self.wfile.flush()

            # PHASE 3: ARM C (Dsh-OxCaml + DSOxCaml Lenses)
            self.wfile.write(b"data: {\"type\":\"phase\",\"arm\":\"C\",\"name\":\"Arm C: Dsh-OxCaml + DSOxCaml\"}\n\n")
            self.wfile.flush()

            for i, (name, _, _, delta_dsh) in enumerate(STEPS, 1):
                t0 = time.time()
                dso_prompt = f"[τ={i}] Delta: {delta_dsh}\nPatch: "
                res = llm(dso_prompt, max_tokens=15, stop=["\n", "]"])
                t_ms = (time.time() - t0) * 1000.0
                out_text = res["choices"][0]["text"].strip()
                in_tok = res["usage"]["prompt_tokens"]
                out_tok = res["usage"]["completion_tokens"]

                payload = {
                    "type": "step",
                    "arm": "C",
                    "step": i,
                    "name": name,
                    "prompt": delta_dsh,
                    "text": out_text,
                    "inTok": in_tok,
                    "outTok": out_tok,
                    "ms": round(t_ms, 1)
                }
                self.wfile.write(f"data: {json.dumps(payload)}\n\n".encode("utf-8"))
                self.wfile.flush()

            # Finish
            self.wfile.write(b"data: {\"type\":\"complete\",\"msg\":\"Sequential Hardware Run Complete!\"}\n\n")
            self.wfile.flush()
        else:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(b'{"status":"puro-2b-hot-ready","port":8091}')

def run_server():
    server = HTTPServer(("0.0.0.0", PORT), LiveInferenceHandler)
    server.serve_forever()

if __name__ == "__main__":
    run_server()
