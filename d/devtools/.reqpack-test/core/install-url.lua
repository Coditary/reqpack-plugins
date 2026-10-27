return {
  name = "devtools install url package",
  request = {
    action = "install",
    system = "devtools",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    packages = {
      { name = "https://example.invalid/pkg_0.2.0.tar.gz", flags = { "source=url" } }
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
      match = [=[R_LIBS_USER='${fixtureRoot}/.reqpack-data/library' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-data/cache' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-data/config' TMPDIR='${fixtureRoot}/.reqpack-data/tmp' R_PACKAGES_CACHE_USER_DIR=TRUE R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null LC_ALL=C LANG=C LANGUAGE=C Rscript --vanilla -e 'lib <- "${fixtureRoot}/.reqpack-data/library"; helper <- "${fixtureRoot}/.reqpack-data/helper-library"; repo <- "https://cloud.r-project.org"; dir.create(lib, recursive = TRUE, showWarnings = FALSE); dir.create(helper, recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CACHE_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CONFIG_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("TMPDIR"), recursive = TRUE, showWarnings = FALSE); options(repos = c(CRAN = repo)); .libPaths(c(helper, .libPaths())); if (!requireNamespace("devtools", quietly = TRUE, lib.loc = helper)) utils::install.packages("devtools", lib = helper, repos = repo, quiet = TRUE); .libPaths(c(lib, helper, .libPaths())); field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(""); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(""); gsub("[\t\r\n]+", " ", value); }; row_out <- function(values) { cat(paste(vapply(values, field, ""), collapse = "\t"), "\n", sep = ""); }; devtools::install_url(url = "https://example.invalid/pkg_0.2.0.tar.gz", dependencies = NA, upgrade = "default", force = FALSE, quiet = TRUE, build = TRUE, build_manual = FALSE, build_vignettes = FALSE, repos = repo);']=],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = [=[R_LIBS_USER='${fixtureRoot}/.reqpack-data/library' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-data/cache' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-data/config' TMPDIR='${fixtureRoot}/.reqpack-data/tmp' R_PACKAGES_CACHE_USER_DIR=TRUE R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null LC_ALL=C LANG=C LANGUAGE=C Rscript --vanilla -e 'lib <- "${fixtureRoot}/.reqpack-data/library"; helper <- "${fixtureRoot}/.reqpack-data/helper-library"; repo <- "https://cloud.r-project.org"; dir.create(lib, recursive = TRUE, showWarnings = FALSE); dir.create(helper, recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CACHE_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CONFIG_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("TMPDIR"), recursive = TRUE, showWarnings = FALSE); options(repos = c(CRAN = repo)); .libPaths(c(helper, .libPaths())); if (!requireNamespace("devtools", quietly = TRUE, lib.loc = helper)) utils::install.packages("devtools", lib = helper, repos = repo, quiet = TRUE); if (!requireNamespace("BiocManager", quietly = TRUE, lib.loc = helper)) utils::install.packages("BiocManager", lib = helper, repos = repo, quiet = TRUE); .libPaths(c(lib, helper, .libPaths())); field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(""); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(""); gsub("[\t\r\n]+", " ", value); }; row_out <- function(values) { cat(paste(vapply(values, field, ""), collapse = "\t"), "\n", sep = ""); }; fields <- eval(parse(text = "c(\"Priority\",\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Built\",\"Depends\",\"Imports\",\"Suggests\",\"RemoteType\",\"RemoteHost\",\"RemoteRepo\",\"RemoteUsername\",\"RemoteRef\",\"RemoteSha\",\"RemoteSubdir\",\"RemoteUrl\",\"RemotePkgRef\",\"RemoteRepos\",\"RemotePkgType\",\"RemoteMirror\",\"RemoteRelease\",\"RemoteBranch\")")); db <- utils::installed.packages(lib.loc = lib, noCache = TRUE, fields = fields); if (nrow(db) > 0L) { for (i in seq_len(nrow(db))) row_out(list(db[i, "Package"], db[i, "Version"], db[i, "LibPath"], db[i, "Priority"], db[i, "Description"], db[i, "License"], db[i, "URL"], db[i, "NeedsCompilation"], db[i, "Built"], db[i, "Depends"], db[i, "Imports"], db[i, "Suggests"], db[i, "RemoteType"], db[i, "RemoteHost"], db[i, "RemoteRepo"], db[i, "RemoteUsername"], db[i, "RemoteRef"], db[i, "RemoteSha"], db[i, "RemoteSubdir"], db[i, "RemoteUrl"], db[i, "RemotePkgRef"], db[i, "RemoteRepos"], db[i, "RemotePkgType"], db[i, "RemoteMirror"], db[i, "RemoteRelease"], db[i, "RemoteBranch"])); }']=],
      exitCode = 0,
      stdout = "pkg\t0.2.0\t${fixtureRoot}/.reqpack-data/library\t\tExample package\tMIT\thttps://example.invalid/pkg\tno\tR 4.4.1; ; 2025-05-01 12:00:00 UTC; unix\t\t\t\turl\t\t\t\t\tabcd1234\t\thttps://example.invalid/pkg_0.2.0.tar.gz\thttps://example.invalid/pkg_0.2.0.tar.gz\t\tsource\t\t\t\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
