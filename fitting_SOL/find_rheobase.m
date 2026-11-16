function rh = find_rheobase(p)
% FIND_RHEOBASE Estimate the current threshold for one spike in 500 ms.
% This is a numerical, protocol-dependent rheobase (uA/cm^2), not a
% measured property of SOL or TA motoneurons.
% Uses run_protocol.m and its findpeaks-based spike detection.

lo = 0;
hi = 1;  % Initial upper test current (uA/cm^2).

% Find a current that elicits at least one action potential.
for k = 1:9
    r = run_protocol(p, [hi 500]);
    if ~isempty(r.spikes)
        break;
    end
    hi = 2*hi;
end

if isempty(r.spikes)
    error('No spike found during rheobase search.');
end

% Narrow the threshold interval by binary search (11 refinements).
for k = 1:11
    mid = (lo + hi)/2;
    r = run_protocol(p, [mid 500]);

    if isempty(r.spikes)
        lo = mid;
    else
        hi = mid;
    end
end

% Report the lowest tested current that elicited a spike.
% The estimate has finite precision and assumes a consistent firing threshold.
rh = hi;
end
