function out = main(mode, numerology, runControl)
if nargin < 1 || isempty(mode)
    mode = 'PLOTS';
end
mode = upper(char(mode));

rootDir = fileparts(mfilename('fullpath'));
if nargin >= 2 && ~isempty(numerology)
    numerology = lower(char(numerology));
else
    numerology = 'wide';
end

if strcmp(mode, 'PLOTS')
    resultFile = fullfile(rootDir, 'results', sprintf('audit_%s_results.mat', numerology));
    if ~isfile(resultFile)
        error('Saved result not found: %s', resultFile);
    end
    if nargin >= 3 && ~isempty(runControl) && isnumeric(runControl)
        out = plot_results(resultFile, runControl);
    else
        out = plot_results(resultFile);
    end
    return;
end

if nargin < 3 || isempty(runControl)
    runControl = 'RESUME';
end

addpath(rootDir);
addpath(genpath(fullfile(rootDir, 'src')));
addpath(genpath(fullfile(rootDir, 'experiments')));
addpath(genpath(fullfile(rootDir, 'validation')));

if strcmp(mode, 'SMOKE')
    out = timing_probe(numerology, 'AUDIT');
    return;
end
if strcmp(mode, 'CHECKS')
    quick_smoke_test;
    out = [];
    return;
end
cfg = physical_core('ofdm_config', mode, numerology);
resultsDir = fullfile(rootDir, 'results');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

if strcmpi(runControl, 'RESTART')
    researchX_clean_results(resultsDir, numerology, mode);
end

physical_core('channel_model', 'delay_model', cfg.delayModel, cfg.delayFilterHalfLength);
physical_core('validate_config', cfg);

fprintf('\n############################################################\n');
fprintf('# OFDM / OTFS DOUBLY-DISPERSIVE RESEARCH PLATFORM\n');
fprintf('# Mode: %s | numerology: %s | release %s\n', mode, cfg.numerology, cfg.release);
fprintf('############################################################\n');



out = research_suite('research_experiments_resumable', cfg, mode, runControl);
out.meta.mode = mode;
out.meta.timestamp = datestr(now, 30);
out.meta.release = cfg.release;
out.meta.completed = true;
out.cfg = cfg;

fname = fullfile(resultsDir, sprintf('%s_%s_results.mat', lower(mode), lower(cfg.numerology)));
researchX_atomic_save(fname, 'out', 'cfg');
fprintf('\nFinal results saved to %s\n', fname);

V1 = struct('pass', false, 'flags', {{'Scientific gate did not execute.'}});
V2 = struct('pass', false, 'flags', {{'Numerical gate did not execute.'}});
try
    V1 = analysis_tools('research_report', 'validate', fname);
catch ME
    V1.pass = false;
    V1.flags = {sprintf('Scientific gate threw %s: %s', ME.identifier, ME.message)};
    fprintf('[VALIDATION ERROR] %s\n', ME.message);
end
try
    V2 = analysis_tools('numerical_identity_checks', fname, mode);
catch ME
    V2.pass = false;
    V2.flags = {sprintf('Numerical gate threw %s: %s', ME.identifier, ME.message)};
    fprintf('[VALIDATION ERROR] %s\n', ME.message);
end
out.validation = V1;
out.validation.numerical = V2;
out.meta.validationPass = logical(V1.pass && V2.pass);
out.meta.projectChecksPass = logical(V1.pass && V2.pass);
researchX_atomic_save(fname, 'out', 'cfg');
researchX_atomic_save(fullfile(resultsDir, 'validation.mat'), 'V1', 'V2');

if V1.pass && V2.pass
    fprintf('\n[PASS] Result passed both the scientific and the numerical gate.\n');
    try
        researchX_export_claim_summary(fname,out,resultsDir);
    catch ME
        fprintf('[CLAIM REPORT WARNING] %s\n',ME.message);
    end
else
    fprintf('\n[WARN] Validation did not fully pass. Results are saved but NOT certified.\n');
    if ~V1.pass && isfield(V1, 'flags') && ~isempty(V1.flags)
        fprintf('       Scientific gate:\n');
        for ii = 1:numel(V1.flags), fprintf('         - %s\n', V1.flags{ii}); end
    end
    if ~V2.pass
        if isfield(V2, 'flags') && ~isempty(V2.flags)
            fprintf('       Numerical gate:\n');
            for ii = 1:numel(V2.flags), fprintf('         - %s\n', V2.flags{ii}); end
        end
        if isfield(V2, 'checks')
            for ii = 1:numel(V2.checks)
                if ~V2.checks(ii).pass
                    fprintf('         - FAILED CHECK: %s (%s)\n', V2.checks(ii).name, V2.checks(ii).detail);
                end
            end
        end
    end
    fprintf('       Do not quote figures or metrics from an uncertified run.\n');
end

if ~strcmp(mode, 'MASSIVE')
    try
        plot_results(fname);
    catch ME
        fprintf('[PLOT ERROR] %s\n', ME.message);
    end
end
end

function researchX_export_claim_summary(fname,out,resultsDir)
if ~isfield(out,'crosswaveform') || ~isfield(out.crosswaveform,'snrDb')
    return;
end
cw=out.crosswaveform;
rows={};
for fi=1:numel(cw.fdTu)
    for si=1:numel(cw.snrDb)
        rows(end+1,:)={cw.fdTu(fi),cw.fdHz(fi),cw.snrDb(si),cw.errorsOFDM(fi,si),cw.errorsOTFS(fi,si),cw.bitsPerPoint,...
            cw.berOFDM(fi,si),cw.berOTFS(fi,si),cw.ciOFDM.low(fi,si),cw.ciOFDM.high(fi,si),cw.ciOTFS.low(fi,si),cw.ciOTFS.high(fi,si),...
            cw.pairOOnly(fi,si),cw.pairTOnly(fi,si),cw.mcnemarPExact(fi,si),cw.zeroErrorUpperBound};
    end
end
T=cell2table(rows,'VariableNames',{'fdTu','fdHz_Hz','EbN0_dB','errorsOFDM','errorsOTFS','bitsPerPoint','berOFDM','berOTFS','ofdmCI95Low','ofdmCI95High','otfsCI95Low','otfsCI95High','pairedOFDMOnly','pairedOTFSOnly','mcnemarPExact','zeroErrorUpperBound95'});
writetable(T,fullfile(resultsDir,'claim_crosswaveform_metrics.csv'));
fid=fopen(fullfile(resultsDir,'claimability_summary.txt'),'w');
if fid<0
    error('Cannot create claimability_summary.txt');
end
c=onCleanup(@() fclose(fid));
fprintf(fid,'Certified claimability summary\n');
fprintf(fid,'Result file: %s\n',fname);
fprintf(fid,'Release: %s\n',out.meta.release);
fprintf(fid,'Scope: matched truncated PCG-MMSE, perfect CSI, equal information-bit budget, equal waveform duration, paired information bits.\n');
fprintf(fid,'Zero-error observations are reported as one-sided 95%% upper bounds, not measured BER=0.\n');
if isfield(cw,'primaryEndpoint')
    pe=cw.primaryEndpoint;
    fprintf(fid,'Primary endpoint: f_D T_u=%.2f, E_b/N_0=%g dB.\n',pe.fdTu,pe.snrDb);
    fprintf(fid,'OFDM errors: %d / %d; BER %.6g; 95%% Wilson CI [%.6g, %.6g].\n',pe.errorsOFDM,pe.bits,pe.berOFDM,pe.ciOFDM(1),pe.ciOFDM(2));
    fprintf(fid,'OTFS errors: %d / %d; BER %.6g; 95%% Wilson CI [%.6g, %.6g].\n',pe.errorsOTFS,pe.bits,pe.berOTFS,pe.ciOTFS(1),pe.ciOTFS(2));
    fprintf(fid,'OTFS zero-error 95%% upper bound: %.6g.\n',pe.zeroErrorUpperBound);
    fprintf(fid,'Exact paired McNemar p-value: %.6g (diagnostic, not a preregistered hypothesis test).\n',pe.pMcNemarExact);
    fprintf(fid,'Discordant pairs: OFDM-only errors %d; OTFS-only errors %d.\n',pe.pairOOnly,pe.pairTOnly);
end
fprintf(fid,'No diversity-order claim is made from the matched-detector slopes.\n');
fprintf(fid,'Figure 10 is a controlled impairment sensitivity experiment, not a universal robustness bound.\n');
fprintf(fid,'Figure 11 separates the clustered EVA physical model from a separately generated Clarke-Jakes statistical reference.\n');
end

function researchX_clean_results(resultsDir,numerology,mode)
resultFile=fullfile(resultsDir,sprintf('%s_%s_results.mat',lower(mode),lower(numerology)));
files={resultFile,fullfile(resultsDir,'validation.mat'),fullfile(resultsDir,'paper_validation.mat'),fullfile(resultsDir,'cv_metrics.csv'),fullfile(resultsDir,sprintf('claim_%s_results.mat',numerology)),fullfile(resultsDir,'claim_crosswaveform_metrics.csv'),fullfile(resultsDir,'claimability_summary.txt')};
for k=1:numel(files)
    if exist(files{k},'file')
        delete(files{k});
    end
end
figDir=fullfile(resultsDir,'figures');
if exist(figDir,'dir')
    rmdir(figDir,'s');
end
end

function researchX_atomic_save(fname,varargin)
tmp=[tempname(fileparts(fname)) '.mat'];
cleanup=onCleanup(@() researchX_delete_if_exists(tmp));
S=struct();
for k=1:numel(varargin)
    name=varargin{k};
    S.(name)=evalin('caller',name);
end
save(tmp,'-struct','S','-v7.3');
movefile(tmp,fname,'f');
clear cleanup
end

function researchX_delete_if_exists(f)
if exist(f,'file')
    delete(f);
end
end
