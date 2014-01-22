function equivHOG(feat, n, gam, pd),

if ~exist('n', 'var'),
  n = 6;
end
if ~exist('gam', 'var'),
  gam = 1;
end

bord = 5;
[ny, nx, nf] = size(feat);
numwindows = (ny+12-pd.ny+1)*(nx+12-pd.nx+1);

fprintf('ihog: attempting to find %i equivalent images in HOG space\n', n);

prev = zeros(pd.k, numwindows, n);
ims = ones((ny+2)*8, (nx+2)*8, n);
dists = zeros(n, 1);

for i=1:n,
  fprintf('ihog: searching for image #%i\n', i);
  [im, a] = invertHOG(feat, prev(:, :, 1:i), gam, pd);

  ims(:, :, i) = im;
  prev(:, :, i) = a;

  subplot(221);
  imagesc(repmat(im, [1 1 3])); axis image;
  title(sprintf('Image #%i', i), 'FontSize', 20);

  subplot(222);
  montage(repmat(permute(padarray(ims, [bord bord 0], 1), [1 2 4 3]), [1 1 3]));
  axis image;

  subplot(223);
  dists = pdist(reshape(ims(:, :, 1:i), [], i)');
  dists = squareform(dists);
  imagesc(dists);
  colormap jet;

  subplot(224);
  imagesc(abs(reshape(prev(:, :, 1:i), [], i)));

  drawnow;
end
