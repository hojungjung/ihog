function equivHOG(feat, n, gam),

if ~exist('n', 'var'),
  n = 6;
end
if ~exist('gam', 'var'),
  gam = 1;
end

bord = 10;

fprintf('ihog: attempting to find %i equivalent images in HOG space\n', n);

prev = zeros(0, 0, 0);
dists = zeros(n, 1);
first = [];

for i=1:n,
  fprintf('ihog: searching for image #%i\n', i);
  [im, a] = invertHOG(feat, prev, gam);

  if i==1,
    prev = a;
    first = im;
    ims = padarray(im, [bord bord], 1);
  else,
    prev = cat(3, prev, a);
    ims = cat(4, ims, padarray(im, [bord bord], 1));
  end

  subplot(221);
  imagesc(im); axis image;
  title(sprintf('Image #%i', i), 'FontSize', 20);

  subplot(122);
  montage(ims);
  title('All Images');
  axis image;

  subplot(223);
  dists(i) = (im(:)' * first(:))^2;
  plot(dists(1:i));

  drawnow;
end
