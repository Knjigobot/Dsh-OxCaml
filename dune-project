(lang dune 3.10)
(name dsh_oxcaml)
(version 1.0.0)

(generate_opam_files true)

(license MIT)
(authors "DeepSeek-AI" "Cordiverse" "Jane Street" "Knjigobot" "Dsh-OxCaml Contributors")
(maintainers "knjigobot@users.noreply.github.com")

(package
 (name dsh-oxcaml)
 (synopsis "DeepSeek Agent Harness Port in OxCaml on Cordis Spatiotemporal Meta-Framework")
 (description
  "Dsh-OxCaml is an industrial-grade native OxCaml port of the DeepSeek Agent Harness (DSH). It grounds agent architectures in Polynomial Functors (Poly), Categorical Cybernetics, Open Games, and Cordis spatiotemporal fibers with deterministic simulation testing (DST), reversible effect lifecycles, and sub-millisecond multicore execution.")
 (depends
  (ocaml (>= 5.0.0))
  (dune (>= 3.10.0))
  (unix (>= 0))
  (alcotest (>= 1.7.0) :with-test))
 (tags ("deepseek" "harness" "dsh" "agent" "poly" "cordis" "oxcaml" "cybernetics" "open-games" "dst")))
