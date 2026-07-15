function SimulateBiasedUniform()
    % SimulateBiasedUniform.m
    % Tests whether the biasedUniform design produces step-like DVs
    % or whether Poisson noise distorts the distribution significantly.
    
    % Test parameters
    TrialCounts = [100, 500, 1000, 5000];
    TotalClicksValues = [40, 60, 100, 200];
    Biases = [0.5, 0.8, 0.2];
    BiasNames = {'Unbiased (p=0.5)', 'Left Bias (p=0.8)', 'Right Bias (p=0.2)'};
    
    Duration = 1;       % seconds
    SamplingRate = 25000;
    ClickLength = 2;
    
    fig = figure('Name', 'Biased Uniform Simulation', 'Position', [50 50 1600 1000]);
    tlo = tiledlayout(fig, numel(TrialCounts), numel(Biases));
    tlo.TileSpacing = 'tight';
    tlo.Padding = 'tight';
    sgtitle('Effect of Trial Count and Total Clicks on DV Distribution Shape', 'FontSize', 14);
    
    for iBias = 1:numel(Biases)
        p = Biases(iBias);
        
        for iTrials = 1:numel(TrialCounts)
            nTrials = TrialCounts(iTrials);
            TotalClicks = TotalClicksValues(iTrials);  % Scale clicks with trial count
            
            % Simulate nTrials using biasedUniform logic
            Omegas = zeros(1, nTrials);
            ObservedDVs = zeros(1, nTrials);
            
            for t = 1:nTrials
                % Draw from biasedUniform
                if rand() < p
                    DV_intended = rand();  % U(0.5, 1) mapped to DV in [0, 1]
                else
                    DV_intended = -rand(); % U(-1, 0) mapped to DV in [-1, 0]
                end
                
                Omega_intended = (DV_intended + 1) / 2;
                LeftClickRate = round((TotalClicks / 2) * (DV_intended + 1));
                RightClickRate = TotalClicks - LeftClickRate;
                
                % Generate Poisson click trains
                LeftTrain = GeneratePoissonClickTrain(LeftClickRate, Duration, SamplingRate, ClickLength);
                RightTrain = GeneratePoissonClickTrain(RightClickRate, Duration, SamplingRate, ClickLength);
                
                % Observed DV
                sumL = sum(LeftTrain);
                sumR = sum(RightTrain);
                if (sumL + sumR) > 0
                    ObservedDVs(t) = (sumL - sumR) / (sumL + sumR);
                else
                    ObservedDVs(t) = 0;
                end
                Omegas(t) = (ObservedDVs(t) + 1) / 2;
            end
            
            % Clip to (0,1) for beta fitting
            Omega_fit = min(max(Omegas, 1e-6), 1 - 1e-6);
            
            % Plot
            nexttile(tlo, (iTrials - 1) * numel(Biases) + iBias);
            hold on
            
            % Histogram
            histogram(Omega_fit, 'Normalization', 'pdf', 'BinWidth', 0.05, ...
                      'FaceColor', [0.7 0.7 0.7], 'EdgeColor', [0.5 0.5 0.5]);
            
            % Theoretical Biased Uniform step function
            x = linspace(0, 1, 200);
            yUniform = zeros(size(x));
            yUniform(x < 0.5) = 2 * (1 - p);
            yUniform(x >= 0.5) = 2 * p;
            plot(x, yUniform, 'k:', 'LineWidth', 1.5);
            
            % Fitted Beta
            phat = betafit(Omega_fit);
            yBeta = betapdf(x, phat(1), phat(2));
            plot(x, yBeta, 'r-', 'LineWidth', 1.5);
            
            % Calculate AIC for both models
            % Uniform NLL
            uniformPDF_vals = 2 * (1 - p) * (Omega_fit < 0.5) + 2 * p * (Omega_fit >= 0.5);
            nllUniform = -sum(log(uniformPDF_vals));
            aicUniform = 2 * 1 + 2 * nllUniform;
            
            % Beta NLL
            nllBeta = -sum(log(betapdf(Omega_fit, phat(1), phat(2))));
            aicBeta = 2 * 2 + 2 * nllBeta;
            
            % Title with AIC comparison
            if aicUniform < aicBeta
                winner = 'UNIFORM wins';
                winColor = [0 0.6 0];
            else
                winner = 'BETA wins';
                winColor = [0.8 0 0];
            end
            
            title(sprintf('%s, N=%d, C=%d\nAIC_U=%.0f, AIC_B=%.0f → %s', ...
                          BiasNames{iBias}, nTrials, TotalClicks, ...
                          aicUniform, aicBeta, winner), ...
                  'FontSize', 8, 'Color', winColor);
            
            xlim([0 1]);
            ylim([0 4]);
            xlabel('\Omega');
            ylabel('PDF');
            
            % Legend for first tile only
            if iTrials == 1 && iBias == 1
                legend('Observed', 'Uniform (theory)', 'Beta (fit)', 'Location', 'best');
            end
            hold off
        end
    end
end