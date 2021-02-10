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

intervals = sort([5, 10, 30, 60])
nintervals = length(intervals) + 1
function coordinate2group(xy)
    l = norm(xy)
    for (i, L) in pairs(intervals)
        if l ≤ L
            return i
        end
    end
    return nintervals
end

function directionstats(xy, dropoff)
    if length(xy) < 10
        return missing
    end
    ss = [[Mean(), Mean()] for _ in 1:nintervals]
    for i in 2:length(xy)
        g = coordinate2group(xy[i] - dropoff)
        fit!.(ss[g], LinearAlgebra.normalize(xy[i] - xy[i-1]))
    end
    [OnlineStats.nobs(s[1]) > 0 ? atand(reverse(value.(s))...) : missing for s in ss]
end
directionstats(track::Track, dropoff) = (; (Symbol(k, :direction) => directionstats(getproperty(track, k), dropoff) for k in (:homing, :searching))...)
