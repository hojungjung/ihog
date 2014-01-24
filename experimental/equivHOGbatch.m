function equivHOGbatch(stream, output),

seedrandom();

ny = 10;
nx = 10;
sbin = 8;

n = 15;
gam = 100;
sig = 1;
omp = 0;
triangle = 0;

iters = 1000;
pd = load('pd.mat');

files = dir(stream);

gy = (ny+2)*sbin;
gx = (nx+2)*sbin;

jobid = dec2hex(randi(1000000000000));

for i=1:iters,
  fprintf('ihog: iteration %i\n', i);
  f = files(floor(rand() * length(files))+1);
  if f.isdir,
    fprintf('ihog: %s is directory, skipping\n', f.name);
    continue;
  end
  im = im2double(imread([stream '/' f.name]));
  [h, w, ~] = size(im);

  iy = floor(rand()*(h - gy - 1))+1;
  ix = floor(rand()*(w - gx - 1))+1;

  im = im(iy:iy+gy, ix:ix+gx, :);
  out = equivHOG(im, n, gam, sig, omp, triangle, pd);

  s = sprintf('%s/%s_%i.mat', output, jobid, i);
  save(s, 'im', 'out');
  fprintf('ihog: wrote %s\n', s);
end



% Generates a random seed for MATLAB that is robust against many problems that
% crop up when laucning jobs on the cluster. It is better than just seeding
% with the clock since cluster jobs may start at the *exact* same time.
function seed = seedrandom(),

[~, hostname] = system('hostname');
hostname = strtrim(hostname);
hostname = double(hostname);
hostname = sum(hostname);

[~, randnum] = system('echo $RANDOM');
randnum = strtrim(randnum);
randnum = str2num(randnum);

pid = feature('getpid');

seed = hostname * randnum * pid;
seed = mod(seed, 2^31);

rng(seed);

fprintf('ihog: random seed set to %i = %i * %i * %i\n', seed, hostname, randnum, pid);
