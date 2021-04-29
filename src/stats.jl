function speedstats(xy, Δt)
    if length(xy) < 2
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

const intervals = sort([5, 10, 30, 60, 90, 120])
const nintervals = length(intervals) + 1

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
    if length(xy) < 2
        return missing
    end
    ss = [[Mean(), Mean()] for _ in 1:nintervals]
    for i in 2:length(xy)
        g = coordinate2group(xy[i] - dropoff)
        fit!.(ss[g], LinearAlgebra.normalize(xy[i] - xy[i-1]))
    end
    # [OnlineStats.nobs(s[1]) > 0 ? atand(reverse(value.(s))...) : missing for s in ss]
    [OnlineStats.nobs(s[1]) > 0 ? rad2deg(angular_diff_from_pos_y_axis(value.(s))) : missing for s in ss]
end
directionstats(track::Track, dropoff) = (; (Symbol(k, :direction) => directionstats(getproperty(track, k), dropoff) for k in (:homing, :searching))...)

function angular_diff_from_pos_y_axis(u)
    α = π/2 - atan(reverse(u)...)
    return α > π ? α - 2π : α
end

dropoff2tp(track::Track, dropoff) = (; vector_length = norm(track.turning_point - dropoff))


function finddiscrete(xy, dropoff)
    g = [coordinate2group(p - dropoff) for p in xy]
    Δ = diff(g)
    findall(!iszero, Δ)
end

function discretedirection(xy, dropoff)
    if length(xy) < 2
        return missing
    end
    map(finddiscrete(xy, dropoff)) do i
        isnothing(i) ? missing : rad2deg(angular_diff_from_pos_y_axis(LinearAlgebra.normalize(xy[i + 1] - xy[i])))
    end
end

discretedirection(track::Track, dropoff) = (; (Symbol(k, :discretedirection) => discretedirection(getproperty(track, k), dropoff) for k in (:homing, :searching))...)

tp_discretedirection(track::Track) = (; tpdiscretedirection = track.tp == 1 ? missing : rad2deg(angular_diff_from_pos_y_axis(LinearAlgebra.normalize(track.coords[track.tp] - track.coords[track.tp - 1]))))

path_length(s) = (; path_length = length(s.track.homing) > 1 ? sum(norm, diff(s.track.homing)) : missing, nest_corrected_vector_2 = -s.nest2feeder - last(s.track.turning_point), nest_corrected_vector_1 = last(s.track.turning_point))
