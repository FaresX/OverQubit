# 临时探针：拿两个 notebook 默认参数下的真实数字（写文案时引用，避免拍脑袋）
include(joinpath(@__DIR__, "..", "src", "OverQubit.jl"))
using .OverQubit

function probe(tag, t)
	E = eigenenergies(t, 0.0)
	f01, f12 = f01_f12(t, 0.0)
	α = f12 - f01
	ngs, Es = charge_dispersion(t, 81, 3)
	e01s = Es[:, 2] .- Es[:, 1]
	band = (maximum(e01s) - minimum(e01s)) * 1000
	println(tag, ": EJ=", t.EJ, " EC=", t.EC, "  EJ/EC=", round(t.EJ / t.EC, digits=1))
	println("   E0..E3 = ", round.(E[1:4], digits=4))
	println("   f01=", round(f01, digits=4), " f12=", round(f12, digits=4), " alpha=", round(α, digits=4))
	koch = t.EC * (sqrt(8 * t.EJ / t.EC) - 1)
	println("   koch=", round(koch, digits=4), "  偏差%=", round(100 * abs(f01 - koch) / f01, digits=3))
	println("   zpf=", round((2 * t.EC / t.EJ)^0.25, digits=4), "  omega_ho=", round(sqrt(8 * t.EC * t.EJ), digits=4))
	println("   色散带宽 = ", round(band, digits=5), " MHz   （指数 exp(-sqrt(8EJ/EC)) = ",
		exp(-sqrt(8 * t.EJ / t.EC)), "）")
end

# mvp0 默认
probe("mvp0 默认", Transmon(20, 0.3; ncut=80))
probe("mvp0 CPB(5,0.5)", Transmon(5, 0.5; ncut=80))
probe("mvp0 EJ=5,EC=0.3", Transmon(5, 0.3; ncut=80))

# flux 默认与极限
probe("flux 默认 Φ=0.25 D=0.1", transmon_at_flux(20, 0.3, 0.25; D=0.1, ncut=80))
probe("flux Φ=0 D=0.1", transmon_at_flux(20, 0.3, 0.0; D=0.1, ncut=80))
probe("flux Φ=0.5 D=0", transmon_at_flux(20, 0.3, 0.5; D=0.0, ncut=80))
probe("flux Φ=0.5 D=0.1", transmon_at_flux(20, 0.3, 0.5; D=0.1, ncut=80))
probe("flux Φ=0.45 D=0.1", transmon_at_flux(20, 0.3, 0.45; D=0.1, ncut=80))
probe("flux Φ=0.5 D=0.3", transmon_at_flux(20, 0.3, 0.5; D=0.3, ncut=80))
probe("flux Φ=0.48 D=0", transmon_at_flux(20, 0.3, 0.48; D=0.0, ncut=80))
