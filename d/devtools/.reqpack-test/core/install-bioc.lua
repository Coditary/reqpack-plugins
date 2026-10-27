return {
  name = "devtools install bioc package",
  request = {
    action = "install",
    system = "devtools",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    packages = {
      { name = "Biostrings", flags = { "source=bioc" } }
    },
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
      match = [=[R_LIBS_USER='${fixtureRoot}/.reqpack-data/library' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-data/cache' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-data/config' TMPDIR='${fixtureRoot}/.reqpack-data/tmp' R_PACKAGES_CACHE_USER_DIR=TRUE R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null LC_ALL=C LANG=C LANGUAGE=C Rscript --vanilla -e 'lib <- "${fixtureRoot}/.reqpack-data/library"; helper <- "${fixtureRoot}/.reqpack-data/helper-library"; repo <- "https://cloud.r-project.org"; dir.create(lib, recursive = TRUE, showWarnings = FALSE); dir.create(helper, recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CACHE_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CONFIG_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("TMPDIR"), recursive = TRUE, showWarnings = FALSE); options(repos = c(CRAN = repo)); .libPaths(c(helper, .libPaths())); if (!requireNamespace("BiocManager", quietly = TRUE, lib.loc = helper)) utils::install.packages("BiocManager", lib = helper, repos = repo, quiet = TRUE); if (!requireNamespace("devtools", quietly = TRUE, lib.loc = helper)) utils::install.packages("devtools", lib = helper, repos = repo, quiet = TRUE); .libPaths(c(lib, helper, .libPaths())); field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(""); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(""); gsub("[\t\r\n]+", " ", value); }; row_out <- function(values) { cat(paste(vapply(values, field, ""), collapse = "\t"), "\n", sep = ""); }; devtools::install_bioc(repo = "Biostrings", dependencies = NA, upgrade = "default", force = FALSE, quiet = TRUE, build = TRUE, build_manual = FALSE, build_vignettes = FALSE, repos = repo);']=],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = [=[R_LIBS_USER='${fixtureRoot}/.reqpack-data/library' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-data/cache' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-data/config' TMPDIR='${fixtureRoot}/.reqpack-data/tmp' R_PACKAGES_CACHE_USER_DIR=TRUE R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null LC_ALL=C LANG=C LANGUAGE=C Rscript --vanilla -e 'lib <- "${fixtureRoot}/.reqpack-data/library"; helper <- "${fixtureRoot}/.reqpack-data/helper-library"; repo <- "https://cloud.r-project.org"; dir.create(lib, recursive = TRUE, showWarnings = FALSE); dir.create(helper, recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CACHE_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CONFIG_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("TMPDIR"), recursive = TRUE, showWarnings = FALSE); options(repos = c(CRAN = repo)); .libPaths(c(helper, .libPaths())); if (!requireNamespace("devtools", quietly = TRUE, lib.loc = helper)) utils::install.packages("devtools", lib = helper, repos = repo, quiet = TRUE); if (!requireNamespace("BiocManager", quietly = TRUE, lib.loc = helper)) utils::install.packages("BiocManager", lib = helper, repos = repo, quiet = TRUE); .libPaths(c(lib, helper, .libPaths())); field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(""); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(""); gsub("[\t\r\n]+", " ", value); }; row_out <- function(values) { cat(paste(vapply(values, field, ""), collapse = "\t"), "\n", sep = ""); }; fields <- eval(parse(text = "c(\"Priority\",\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Built\",\"Depends\",\"Imports\",\"Suggests\",\"RemoteType\",\"RemoteHost\",\"RemoteRepo\",\"RemoteUsername\",\"RemoteRef\",\"RemoteSha\",\"RemoteSubdir\",\"RemoteUrl\",\"RemotePkgRef\",\"RemoteRepos\",\"RemotePkgType\",\"RemoteMirror\",\"RemoteRelease\",\"RemoteBranch\")")); db <- utils::installed.packages(lib.loc = lib, noCache = TRUE, fields = fields); if (nrow(db) > 0L) { for (i in seq_len(nrow(db))) row_out(list(db[i, "Package"], db[i, "Version"], db[i, "LibPath"], db[i, "Priority"], db[i, "Description"], db[i, "License"], db[i, "URL"], db[i, "NeedsCompilation"], db[i, "Built"], db[i, "Depends"], db[i, "Imports"], db[i, "Suggests"], db[i, "RemoteType"], db[i, "RemoteHost"], db[i, "RemoteRepo"], db[i, "RemoteUsername"], db[i, "RemoteRef"], db[i, "RemoteSha"], db[i, "RemoteSubdir"], db[i, "RemoteUrl"], db[i, "RemotePkgRef"], db[i, "RemoteRepos"], db[i, "RemotePkgType"], db[i, "RemoteMirror"], db[i, "RemoteRelease"], db[i, "RemoteBranch"])); }']=],
      exitCode = 0,
      stdout = "Biostrings\t2.72.1\t${fixtureRoot}/.reqpack-data/library\t\tEfficient manipulation of biological strings\tArtistic-2.0\thttps://bioconductor.org/packages/Biostrings\tno\tR 4.4.1; ; 2025-05-01 12:00:00 UTC; unix\t\t\t\tbioc_xgit\t\tBiostrings\t\t\tdeadbeef\t\t\tBiostrings\thttps://bioconductor.org/packages/3.20/bioc\tsource\thttps://git.bioconductor.org/packages\t3.20\tRELEASE_3_20\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
