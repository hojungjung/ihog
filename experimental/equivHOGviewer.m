function equivHOGviewer(frames),

files = dir(frames);
for i=1:length(files),
  if files(i).isdir,
    continue;
  end

  filename = sprintf('%s/%s', frames, files(i).name);
  fprintf('ihog: view %s\n', filename);
  payload = load(filename);

  subplot(121);
  imdiffmatrix(payload.out, payload.im);

  subplot(122);
  immovie(payload.out, 0.2, 2);
end
