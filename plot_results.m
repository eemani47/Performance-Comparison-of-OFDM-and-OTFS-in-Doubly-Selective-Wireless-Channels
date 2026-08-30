function files = plot_results(resultFile, figureNumber)
if nargin < 1 || isempty(resultFile)
    rootDir = fileparts(mfilename('fullpath'));
    resultFile = fullfile(rootDir,'results','audit_wide_results.mat');
end
if ~isfile(resultFile)
    error('Result file not found: %s',resultFile);
end

rootDir = fileparts(mfilename('fullpath'));
R = loadResult(resultFile);
warnIfStale(R, resultFile);
figDir = fullfile(fileparts(resultFile),'figures');
if nargin < 2 || isempty(figureNumber)
    if exist(figDir,'dir'), rmdir(figDir,'s'); end
end
if ~exist(figDir,'dir'), mkdir(figDir); end

if nargin >= 2 && ~isempty(figureNumber)
    n = double(figureNumber);
    if ~isscalar(n) || n ~= floor(n) || n < 1 || n > 13
        error('Figure number must be an integer from 1 to 13.');
    end
    files = {makeFigure(R,figDir,n)};
else
    files = {};
    for n = 1:13
        fn = makeFigure(R,figDir,n);
        if ~isempty(fn), files{end+1} = fn; end
    end
end
fprintf('Generated %d project figures in %s\n',numel(files),figDir);
end

function warnIfStale(R, file)
codeRelease = '';
try
    cfgNow = physical_core('ofdm_config','AUDIT');
    if isfield(cfgNow,'release'), codeRelease = char(cfgNow.release); end
catch
    return;   % physical_core not on the path (read-only plotting use); skip the check
end
if isempty(codeRelease), return; end
dataRelease = '';
if isfield(R,'meta') && isfield(R.meta,'release'), dataRelease = char(R.meta.release);
elseif isfield(R,'cfg') && isfield(R.cfg,'release'), dataRelease = char(R.cfg.release);
end
if ~isempty(dataRelease) && ~strcmp(dataRelease, codeRelease)
    fprintf(2,['[STALE RESULT] %s was produced by release "%s" but this source tree is "%s".\n' ...
               '               The figures will render, but they show the OLDER science.\n' ...
               '               Re-run main(''AUDIT'',''wide'',''RESTART'') before quoting them.\n'], ...
        file, dataRelease, codeRelease);
end
end

function R = loadResult(file)
S = load(file);
if isfield(S,'out')
    R = S.out;
else
    error('Result MAT must contain variable "out".');
end
end

function file = makeFigure(R,d,n)
switch n
    case 1, file = fig01(R,d);
    case 2, file = fig02(R,d);
    case 3, file = fig03(R,d);
    case 4, file = fig04(R,d);
    case 5, file = fig05(R,d);
    case 6, file = fig06(R,d);
    case 7, file = fig07(R,d);
    case 8, file = fig08(R,d);
    case 9, file = fig09(R,d);
    case 10, file = fig10(R,d);
    case 11, file = fig11(R,d);
    case 12, file = fig12(R,d);
    case 13, file = fig13(R,d);
    otherwise, file = '';
end
end

function file = fig01(R,d)
f = newFigure('01 Baseline BER'); ax = axes('Parent',f); hold(ax,'on');
snr = vec(R.baseline.snrDb); theory = vec(R.baseline.theory);
meas = [R.baseline.berAwgn(:); R.baseline.berStatic(:); R.baseline.berDoppler(:)];
bnd  = boundSeries(R.baseline.zeroErrorUpperBound,numel(snr),1);
floorBer = max(min(bnd(bnd>0)), 1e-6);
if isempty(floorBer) || ~isfinite(floorBer), floorBer = 1e-6; end
theoryPlot = max(theory, floorBer);
mask = isfinite(theoryPlot) & theoryPlot > 0;
semilogy(ax,snr(mask),theoryPlot(mask),'k--','LineWidth',1.5,'DisplayName','QPSK theory');
plotBer(ax,snr,R.baseline.berAwgn,boundSeries(R.baseline.zeroErrorUpperBound,numel(snr),1),'o-','AWGN');
plotBer(ax,snr,R.baseline.berStatic,boundSeries(R.baseline.zeroErrorUpperBound,numel(snr),2),'s-','Static EVA');
plotBer(ax,snr,R.baseline.berDoppler,boundSeries(R.baseline.zeroErrorUpperBound,numel(snr),3),'^-','Doppler EVA');
set(ax,'YScale','log'); grid(ax,'on');
xlabel(ax,'E_b/N_0 (dB)'); ylabel(ax,'Bit-error rate (BER)');
title(ax,'Baseline OFDM BER: AWGN reference, static EVA, and Doppler EVA');
legend(ax,'Location','southwest');
setReasonableLogY(ax,[meas; floorBer]);
ylim(ax,[floorBer/3, 1]);
file=savePng(f,d,'01_baseline_ber');
end

function file = fig02(R,d)
f=newFigure('02 Channel Estimation');
methods=cellstr(R.estimation.methods(:)); snr=vec(R.estimation.snrDb); M=double(R.estimation.mse);
hasPilot = isfield(R.estimation,'msePilot') && ~isempty(R.estimation.msePilot);
if hasPilot, ax=subplot(1,2,1,'Parent',f); else, ax=subplot(1,1,1,'Parent',f); end
hold(ax,'on');
for k=1:numel(methods)
    semilogy(ax,snr,max(series2D(M,numel(snr),k,'estimation MSE'),realmin),'LineWidth',1.2,'DisplayName',methods{k});
end
if isfield(R.estimation,'crlb')
    semilogy(ax,snr,max(vec(R.estimation.crlb),realmin),'k--','LineWidth',1.6,'DisplayName','Bayesian posterior CRLB');
end
if isfield(R.estimation,'mseDiagonal')
    iLP=find(strcmp(cellstr(R.estimation.methods(:)),'LMMSE-Pilot'),1);
    if ~isempty(iLP)
        semilogy(ax,snr,max(series2D(R.estimation.mseDiagonal,numel(snr),iLP,'diagonal MSE'),realmin),':','LineWidth',1.5,'DisplayName','LMMSE-Pilot, ICI-free');
    end
end
set(ax,'YScale','log'); grid(ax,'on');
xlabel(ax,'E_b/N_0 (dB)'); ylabel(ax,'Channel MSE (all subcarriers)');
title(ax,'Estimation error vs the Bayesian bound'); legend(ax,'Location','southwest');
if hasPilot
    ax2=subplot(1,2,2,'Parent',f); hold(ax2,'on');
    MP=double(R.estimation.msePilot);
    for k=1:numel(methods)
        semilogy(ax2,snr,max(series2D(MP,numel(snr),k,'pilot MSE'),realmin),'LineWidth',1.2,'DisplayName',methods{k});
    end
    if isfield(R.estimation,'classicalPilotCRLB')
        semilogy(ax2,snr,max(vec(R.estimation.classicalPilotCRLB),realmin),'k:','LineWidth',1.6,'DisplayName','Classical per-pilot bound');
    end
    set(ax2,'YScale','log'); grid(ax2,'on');
    xlabel(ax2,'E_b/N_0 (dB)'); ylabel(ax2,'Channel MSE (pilot subcarriers)');
    title(ax2,'Pilot-subcarrier error vs the classical bound'); legend(ax2,'Location','southwest');
    sgtitle('Channel estimation against the bound that applies to each quantity');
else
    sgtitle('Channel estimation error versus SNR');
end
file=savePng(f,d,'02_channel_estimation');
end

function file = fig03(R,d)
f=newFigure('03 ICI Growth'); ax=axes('Parent',f); hold(ax,'on');
x=vec(R.ici.fdTu); sim=vec(R.ici.sim); theory=vec(R.ici.theory);
loglog(ax,x,max(0.5*theory,realmin),'k:','LineWidth',1.3,'DisplayName','Jakes asymptote');
loglog(ax,x,max(theory,realmin),'k--','LineWidth',1.5,'DisplayName','Worst-case asymptote');
loglog(ax,x,max(sim,realmin),'o-','LineWidth',1.2,'DisplayName','Simulation');
set(ax,'XScale','log','YScale','log'); grid(ax,'on');
xlabel(ax,'f_D T_u'); ylabel(ax,'ICI power / desired-carrier power');
title(ax,'ICI growth versus normalized Doppler');
legend(ax,'Location','northwest');
file=savePng(f,d,'03_ici_growth_bandwidth');
end

function file = fig04(R,d)
f=newFigure('04 BEM Order'); ax=axes('Parent',f); hold(ax,'on');
Q=vec(R.ici.bemOrders);
semilogy(ax,Q,max(vec(R.ici.bemFreqNMSE),realmin),'o-','LineWidth',1.2,'DisplayName','Frequency-domain matrix NMSE');
semilogy(ax,Q,max(vec(R.ici.bemMSE),realmin),'s--','LineWidth',1.2,'DisplayName','Tap-time NMSE');
set(ax,'YScale','log'); grid(ax,'on');
xlabel(ax,'CE-BEM order Q'); ylabel(ax,'NMSE');
title(ax,'CE-BEM order versus approximation error');
legend(ax,'Location','southwest');
file=savePng(f,d,'04_bem_order');
end

function file = fig05(R,d)
f=newFigure('05 Receiver Ladder'); ax=axes('Parent',f); hold(ax,'on');
labels=cellstr(R.equalizer.labels(:)); snr=vec(R.equalizer.snrDb); A=double(R.equalizer.berHighDoppler);
hi=1;
if isfield(R.equalizer,'highDopplerIndex'), hi=double(R.equalizer.highDopplerIndex); end
bpp=double(R.equalizer.bitsPerPoint); hi=min(max(hi,1),numel(bpp));
bound=3/max(1,bpp(hi));
if isfield(R.equalizer,'zeroErrorUpperBound') && ~isempty(R.equalizer.zeroErrorUpperBound)
    zb=double(R.equalizer.zeroErrorUpperBound); bound=zb(min(hi,numel(zb)));
end
for k=1:numel(labels)
    plotBer(ax,snr,series2D(A,numel(snr),k,'high-Doppler BER'),repmat(bound,numel(snr),1),'-',labels{k});
end
set(ax,'YScale','log'); grid(ax,'on');
xlabel(ax,'E_b/N_0 (dB)'); ylabel(ax,'BER');
title(ax,sprintf('Receiver comparison at high Doppler: f_D T_u = %.3g',R.equalizer.fdTuHigh));
legend(ax,'Location','southwest');
file=savePng(f,d,'05_receiver_ladder_high_doppler');
end

function file = fig06(R,d)
f=newFigure('06 Receiver Cost');
ax1=subplot(1,3,1,'Parent',f);
names={'LS','DFT-LS','LMMSE','Kalman','BEM','Full-ICI','B8'};
vals=[R.complexity.LS,R.complexity.DFT_LS,R.complexity.LMMSE,R.complexity.Kalman,R.complexity.BEM,R.complexity.MMSE_ICI_full,R.complexity.B8];
vals=double(vals(:));
assert(numel(vals)==numel(names),'Analytical cost: %d values for %d labels.',numel(vals),numel(names));
bar(ax1,1:numel(vals),vals); set(ax1,'YScale','log','XTick',1:numel(vals),'XTickLabel',names); xtickangle(ax1,35); grid(ax1,'on');
ylabel(ax1,'Analytical operation proxy'); title(ax1,'Analytical cost model');
ax2=subplot(1,3,2,'Parent',f); labels=cellstr(R.equalizer.labels(:)); rt=double(R.equalizer.runtimeMs);
med=collapseToLabels(rt,numel(labels));
bar(ax2,1:numel(labels),med); set(ax2,'XTick',1:numel(labels),'XTickLabel',labels); xtickangle(ax2,35); grid(ax2,'on');
ylabel(ax2,'Median runtime per call (ms)'); title(ax2,'Measured runtime across SNR');
ax3=subplot(1,3,3,'Parent',f); hold(ax3,'on');
if isfield(R.equalizer,'pcgRelResidual')
    snr=vec(R.equalizer.snrDb); P=double(R.equalizer.pcgRelResidual);
    grid_=vec(R.equalizer.fdTuGrid);
    for k=1:numel(grid_)
        semilogy(ax3,snr,max(series2D(P,numel(snr),k,'PCG residual'),realmin),'o-','LineWidth',1.2,'DisplayName',sprintf('f_D T_u = %.3g',grid_(k)));
    end
    if isfield(R.equalizer,'pcgTolerance')
        yline(ax3,double(R.equalizer.pcgTolerance),'k--','DisplayName','tolerance');
    end
end
grid(ax3,'on'); set(ax3,'YScale','log'); xlabel(ax3,'E_b/N_0 (dB)'); ylabel(ax3,'Relative residual'); title(ax3,'Truncated PCG-MMSE convergence'); legend(ax3,'Location','best');
sgtitle('Receiver cost and iterative-solver behaviour');
file=savePng(f,d,'06_receiver_cost');
end

function file = fig07(R,d)
f=newFigure('07 OTFS Detectors');
frac=vec(R.otfs.frac); snr=vec(R.otfs.snrDb); names={'MF','MMSE','Message passing','Gauss-Seidel'};
fields={'berMF','berMMSE','berMP','berGS'};
for k=1:numel(frac)
    ax=subplot(2,2,k,'Parent',f); hold(ax,'on');
    for q=1:numel(fields)
        y=series2D(R.otfs.(fields{q}),numel(snr),k,'OTFS detector BER');
        plotBer(ax,snr,y,repmat(double(R.otfs.zeroErrorUpperBound),numel(snr),1),'-',names{q});
    end
    set(ax,'YScale','log'); grid(ax,'on'); xlabel(ax,'E_b/N_0 (dB)'); ylabel(ax,'BER');
    title(ax,sprintf('Fractional Doppler = %.3g',frac(k))); legend(ax,'Location','southwest');
end
sgtitle('Synthetic sparse DD detector benchmark (32x32) — not the physical EVA comparison');
file=savePng(f,d,'07_otfs_detectors');
end

function file = fig08(R,d)
f=newFigure('08 OFDM vs OTFS'); fd=vec(R.crosswaveform.fdTu); snr=vec(R.crosswaveform.snrDb);
hasMP = isfield(R.crosswaveform,'berOTFS_MP') && ~isempty(R.crosswaveform.berOTFS_MP) && any(isfinite(R.crosswaveform.berOTFS_MP(:)));
for k=1:numel(fd)
    ax=subplot(2,2,k,'Parent',f); hold(ax,'on');
    b=double(R.crosswaveform.zeroErrorUpperBound);
    if numel(b)==1, b=repmat(b,numel(snr),1); else, b=boundSeries(b,numel(snr),1); end
    plotBer(ax,snr,series2D(R.crosswaveform.berOFDM,numel(snr),k,'OFDM BER'),b,'o-','OFDM PCG-MMSE');
    plotBer(ax,snr,series2D(R.crosswaveform.berOTFS,numel(snr),k,'OTFS BER'),b,'s-','OTFS PCG-MMSE');
    if hasMP
        plotBer(ax,snr,series2D(R.crosswaveform.berOTFS_MP,numel(snr),k,'OTFS MP BER'),b,'d--','OTFS message passing (secondary)');
    end
    set(ax,'YScale','log'); grid(ax,'on'); xlabel(ax,'E_b/N_0 (dB)'); ylabel(ax,'BER');
    title(ax,sprintf('f_D T_u = %.3g   matched PCG-MMSE, perfect CSI',fd(k)));
    yy=series2D(R.crosswaveform.berOTFS,numel(snr),k,'OTFS BER'); zz=series2D(R.crosswaveform.berOFDM,numel(snr),k,'OFDM BER');
    if any(yy<=0 | zz<=0), text(ax,0.02,0.04,'Zero errors: one-sided 95% upper bound','Units','normalized','FontSize',8); end
    legend(ax,'Location','southwest');
end
sgtitle('OFDM vs OTFS: matched truncated PCG-MMSE, equal bits and equal duration, perfect CSI');
file=savePng(f,d,'08_ofdm_vs_otfs');
end
function file = fig09(R,d)
f=newFigure('09 OTFS Pilot'); P=R.otfsPilot; snr=vec(P.snrDb);
ax1=subplot(1,2,1,'Parent',f); hold(ax1,'on');
semilogy(ax1,snr,max(vec(P.pathGainNMSE),realmin),'s-','LineWidth',1.2,'DisplayName','Estimated path gains');
if isfield(P,'NMSE') && isfield(P,'definition')
    semilogy(ax1,snr,max(vec(P.NMSE),realmin),'o-','LineWidth',1.2,'DisplayName','DD operator rebuilt from estimates');
end
set(ax1,'YScale','log'); grid(ax1,'on'); xlabel(ax1,'SNR (dB)'); ylabel(ax1,'NMSE');
dAll=[vec(P.pathGainNMSE)];
if isfield(P,'NMSE') && isfield(P,'definition'), dAll=[dAll; vec(P.NMSE)]; end
setReasonableLogY(ax1,dAll);
title(ax1,'Embedded-pilot estimation error'); legend(ax1,'Location','southwest');
ax2=subplot(1,2,2,'Parent',f); hold(ax2,'on');
plot(ax2,snr,vec(P.detectRate),'o-','LineWidth',1.2,'DisplayName','Tap detection rate');
if isfield(P,'falseAlarmRate')
    plot(ax2,snr,vec(P.falseAlarmRate),'s--','LineWidth',1.2,'DisplayName','False-alarm rate');
end
ylim(ax2,[-0.05 1.05]); grid(ax2,'on'); xlabel(ax2,'SNR (dB)'); ylabel(ax2,'Rate');
if isfield(P,'guardOverhead')
    title(ax2,sprintf('3\\sigma_n threshold detection (guard = %.0f%% of frame)',100*double(P.guardOverhead)));
else
    title(ax2,'Path-recovery rate');
end
legend(ax2,'Location','east');
sgtitle('OTFS embedded delay-Doppler pilot');
file=savePng(f,d,'09_otfs_pilot');
end

function file = fig10(R,d)
f=newFigure('10 Impairments');
ax1=subplot(1,3,1,'Parent',f); hold(ax1,'on'); plotBer(ax1,R.impairments.cp,R.impairments.cpBer,R.impairments.zeroErrorUpperBound,'o-','BER'); grid(ax1,'on'); set(ax1,'YScale','log'); xlabel(ax1,'CP length (samples)'); ylabel(ax1,'BER'); title(ax1,'CP-length stress (perfect CSI)');
ax2=subplot(1,3,2,'Parent',f); hold(ax2,'on'); plotBer(ax2,R.impairments.phaseNoiseStd,R.impairments.phaseNoiseBer,R.impairments.zeroErrorUpperBound,'s-','BER'); grid(ax2,'on'); set(ax2,'YScale','log'); xlabel(ax2,'Wiener phase increment \\sigma_\\phi (rad/sample)'); ylabel(ax2,'BER'); title(ax2,'Phase-noise sensitivity (perfect CSI)');
ax3=subplot(1,3,3,'Parent',f); hold(ax3,'on'); plotBer(ax3,R.impairments.impulsiveProb,R.impairments.impulsiveBer,R.impairments.zeroErrorUpperBound,'^-','BER'); grid(ax3,'on'); set(ax3,'YScale','log'); xlabel(ax3,'Impulse probability'); ylabel(ax3,'BER'); title(ax3,'Impulsive-noise sensitivity (perfect CSI)');
sgtitle(sprintf('Controlled impairment sensitivity at %g dB: perfect CSI, isolated effects',R.impairments.snrDb));
file=savePng(f,d,'10_impairments');
end

function file = fig11(R,d)
f=newFigure('11 Physical Channel Diagnostics');
ax1=subplot(2,2,1,'Parent',f); stem(ax1,R.mobility.pdpDelayNs,R.mobility.pdpPowerDb,'filled'); grid(ax1,'on'); xlabel(ax1,'Path delay (ns)'); ylabel(ax1,'Average path power (dB)'); title(ax1,'EVA power-delay profile');
ax2=subplot(2,2,2,'Parent',f); plot(ax2,R.mobility.fadingTimeMs,R.mobility.fadingEnvelope,'LineWidth',1.0); grid(ax2,'on'); xlabel(ax2,'Time (ms)'); ylabel(ax2,'|h_1(t)|'); title(ax2,sprintf('Clustered EVA fading envelope (f_D = %.0f Hz)',R.mobility.generatedFdHz));
ax3=subplot(2,2,3,'Parent',f); hold(ax3,'on');
semilogy(ax3,R.mobility.psdFrequency,max(R.mobility.psd,realmin),'LineWidth',1.0,'DisplayName','Clustered EVA realization');
if isfield(R.mobility,'jakesFrequency')
    semilogy(ax3,R.mobility.jakesFrequency,max(R.mobility.jakesEmpiricalPSD,realmin),'--','LineWidth',1.0,'DisplayName','Generated Jakes reference');
    semilogy(ax3,R.mobility.jakesFrequency,max(R.mobility.jakesTheoreticalPSD,realmin),':','LineWidth',1.2,'DisplayName','Clarke-Jakes theory');
end
if isfield(R,'cfg') && isfield(R.cfg,'fd'), span=3*double(R.cfg.fd); xlim(ax3,[-span span]); end
grid(ax3,'on'); xlabel(ax3,'Doppler frequency (Hz)'); ylabel(ax3,'PSD/Hz'); title(ax3,sprintf('Long-run Doppler statistics (%.1f s diagnostic record)',R.mobility.durationSec)); legend(ax3,'Location','best');
ax4=subplot(2,2,4,'Parent',f); hold(ax4,'on');
if isfield(R.mobility,'jakesAcfLags')
    fsJ=R.mobility.jakesSampleRateHz; tms=R.mobility.jakesAcfLags/fsJ*1e3; plot(ax4,tms,real(R.mobility.jakesAcf),'LineWidth',1.0,'DisplayName','Generated Jakes R_h(\\tau)'); plot(ax4,tms,real(R.mobility.jakesAcfTheory),'--','LineWidth',1.0,'DisplayName','J_0(2\\pi f_D\\tau)');
end
grid(ax4,'on'); xlabel(ax4,'Lag (ms)'); ylabel(ax4,'Normalized ACF (real)'); title(ax4,sprintf('Jakes ACF reference (RMSE %.3g)',R.mobility.jakesAcfRMSE)); legend(ax4,'Location','best');
sgtitle('Physical doubly-dispersive channel diagnostics — Jakes reference is separate from EVA model'); file=savePng(f,d,'11_physical_channel_diagnostics');
end
function file = fig12(R,d)
file='';
if ~isfield(R,'mismatch') || isempty(R.mismatch) || ~isstruct(R.mismatch), return; end
Mm=R.mismatch; f=newFigure('12 Covariance Mismatch'); ax=axes('Parent',f); hold(ax,'on');
snr=vec(Mm.snrs);
if isfield(Mm,'penaltyDbAll') && isfield(Mm,'priorNames')
    P=double(Mm.penaltyDbAll); nm=cellstr(Mm.priorNames(:));
    for q=1:numel(nm)
        plot(ax,snr,series2D(P,numel(snr),q,'mismatch penalty'),'o-','LineWidth',1.3,'DisplayName',nm{q});
    end
else
    plot(ax,snr,vec(Mm.penaltyDb),'o-','LineWidth',1.3,'DisplayName','Mismatched prior');
end
yline(ax,0,'k:','DisplayName','matched prior');
grid(ax,'on'); xlabel(ax,'E_b/N_0 (dB)'); ylabel(ax,'LMMSE MSE penalty (dB)');
title(ax,'Analytical MSE penalty of a mismatched channel-covariance prior');
legend(ax,'Location','best');
file=savePng(f,d,'12_covariance_mismatch');
end

function file = fig13(R,d)
file='';
if ~isfield(R,'mimo') || isempty(R.mimo) || ~isstruct(R.mimo), return; end
f=newFigure('13 MIMO-OFDM'); ax=axes('Parent',f); hold(ax,'on');
snr=vec(R.mimo.snrDb);
plotBer(ax,snr,vec(R.mimo.berZF),0,'o-','ZF');
plotBer(ax,snr,vec(R.mimo.berMMSE),0,'s-','MMSE (pilot-aided, aged CSI)');
if isfield(R.mimo,'berMMSEPerfectCSI'), plotBer(ax,snr,vec(R.mimo.berMMSEPerfectCSI),0,'d--','MMSE (perfect CSI)'); end
set(ax,'YScale','log'); grid(ax,'on'); xlabel(ax,'E_b/N_0 (dB)'); ylabel(ax,'BER');
title(ax,'2x2 MIMO-OFDM, Zadoff-Chu training, one-symbol-aged CSI');
legend(ax,'Location','southwest');
file=savePng(f,d,'13_mimo_ofdm');
end

function f=newFigure(name)
f=figure('Name',name,'NumberTitle','off','Color','w', ...
         'MenuBar','figure','ToolBar','auto','Visible','on');
persistent nOpen
if isempty(nOpen), nOpen=0; end
nOpen=mod(nOpen,8);
set(f,'Units','pixels','Position',[80+30*nOpen, 90+26*nOpen, 1000, 640]);
nOpen=nOpen+1;
end

function file=savePng(f,d,name)
file=fullfile(d,name);
exportgraphics(f,[file '.png'],'Resolution',300);
end

function plotBer(ax,x,y,bound,style,label)
x=vec(x); y=vec(y); bound=vec(bound);
if numel(x)~=numel(y), error('%s: x/y lengths differ (%d/%d).',label,numel(x),numel(y)); end
if isempty(bound), bound=zeros(numel(y),1); end
if numel(bound)==1, bound=repmat(bound,numel(y),1); end
if numel(bound)~=numel(y), error('%s: BER bound length %d does not match %d samples.',label,numel(bound),numel(y)); end
resolved = isfinite(y) & y>0;
censored = isfinite(y) & y<=0;
floorVal = bound;
floorVal(~isfinite(floorVal) | floorVal<=0) = NaN;
if all(isnan(floorVal))
    fb = min(y(resolved));
    if isempty(fb) || ~isfinite(fb), fb = 1e-6; end
    floorVal(:) = fb/3;
end
yPlot = y;
yPlot(censored) = floorVal(censored);
draw = isfinite(yPlot) & yPlot>0;
if any(draw)
    semilogy(ax,x(draw),yPlot(draw),style,'LineWidth',1.1,'DisplayName',label);
else
    semilogy(ax,nan,nan,style,'LineWidth',1.1,'DisplayName',label);
end
mark = censored & isfinite(floorVal);
if any(mark)
    semilogy(ax,x(mark),floorVal(mark),'o','MarkerSize',9, ...
        'MarkerFaceColor','none','LineStyle','none','HandleVisibility','off');
end
end

function v=collapseToLabels(A,nLabels)
A=double(A);
if isvector(A)
    v=A(:);
elseif size(A,1)==nLabels
    v=median(A,2,'omitnan');
elseif size(A,2)==nLabels
    v=median(A,1,'omitnan').';
else
    error('Cannot orient array of size %s to %d labels.',mat2str(size(A)),nLabels);
end
v=v(:);
if numel(v)~=nLabels
    error('Collapsed vector has %d entries for %d labels.',numel(v),nLabels);
end
end

function y=series2D(A,nSamples,index,what)
A=double(A);
if isvector(A)
    y=A(:); if numel(y)~=nSamples, error('%s: vector length mismatch.',what); end; return;
end
if size(A,1)==nSamples
    if index>size(A,2), error('%s: series index out of range.',what); end
    y=A(:,index);
elseif size(A,2)==nSamples
    if index>size(A,1), error('%s: series index out of range.',what); end
    y=A(index,:).';
else
    error('%s: cannot orient array of size %s to %d samples.',what,mat2str(size(A)),nSamples);
end
y=y(:);
end

function b=boundSeries(B,nSamples,index)
B=double(B);
if isscalar(B), b=repmat(B,nSamples,1); return; end
if isvector(B)
    b=B(:); if numel(b)==nSamples, return; end
end
if size(B,1)==nSamples
    b=B(:,min(index,size(B,2))); return;
end
if size(B,2)==nSamples
    b=B(min(index,size(B,1)),:).'; return;
end
error('Cannot orient bound matrix %s to %d samples.',mat2str(size(B)),nSamples);
end

function x=vec(x)
x=double(x(:));
end

function setReasonableLogY(ax,data)
pos=data(isfinite(data)&data>0);
if isempty(pos), return; end
lo=10^(floor(log10(min(pos)))-1); hi=10^(ceil(log10(max(pos)))+1);
maxDecades=8;
if log10(hi/lo)>maxDecades, lo=hi/10^maxDecades; end
yLim=[max(lo,realmin) hi];
if yLim(1)>=yLim(2), yLim=[max(min(pos)/10,realmin),max(pos)*10]; end
ylim(ax,yLim);
end
