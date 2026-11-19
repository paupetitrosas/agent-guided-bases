# Examples

Five families that are well known in the literature, each with a `family.wl` and a `run.wl`. To try one,
copy its folder somewhere, add a `paths.wl` if your tools are not found automatically, and ask your agent to
find the maximal-cut bases (it works one sector at a time), or run `bin/run_all.sh run.wl` yourself.

| folder | family | what it shows | what to expect |
|---|---|---|---|
| `bubble-massive` | one-loop bubble with two equal masses | a point-like cut, the Gram square root `Sqrt[s(s-4m2)]`, dots, the Γ prefactor | `eps-form` for the bubble and for the tadpole |
| `box-one-loop` | one-loop massless box | point-like cuts, normalisations `s t`, `s` and `t` | `eps-form` for the box and both bubbles |
| `doublebox-massless` | two-loop planar massless double box (only the top sector in `run.wl`) | a rational one-variable cut, two masters, a numerator on an ISP | `eps-form`; the known pair is `s² t ε⁴ j[..,0,0]` and `s² ε⁴ j[..,-1,0]`, up to normalisation (arXiv:1304.1806) |
| `sunrise-equal-mass` | two-loop equal-mass sunrise (top sector) | an elliptic curve `y² = z(4m2 - z)Q(z)`, curve candidates, the dimension shift | `eps-polynomial` with powers `{0, 1}`, i.e. `A = A₀ + ε A₁`; classification `elliptic` |
| `banana-three-loop` | three-loop equal-mass banana (top sector), d = 2 − 2ε | a K3 surface: the Picard-Fuchs operator at ε = 0 has order 3 and is a symmetric square (the planted K3 case of the picard-fuchs step) | `eps-polynomial` with powers `{0, 1}`; classification `K3` |

All five `family.wl` files pass `bin/validate_family.wls` with the scaling self-test. All five have been run through
the automatic first pass and the Kira check, and reach the status listed above in every sector. The
sunrise and the bubble have also been through the FiniteFlow check, which agrees with Kira; the box and the double
box have not. The banana (three masters on the maximal cut of its top sector) has been through the first pass and the
Kira check too, but not the FiniteFlow check.

The Picard-Fuchs step labels every sector of the first four `polylog`, except the sunrise's top sector, which is
`elliptic`; the banana's is `K3`. These were measured on 2026-10-14. `tests/picard_fuchs_examples.wls` checks the
labels of the sunrise and the banana.
