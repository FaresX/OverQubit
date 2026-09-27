"""
    OverQubit

超导量子比特原理演示器的 Julia 包：物理层（transmon 能谱 / 色散读取 / 驱动动力学 /
两比特耦合 / CZ 门）+ 渲染层（子模块 `OverQubitViz`，Plotly HTML 组件）。

分层铁律：物理层只依赖 LinearAlgebra，不 import 任何渲染符号；
渲染层（`OverQubitViz`）不含物理。两个世界的 API 经本模块统一导出。

文件布局：`transmon.jl` / `readout.jl` / `dynamics.jl` / `two_qubit.jl` / `cz.jl` /
`viz/OverQubitViz.jl`——include 顺序即依赖顺序（transmon 最底层）。
"""
module OverQubit

using LinearAlgebra

include("transmon.jl")
include("readout.jl")
include("dynamics.jl")
include("two_qubit.jl")
include("cz.jl")

include("viz/OverQubitViz.jl")
using .OverQubitViz          # 渲染层 API 转入 OverQubit 命名空间（下方一并 export）

# —— 导出：transmon 能谱与磁通调谐（transmon.jl）——
export Transmon, charge_states, charge_hamiltonian, spectrum, eigenenergies,
       f01_f12, anharmonicity, potential, wavefunctions, charge_dispersion,
       charge_matrix_element, squid_ej, transmon_at_flux

# —— 导出：谐振器色散读取（readout.jl）——
export jc_chi, dispersive_params, s21, steady_amplitude

# —— 导出：驱动动力学与序列引擎（dynamics.jl）——
export driven_basis, drive_envelope, evolve_density, evolve_density_iq,
       dissipator_super, rotating_drive, SequenceEngine, evolve_segments

# —— 导出：两比特耦合（two_qubit.jl）——
export coupled_hamiltonian, coupled_spectrum, TwoQubit, basis_index, dressed_index,
       level_energy, energies_ghz, bare_detuning, exchange_rate, conditional_f01,
       conditional_f01_2, zz_rate, evolve_two_qubit

# —— 导出：CZ 门引擎（cz.jl）——
export CZPair, cz_pair, cz_squid_ej, cz_hamiltonian, cz_levels, cz_level_energy,
       cz_gap, cz_crossing, cz_detuning, cz_pulse_shape, cz_flux, cz_evolve,
       cz_conditional_phase, cz_leakage, cz_ramsey, cz_ramsey_pair, cz_metrics, cz_chevron,
       cz_zcorrect

# —— 导出：渲染层（viz/OverQubitViz.jl，转出口）——
export HTMLStr, plotly_html, spec_json, layout_base, frame, animation_menu, anim_frame,
       derivation, concept_cards, tryout, PAL, PAL_FILL, INK, SUB, GRID, AXIS, FONT,
       banner, section_header, stat_card, setup_page, stat_row, readout_table, callout,
       figure_note, lesson_nav, quiz, divider, oq_stack, tex, texblock

end # module
