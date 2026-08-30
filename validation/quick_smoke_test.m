function quick_smoke_test

cfg=physical_core('ofdm_config','SMOKE');
physical_core('channel_model','delay_model',cfg.delayModel,cfg.delayFilterHalfLength);
physical_core('validate_config',cfg);

for M=[4 16 64]
    k=log2(M);
    allBits=reshape(dec2bin(0:M-1,k).'=='1',[],1);
    [allSym,~]=physical_core('modem_ofdm','qammap',allBits,M);
    assert(abs(mean(abs(allSym).^2)-1)<1e-12, ...
        'QAM constellation is not unit average power for M=%d.',M);

    b=randi([0 1],cfg.N*k,1);
    [sm,~]=physical_core('modem_ofdm','qammap',b,M);
    assert(isequal(logical(physical_core('modem_ofdm','qamdemap',sm,M)),logical(b)), ...
        'Gray QAM map/demap round trip failed for M=%d.',M);
end
bits=randi([0 1],cfg.N*cfg.bitsPerSym,1);
[X,~]=physical_core('modem_ofdm','qammap',bits,cfg.M);
[tx,cp]=physical_core('modem_ofdm','ofdmtx',X,cfg.Ncp);
assert(numel(tx)==cfg.N+cfg.Ncp && numel(cp)==cfg.Ncp);
[X2,~]=physical_core('modem_ofdm','ofdmdemux',tx,cfg.N,cfg.Ncp);
assert(norm(X2-X)<1e-10);

p=physical_core('channel_model','profile',cfg.profiles,cfg.activeProfile);
[Gf,tapF]=physical_core('channel_model','taps',p.delay,cfg.fs,'fractional',cfg.delayFilterHalfLength);
[Gr,tapR]=physical_core('channel_model','taps',p.delay,cfg.fs,'rounded');
assert(numel(tapF)>=numel(tapR),'Fractional model must not have fewer taps than rounding.');
assert(all(abs(sum(Gf.^2,1)-1)<1e-6),'Delay filters must have unit l2 norm so the PDP power is preserved.');
assert(max(tapF)<=cfg.Ncp,'Resolved tap span exceeds the cyclic prefix.');

pSm=physical_core('channel_model','profile',cfg.profiles,cfg.activeProfile);
RhhChk=physical_core('channel_model','cov',cfg.N,pSm.delay,pSm.powerLin,cfg.fs);
[Gc,tapC]=physical_core('channel_model','taps',pSm.delay,cfg.fs);
Wc=exp(-1j*2*pi*((0:cfg.N-1).')*(tapC(:).')/cfg.N);
rsChk=RandStream('twister','Seed',12345);
hPath=(randn(rsChk,pSm.numPaths,1)+1j*randn(rsChk,pSm.numPaths,1))/sqrt(2).*sqrt(pSm.powerLin(:));
Hexact=Wc*(Gc*hPath);
Rsym=(RhhChk+RhhChk')/2; Rsym=Rsym+1e-10*trace(Rsym)/cfg.N*eye(cfg.N);
Hproj=Rsym*((Rsym+1e-9*eye(cfg.N))\Hexact);
projErr=mean(abs(Hproj-Hexact).^2)/mean(abs(Hexact).^2);
assert(projErr<1e-4, ...
    ['Channel-covariance prior does not span the simulated channel (relative projection error %.3g). ' ...
     'Rebuild cov on the resolved tap grid.'],projErr);

zc=researchXexperimentsXzadoffChuProbe(cfg.N);
assert(max(abs(abs(zc)-1))<1e-9,'Zadoff-Chu pilot is not constant modulus in frequency.');
tzc=ifft(zc);
zcRel=max(abs(abs(tzc)/sqrt(mean(abs(tzc).^2))-1));
assert(zcRel<1e-9,'Zadoff-Chu training sequence is not constant modulus in the time domain.');

snrAwgn=4; nAwgnFrames=100; errAwgn=0; bitAwgn=0; rsAwgn=RandStream('twister','Seed',314159);
for a=1:nAwgnFrames
    bA=randi(rsAwgn,[0 1],cfg.N*cfg.bitsPerSym,1);
    [xA,~]=physical_core('modem_ofdm','qammap',bA,cfg.M);
    [tA,~]=physical_core('modem_ofdm','ofdmtx',xA,cfg.Ncp);
    nvA=1/(cfg.N*cfg.bitsPerSym*10^(snrAwgn/10));
    yA=tA+sqrt(nvA/2)*(randn(rsAwgn,size(tA))+1j*randn(rsAwgn,size(tA)));
    XA=physical_core('modem_ofdm','ofdmdemux',yA,cfg.N,cfg.Ncp);
    bAh=physical_core('modem_ofdm','qamdemap',XA,cfg.M);
    errAwgn=errAwgn+sum(bAh~=bA); bitAwgn=bitAwgn+numel(bA);
end
berAwgn=errAwgn/max(bitAwgn,1); theoryAwgn=physical_core('modem_ofdm','qpsk_theory',snrAwgn);
assert(abs(berAwgn-theoryAwgn)<0.006, ...
    'AWGN QPSK regression is %.4f vs theory %.4f at %g dB; check Eb/N0/noise scaling.', ...
    berAwgn,theoryAwgn,snrAwgn);

wTest=(randn(cfg.N,2048)+1j*randn(cfg.N,2048))/sqrt(2);
inflation=var(reshape(fft(wTest,cfg.N,1),[],1))/var(wTest(:));
assert(abs(inflation/cfg.N-1)<0.08, ...
    'FFT noise inflation measured %.1f, expected N=%d; the noiseVarFD convention is wrong.',inflation,cfg.N);

pB=physical_core('channel_model','profile',cfg.profiles,cfg.activeProfile);
RhhB=physical_core('channel_model','cov',cfg.N,pB.delay,pB.powerLin,cfg.fs,cfg.delayModel,cfg.delayFilterHalfLength);
[pIdxB,~,pvB]=estimation_receiver('channel_estimation','pilot_grid',cfg.N,cfg.pilotSpacing(2),cfg.pilotValue);
[GB,tapB]=physical_core('channel_model','taps',pB.delay,cfg.fs,cfg.delayModel,cfg.delayFilterHalfLength);
WB=exp(-1j*2*pi*((0:cfg.N-1).')*(tapB(:).')/cfg.N);
sigW=1e-2; pilotPow=abs(cfg.pilotValue)^2;
rsB=RandStream('twister','Seed',24680); accB=0; nTrial=40;
for tB=1:nTrial
    hB=(randn(rsB,pB.numPaths,1)+1j*randn(rsB,pB.numPaths,1))/sqrt(2).*sqrt(pB.powerLin(:));
    Hb=WB*(GB*hB);
    zB=Hb(pIdxB)+sqrt(sigW/pilotPow/2)*(randn(rsB,numel(pIdxB),1)+1j*randn(rsB,numel(pIdxB),1));
    HhatB=estimation_receiver('channel_estimation','lmmse_pilot',zB,pIdxB,RhhB,pilotPow,sigW);
    accB=accB+mean(abs(HhatB-Hb).^2);
end
mseB=accB/nTrial;
crlbB=mean(estimation_receiver('channel_estimation','bayes_crlb',pIdxB,pvB,sigW,RhhB,cfg.N));
assert(mseB<=2.0*crlbB, ...
    'Comb-pilot LMMSE MSE %.3e exceeds twice the Bayesian CRLB %.3e; prior, noise domain or estimator form is wrong.',mseB,crlbB);

Rhh=physical_core('channel_model','cov',cfg.N,p.delay,p.powerLin,cfg.fs);
assert(norm(Rhh-Rhh','fro')<1e-9);
[h,~]=physical_core('channel_model',cfg.channelModel,cfg.N+cfg.Ncp,cfg.fd,cfg.fs,p.numPaths,cfg.jakesOsc,p.powerLin,cfg.jakesSeed,cfg.ricianKDb,cfg.raysPerCluster,cfg.angularSpreadDeg);
H=physical_core('channel_model','matrix',h,p.delay,cfg.N,cfg.Ncp,cfg.fs);
assert(all(size(H)==[cfg.N cfg.N]));

[pilotIdx,~,~]=estimation_receiver('channel_estimation','pilot_grid',cfg.N,4,cfg.pilotValue);
alpha=besselj(0,2*pi*cfg.fd*cfg.Tsym);
assert(isscalar(alpha),'Jakes correlation coefficient must be scalar.');
assert(abs(alpha-besselj(0,2*pi*cfg.fd*cfg.Tsym))<1e-12);
Q=(1-abs(alpha)^2)*Rhh;
[Hk,Pk]=estimation_receiver('channel_estimation','kalman',nan(cfg.N,1),diag(H),Rhh,alpha,Q,1e-3);
assert(numel(Hk)==cfg.N && all(size(Pk)==[cfg.N cfg.N]));

[HB,~,nmse]=estimation_receiver('channel_estimation','bem',h,2);
assert(isequal(size(HB),size(h)) && all(isfinite(nmse(:))));

[pD,pICI,ratio]=estimation_receiver('ici_model','metrics',H);
assert(all(isfinite([pD pICI ratio])));
Dg=diag(diag(H)); Og=H-Dg;
assert(abs(pICI-sum(abs(Og(:)).^2)/cfg.N)<1e-12,'ICI power must be per-subcarrier, not per matrix entry.');
assert(abs(pD-sum(abs(diag(Dg)).^2)/cfg.N)<1e-12);
[HBmat,~,~]=estimation_receiver('ici_model','bem_matrix',h,p.delay,cfg.N,cfg.Ncp,cfg.fs,2);
assert(all(size(HBmat)==[cfg.N cfg.N]));

bitsDD=randi([0 1],cfg.otfsN*cfg.otfsM*cfg.bitsPerSym,1);
[sDD,~]=physical_core('modem_ofdm','qammap',bitsDD,4); Xdd=reshape(sDD,cfg.otfsN,cfg.otfsM);
[txOTFS,~]=otfs_core('otfs_system','tx',Xdd,cfg.otfsNcp);
Xdd2=otfs_core('otfs_system','rx',txOTFS,cfg.otfsN,cfg.otfsM,cfg.otfsNcp);
assert(norm(Xdd2(:)-Xdd(:))/max(norm(Xdd(:)),eps)<1e-10);

paths(1)=struct('delayBin',1,'dopplerBin',1,'fracDoppler',0,'gain',1);
Ydd=otfs_core('otfs_system','dd_channel',Xdd,paths,0);
Hdd=otfs_core('otfs_system','dd_matrix',paths,cfg.otfsN,cfg.otfsM);
assert(norm(Hdd*Xdd(:)-Ydd(:))/max(norm(Ydd(:)),eps)<1e-10);

xmp=otfs_core('otfs_detector','mp',Ydd(:),Hdd,1e-8,10);
assert(sum(physical_core('modem_ofdm','qamdemap',xmp,4)~=bitsDD)==0, ...
    'Message passing failed on a noiseless single-path DD channel.');

C=analysis_tools('complexity_analysis',cfg.N,cfg.iciBands,[cfg.otfsN cfg.otfsM],4,cfg.otfsIterations);
assert(C.MMSE_ICI_full>C.LMMSE && C.LMMSE>C.LS,'Complexity hierarchy is inverted.');

ref=analysis_tools('reference_validation');
assert(ref.roundTripBitErrors==0,'QAM round trip is not lossless.');
if ref.qammodAvailable
    assert(ref.constellationSetError<1e-9,'Hand constellation does not match the toolbox point set.');
end

fprintf('[PASS] V8.5 scientific-correction smoke test: Gray modem, delay resolution, channel, vector Kalman, BEM,\n');
fprintf('       per-subcarrier ICI, covariance basis, noise-domain convention,\n');
fprintf('       comb-pilot LMMSE vs Bayesian CRLB, constant-modulus training,\n');
fprintf('       OTFS waveform/DD operator, AWGN reference, message passing, complexity.\n');
end

function z=researchXexperimentsXzadoffChuProbe(N,root)
if nargin<2 || isempty(root), root=1; end
n=(0:N-1).';
if mod(N,2)==0, z=exp(-1j*pi*root*n.^2/N); else, z=exp(-1j*pi*root*n.*(n+1)/N); end
end
