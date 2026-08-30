function varargout = analysis_tools(mode,varargin)
mode=lower(char(mode));
switch mode
case 'complexity_analysis'
    if nargout==0
        complexityXanalysisXcomplexity_analysis(varargin{:});
    else
        [varargout{1:nargout}] = complexityXanalysisXcomplexity_analysis(varargin{:});
    end
case 'reference_validation'
    if nargout==0
        referenceXvalidationXreference_validation(varargin{:});
    else
        [varargout{1:nargout}] = referenceXvalidationXreference_validation(varargin{:});
    end
case 'research_report'
    if nargout==0
        researchXreportXresearch_report(varargin{:});
    else
        [varargout{1:nargout}] = researchXreportXresearch_report(varargin{:});
    end
case 'numerical_identity_checks'
    if nargout==0
        numericalXidentityXchecks(varargin{:});
    else
        [varargout{1:nargout}] = numericalXidentityXchecks(varargin{:});
    end
case 'cv_metrics_report'
    if nargout==0
        cvXmetricsXreportXcv_metrics_report(varargin{:});
    else
        [varargout{1:nargout}] = cvXmetricsXreportXcv_metrics_report(varargin{:});
    end
otherwise
    error('Unknown mode %s for %s.',mode,mfilename);
end
end

function C = complexityXanalysisXcomplexity_analysis(N,bands,otfsGrid,bemOrder,otfsIters,alphabetSize)
if nargin<2 || isempty(bands), bands=[1 2 4 8 16]; end
if nargin<3 || isempty(otfsGrid), otfsGrid=[32 32]; end
if nargin<4 || isempty(bemOrder), bemOrder=4; end
if nargin<5 || isempty(otfsIters), otfsIters=15; end
if nargin<6 || isempty(alphabetSize), alphabetSize=4; end
Q=bemOrder;
C.LS = N;                                  % pilot division + linear interp
C.DFT_LS = N*log2(N)+N;                    % two length-N transforms
C.LMMSE = 8*N^3/3;                         % one complex NxN Cholesky solve
C.Kalman = 4*8*N^3;                        % ~4 complex NxN products, Joseph form
C.BEM = N*(2*Q+1)*4;                       % per-tap least-squares fit at order Q
C.BEM_MMSE = 8*N*(2*Q+1)^2;                % banded solve at BEM half-band Q
C.MMSE_ICI_full = 8*N^3 + 8*N^3/3;         % H'H product PLUS the solve
for b=bands
    C.(sprintf('B%d',b)) = 8*N*(2*b+1)^2;
end
L=prod(otfsGrid); edgesPerCol=max(1,otfsGrid(2));
C.OTFS_MP = 8*L*edgesPerCol*alphabetSize*otfsIters;
C.OTFS_MMSE = 8*L^3/3;
C.fullMemoryBytes=16*N^2;
for b=bands
    C.(sprintf('B%dMemoryBytes',b))=16*N*(2*b+1);
end
C.bandedReductionFullVsB8 = C.MMSE_ICI_full/max(C.B8,eps);
C.memoryReductionFullVsB8 = C.fullMemoryBytes/max(C.B8MemoryBytes,eps);
C.bemOrder=Q; C.otfsIterations=otfsIters; C.alphabetSize=alphabetSize;
C.note='Analytical real-flop proxies. Counts track cfg (BEM order, OTFS iterations, alphabet size). Measured runtime is stored separately by the experiment layer.';
end


function R=referenceXvalidationXreference_validation()
R.qammodAvailable = ~isempty(which('qammod'));
R.qamdemodAvailable = ~isempty(which('qamdemod'));
R.mimoChannelAvailable = ~isempty(which('comm.MIMOChannel'));
R.pwelchAvailable = ~isempty(which('pwelch'));
R.parallelAvailable = ~isempty(which('parfor'));
R.constellationSetError = 0;
R.unitPowerError = 0;
R.roundTripBitErrors = 0;
R.labellingMatchesToolbox = 0;

for M=[4 16]
    k=log2(M); idx=(0:M-1).';
    bitsAll=false(M*k,1);
    for ii=1:M
        b=bitget(idx(ii),k:-1:1);
        bitsAll((ii-1)*k+(1:k))=logical(b(:));
    end
    [ours,~]=physical_core('modem_ofdm','qammap',bitsAll,M);
    R.unitPowerError = max(R.unitPowerError, abs(mean(abs(ours).^2)-1));
    back=physical_core('modem_ofdm','qamdemap',ours,M);
    R.roundTripBitErrors = max(R.roundTripBitErrors, sum(back~=bitsAll));
    if R.qammodAvailable
        ref=qammod(idx,M,'UnitAveragePower',true);
        so=sortrows([real(ours(:)) imag(ours(:))],[1 2]);
        sr=sortrows([real(ref(:))  imag(ref(:))], [1 2]);
        R.constellationSetError = max(R.constellationSetError, max(abs(so(:)-sr(:))));
        R.labellingMatchesToolbox = max(R.labellingMatchesToolbox, double(max(abs(ours(:)-ref(:)))>1e-9));
    end
end
R.constellationNote='constellationSetError compares point sets under unit average power and must be ~0. labellingMatchesToolbox=1 means our Gray labelling differs from the toolbox bit-to-symbol assignment, which is a convention difference and does not affect BER because our mapper and demapper are mutually inverse (roundTripBitErrors=0).';
R.MATLAB=version('-release');
end


function varargout=researchXreportXresearch_report(action,varargin)
if nargin<1, action='plot'; end
switch lower(action)
    case 'plot', varargout{1}=researchXreportXplot_all(varargin{:});
    case 'validate', varargout{1}=researchXreportXvalidate_all(varargin{:});
    case 'summary', varargout{1}=researchXreportXsummary_all(varargin{:});
    case 'cv', varargout{1}=researchXreportXcv_report(varargin{:});
    otherwise, error('Use plot, validate, summary, or cv.');
end
end

function R=researchXreportXload_result(file)
S=load(file); if isfield(S,'out'),R=S.out; else, error('Result structure not found.'); end
end


function files=researchXreportXplot_all(file)
R=researchXreportXload_result(file);
d=fullfile(fileparts(file),'figures');
if exist(d,'dir'), rmdir(d,'s'); end
mkdir(d);
files={};

f=figure('Name','01 Baseline BER','Color','w'); ax=gca; hold(ax,'on');
snr=R.baseline.snrDb(:); theory=R.baseline.theory(:);
pos=isfinite(theory)&theory>0;
semilogy(ax,snr(pos),theory(pos),'k--','LineWidth',1.5,'DisplayName','QPSK theory');
researchXreportXplotBer(ax,snr,R.baseline.berAwgn(:),R.baseline.zeroErrorUpperBound(1,:),'o-','AWGN');
researchXreportXplotBer(ax,snr,R.baseline.berStatic(:),R.baseline.zeroErrorUpperBound(2,:),'s-','Static EVA');
researchXreportXplotBer(ax,snr,R.baseline.berDoppler(:),R.baseline.zeroErrorUpperBound(3,:),'^-','Doppler EVA');
grid(ax,'on'); xlabel(ax,'E_b/N_0 (dB)'); ylabel(ax,'BER');
title(ax,'Baseline OFDM BER: AWGN reference, static EVA, and Doppler EVA');
legend(ax,'Location','southwest');
yData=[R.baseline.berAwgn(:);R.baseline.berStatic(:);R.baseline.berDoppler(:);R.baseline.zeroErrorUpperBound(:)];
researchXreportXlimitY(ax,yData);
files{end+1}=researchXreportXsavePng(f,d,'01_baseline_ber');

f=figure('Name','02 Channel Estimation','Color','w');
ax=subplot(1,2,1); hold(ax,'on');
semilogy(ax,R.estimation.snrDb(:),R.estimation.mse.','LineWidth',1.2);
semilogy(ax,R.estimation.snrDb(:),max(R.estimation.crlb(:),eps),'k--','LineWidth',1.6);
grid(ax,'on'); xlabel(ax,'E_b/N_0 (dB)'); ylabel(ax,'Channel MSE (all subcarriers)');
legend(ax,[R.estimation.methods(:).' {'Bayesian posterior CRLB'}],'Location','southwest');
title(ax,'Estimation error vs the Bayesian bound');
if isfield(R.estimation,'msePilot')
    ax2=subplot(1,2,2); hold(ax2,'on');
    semilogy(ax2,R.estimation.snrDb(:),R.estimation.msePilot.','LineWidth',1.2);
    semilogy(ax2,R.estimation.snrDb(:),max(R.estimation.classicalPilotCRLB(:),eps),'k:','LineWidth',1.6);
    grid(ax2,'on'); xlabel(ax2,'E_b/N_0 (dB)'); ylabel(ax2,'Channel MSE (pilot subcarriers)');
    legend(ax2,[R.estimation.methods(:).' {'Classical per-pilot bound'}],'Location','southwest');
    title(ax2,'Pilot-subcarrier error vs the classical bound');
end
sgtitle('Channel estimation against the bounds that apply to each quantity');
files{end+1}=researchXreportXsavePng(f,d,'02_channel_estimation');

f=figure('Name','03 ICI Growth','Color','w');
yyaxis left; loglog(R.ici.fdTu,max(R.ici.theoryWorstCase,eps),'k--','LineWidth',1.5); hold on;
if isfield(R.ici,'theoryJakes'), loglog(R.ici.fdTu,max(R.ici.theoryJakes,eps),'k:','LineWidth',1.3); end
loglog(R.ici.fdTu,max(R.ici.sim,eps),'o-','LineWidth',1.2); ylabel('ICI power / desired-carrier power');
yyaxis right; semilogx(R.ici.fdTu,R.ici.band99,'s-','LineWidth',1.1); hold on; semilogx(R.ici.fdTu,R.ici.band999,'^-','LineWidth',1.1); ylabel('ICI half-bandwidth (subcarriers)');
xlabel('f_D T_u'); grid on; legend('Worst-case asymptote (E[\nu^2]=f_D^2)','Jakes asymptote (E[\nu^2]=f_D^2/2)','Simulation','99% energy half-band','99.9% energy half-band','Location','northwest');
title('ICI growth bracketed by the two small-Doppler asymptotes');
files{end+1}=researchXreportXsavePng(f,d,'03_ici_growth_bandwidth');

f=figure('Name','04 BEM Order','Color','w');
semilogy(R.ici.bemOrders,max(R.ici.bemFreqNMSE,eps),'o-','LineWidth',1.2); hold on;
semilogy(R.ici.bemOrders,max(R.ici.bemMSE,eps),'s--','LineWidth',1.1);
grid on; xlabel('CE-BEM order Q'); ylabel('NMSE');
legend('Frequency-domain matrix NMSE','Tap-time NMSE','Location','southwest');
title('CE-BEM order versus approximation error');
files{end+1}=researchXreportXsavePng(f,d,'04_bem_order');

f=figure('Name','05 Receiver Ladder','Color','w'); ax=gca; hold(ax,'on');
idx=R.equalizer.highDopplerIndex; if ~isscalar(idx), idx=2; end
if isfield(R.equalizer,'zeroErrorUpperBound')
    floorEq=R.equalizer.zeroErrorUpperBound(idx);
else
    floorEq=3/max(R.equalizer.bitsPerPoint(idx),1);
end
h=gobjects(1,numel(R.equalizer.labels));
for k=1:numel(R.equalizer.labels)
    h(k)=researchXreportXplotBer(ax,R.equalizer.snrDb(:),R.equalizer.berHighDoppler(k,:),floorEq,'-','');
end
legend(ax,h,R.equalizer.labels,'Location','southwest');
grid(ax,'on'); xlabel(ax,'E_b/N_0 (dB)'); ylabel(ax,'BER');
title(ax,sprintf('Receiver comparison at high Doppler: f_D T_u = %.3g',R.equalizer.fdTuHigh));
files{end+1}=researchXreportXsavePng(f,d,'05_receiver_ladder_high_doppler');

f=figure('Name','06 Receiver Cost','Color','w');
subplot(1,3,1); names={'LS','DFT-LS','LMMSE','Kalman','BEM','Full-ICI','B8'}; vals=[R.complexity.LS R.complexity.DFT_LS R.complexity.LMMSE R.complexity.Kalman R.complexity.BEM R.complexity.MMSE_ICI_full R.complexity.B8]; bar(categorical(names),vals); set(gca,'YScale','log'); grid on; ylabel('Analytical operation proxy'); title('Analytical cost model');
subplot(1,3,2); medRuntime=median(R.equalizer.runtimeMs,1,'omitnan'); bar(categorical(R.equalizer.labels),medRuntime); grid on; ylabel('Median runtime per call (ms)'); title('Measured runtime across SNR points'); xtickangle(35);
if isfield(R.equalizer,'pcgRelResidual')
    subplot(1,3,3);
    semilogy(R.equalizer.snrDb,R.equalizer.pcgRelResidual,'o-','LineWidth',1.2); grid on;
    xlabel('E_b/N_0 (dB)'); ylabel('PCG relative residual');
    yline(R.equalizer.pcgTolerance,'k--');
    legend(arrayfun(@(v)sprintf('f_DT_u=%.3g',v),R.equalizer.fdTuGrid,'UniformOutput',false),'Location','best');
    title(sprintf('Truncated CG (%d iters): distance from exact MMSE',R.equalizer.pcgIterations));
end
sgtitle('Receiver cost: analytical proxy, measured runtime, and solver convergence');
files{end+1}=researchXreportXsavePng(f,d,'06_receiver_cost');

f=figure('Name','07 OTFS Detectors','Color','w');
for k=1:numel(R.otfs.frac)
    ax=subplot(2,2,k); hold(ax,'on');
    h=[]; h(end+1)=researchXreportXplotBer(ax,R.otfs.snrDb(:),R.otfs.berMF(k,:),R.otfs.zeroErrorUpperBound,'^-','MF');
    h(end+1)=researchXreportXplotBer(ax,R.otfs.snrDb(:),R.otfs.berMMSE(k,:),R.otfs.zeroErrorUpperBound,'s-','MMSE');
    h(end+1)=researchXreportXplotBer(ax,R.otfs.snrDb(:),R.otfs.berMP(k,:),R.otfs.zeroErrorUpperBound,'o-','Message passing');
    h(end+1)=researchXreportXplotBer(ax,R.otfs.snrDb(:),R.otfs.berGS(k,:),R.otfs.zeroErrorUpperBound,'v:','Gauss-Seidel');
    grid(ax,'on'); xlabel(ax,'E_b/N_0 (dB)'); ylabel(ax,'BER'); title(ax,sprintf('Fractional Doppler = %.2f',R.otfs.frac(k))); legend(ax,h,{'MF','MMSE','Message passing','Gauss-Seidel'},'Location','southwest');
end
sgtitle('Synthetic sparse DD detector benchmark (32x32) — not the physical EVA comparison');
files{end+1}=researchXreportXsavePng(f,d,'07_otfs_detectors');

f=figure('Name','08 OFDM vs OTFS','Color','w');
for k=1:numel(R.crosswaveform.fdTu)
    ax=subplot(2,2,k); hold(ax,'on');
    h1=researchXreportXplotBer(ax,R.crosswaveform.snrDb(:),R.crosswaveform.berOFDM(k,:),R.crosswaveform.zeroErrorUpperBound,'o-','OFDM PCG-MMSE');
    h2=researchXreportXplotBer(ax,R.crosswaveform.snrDb(:),R.crosswaveform.berOTFS(k,:),R.crosswaveform.zeroErrorUpperBound,'s-','OTFS PCG-MMSE');
    hh=[h1 h2]; ll={'OFDM PCG-MMSE','OTFS PCG-MMSE'};
    if isfield(R.crosswaveform,'berOTFS_MP')
        hm=researchXreportXplotBer(ax,R.crosswaveform.snrDb(:),R.crosswaveform.berOTFS_MP(k,:),R.crosswaveform.zeroErrorUpperBound,'d--','OTFS message passing');
        hh=[hh hm]; ll=[ll {'OTFS message passing'}];
    end
    legend(ax,hh,ll,'Location','southwest');
    grid(ax,'on'); xlabel(ax,'E_b/N_0 (dB)'); ylabel(ax,'BER');
    if isfield(R.crosswaveform,'fdHz')
        title(ax,sprintf('f_D T_u = %.2f  (f_D = %.1f kHz) — matched PCG-MMSE',R.crosswaveform.fdTu(k),R.crosswaveform.fdHz(k)/1e3));
    else
        title(ax,sprintf('f_D T_u = %.2f — matched PCG-MMSE',R.crosswaveform.fdTu(k)));
    end
end
sgtitle('OFDM vs OTFS: matched truncated PCG-MMSE, equal bits and equal duration, perfect CSI');
files{end+1}=researchXreportXsavePng(f,d,'08_ofdm_vs_otfs');

f=figure('Name','09 OTFS Pilot','Color','w');
subplot(1,2,1);
semilogy(R.otfsPilot.snrDb,max(R.otfsPilot.NMSE,eps),'o-','LineWidth',1.2); hold on;
semilogy(R.otfsPilot.snrDb,max(R.otfsPilot.pathGainNMSE,eps),'s-','LineWidth',1.2);
grid on; xlabel('SNR (dB)'); ylabel('NMSE');
legend('DD operator rebuilt from estimates','Estimated path gains','Location','southwest');
title('Embedded-pilot estimation error');
subplot(1,2,2);
plot(R.otfsPilot.snrDb,R.otfsPilot.detectRate,'o-','LineWidth',1.2); hold on;
if isfield(R.otfsPilot,'falseAlarmRate')
    plot(R.otfsPilot.snrDb,R.otfsPilot.falseAlarmRate,'s--','LineWidth',1.2);
    legend('Tap detection rate','False-alarm rate','Location','east');
else
    legend('Tap detection rate','Location','east');
end
grid on; ylim([-0.05 1.05]); xlabel('SNR (dB)'); ylabel('Rate');
if isfield(R.otfsPilot,'guardOverhead')
    title(sprintf('3\\sigma_n threshold detection (guard = %.0f%% of frame)',100*R.otfsPilot.guardOverhead));
else
    title('Threshold-based tap detection');
end
sgtitle('Embedded delay-Doppler pilot: threshold detection and estimation accuracy');
files{end+1}=researchXreportXsavePng(f,d,'09_otfs_pilot');

f=figure('Name','10 Impairments','Color','w');
subplot(1,3,1); hold on; researchXreportXplotBer(gca,R.impairments.cp,R.impairments.cpBer,R.impairments.zeroErrorUpperBound,'o-',''); grid on; xlabel('CP length (samples)'); ylabel('BER'); title(sprintf('CP-length stress (perfect CSI) at %g dB',R.impairments.snrDb));
subplot(1,3,2); hold on; researchXreportXplotBer(gca,R.impairments.phaseNoiseStd,R.impairments.phaseNoiseBer,R.impairments.zeroErrorUpperBound,'s-',''); grid on; xlabel('Wiener phase increment \sigma_\phi (rad/sample)'); ylabel('BER'); title('Phase-noise sensitivity (perfect CSI)');
subplot(1,3,3); hold on; researchXreportXplotBer(gca,R.impairments.impulsiveProb,R.impairments.impulsiveBer,R.impairments.zeroErrorUpperBound,'^-',''); grid on; xlabel('Impulse probability'); ylabel('BER'); title('Impulsive-noise sensitivity (perfect CSI)');
sgtitle('Receiver robustness to modeled implementation impairments');
files{end+1}=researchXreportXsavePng(f,d,'10_impairments');

f=figure('Name','11 Physical Channel Diagnostics','Color','w');
subplot(2,2,1); stem(R.mobility.pdpDelayNs,R.mobility.pdpPowerDb,'filled'); grid on; xlabel('Path delay (ns)'); ylabel('Average path power (dB)'); title('EVA power-delay profile');
subplot(2,2,2); plot(R.mobility.fadingTimeMs,R.mobility.fadingEnvelope,'LineWidth',1.0); grid on; xlabel('Time (ms)'); ylabel('|h_1(t)|'); title(sprintf('Clustered EVA fading envelope (f_D = %.0f Hz)',R.mobility.generatedFdHz));
subplot(2,2,3); hold on; semilogy(R.mobility.psdFrequency,max(R.mobility.psd,eps),'LineWidth',1.0); if isfield(R.mobility,'jakesFrequency'), semilogy(R.mobility.jakesFrequency,max(R.mobility.jakesEmpiricalPSD,eps),'--','LineWidth',1.0); semilogy(R.mobility.jakesFrequency,max(R.mobility.jakesTheoreticalPSD,eps),':','LineWidth',1.2); end; if isfield(R,'cfg'), xlim([-3*R.cfg.fd 3*R.cfg.fd]); end; grid on; xlabel('Doppler frequency (Hz)'); ylabel('PSD/Hz'); title('Long-run Doppler statistics and Jakes reference');
subplot(2,2,4); hold on; if isfield(R.mobility,'jakesAcfLags'), tms=R.mobility.jakesAcfLags/R.cfg.fs*1e3; plot(tms,real(R.mobility.jakesAcf),'LineWidth',1.0); plot(tms,real(R.mobility.jakesAcfTheory),'--','LineWidth',1.0); end; grid on; xlabel('Lag (ms)'); ylabel('Normalized ACF (real)'); title(sprintf('Jakes ACF reference (RMSE %.3g)',R.mobility.jakesAcfRMSE));
sgtitle('Physical clustered doubly-dispersive channel and separate Jakes reference');
files{end+1}=researchXreportXsavePng(f,d,'11_physical_channel_diagnostics');

if isfield(R,'mismatch') && ~isempty(R.mismatch) && isstruct(R.mismatch)
    f=figure('Name','12 Covariance Mismatch','Color','w');
    plot(R.mismatch.snrs,R.mismatch.penaltyDb,'o-','LineWidth',1.3); grid on;
    xlabel('E_b/N_0 (dB)'); ylabel('LMMSE MSE penalty (dB)');
    yline(0,'k:','matched prior');
    title('Analytical MSE penalty of a mismatched channel-covariance prior');
    files{end+1}=researchXreportXsavePng(f,d,'12_covariance_mismatch');
end
if isfield(R,'mimo') && ~isempty(R.mimo) && isstruct(R.mimo)
    f=figure('Name','13 MIMO-OFDM','Color','w'); ax=gca; hold(ax,'on');
    h1=researchXreportXplotBer(ax,R.mimo.snrDb(:),R.mimo.berZF(:),0,'o-','ZF');
    h2=researchXreportXplotBer(ax,R.mimo.snrDb(:),R.mimo.berMMSE(:),0,'s-','MMSE');
    grid(ax,'on'); xlabel(ax,'E_b/N_0 (dB)'); ylabel(ax,'BER');
    legend(ax,[h1 h2],{'ZF','MMSE'},'Location','southwest');
    title(ax,'2x2 MIMO-OFDM, Zadoff-Chu training, one-symbol-aged CSI');
    files{end+1}=researchXreportXsavePng(f,d,'13_mimo_ofdm');
end

fprintf('Generated %d project figures in %s\n',numel(files),d);
end

function h=researchXreportXplotBer(ax,x,y,bound,style,label)
x=double(x(:)); y=double(y(:));
assert(numel(x)==numel(y), ...
    'plotBer: %d abscissa values but %d ordinates. A transposed BER array will otherwise be plotted silently.', ...
    numel(x),numel(y));
finiteMask=isfinite(y)&y>0;
if any(finiteMask)
    h=semilogy(ax,x(finiteMask),y(finiteMask),style,'LineWidth',1.05,'DisplayName',label); hold(ax,'on');
else
    h=semilogy(ax,nan,nan,style,'LineWidth',1.05,'DisplayName',label);
end
z=(isfinite(y)&y<=0);
if isscalar(bound), bz=repmat(double(bound),size(y)); else, bz=double(bound(:)); if numel(bz)~=numel(y), bz=repmat(max(bz),size(y)); end; end
if any(z)
    semilogy(ax,x(z),bz(z),'o','MarkerFaceColor','none','HandleVisibility','off');
end
end

function researchXreportXlimitY(ax,data)
pos=data(data>0 & isfinite(data)); if isempty(pos), return; end
lo=10^(floor(log10(min(pos)))-1); hi=10^(ceil(log10(max(pos)))+1); ylim(ax,[max(lo,eps) hi]);
end

function file=researchXreportXsavePng(f,d,name)
file=fullfile(d,name); exportgraphics(f,[file '.png'],'Resolution',300); close(f);
end

function V=researchXreportXvalidate_all(file)
R=researchXreportXload_result(file); V.pass=true;V.flags={};
idx=1:min(5,numel(R.baseline.snrDb)); if max(abs(R.baseline.berAwgn(idx)-R.baseline.theory(idx)))>0.015,V.pass=false;V.flags{end+1}='AWGN simulation differs from analytical theory by > 0.015 at low SNR.';end
low=R.ici.fdTu<=0.02;
if isfield(R.ici,'theoryJakes'), lowCurve=R.ici.theoryJakes(low); else, lowCurve=0.5*R.ici.theoryWorstCase(low); end
hiCurve=R.ici.theoryWorstCase(low);
if any(R.ici.sim(low) > 1.30*hiCurve)
    V.pass=false;V.flags{end+1}=sprintf('Low-Doppler ICI exceeds the worst-case asymptote by %.2f dB; inspect the per-subcarrier normalization.',10*log10(max(R.ici.sim(low)./hiCurve)));
end
if any(R.ici.sim(low) < 0.70*lowCurve)
    V.pass=false;V.flags{end+1}=sprintf('Low-Doppler ICI is %.2f dB below the Jakes asymptote; the ICI metric is under-counting.',10*log10(min(lowCurve./R.ici.sim(low))));
end
high=R.ici.fdTu>=0.1; if any(10*log10(max(R.ici.sim(high),eps)./max(R.ici.theory(high),eps))>3),V.flags{end+1}='Simulated ICI exceeds the small-Doppler asymptote at high Doppler; expected direction is below.';end
anchor=find(abs(R.otfs.frac)<1e-12,1); if ~isempty(anchor) && R.otfs.berMMSE(anchor,end)>R.otfs.berMMSE(anchor,1),V.pass=false;V.flags{end+1}='Integer-Doppler OTFS MMSE does not decrease with SNR.';end
if ~isempty(R.mimo) && any(~isfinite([R.mimo.berZF(:);R.mimo.berMMSE(:)])),V.pass=false;V.flags{end+1}='MIMO contains non-finite BER values.';end
if isfield(R.otfs,'berMP') && any(~isfinite(R.otfs.berMP(:)))
    V.pass=false;V.flags{end+1}='OTFS message-passing BER contains non-finite values.';
end
if isfield(R,'reference')
    if isfinite(R.reference.roundTripBitErrors) && R.reference.roundTripBitErrors>0
        V.pass=false;V.flags{end+1}='QAM map/demap round trip is not lossless.';
    end
    if isfinite(R.reference.constellationSetError) && R.reference.constellationSetError>1e-9
        V.pass=false;V.flags{end+1}='Hand constellation does not match the toolbox point set under unit average power.';
    end
end
if isfield(R.estimation,'kalmanAlpha') && ~isscalar(R.estimation.kalmanAlpha)
    V.pass=false;V.flags{end+1}='estimation.kalmanAlpha is not scalar; the built-in pi is shadowed by the pilot index vector.';
end
if any(~isfinite(R.estimation.crlb)) || any(R.estimation.crlb<0),V.pass=false;V.flags{end+1}='Invalid CRLB array.';end
iLS=find(strcmp(R.estimation.methods,'LS'),1); iLM=find(strcmp(R.estimation.methods,'LMMSE'),1);
if ~isempty(iLS) && ~isempty(iLM)
    V.lmmseVsLsWorstRatio=max(R.estimation.mse(iLM,:)./max(R.estimation.mse(iLS,:),eps));
end
required={'baseline','estimation','ici','equalizer','otfs','crosswaveform','otfsPilot'}; for ii=1:numel(required), if ~isfield(R,required{ii}), V.pass=false; V.flags{end+1}=['Missing required project output: ' required{ii}]; end; end
V.generated=datestr(now,30);
if V.pass, fprintf('[PASS] Scientific validation gate passed basic checks.\n'); else, fprintf('[WARN/FAIL] Scientific validation flags:\n');disp(V.flags(:));end
end

function T=researchXreportXsummary_all(file)
R=researchXreportXload_result(file);T=table;T.metric={'Nominal Doppler Hz';'fdTu';'Full/B8 complexity reduction';'Full/B8 memory reduction';'BEM order with minimum matrix NMSE';'OTFS integer-Doppler BER at highest SNR'};T.value=[R.cfg.fd;R.cfg.fdTuNominal;R.complexity.bandedReductionFullVsB8;R.complexity.fullMemoryBytes/R.complexity.B8MemoryBytes;R.ici.bemOrders(researchXreportXargmin(R.ici.bemFreqNMSE));R.otfs.berMMSE(find(abs(R.otfs.frac)<eps,1),end)];
end

function T=researchXreportXcv_report(file)
R=researchXreportXload_result(file); names={'Nominal Doppler Hz','fdTu','Full/B8 complexity reduction','Full/B8 memory reduction','BEM minimum matrix NMSE','Pilot-frequency Nyquist bound'}; vals=[R.cfg.fd;R.cfg.fdTuNominal;R.complexity.bandedReductionFullVsB8;R.complexity.fullMemoryBytes/R.complexity.B8MemoryBytes;min(R.ici.bemFreqNMSE);R.pilots.freqNyquistBound]; T=table(names.',vals,'VariableNames',{'Metric','Value'});writetable(T,fullfile(fileparts(file),'cv_metrics.csv'));disp(T);
end

function i=researchXreportXargmin(x),[~,i]=min(x);end



function T=cvXmetricsXreportXcv_metrics_report(file)
S=load(file); R=S.out; if isfield(S,'cfg'), C=S.cfg; elseif isfield(R,'cfg'), C=R.cfg; else, error('Result file does not contain cfg.'); end; rows={}; vals=[]; units={}; src={};
cvXmetricsXreportXadd('Maximum Doppler',C.fd,'Hz','cfg.fd');
cvXmetricsXreportXadd('Nominal normalized Doppler fD*Tu',C.fdTuNominal,'dimensionless','cfg.fdTuNominal');
cvXmetricsXreportXadd('Full-to-B8 MMSE-ICI analytical complexity ratio',R.complexity.bandedReductionFullVsB8,'x','complexity.bandedReductionFullVsB8');
cvXmetricsXreportXadd('Full-to-B8 ICI memory ratio',R.complexity.memoryReductionFullVsB8,'x','complexity.memoryReductionFullVsB8');
cvXmetricsXreportXadd('Minimum frequency-domain BEM NMSE',min(R.ici.bemFreqNMSE),'NMSE','ici.bemFreqNMSE');
cvXmetricsXreportXadd('BEM order at minimum frequency-domain NMSE',R.ici.bemOrders(cvXmetricsXreportXargmin(R.ici.bemFreqNMSE)),'order','ici.bemOrders');
cvXmetricsXreportXadd('Frequency pilot Nyquist limit',R.pilots.freqNyquistBound,'subcarriers','pilots.freqNyquistBound');
cvXmetricsXreportXadd('Time pilot Nyquist limit',R.pilots.timeNyquistBound,'OFDM symbols','pilots.timeNyquistBound');
cvXmetricsXreportXadd('Measured B8 runtime at lowest SNR',R.equalizer.runtimeMs(find(strcmp(R.equalizer.labels,'B8')),1),'ms/call','equalizer.runtimeMs');
cvXmetricsXreportXadd('Measured full-MMSE runtime at lowest SNR',R.equalizer.runtimeMs(find(strcmp(R.equalizer.labels,'Full-MMSE')),1),'ms/call','equalizer.runtimeMs');
idx=find(abs(R.otfs.frac)<1e-12,1);
if ~isempty(idx), cvXmetricsXreportXadd('Integer-Doppler OTFS MMSE BER at highest tested SNR',R.otfs.berMMSE(idx,end),'BER','otfs.berMMSE'); end
T=table(rows',vals,units',src','VariableNames',{'Metric','Value','Units','Source'});
outDir=fileparts(file); if isempty(outDir), outDir=pwd; end
writetable(T,fullfile(fileparts(file),'cv_metrics.csv'));
disp(T);
function cvXmetricsXreportXadd(a,b,c,d),rows{end+1}=a;vals(end+1,1)=b;units{end+1}=c;src{end+1}=d;end
end
function i=cvXmetricsXreportXargmin(x),[~,i]=min(x);end


function V=numericalXidentityXchecks(file,mode)
if nargin<2, mode='short'; end
S=load(file); R=S.out;
if isfield(S,'cfg'), cfg=S.cfg; elseif isfield(R,'cfg'), cfg=R.cfg; else, error('Result file contains no cfg.'); end
rng(cfg.randomSeed+99,'twister');
V.pass=true; V.checks=struct('name',{},'pass',{},'metric',{},'tolerance',{},'detail',{}); V.flags={};

N=cfg.otfsN; M=cfg.otfsM; X=(randn(N,M)+1j*randn(N,M))/sqrt(2);
tx=otfs_core('otfs_system','tx',X,cfg.otfsNcp); Xr=otfs_core('otfs_system','rx',tx,N,M,cfg.otfsNcp);
metricCheck('OTFS TX/RX identity',norm(X-Xr,'fro')/max(norm(X,'fro'),eps),1e-10,'relative reconstruction error');

xuse=reshape(tx,[],1);
if cfg.otfsNcp>0
    xu=zeros(N,M);
    for mm=1:M
        idx=(mm-1)*(N+cfg.otfsNcp)+(cfg.otfsNcp+(1:N));
        xu(:,mm)=tx(idx);
    end
else
    xu=reshape(tx,N,M);
end
metricCheck('OTFS useful transform is energy preserving',abs(norm(xu,'fro')/max(norm(X,'fro'),eps)-1),1e-10, ...
    'useful time-domain waveform energy vs delay-Doppler energy (CP excluded)');

paths(1)=struct('delayBin',2,'dopplerBin',3,'fracDoppler',0.25,'gain',1/sqrt(2));
paths(2)=struct('delayBin',5,'dopplerBin',-2,'fracDoppler',-0.125,'gain',1/sqrt(2));
y=otfs_core('otfs_system','dd_channel',X,paths,0); H=otfs_core('otfs_system','dd_matrix',paths,N,M);
metricCheck('DD operator matches dd_channel',norm(y(:)-H*X(:))/max(norm(y(:)),eps),1e-10,'relative operator error');

Xo=(randn(cfg.N,1)+1j*randn(cfg.N,1))/sqrt(2);
[txo,~]=physical_core('modem_ofdm','ofdmtx',Xo,cfg.Ncp);
[Xo2,~]=physical_core('modem_ofdm','ofdmdemux',txo,cfg.N,cfg.Ncp);
metricCheck('OFDM TX/RX identity',norm(Xo-Xo2)/max(norm(Xo),eps),1e-12,'relative reconstruction error');

w=(randn(cfg.N,4096)+1j*randn(cfg.N,4096))/sqrt(2);
Wf=fft(w,cfg.N,1);
metricCheck('Frequency-domain noise inflation equals N',abs(var(Wf(:))/max(var(w(:)),eps)/cfg.N-1),0.05, ...
    sprintf('measured %.1f vs N = %d',var(Wf(:))/max(var(w(:)),eps),cfg.N));

p=physical_core('channel_model','profile',cfg.profiles,cfg.activeProfile);
Rhh=physical_core('channel_model','cov',cfg.N,p.delay,p.powerLin,cfg.fs,cfg.delayModel,cfg.delayFilterHalfLength);
[Gc,tapC]=physical_core('channel_model','taps',p.delay,cfg.fs,cfg.delayModel,cfg.delayFilterHalfLength);
Wc=exp(-1j*2*pi*((0:cfg.N-1).')*(tapC(:).')/cfg.N);
hPath=(randn(p.numPaths,1)+1j*randn(p.numPaths,1))/sqrt(2).*sqrt(p.powerLin(:));
Hex=Wc*(Gc*hPath); Rsym=(Rhh+Rhh')/2; Rsym=Rsym+1e-10*trace(Rsym)/cfg.N*eye(cfg.N);
Hproj=Rsym*((Rsym+1e-9*eye(cfg.N))\Hex);
metricCheck('Covariance prior spans the simulated channel',mean(abs(Hproj-Hex).^2)/max(mean(abs(Hex).^2),eps),1e-4, ...
    'relative projection error of a noiseless channel');

if isfield(R,'resource')
    [ptest,~,Ctest]=mimo_resource_allocation('waterfill',R.resource.gains,R.resource.totalPower,R.resource.noiseVar);
    Cref=mimo_resource_allocation('capacity',R.resource.gains,ptest,R.resource.noiseVar);
    metricCheck('Water-filling capacity identity',abs(Ctest-Cref),1e-10,'Shannon water-filling formula');
    gap=min(R.resource.capacityWF-R.resource.capacityUniform);
    metricCheck('Water-filling never below uniform power',max(0,-gap),1e-10, ...
        'capacity gap below zero beyond numerical tolerance');
end

metricCheck('Pilot frequency bound formula',abs(R.pilots.freqNyquistBound-1/(2*max(p.delay)*cfg.deltaF)),1e-12,'1/(2 tau_max Delta-f)');
metricCheck('Pilot time bound formula',abs(R.pilots.timeNyquistBound-1/(2*cfg.fd*cfg.Tsym)),1e-12,'1/(2 f_D T_sym)');

if isfield(R,'estimation')
    metricCheck('CRLB finite and nonnegative',max([max(-R.estimation.crlb) max(~isfinite(R.estimation.crlb))]),0,'invalid CRLB magnitude');
    bestRatio=min(min(R.estimation.mse,[],1)./max(R.estimation.crlb(:).',eps));
    metricCheck('Bayesian CRLB is not violated beyond Monte-Carlo slack',0.7-bestRatio,0, ...
        sprintf('lowest MSE/CRLB ratio %.3f (must stay above 0.7)',bestRatio));
    Ntest=min(64,N); [pidx,~,xp]=estimation_receiver('channel_estimation','pilot_grid',Ntest,8,2);
    Rh=physical_core('channel_model','cov',Ntest,p.delay,p.powerLin,cfg.fs,cfg.delayModel,cfg.delayFilterHalfLength);
    Rh=(Rh+Rh')/2; Rh=Rh+1e-10*trace(Rh)/Ntest*eye(Ntest);
    Lchol=chol(Rh,'lower'); nv=0.25;
    rng(cfg.randomSeed+707,'twister');
    A_ls=2000; accumLS=0;
    for aa=1:A_ls
        h0=Lchol*((randn(Ntest,1)+1j*randn(Ntest,1))/sqrt(2));
        eta=(randn(numel(pidx),1)+1j*randn(numel(pidx),1))*sqrt(nv/2);
        z=h0(pidx)+eta./xp;
        accumLS=accumLS+mean(abs(z-h0(pidx)).^2);
    end
    mseLS=accumLS/A_ls; crls=mean(estimation_receiver('channel_estimation','crlb',xp,nv));
    metricCheck('LS pilot variance matches classical bound',abs(mseLS/max(crls,eps)-1),0.08, ...
        sprintf('static pilot ensemble ratio %.3f (A=%d)',mseLS/max(crls,eps),A_ls));
    Cb=estimation_receiver('channel_estimation','bayes_crlb',pidx,xp,nv,Rh,Ntest);
    A=1000; accum=0;
    for aa=1:A
        h0=Lchol*((randn(Ntest,1)+1j*randn(Ntest,1))/sqrt(2));
        eta=(randn(numel(pidx),1)+1j*randn(numel(pidx),1))*sqrt(nv/2);
        za=h0(pidx)+eta./xp;
        ha=estimation_receiver('channel_estimation','lmmse_pilot',za,pidx,Rh,mean(abs(xp).^2),nv);
        accum=accum+mean(abs(ha-h0).^2);
    end
    mseBayes=accum/A; meanCb=mean(Cb);
    metricCheck('Comb-pilot LMMSE matches Bayesian posterior MSE',abs(mseBayes/max(meanCb,eps)-1),0.15, ...
        sprintf('static Gaussian-model MSE/conditional-bound ratio %.3f',mseBayes/max(meanCb,eps)));
    if isfield(R.estimation,'msePilot')
        iLS=find(strcmp(R.estimation.methods,'LS'),1); iLP=find(strcmp(R.estimation.methods,'LMMSE-Pilot'),1);
        if ~isempty(iLS), R.estimation.validationPilotNote='Classical pilot bound validated separately under the diagonal static observation model; production Doppler sweep includes ICI and is not compared to this bound.'; end
        if ~isempty(iLP), R.estimation.validationBayesNote='Bayesian LMMSE equality validated separately under the exact linear-Gaussian pilot model; production Doppler sweep includes ICI.'; end
    end
end

if isfield(R,'ici') && isfield(R.ici,'theoryWorstCase')
    lowm=R.ici.fdTu<=0.02;
    rImp=mean(R.ici.sim(lowm)./max(R.ici.theoryWorstCase(lowm),eps));
    metricCheck('ICI lies between the Jakes and worst-case asymptotes',(rImp>=0.35)&&(rImp<=1.30),true, ...
        sprintf('implied E[nu^2]/fd^2 = %.3f (Jakes 0.5, worst case 1.0)',rImp));
end

if isfield(R,'otfsPilot')
    metricCheck('Embedded pilot detects its taps at high SNR',R.otfsPilot.detectRate(end)>=0.95,true, ...
        sprintf('detection rate %.2f at %g dB',R.otfsPilot.detectRate(end),R.otfsPilot.snrDb(end)));
    metricCheck('Embedded-pilot gain NMSE improves with SNR', ...
        R.otfsPilot.pathGainNMSE(end)/max(R.otfsPilot.pathGainNMSE(1),eps),0.25, ...
        'a flat curve would mean the estimator is limited by data leakage, not noise');
    if isfield(R.otfsPilot,'falseAlarmRate')
        metricCheck('Embedded-pilot false-alarm rate is low',max(R.otfsPilot.falseAlarmRate),0.10, ...
            'spurious taps per candidate delay');
    end
end

if isfield(R,'crosswaveform')
    cw=R.crosswaveform;
    metricCheck('Cross-waveform matched BER arrays are finite', ...
        all(isfinite([cw.berOFDM(:);cw.berOTFS(:)])),true,'matched PCG-MMSE curves');
    if isfield(cw,'receiverMatched')
        metricCheck('Cross-waveform receiver is matched',cw.receiverMatched,true, ...
            'headline curves must use the same detector family and settings');
    end
    if isfield(cw,'pcgIterations') && isfield(cw,'pcgTolerance')
        metricCheck('Matched PCG settings are explicit', ...
            isfinite(cw.pcgIterations)&&isfinite(cw.pcgTolerance),true, ...
            sprintf('iterations=%g, tolerance=%.3g',cw.pcgIterations,cw.pcgTolerance));
    end
    if isfield(cw,'bitsPerPoint')
        metricCheck('Cross-waveform Monte-Carlo budget is adequate for reported bounds',cw.bitsPerPoint>=1.5e5,true, ...
            sprintf('%g bits/point; zero-error 95%% upper bound %.3g',cw.bitsPerPoint,cw.zeroErrorUpperBound));
    end
    if isfield(cw,'ciOFDM') && isfield(cw,'ciOTFS')
        metricCheck('Cross-waveform confidence intervals are finite', ...
            all(isfinite([cw.ciOFDM.low(:);cw.ciOFDM.high(:);cw.ciOTFS.low(:);cw.ciOTFS.high(:)])),true,'Wilson 95% intervals');
    end
    if isfield(cw,'Nofdm') && isfield(cw,'Mofdm') && isfield(cw,'Ndd') && isfield(cw,'Mdd') && ...
            isfield(cw,'waveformDurationSamples')
        metricCheck('Cross-waveform information-symbol budget matches', ...
            cw.Nofdm*cw.Mofdm==cw.Ndd*cw.Mdd,true, ...
            sprintf('OFDM %d*%d = OTFS %d*%d',cw.Nofdm,cw.Mofdm,cw.Ndd,cw.Mdd));
        if isfield(cw,'cpOFDM') && isfield(cw,'cpOTFS')
            durO=cw.Mofdm*(cw.Nofdm+cw.cpOFDM); durT=cw.Mdd*(cw.Ndd+cw.cpOTFS);
            metricCheck('Cross-waveform duration matches',durO==durT,true, ...
                sprintf('OFDM %d samples vs OTFS %d samples',durO,durT));
        end
    end
    if isfield(cw,'diversityOFDM') && isfield(cw,'diversityOTFS')
        gd=isfinite(cw.diversityOFDM)&isfinite(cw.diversityOTFS);
        if any(gd)
            slopeGap=mean(cw.diversityOTFS(gd)-cw.diversityOFDM(gd));
            V.flags{end+1}=sprintf(['Matched-detector diversity slope difference (OTFS-OFDM) = %.3f; ' ...
                'descriptive only, not a pass/fail claim.'],slopeGap);
        end
    end
end

if isfield(R,'crosswaveform') && isfield(R.crosswaveform,'sparsity')
    dd=[R.crosswaveform.sparsity.ddDensity];
    if ~isempty(dd) && all(isfinite(dd))
        V.flags{end+1}=sprintf(['Observed DD density across the cross-waveform sweep: %.3f..%.3f; ' ...
            'this diagnoses the secondary message-passing receiver and does not invalidate the matched PCG result.'], ...
            min(dd),max(dd));
    end
end

if isfield(R,'impairments') && isfield(R.impairments,'zeroErrorUpperBound')
    fl=double(R.impairments.zeroErrorUpperBound);
    for nmC={'cpBer','phaseNoiseBer','impulsiveBer'}
        nmS=nmC{1};
        if isfield(R.impairments,nmS)
            v=double(R.impairments.(nmS)); v=v(isfinite(v));
            if numel(v)>=2
                spread=max(v)-min(v);
                metricCheck(sprintf('Impairment sweep %s resolves a change',nmS), spread>3*fl, true, ...
                    sprintf('range %.3g against %.3g resolution scale',spread,fl));
            end
        end
    end
end
if isfield(R,'mismatch') && isfield(R.mismatch,'penaltyDbAll')
    metricCheck('Covariance mismatch study shows a resolved penalty',max(abs(R.mismatch.penaltyDbAll(:)))>0.5,true, ...
        sprintf('largest penalty %.2f dB',max(abs(R.mismatch.penaltyDbAll(:)))));
end
if isfield(R,'estimation') && isfield(R.estimation,'mseDiagonal') && isfield(R.estimation,'crlbDiagonal')
    iLP=find(strcmp(cellstr(R.estimation.methods(:)),'LMMSE-Pilot'),1);
    if ~isempty(iLP)
        rr=R.estimation.mseDiagonal(iLP,:)./max(R.estimation.crlbDiagonal(:).',eps);
        metricCheck('LMMSE-Pilot attains its CRLB under the diagonal model',max(rr),1.6, ...
            sprintf('worst MSE/CRLB ratio %.3f',max(rr)));
        metricCheck('Diagonal-model MSE does not undercut its bound',0.7-min(rr),0, ...
            sprintf('lowest ratio %.3f',min(rr)));
    end
    if isfield(R.estimation,'iciPenaltyDb')
        metricCheck('Estimated ICI penalty is finite',all(isfinite(R.estimation.iciPenaltyDb(:))),true,'non-finite ICI penalty detected');
    end
end
if isfield(R,'mimo') && isfield(R.mimo,'berMMSEPerfectCSI')
    metricCheck('MIMO CSI-aging curves are finite',all(isfinite(R.mimo.berMMSE)) && all(isfinite(R.mimo.berMMSEPerfectCSI)) && all(isfinite(R.mimo.csiAgingPenaltyDb)),true, ...
        'non-finite CSI-aging diagnostic');
end

if isfield(R,'ici')
    q=R.ici.bemOrders; e=R.ici.bemFreqNMSE; [emin,iq]=min(e);
    metricCheck('BEM has finite optimum',~isempty(iq)&&isfinite(emin),true,'minimum matrix-NMSE exists');
    metricCheck('BEM order within configured sweep',q(iq)>=0 && q(iq)<=max(q),true,'selected Q inside the sweep');
    if isfield(R.ici,'bemMSE')
        worstRise=max([0 diff(R.ici.bemMSE)./max(R.ici.bemMSE(1:end-1),eps)]);
        metricCheck('BEM tap-fit error is monotone in order',worstRise,0.05, ...
            sprintf('largest relative increase %.3f between adjacent orders',worstRise));
    end
end

if isfield(R,'equalizer') && isfield(R.equalizer,'berHighDoppler')
    b=find(strcmp(R.equalizer.labels,'BEM-MMSE'),1); fM=find(strcmp(R.equalizer.labels,'Full-MMSE'),1);
    zf=find(strcmp(R.equalizer.labels,'ZF'),1); b16=find(strcmp(R.equalizer.labels,'B16'),1);
    floorBer=max(R.equalizer.zeroErrorUpperBound(:));
    metricCheck('BEM-MMSE present with finite BER',~isempty(b)&&all(isfinite(R.equalizer.ber(b,:))),true,'receiver ran');
    if ~isempty(fM) && ~isempty(b)
        sepHi=max(abs(R.equalizer.berHighDoppler(b,:)-R.equalizer.berHighDoppler(fM,:)));
        metricCheck('Receiver ladder resolved at high Doppler',sepHi>3*floorBer,true, ...
            sprintf('max BEM-MMSE vs Full-MMSE gap %.3g against a %.3g resolution floor',sepHi,floorBer));
    end
    if ~isempty(zf) && ~isempty(b16)
        metricCheck('Wider ICI band beats ZF at high Doppler',R.equalizer.berHighDoppler(b16,end)<R.equalizer.berHighDoppler(zf,end),true, ...
            'B16 must exploit ICI structure that ZF ignores');
    end
end

if isfield(R,'otfs')
    metricCheck('OTFS detector BER arrays finite', ...
        all(isfinite([R.otfs.berMF(:);R.otfs.berMMSE(:);R.otfs.berMP(:);R.otfs.berGS(:)])), ...
        true,'detector outputs are finite');
end

if isfield(R,'crosswaveform')
    metricCheck('Cross-waveform BER arrays finite',all(isfinite([R.crosswaveform.berOFDM(:);R.crosswaveform.berOTFS(:)])),true,'same-channel anchor');
    metricCheck('Cross-waveform Doppler grid',isequal(R.crosswaveform.fdTu,[0.01 0.05 0.10 0.20]),true,'requested fdTu grid');
    if isfield(R.crosswaveform,'subcarrierSpacingHz')
        metricCheck('Cross-waveform Doppler is self-consistent', ...
            max(abs(R.crosswaveform.fdHz-R.crosswaveform.fdTu*R.crosswaveform.subcarrierSpacingHz)),1e-6, ...
            'f_D T_u must use the physical OFDM useful-symbol spacing Delta-f = 1/T_u');
    end
end

if isfield(R,'mobility') && isfield(R.mobility,'jakesAcfRMSE')
    metricCheck('Generated Jakes ACF matches Clarke-Jakes',R.mobility.jakesAcfRMSE,0.12, ...
        sprintf('normalized ACF RMSE %.3g',R.mobility.jakesAcfRMSE));
end
if isfield(R,'crosswaveform')
    if isfield(R.crosswaveform,'bitsPerPoint')
        metricCheck('Cross-waveform bits per point support the claim',R.crosswaveform.bitsPerPoint>=1.5e5,true, ...
            sprintf('%g bits/point',R.crosswaveform.bitsPerPoint));
    end
    if isfield(R.crosswaveform,'confidenceLevel')
        metricCheck('Cross-waveform confidence level recorded',abs(R.crosswaveform.confidenceLevel-0.95)<1e-12,true,'95% one-sided zero-error bounds');
    end
end
V.generated=datestr(now,30); V.mode=mode;
nFail=sum(~[V.checks.pass]);
if V.pass
    fprintf('[PASS] Numerical identity gate: %d/%d checks passed.\n',numel(V.checks),numel(V.checks));
else
    fprintf('[FAIL] Numerical identity gate: %d of %d checks failed.\n',nFail,numel(V.checks));
    for ii=1:numel(V.checks)
        if ~V.checks(ii).pass, fprintf('        - %s (%s)\n',V.checks(ii).name,V.checks(ii).detail); end
    end
end

    function metricCheck(name,metric,tol,detail)
        if islogical(metric), ok=logical(metric); metricValue=double(metric);
        else, metricValue=metric; ok=isfinite(metricValue) && metricValue<=tol; end
        if islogical(tol), ok=logical(metric); tolValue=double(tol); else, tolValue=tol; end
        if ~ok, V.pass=false; V.flags{end+1}=sprintf('%s failed (%s)',name,detail); end
        k=numel(V.checks)+1;
        V.checks(k).name=name; V.checks(k).pass=ok; V.checks(k).metric=metricValue;
        V.checks(k).tolerance=tolValue; V.checks(k).detail=detail;
    end
end
