return {
  name = "devtools info bioc package",
  request = {
    action = "info",
    system = "devtools",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    prompt = "Biostrings",
  },
  fakeExec = {
    {
      match = "command -v 'Rscript' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = [=[R_LIBS_USER='${fixtureRoot}/.reqpack-data/library' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-data/cache' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-data/config' TMPDIR='${fixtureRoot}/.reqpack-data/tmp' R_PACKAGES_CACHE_USER_DIR=TRUE R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null LC_ALL=C LANG=C LANGUAGE=C Rscript --vanilla -e 'lib <- "${fixtureRoot}/.reqpack-data/library"; helper <- "${fixtureRoot}/.reqpack-data/helper-library"; repo <- "https://cloud.r-project.org"; dir.create(lib, recursive = TRUE, showWarnings = FALSE); dir.create(helper, recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CACHE_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CONFIG_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("TMPDIR"), recursive = TRUE, showWarnings = FALSE); options(repos = c(CRAN = repo)); .libPaths(c(helper, .libPaths())); if (!requireNamespace("BiocManager", quietly = TRUE, lib.loc = helper)) utils::install.packages("BiocManager", lib = helper, repos = repo, quiet = TRUE); if (!requireNamespace("devtools", quietly = TRUE, lib.loc = helper)) utils::install.packages("devtools", lib = helper, repos = repo, quiet = TRUE); .libPaths(c(lib, helper, .libPaths())); field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(""); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(""); gsub("[\t\r\n]+", " ", value); }; row_out <- function(values) { cat(paste(vapply(values, field, ""), collapse = "\t"), "\n", sep = ""); }; target <- "Biostrings"; fields <- eval(parse(text = "c(\"Priority\",\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Built\",\"Depends\",\"Imports\",\"Suggests\",\"RemoteType\",\"RemoteHost\",\"RemoteRepo\",\"RemoteUsername\",\"RemoteRef\",\"RemoteSha\",\"RemoteSubdir\",\"RemoteUrl\",\"RemotePkgRef\",\"RemoteRepos\",\"RemotePkgType\",\"RemoteMirror\",\"RemoteRelease\",\"RemoteBranch\")")); inst <- utils::installed.packages(lib.loc = lib, noCache = TRUE, fields = fields); if (nrow(inst) > 0L && target %in% rownames(inst)) row_out(list("local", target, inst[target, "Version"], inst[target, "LibPath"], inst[target, "Priority"], inst[target, "Description"], inst[target, "License"], inst[target, "URL"], inst[target, "NeedsCompilation"], inst[target, "Built"], inst[target, "Depends"], inst[target, "Imports"], inst[target, "Suggests"], inst[target, "RemoteType"], inst[target, "RemoteHost"], inst[target, "RemoteRepo"], inst[target, "RemoteUsername"], inst[target, "RemoteRef"], inst[target, "RemoteSha"], inst[target, "RemoteSubdir"], inst[target, "RemoteUrl"], inst[target, "RemotePkgRef"], inst[target, "RemoteRepos"], inst[target, "RemotePkgType"], inst[target, "RemoteMirror"], inst[target, "RemoteRelease"], inst[target, "RemoteBranch"])); avail <- utils::available.packages(repos = repo, fields = c("Priority","Description","License","URL","NeedsCompilation","Repository","Depends","Imports","Suggests"), cache_user_dir = TRUE); if (nrow(avail) > 0L && target %in% rownames(avail)) row_out(list("remote", target, avail[target, "Version"], avail[target, "Repository"], avail[target, "Priority"], avail[target, "Description"], avail[target, "License"], avail[target, "URL"], avail[target, "NeedsCompilation"], "", avail[target, "Depends"], avail[target, "Imports"], avail[target, "Suggests"])); if (!(nrow(avail) > 0L && target %in% rownames(avail))) { bioc_repos <- tryCatch(BiocManager::repositories(), error = function(e) NULL); bioc_avail <- if (!is.null(bioc_repos)) tryCatch(utils::available.packages(repos = bioc_repos, fields = c("Priority","Description","License","URL","NeedsCompilation","Repository","Depends","Imports","Suggests"), cache_user_dir = TRUE), error = function(e) NULL) else NULL; if (!is.null(bioc_avail) && nrow(bioc_avail) > 0L && target %in% rownames(bioc_avail)) row_out(list("remote", target, bioc_avail[target, "Version"], bioc_avail[target, "Repository"], bioc_avail[target, "Priority"], bioc_avail[target, "Description"], bioc_avail[target, "License"], bioc_avail[target, "URL"], bioc_avail[target, "NeedsCompilation"], "", bioc_avail[target, "Depends"], bioc_avail[target, "Imports"], bioc_avail[target, "Suggests"], "bioc")); }']=],
      exitCode = 0,
      stdout = "remote\tBiostrings\t2.72.1\thttps://bioconductor.org/packages/3.20/bioc\t\tEfficient manipulation of biological strings\tArtistic-2.0\thttps://bioconductor.org/packages/Biostrings\tno\t\t\t\tbioc\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultName = "Biostrings",
    resultVersion = "2.72.1",
    events = { "informed" },
  }
}
