function speedstats(xy, Δt)
    if length(xy) < 10
        return missing
    end
    l = norm.(diff(xy))
    # L = cumsum(l)
    s = l/Δt
    μ = mean(s)
    σ = std(s, mean = μ)
    μ ± σ
end
speedstats(track) = (; (Symbol(k, :speed) => speedstats(getproperty(track, k), step(track.t)) for k in (:homing, :searching))...)


