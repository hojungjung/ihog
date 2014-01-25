% invertHOGtriangle(feat)
%
% Attempts to reconstruct the image for the HOG features 'feat' using a brute
% force algorithm that repeatedly adds triangles to an image only if doing
% so improves the reconstruction.
function reconstruction = invertHOGtriangle(feat, init, prev, gam, time, draw, sbin),

[ny, nx, ~] = size(feat);

if ~exist('gam', 'var'),  
  gam = 0;
end
if ~exist('time', 'var'),
  time = 30;;
end
if ~exist('draw', 'var'),
  draw = true;
end
if ~exist('sbin', 'var'),
  sbin = 8;
end

iters = time * 1000;

ry = (ny+2)*sbin;
rx = (nx+2)*sbin;

if ~exist('init', 'var'),
  init = 0.5 * ones(ry, rx);
end

core = tril(ones(max(ry, rx)));

objhistory = zeros(iters, 1);
objhoghistory = zeros(iters, 1);
objmultihistory = zeros(iters, 1);
goodtrials = 0;
acceptances = zeros(iters, 1);

reconstruction = init;
changes = zeros(size(init));
objective = -1;

starttime = tic();

fil = fspecial('gaussian', [sbin sbin], 1);
passfilter = fspecial('gaussian', [5*sbin 5*sbin], 1);

for iter=1:iters,
  itertime = toc(starttime);

  rot = rand() * 360;                      % rotate
  w = floor(rand() * sbin*4 + sbin/2)+1;   % width
  h = floor(rand() * sbin*4 + sbin/2)+1;   % height
  x = floor(rand() * rx);                  % center x
  y = floor(rand() * ry);                  % center y 
  int = (rand()-0.5) * 0.5;                % intensity

  trial = imrotate(core, rot);
  trial = imresize(trial, [h w]);
  trial = int * trial;
  trial = filter2(fil, trial);

  % calculate position in reconstruction from center of triangle
  ix = floor(x - w/2);
  iy = floor(y - h/2);

  if ix+w > rx,
    trial = trial(:, 1:end-(ix+w-rx));
    w = rx-ix;
  end
  if iy+h > ry,
    trial = trial(1:end-(iy+h-ry), :);
    h = ry-iy;
  end

  if ix < 1,
    trial = trial(:, 1-ix:end);
    w = w-(1-ix)+1;
    ix = 1;
  end
  if iy < 1,
    trial = trial(1-iy:end, :);
    h = h-(1-iy)+1;
    iy = 1;
  end

  candidate = reconstruction;
  candidate(iy:iy+h-1, ix:ix+w-1) = candidate(iy:iy+h-1, ix:ix+w-1) + trial;
  candidate(candidate > 1) = 1;
  candidate(candidate < 0) = 0;

  candidatechanges = changes;
  candidatechanges(iy:iy+h-1, ix:ix+w-1) = candidatechanges(iy:iy+h-1, ix:ix+w-1) + trial;

  candidatefeat = features(repmat(candidate, [1 1 3]), sbin);
  candidateobjhog = sqrt(mean((candidatefeat(:) - feat(:)).^2));

  candidateobjmulti = 0;
  for i=1:size(prev, 3),
    previm = prev(:, :, i);
    diffim = previm - candidate;
    diffim2 = diffim - filter2(passfilter, diffim, 'same');
    candidateobjmulti = candidateobjmulti - gam/size(prev,3) * sqrt(mean(diffim2(:).^2));
  end

  candidateobj = candidateobjhog + candidateobjmulti;

  if iter==1 || candidateobj < objective,
    reconstruction = candidate;
    changes = candidatechanges;
    objective = candidateobj;
    goodtrials = goodtrials + 1;
    objhistory(goodtrials) = candidateobj;
    objhoghistory(goodtrials) = candidateobjhog;
    objmultihistory(goodtrials) = candidateobjmulti;
    acceptances(iter) = 1;
  else,
    acceptances(iter) = -1;
  end

  if mod(iter-1, 100) == 0,
    fprintf('ihog: iter#%i: timeleft=%0.2fs, rate=%0.2fhz, obj=%f\n', iter, time - itertime, iter / itertime, objective);
  end

  if draw && mod(iter, 1000) == 0,
    subplot(241);
    imagesc(reconstruction, [0 1]); axis image;
    title('Reconstruction');
    subplot(242);
    imagesc(init); axis image;
    title('Initialization');
    subplot(243);
    imagesc(reconstruction - init); axis image;
    title('Difference');
    subplot(444);
    showHOG(candidatefeat - mean(candidatefeat(:))); axis image;
    title('Reconstruction HOG');
    subplot(448);
    showHOG(feat - mean(feat(:)));
    title('Target HOG');
    subplot(223);
    cla;
    plot(objhistory(1:goodtrials), 'k', 'LineWidth', 5);
    hold on;
    plot(objhoghistory(1:goodtrials), 'r', 'LineWidth', 2);
    plot(objmultihistory(1:goodtrials), 'b', 'LineWidth', 2);
    grid on;
    title('Objective');
    subplot(224);
    if size(prev,3) > 0,
      imdiffmatrix(cat(3, prev, candidate));
    else,
      imdiffmatrix(candidate);
    end
    title('Difference Matrix');
    drawnow;
  end

  if itertime > time,
    fprintf('ihog: breaking after %0.2fs\n', itertime);
    break;
  end
end
