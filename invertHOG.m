% invertHOG(feat)
%
% This function recovers the natural image that may have generated the HOG
% feature 'feat'. Usage is simple:
%
%   >> feat = features(im, 8);
%   >> ihog = invertHOG(feat);
%   >> imagesc(ihog); axis image;
%
% This function should take no longer than a second to invert any reasonably
% sized HOG feature point on a 12 core machine.
%
% By default, invertHOG() will load a prelearned paired dictionary to perform
% the inversion. However, if you want to pass your own, you can specify the
% optional second parameter to use your own parameters:
% 
%   >> pd = learnpairdict('/path/to/images');
%   >> ihog = invertHOG(feat, pd);
%
% This function also supports inverting whitened HOG if the paired dictionary
% is whitened. If 'pd.whitened' is true, then the input feature 'feat' will
% be whitened automatically. If you wish to suppress this behavior, set
% 'whiten' to false.
%
% If you have many points you wish to invert, this function can be vectorized.
% If 'feat' is size AxBxCxK, then it will invert K HOG features each of size
% AxBxC. It will return an PxQxK image tensor where the last channel is the kth
% inversion. This is usually significantly faster than calling invertHOG() 
% multiple times.
function [im, a] = invertHOG(feat, prev, gam, sig, omp, pd, whiten, verbose),

if ~exist('prev', 'var'),
  prev = zeros(0,0,0);
end
if ~exist('gam', 'var'),
  gam = 10;
end
if ~exist('sig', 'var'),
  sig = 1;
end
if ~exist('omp', 'var'),
  omp = 0;
end
if ~exist('pd', 'var') || isempty(pd),
  global ihog_pd
  if isempty(ihog_pd),
    ihog_pd = load('pd.mat');
  end
  pd = ihog_pd;
end
if ~isfield(pd, 'whitened'),
  pd.whitened = false;
end
if ~exist('whiten', 'var'),
  whiten = true;
end
if ~exist('verbose', 'var'),
  verbose = true;
end

t = tic();

par = 6;
feat = padarray(feat, [par par 0 0], 0);

[ny, nx, ~, nn] = size(feat);

numprev = size(prev, 3);
numpreva = size(prev, 2);

% pad feat if dim lacks occlusion feature
if size(feat,3) == featuresdim()-1,
  feat(:, :, end+1, :) = 0;
end

if verbose,
  fprintf('ihog: extracting windows\n');
end

% extract every window 
windows = zeros(pd.ny*pd.nx*featuresdim(), (ny-pd.ny+1)*(nx-pd.nx+1)*nn);
c = 1;
for k=1:nn,
  for i=1:size(feat,1) - pd.ny + 1,
    for j=1:size(feat,2) - pd.nx + 1,
      hog = feat(i:i+pd.ny-1, j:j+pd.nx-1, :, k);
      windows(:,c) = hog(:);
      c = c + 1;
    end
  end
end

% whiten HOG if needed
if whiten && pd.whitened,
  windows = bsxfun(@minus, windows, pd.muhog);
  windows = pd.whog * windows;
  if verbose,
    fprintf('ihog: whitening input\n');
  end
elseif ~pd.whitened,
  if verbose,
    fprintf('ihog: normalizing input\n');
  end
  windows = bsxfun(@minus, windows, mean(windows));
  windows = bsxfun(@rdivide, windows, sqrt(sum(windows.^2) + eps));
else,
  if verbose,
    fprintf('ihog: not applying whitening or normalization to input\n');
  end
end

dhog = pd.dhog;
mask = logical(ones(size(windows)));

if numprev > 0,
  if verbose,
    fprintf('ihog: adding multiple inversion constraints\n');
  end

  % build blurred dictionary
  if sig > 0,
    fprintf('ihog: highpass with sigma=%0.2f\n', sig);
    dblur = xpassdict(pd, sig, false);
  elseif sig < 0,
    fprintf('ihog: lowpass with sigma=%0.2f\n', -sig);
    dblur = xpassdict(pd, -sig, true);
  end

  windows = padarray(windows, [numprev*numpreva 0], 0, 'post');
  mask = cat(1, mask, repmat(logical(eye(numpreva, size(windows,2))), [numprev 1]));
  offset = size(dhog, 1);
  dhog = padarray(dhog, [numprev*numpreva 0], 0, 'post');
  for i=1:numprev,
    dhog(offset+(i-1)*numpreva+1:offset+i*numpreva, :) = sqrt(gam) * prev(:, :, i)' * dblur' * dblur;
    %dhog(offset+(i-1)*numpreva+1:offset+i*numpreva, :) = sqrt(gam) * prev(:, :, i)';
  end
end

if omp > 0,
  if verbose,
    fprintf('ihog: solving OMP\n');
  end

  % solve omp problem
  param.L = omp;
  param.mode = 0;
  a = full(mexOMPMask(single(windows), dhog, mask, param));
else,
  if verbose,
    fprintf('ihog: solving lasso\n');
  end

  % solve lasso problem
  param.lambda = pd.lambda * size(windows,1) / (pd.ny*pd.nx*featuresdim() + numprev);
  param.mode = 2;
  a = full(mexLassoMask(single(windows), dhog, mask, param));
end

if verbose,
  l0 = sum(a~=0);
  l1 = sum(abs(a));
  l2 = sum(a.^2);
  fprintf('ihog: sparsity = %f\n', sum(a(:) == 0) / length(a(:)));
  fprintf('ihog: ||a||_0 stats: min=%i  mean=%0.2f  median=%i  max=%i\n', min(l0), mean(l0), median(l0), max(l0));
  fprintf('ihog: ||a||_1 stats: min=%0.2f  mean=%0.2f  median=%0.2f  max=%0.2f\n', min(l1), mean(l1), median(l1), max(l1));
  fprintf('ihog: ||a||_2 stats: min=%0.2f  mean=%0.2f  median=%0.2f  max=%0.2f\n', min(l2), mean(l2), median(l2), max(l2));
end

if verbose,
  fprintf('ihog: reconstructing images\n');
end

% reconstruct
recon   = pd.dgray * a;

fil     = fspecial('gaussian', [(pd.ny+2)*pd.sbin (pd.nx+2)*pd.sbin], 9);
im      = zeros((size(feat,1)+2)*pd.sbin, (size(feat,2)+2)*pd.sbin, nn);
weights = zeros((size(feat,1)+2)*pd.sbin, (size(feat,2)+2)*pd.sbin, nn);
c = 1;
for k=1:nn,
  for i=1:size(feat,1) - pd.ny + 1,
    for j=1:size(feat,2) - pd.nx + 1,
      patch = reshape(recon(:, c), [(pd.ny+2)*pd.sbin (pd.nx+2)*pd.sbin]);

      patch(:) = patch(:) - min(patch(:));
      patch(:) = patch(:) / max(patch(:) + eps);
      patch = patch .* fil;

      iii = (i-1)*pd.sbin+1:(i-1)*pd.sbin+(pd.ny+2)*pd.sbin;
      jjj = (j-1)*pd.sbin+1:(j-1)*pd.sbin+(pd.nx+2)*pd.sbin;

      im(iii, jjj, k) = im(iii, jjj, k) + patch;
      weights(iii, jjj, k) = weights(iii, jjj, k) + 1;

      c = c + 1;
    end
  end
end

% post processing averaging and clipping
im = im ./ weights;
im = im(1:(ny+2)*pd.sbin, 1:(nx+2)*pd.sbin, :);
for k=1:nn,
  img = im(:, :, k);
  img(:) = img(:) - min(img(:));
  img(:) = img(:) / max(img(:));
  im(:, :, k) = img;
end

im = im(par*pd.sbin:end-par*pd.sbin-1, par*pd.sbin:end-par*pd.sbin-1, :);

if verbose,
  fprintf('ihog: took %0.1fs to invert\n', toc(t));
end
