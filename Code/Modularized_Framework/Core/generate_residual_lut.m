function lut = generate_residual_lut(N, sigma, method)
% Count-to-residual table for the actual number of independent decisions.
% The MLE endpoints use a declared +/-2.5 LSB saturation convention.
% Sigma is the assumed training noise; varying physical sigma remains a
% sensitivity experiment. This is not a device-level PVT model.
    if ~isscalar(N) || ~isfinite(N) || N < 1 || N ~= floor(N)
        error('ADC:InvalidCount', 'N must be a positive integer.');
    end
    if ~isscalar(sigma) || ~isfinite(sigma) || sigma <= 0
        error('ADC:InvalidNoise', 'sigma must be finite and positive.');
    end
    if strcmpi(method, 'mle')
        lut = zeros(1, N+1);
        lut(1) = -2.5; lut(end) = 2.5;
        k = 1:N-1;
        lut(k+1) = max(-2.5, min(2.5, sqrt(2)*sigma*erfinv(2*k/N-1)));
    elseif strcmpi(method, 'be')
        v = linspace(-10*sigma, 10*sigma, 5001);
        p = min(1-eps, max(eps, 0.5*(1+erf(v/(sqrt(2)*sigma)))));
        log_prior = -0.5*(v/sigma).^2;
        lut = zeros(1, N+1);
        for k = 0:N
            log_weight = k*log(p)+(N-k)*log1p(-p)+log_prior;
            weight = exp(log_weight-max(log_weight));
            lut(k+1) = sum(v.*weight)/sum(weight);
        end
    else
        error('ADC:InvalidMethod', 'method must be mle or be.');
    end
end
