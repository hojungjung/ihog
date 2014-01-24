function out = equivHOGtriangle(orig, n, gam, time),

orig = im2double(orig);
feat = features(orig, 8);

if ~exist('n', 'var'),
  n = 6;
end
if ~exist('gam', 'var'),
  gam = 1;
end
if ~exist('time', 'var'),
  time = 0;
end

bord = 5;
[ny, nx, nf] = size(feat);

fprintf('ihog: attempting to find %i equivalent images in HOG space using triangles\n', n);

ims = ones((ny+2)*8, (nx+2)*8, n);
hogs = zeros(ny, nx, nf, n);
hogdists = zeros(n, 1);

for i=1:n,
  fprintf('ihog: searching for image %i of %i\n', i, n);
  im = invertHOGtriangle(feat, ims(:, :, 1:i-1), gam);

  ims(:, :, i) = im;
  hogs(:, :, :, i) = features(repmat(im, [1 1 3]), 8);

  d = hogs(:, :, :, i) - feat;
  hogdists(i) = sqrt(mean(d(:).^2));

  if nargout == 0,
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
    plot(hogdists(1:i), '.-', 'LineWidth', 2, 'MarkerSize', 40);
    title('HOG Distance to Target');
    ylim([0 .1+max(hogdists(:))]);
    grid on;

    subplot(325);
    imagesc(hogimvis(ims(:, :, 1:i), hogs(:, :, :, 1:i)));
    axis image;

    colormap gray;
    drawnow;
  end
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
