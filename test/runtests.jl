using StippleMathjs
using Stipple, Stipple.ReactiveTools
using Stipple.Genie.HTTPUtils.HTTP
using StippleUI

using Test

function string_get(x)
    String(HTTP.get(x, retries = 0, status_exception = false).body)
end

@testset "Reactive API (implicit)" begin
    
    @eval begin        
        @app begin
            port = rand(8001:9000)
            up(;port, ws_port = port)

            x0 = 1.0
            y0 = 2.0
            
            @in x = x0
            @in y = y0
            @in y_onebased = 2
            @in hh = Stipple.opts(y_onebased = 2, x_onebased =3)
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
        
        @eval payload = string_get("http://127.0.0.1:$port")
    end
    @eval @test match(r"<script[^<]+math\.min\.js", payload).match == "<script src=\"https://cdnjs.cloudflare.com/ajax/libs/mathjs/12.0.0/math.min.js"
    @eval StippleMathjs.LOCAL_MATHJS[] = true
    @eval payload = string_get("http://127.0.0.1:$port")
    @eval @test match(r"<script[^<]+math\.js", payload).match == "<script src=\"stipple.jl/master/assets/js/math.js"
    @test contains(payload, r"<script>Genie.WebChannels.subscriptionHandlers.push\(function\(event\) {\s+Genie.Revivers.addReviver\(math.reviver\);\s+}\);\s+</script>")
end
