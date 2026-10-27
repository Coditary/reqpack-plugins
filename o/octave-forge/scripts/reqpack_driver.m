function reqpack_driver()
  root = getenv("REQPACK_STATE_ROOT");
  action = getenv("REQPACK_ACTION");
  scope = getenv("REQPACK_SCOPE");
  package = getenv("REQPACK_PACKAGE");
  local_install = strcmp(getenv("REQPACK_LOCAL_INSTALL"), "1");
  use_nodeps = strcmp(getenv("REQPACK_NODEPS"), "1");
  use_verbose = strcmp(getenv("REQPACK_VERBOSE"), "1");

  prefix_dir = fullfile(root, "prefix");
  arch_dir = fullfile(root, "arch-prefix");
  local_list_path = fullfile(root, "local", "octave_packages");
  global_list_path = fullfile(root, "global", "octave_packages");
  dirs = {root, prefix_dir, arch_dir, fileparts(local_list_path), fileparts(global_list_path)};
  for i = 1:numel(dirs)
    if (! exist(dirs{i}, "dir"))
      mkdir(dirs{i});
    endif
  endfor

  pkg("prefix", prefix_dir, arch_dir);
  pkg("local_list", local_list_path);
  pkg("global_list", global_list_path);

  switch action
    case "list"
      emit_list();
    case "install"
      args = build_args("install", scope, package, local_install, use_nodeps, use_verbose);
      pkg(args{:});
    case "remove"
      args = build_args("uninstall", scope, package, false, use_nodeps, use_verbose);
      pkg(args{:});
    case "update"
      args = build_args("update", scope, package, false, use_nodeps, use_verbose);
      pkg(args{:});
    otherwise
      error("unsupported action");
  endswitch
endfunction

function args = build_args(command_name, scope, package, local_install, use_nodeps, use_verbose)
  args = {command_name};
  if (strcmp(scope, "global"))
    args{end+1} = "-global";
  else
    args{end+1} = "-local";
  endif
  if (use_nodeps)
    args{end+1} = "-nodeps";
  endif
  if (use_verbose)
    args{end+1} = "-verbose";
  endif
  if (strcmp(command_name, "install") && ! local_install)
    args{end+1} = "-forge";
  endif
  args{end+1} = package;
endfunction

function emit_list()
  [local_pkgs, global_pkgs] = pkg("list");
  all_pkgs = {};
  scopes = {};
  for i = 1:numel(local_pkgs)
    all_pkgs{end+1} = local_pkgs{i};
    scopes{end+1} = "local";
  endfor
  for i = 1:numel(global_pkgs)
    all_pkgs{end+1} = global_pkgs{i};
    scopes{end+1} = "global";
  endfor
  if (numel(all_pkgs) == 0)
    return;
  endif

  names = cellfun(@(x) x.name, all_pkgs, "UniformOutput", false);
  [descs, flags] = pkg("describe", names{:});
  for i = 1:numel(all_pkgs)
    desc = struct();
    status = "";
    arch = "";
    date = "";
    description = "";
    url = "";
    tracker = "";
    depends = {};
    if (i <= numel(descs) && isstruct(descs{i}))
      desc = descs{i};
      if (isfield(desc, "date")), date = desc.date; endif
      if (isfield(desc, "description")), description = desc.description; endif
      if (isfield(desc, "url")), url = desc.url; endif
      if (isfield(desc, "tracker")), tracker = desc.tracker; endif
      if (isfield(desc, "depends")), depends = desc.depends; endif
    endif
    if (i <= numel(flags)), status = flags{i}; endif
    if (isfield(all_pkgs{i}, "archprefix")), arch = all_pkgs{i}.archprefix; endif
    row_out({scopes{i}, all_pkgs{i}.name, all_pkgs{i}.version, status, all_pkgs{i}.loaded, all_pkgs{i}.dir, arch, date, description, url, tracker, dep_text(depends)});
  endfor
endfunction

function out = rf(x)
  if (isempty(x))
    out = "";
  elseif (islogical(x))
    if (x), out = "true"; else out = "false"; endif
  elseif (ischar(x))
    out = x;
  elseif (iscell(x))
    parts = cellfun(@rf, x, "UniformOutput", false);
    parts = parts(! cellfun("isempty", parts));
    out = strjoin(parts, ",");
  else
    out = strtrim(num2str(x));
  endif
  out = strrep(strrep(strrep(out, sprintf("\t"), " "), sprintf("\r"), " "), sprintf("\n"), " ");
endfunction

function dep = dep_text(depends)
  parts = {};
  if (isstruct(depends))
    for j = 1:numel(depends)
      part = "";
      if (isfield(depends(j), "package"))
        part = rf(depends(j).package);
      elseif (isfield(depends(j), "name"))
        part = rf(depends(j).name);
      endif
      if (! isempty(part))
        parts{end+1} = part;
      endif
    endfor
  elseif (iscell(depends))
    for j = 1:numel(depends)
      part = rf(depends{j});
      if (! isempty(part))
        parts{end+1} = part;
      endif
    endfor
  endif
  dep = strjoin(parts, ",");
endfunction

function row_out(values)
  for j = 1:numel(values)
    printf("%s", rf(values{j}));
    if (j < numel(values))
      printf("\t");
    endif
  endfor
  printf("\n");
endfunction
