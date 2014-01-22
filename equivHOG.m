function out = equivHOG(feat, n, gam, pd),

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
  [im, a] = invertHOG(feat, prev(:, :, 1:i-1), gam, pd);

  ims(:, :, i) = im;
  prev(:, :, i) = a;

  subplot(122);
  imagesc(repmat(diffim(ims(:, :, 1:i), 5), [1 1 3]));
  axis image;

  subplot(221);
  dists = squareform(pdist(reshape(ims(:, :, 1:i), [], i)'));
  imagesc(dists);
  title('Image Distance Matrix');

  subplot(223);
  dists = squareform(pdist(reshape(double(prev(:, :, 1:i) == 0), [], i)', 'hamming'));
  imagesc(dists);
  title('Alpha Distance Matrix');

  colormap gray;
  drawnow;
end

out = diffim(ims, 5);


function im = diffim(ims, bord),

[h, w, n] = size(ims);
im = ones(h*(n+1), w*(n+1));

h = h + 2 * bord;
w = w + 2 * bord;

% build borders
for i=1:n,
  im(h*i:h*(i+1)-1, 1:w) = padarray(ims(:, :, i), [bord bord], .8);
  im(1:h, w*i:w*(i+1)-1) = padarray(ims(:, :, i), [bord bord], .8);
end
im(1:h, 1:w) = .8;

for i=1:n,
  for j=1:n,
    d = abs(ims(:, :, i) - ims(:, :, j));
    d(:) = d(:) * 2;
    d = min(d, 1);
    d = padarray(d, [bord bord], 1);
    im(h*j:h*(j+1)-1, w*i:w*(i+1)-1) = d;
  end
end
