# Theoretical Foundations of Dsh-OxCaml

`Dsh-OxCaml` is the native OxCaml port and categorical formalization of the **DeepSeek Agent Harness (DSH)**, powered by the **Cordis Spatiotemporal Meta-Framework**.

---

## 1. Polynomial Functors ($\mathbf{Poly}$) & Interaction Boundaries

Traditional multi-agent frameworks treat agent interaction as unstructured text streams. This leads directly to context explosion and unconstrained error propagation. In `Dsh-OxCaml`, every agent, sandbox, tool, and compiler is formalized as an object in the category $\mathbf{Poly}$ (polynomial functors $\mathbf{Set} \to \mathbf{Set}$).

### 1.1 Polynomial Objects as Interactive Interfaces
An interface $p(y) \in \mathbf{Poly}$ is given by:
$$p(y) = \sum_{i \in p(1)} y^{p[i]}$$

- $p(1)$ is the set of **positions** (the visible states, propositions, generated ASTs, or tool requests emitted by the agent).
- For each position $i \in p(1)$, the exponent $p[i]$ is the set of **directions** (the allowable feedbacks, type checker diagnostics, verification witnesses, or environment observations).

A discrete dynamical system (agent harness) with internal state space $S$ is a coalgebra:
$$S \longrightarrow p(S) \cong (S \to p(1)) \times \left(\prod_{i \in p(1)} (p[i] \to S)\right)$$

### 1.2 Morphisms: Dependent Lenses as Interaction Wiring
A morphism $f: p \to q$ in $\mathbf{Poly}$ is a bidirectional lens:
1. **Forward Map:** $f_1: p(1) \to q(1)$
2. **Dependent Backward Map:** $f^\sharp: \prod_{i \in p(1)} (q[f_1(i)] \to p[i])$

The backward map $f^\sharp$ is parametrically dependent on the exact forward position $i \in p(1)$. Feedback is mathematically routed to the specific sub-expression or assumption that produced it.

```mermaid
flowchart LR
    subgraph Lens ["Dependent Lens: f : p → q"]
        direction LR
        P1["p(1) (Forward Proposal)"] -->|f₁| Q1["q(1) (Target Input)"]
        QDir["q[f₁(i)] (Target Feedback)"] -->|f♯ (Dependent)| PDir["p[i] (Source Update)"]
    end
```

### 1.3 Functorial Backpropagation
Morphisms compose associatively:
$$(g \circ f)_1 = g_1 \circ f_1$$
$$(g \circ f)^\sharp(i, \delta_r) = f^\sharp(i, g^\sharp(f_1(i), \delta_r))$$

This guarantees zero context bleed: intermediate diagnostic feedback is absorbed and translated at each architectural boundary without polluting parent agent contexts.

---

## 2. Categorical Cybernetics & Open Games

Multi-agent coordination in `Dsh-OxCaml` is formulated via **Open Games** (Hedges, Spivak, Capucci):

$$\mathbf{G} = (S, \Sigma, \mathbf{P}, \mathbf{C})$$
- $S$: Internal state space
- $\Sigma$: Strategy profile (policy / prompt weights / temperature parameterization)
- $\mathbf{P}: \Sigma \times S \times \text{Context} \to \text{Observation}$ (Forward play)
- $\mathbf{C}: \Sigma \times S \times \text{CoObservation} \to \text{CoContext} \times \text{Utility}$ (Backward co-state update)

### Compositional Nash & Bayes Equilibria
Open games form a symmetric monoidal category. When sub-agents $G_1$ and $G_2$ are composed via a lens $f: p \otimes q \to r$, the equilibrium of the combined system is computed compositionally from local equilibria:
$$\operatorname{Eq}(G_1 \otimes G_2) \cong \operatorname{Eq}(G_1) \times \operatorname{Eq}(G_2)$$

---

## 3. Resolving the EdgeBench Logarithmic Scaling Wall

The **EdgeBench** benchmark (*"EdgeBench: Unveiling Scaling Laws of Learning from Real-World Environments"*, 2026) demonstrates that unstructured agent interaction follows a log-sigmoid scaling law:
$$P(t) = \frac{1}{1 + \left(\frac{t_{\text{mid}}}{t}\right)^\beta}$$

Unstructured chat loops suffer from exponential state-space branching ($O(e^d)$), causing interaction time $t$ to scale logarithmically with progress.

```mermaid
graph TD
    A[Monolithic Problem] -->|Polynomial Substitution p ∘ q| B[Factorized Sub-Polynomials]
    B --> C[Localized Verification f♯]
    C -->|Directed Co-State Update| D[Linear Convergence O(N)]
```

`Dsh-OxCaml` breaks this wall via **Hierarchical Polynomial Decomposition ($p \circ q$)**:
$$(p \circ q)(y) = \sum_{i \in p(1)} \prod_{k \in p[i]} q(y)$$
- Decomposes combinatorial search spaces into factored linear sub-tasks $\sum O(N_k)$.
- Binds backward verification directly to deterministic local checkers (OxCaml compiler, Agda type checker), achieving directed co-state descent.

---

## 4. Spatiotemporal Cordis Runtime (Revertible Effects & DST)

`Dsh-OxCaml` anchors polynomial coalgebras in the **Cordis** engine:

1. **Discrete Causal Time ($\tau \in \mathbb{N}$):** Replaces wall-clock latency with deterministic Lamport vector ticks.
2. **Revertible Disposal Stack (`ctx.effect`):** When an agent branch fails, Cordis unwinds side-effects in exact causal reverse order (files, sandboxes, sockets).
3. **Deterministic Simulation Testing (DST):** Runs full multi-agent clusters inside a single-threaded virtual time harness with simulated network partitions, clock skew, and fault injection.
