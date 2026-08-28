# Dsh-OxCaml: DeepSeek Agent Harness in OxCaml & Cordis

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)]()
[![OCaml 5](https://img.shields.io/badge/OCaml-5.0%2B-orange.svg)]()
[![Formalized in](https://img.shields.io/badge/Formalized-Cubical_Agda_%26_Rzk-blue.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Dsh-OxCaml** is the industrial-grade, native **OxCaml** port of the **DeepSeek Agent Harness (DSH)**, powered by the **Cordis Spatiotemporal Meta-Framework**.

It replaces unstructured multi-agent prompt loops with **Polynomial Functors ($\mathbf{Poly}$)**, **Dependent Lenses**, **Categorical Cybernetics (Open Games)**, and **Deterministic Simulation Testing (DST)**.

---

## ⚡ Key Highlights

- **Polynomial Interfaces ($\mathbf{Poly}$):**
  Every agent, tool, and evaluation environment is modeled as a polynomial functor $p(y) = \sum_{i \in p(1)} y^{p[i]}$, strictly separating forward proposals from dependent backward error feedback.
- **Hierarchical Decomposition ($p \circ q$):**
  Breaks the **EdgeBench** logarithmic scaling barrier ($P(t) = \frac{1}{1 + (t_{\text{mid}}/t)^\beta}$) by factorizing exponential problem spaces into modular, localized sub-polynomials.
- **Cordis Spatiotemporal Engine:**
  Native OCaml 5 algebraic effect handlers, discrete Lamport ticks ($\tau \in \mathbb{N}$), and automatic revertible disposal stacks (`ctx.effect`).
- **Heterogeneous Model Tiering:**
  Routes high-level reasoning to frontier LLMs, rapid AST generation to fast SLMs/Flash models, and backward feedback validation to zero-cost, deterministic native verification binaries ($f^\sharp$).
- **Mechanized Verification:**
  - **Cubical Agda (`--cubical`):** Machine-checked proofs of lawful dependent lenses and univalent interface substitutions.
  - **Rzk:** Synthetic $\infty$-category proofs of multi-agent causal ordering and dynamic equilibria.

---

## 🏗️ Quick Start

### Build & Run Tests
```bash
# Build libraries, CLI, and examples
dune build @all

# Run all unit, property, and DST test suites
dune runtest
```

### Run CLI Daemon
```bash
dune exec bin/main.exe -- --help
```

---

## 📊 Theoretical Architecture

| Dimension | Conventional Multi-Agent (LangChain, AutoGen) | Dsh-OxCaml (Cordis + $\mathbf{Poly}$) |
| :--- | :--- | :--- |
| **Communication** | Untyped text concatenation / JSON strings | Strongly typed dependent lenses ($f_1, f^\sharp$) |
| **Error Feedback** | 2,000+ token conversational critiques | Precise symbolic differentials & compiler diagnostics |
| **Token Growth** | Quadratic / Exponential context accumulation | Bounded $O(1)$ per local turn |
| **Lifecycle** | Uncontrolled wall-clock async / memory leaks | Revertible effect stack with inverse causal rollback |
| **Testing** | Flaky end-to-end integration tests | Byte-for-byte Deterministic Simulation Testing (DST) |

---

## 📚 Documentation & Theory

- [`THEORY.md`](THEORY.md): Deep dive into Polynomial Functors, Categorical Cybernetics, and EdgeBench log-sigmoid scaling laws.
- [`ARCH_SPEC.md`](ARCH_SPEC.md): Full technical specification, module graph, and runtime invariants.
- [`formal/agda/DshPoly.agda`](formal/agda/DshPoly.agda): Cubical Agda proof scripts.
- [`formal/rzk/DshOpenGame.rzk`](formal/rzk/DshOpenGame.rzk): Rzk synthetic $\infty$-category proofs.

---

## 📄 License & Attribution

Licensed under the [MIT License](LICENSE).
Attributions and prior art notices are documented in [NOTICE](NOTICE).
