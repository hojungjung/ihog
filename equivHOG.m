function out = equivHOG(orig, n, gam, sig, pd),

orig = im2double(orig);
feat = features(orig, 8);

if ~exist('n', 'var'),
  n = 6;
end
if ~exist('gam', 'var'),
  gam = 1;
end
if ~exist('sig', 'var'),
  sig = 1;
end
if ~exist('si', 'var'),
  si = .1;
end

bord = 5;
[ny, nx, nf] = size(feat);
numwindows = (ny+12-pd.ny+1)*(nx+12-pd.nx+1);

fprintf('ihog: attempting to find %i equivalent images in HOG space\n', n);

prev = zeros(pd.k, numwindows, n);
ims = ones((ny+2)*8, (nx+2)*8, n);
hogs = zeros(ny, nx, nf, n);
dists = zeros(n, 1);

for i=1:n,
  fprintf('ihog: searching for image #%i\n', i);
  [im, a] = invertHOG(feat, prev(:, :, 1:i-1), gam, sig, pd);

  ims(:, :, i) = im;
  hogs(:, :, :, i) = features(repmat(im, [1 1 3]), 8);
  prev(:, :, i) = a;

  figure(1);
  subplot(122);
  imdiffmatrix(ims(:, :, 1:i), orig, 5);

  subplot(321);
  sparsity = mean(reshape(double(prev(:, :, 1:i) == 0), [], i));
  plot(sparsity(:), '.-', 'LineWidth', 2, 'MarkerSize', 40);
  title('Alpha Sparsity');
  ylabel('Sparsity');
  ylim([0.75 1]);
  grid on;

  subplot(323);
  dists = squareform(pdist(reshape(hogs(:, :, :, 1:i), [], i)'));
  dists = sqrt(dists / (ny*nx*nf));
  imagesc(dists, [0 .05]);
  title(sprintf('HOG Distance Matrix (max = %0.4f)', max(dists(:))));
  colorbar;

  subplot(325);
  imagesc(hogimvis(ims(:, :, 1:i), hogs(:, :, :, 1:i)));
  axis image;

  colormap gray;
  drawnow;
end

out = ims;



function out = hogimvis(ims, hogs),

out = [];
for i=1:size(ims,3),
  im = ims(:, :, i);
  hog = hogs(:, :, :, i);
  hog(:) = max(hog(:) - mean(hog(:)), 0);
  hog = showHOG(hog);
  hog = imresize(hog, size(im));
  hog(hog > 1) = 1;
  hog(hog < 0) = 0;
  im = padarray(im, [5 10], 1);
  hog = padarray(hog, [5 10], 1);
  graphic = [im; hog];
  out = [out graphic];
end
out = padarray(out, [5 0], 1);
