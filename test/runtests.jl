using StippleMathjs
using Stipple, Stipple.ReactiveTools
using Stipple.Genie.HTTPUtils.HTTP
using StippleUI

using Test

@testset "StippleMathjs.jl" begin
    @testset "Module initialization" begin
        # Test deps function exists
        @test StippleMathjs.deps isa Function

        # Test LOCAL_MATHJS flag
        @test StippleMathjs.LOCAL_MATHJS isa Base.RefValue{Bool}
        @test StippleMathjs.LOCAL_MATHJS[] isa Bool
    end

    @testset "Complex number rendering" begin
        # Test standard rendering for web channels
        z1 = 3.0 + 4.0im
        rendered = Stipple.render(z1)
        @test rendered isa Dict
        @test rendered[:mathjs] == "Complex"
        @test rendered[:re] == 3.0
        @test rendered[:im] == 4.0

        # Test with negative imaginary part
        z2 = 5.0 - 2.5im
        rendered2 = Stipple.render(z2)
        @test rendered2[:re] == 5.0
        @test rendered2[:im] == -2.5

        # Test jsrender for JavaScript code generation
        z3 = 1.0 + 2.0im
        js_rendered = Stipple.jsrender(z3)
        @test js_rendered isa Stipple.JSONText
        js_str = string(js_rendered)
        @test occursin("math.complex", js_str)
        @test occursin("1.0", js_str)
        @test occursin("2.0", js_str)

        # Test jsrender with different complex number
        z4 = -3.5 + 7.8im
        js_rendered2 = Stipple.jsrender(z4)
        js_str2 = string(js_rendered2)
        @test occursin("math.complex", js_str2)
        @test occursin("-3.5", js_str2)
        @test occursin("7.8", js_str2)
    end

    @testset "Complex number parsing" begin
        # Test parsing ComplexF64
        dict1 = Dict("re" => 3.0, "im" => 4.0)
        parsed1 = Stipple.stipple_parse(ComplexF64, dict1)
        @test parsed1 isa ComplexF64
        @test parsed1.re == 3.0
        @test parsed1.im == 4.0

        # Test parsing ComplexF32
        dict2 = Dict("re" => 1.5, "im" => 2.5)
        parsed2 = Stipple.stipple_parse(ComplexF32, dict2)
        @test parsed2 isa ComplexF32
        @test parsed2.re ≈ 1.5f0
        @test parsed2.im ≈ 2.5f0

        # Test parsing generic Complex
        dict3 = Dict("re" => 5, "im" => -3)
        parsed3 = Stipple.stipple_parse(Complex, dict3)
        @test parsed3 isa Complex
        @test parsed3.re == 5
        @test parsed3.im == -3

        # Test parsing with negative values
        dict4 = Dict("re" => -7.2, "im" => -1.8)
        parsed4 = Stipple.stipple_parse(ComplexF64, dict4)
        @test parsed4.re == -7.2
        @test parsed4.im == -1.8
    end

    @testset "Round-trip conversion" begin
        # Test that rendering and parsing are inverses
        original = 3.14 + 2.71im
        rendered = Stipple.render(original)
        # Convert Symbol keys to String keys for parsing
        rendered_str = Dict(string(k) => v for (k, v) in rendered)
        parsed = Stipple.stipple_parse(ComplexF64, rendered_str)
        @test parsed ≈ original

        # Test with different values
        test_values = [
            1.0 + 1.0im,
            0.0 + 0.0im,
            -5.0 + 3.0im,
            2.5 - 4.5im,
            -1.0 - 1.0im
        ]

        for z in test_values
            rendered = Stipple.render(z)
            rendered_str = Dict(string(k) => v for (k, v) in rendered)
            parsed = Stipple.stipple_parse(ComplexF64, rendered_str)
            @test parsed ≈ z
        end
    end

    @testset "Dependencies generation" begin
        # Test CDN mode (default)
        StippleMathjs.LOCAL_MATHJS[] = false
        deps_cdn = StippleMathjs.deps()
        @test deps_cdn isa Vector
        @test length(deps_cdn) >= 2

        # Convert to strings for testing
        deps_cdn_str = string.(deps_cdn)

        # Check for CDN script
        cdn_script = first(filter(d -> occursin("cdnjs.cloudflare.com", d), deps_cdn_str))
        @test occursin("math.min.js", cdn_script)
        @test occursin("integrity", cdn_script)
        @test occursin("crossorigin", cdn_script)

        # Check for reviver script
        @test any(d -> occursin("math.reviver", d), deps_cdn_str)

        # Test local mode
        StippleMathjs.LOCAL_MATHJS[] = true
        deps_local = StippleMathjs.deps()
        @test deps_local isa Vector
        @test length(deps_local) >= 2

        # Convert to strings for testing
        deps_local_str = string.(deps_local)

        # Check for local script
        local_script = first(filter(d -> occursin("stipple.jl", d) && occursin("math.js", d), deps_local_str))
        @test occursin("assets/js/math.js", local_script)

        # Check for reviver script in local mode too
        @test any(d -> occursin("math.reviver", d), deps_local_str)

        # Reset to default
        StippleMathjs.LOCAL_MATHJS[] = false
    end
end

# Integration test with web server
@testset "Web integration" begin
    function string_get(x)
        String(HTTP.get(x, retries = 0, status_exception = false).body)
    end

    port = rand(8001:9000)
    up(; port, ws_port = port)
    x0 = 1.0
    y0 = 2.0

    @app begin
        @in x = x0
        @in y = y0
        @in y_onebased = 2
        @in hh = Stipple.opts(a = 2, b = 3)
        @in z::ComplexF64 = x0 + y0 * im

        @onchange x, y begin
            z[!] = x + y*im
            @push z
        end

        @onchange z begin
            @show z
            x[!] = z.re
            y[!] = z.im
            @push x
            @push y
        end
    end

    @deps StippleMathjs

    function ui()
        [
            card(class = "q-pa-md", [
                numberfield(class = "q-ma-md", "x", :x)
                numberfield(class = "q-ma-md", "y", :y)
            ])

            card(class = "q-pa-md q-my-md", [
                row([cell(col = 2, "z"),        cell("{{ z }}")])
                row([cell(col = 2, "z.mul(z)"), cell("{{ z.mul(z) }}")])
                row([cell(col = 2, "z.abs()"),  cell("{{ z.abs() }}")])

                btn(class = "q-my-md", "square(z)", color = "primary", @click("z = z.mul(z)"))
            ])
        ]
    end

    @page("/", ui, debounce = 10)

    @testset "CDN script loading" begin
        payload = string_get("http://127.0.0.1:$port")
        @test match(r"<script[^<]+math\.min\.js", payload).match == "<script src=\"https://cdnjs.cloudflare.com/ajax/libs/mathjs/12.0.0/math.min.js"
        @test contains(payload, "integrity")
        @test contains(payload, "crossorigin")
    end

    @testset "Local script loading" begin
        StippleMathjs.LOCAL_MATHJS[] = true
        payload = string_get("http://127.0.0.1:$port")
        @test match(r"<script[^<]+math\.js", payload).match == "<script src=\"stipple.jl/$(Genie.Assets.package_version(Stipple))/assets/js/math.js"
    end

    @testset "Reviver registration" begin
        payload = string_get("http://127.0.0.1:$port")
        @test contains(payload, r"Genie.WebChannels.subscriptionHandlers.push\(function\(event\) {\s+Genie.Revivers.addReviver\(math.reviver\);\s+}\)")
    end

    @testset "Page loads successfully" begin
        payload = string_get("http://127.0.0.1:$port")

        # Check that the page loaded (has HTML structure)
        @test contains(payload, "<html")
        @test contains(payload, "</html>")

        # Check for complex number display mustache templates
        @test contains(payload, "{{ z }}")
        @test contains(payload, "{{ z.mul(z) }}")
        @test contains(payload, "{{ z.abs() }}")

        # Check for button with square(z) click handler
        @test contains(payload, "square(z)")
    end
end
