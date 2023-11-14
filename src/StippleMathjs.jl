module StippleMathjs

using Stipple
using Genie

import Genie.Assets.add_fileroute

const LOCAL_MATHJS = Ref(false)

function deps()
    add_fileroute(Stipple.assets_config, "math.js", basedir = joinpath(@__DIR__, ".."))

    [
        if LOCAL_MATHJS[]
            script(src="$(Genie.config.base_path)stipple.jl/master/assets/js/math.js")
        else
            script(
                src="https://cdnjs.cloudflare.com/ajax/libs/mathjs/12.0.0/math.min.js",
                integrity="sha512-eP0ts2A1DdhciB/Ug0EGQ4YAF9Y8pF1Ynl8oPFdO7BiK/RUDqqYi+Y5ij8oQDbUxqTITyDEsRMJnU25wWrUm5w==",
                crossorigin="anonymous",
                referrerpolicy="no-referrer"
            )
        end

        script(js_add_reviver("math.reviver"))
    ]
end


# standard rendering for communication via webchannels
Stipple.render(z::Complex) = Dict(:mathjs => "Complex", :re => 1z.re, :im => 1z.im)

# special rendering for js-file
function Stipple.jsrender(z::Complex, args...)
    JSONText("math.complex('$(replace(strip(repr(z), '"'), 'm' => ""))')")
end

# parsing for incoming json payload
Stipple.stipple_parse(::Type{Complex{T}}, z::Dict{String, Any}) where T = T(z["re"]) + T(z["im"]) * im
Stipple.stipple_parse(::Type{Complex}, z::Dict{String, Any}) = z["re"] + z["im"] * im

# setup route and deps
# function __init__()
#     add_fileroute(Stipple.assets_config, "math.js", basedir = joinpath(@__DIR__, ".."))
#     Stipple.deps!(@type) = mathjs_deps
# end

end # module StippleMathjs
