return {
  name = "renv outdated project package",
  request = {
    action = "outdated",
    system = "renv",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "project=${fixtureRoot}/project"
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
      match = [=[R_LIBS_USER='${fixtureRoot}/project/renv/library/reqpack-library' RENV_PATHS_ROOT='${fixtureRoot}/.reqpack-data/shared/renv-root' RENV_PATHS_CACHE='${fixtureRoot}/.reqpack-data/shared/cache' RENV_PATHS_SOURCE='${fixtureRoot}/.reqpack-data/shared/source' RENV_PATHS_BINARY='${fixtureRoot}/.reqpack-data/shared/binary' RENV_PATHS_CELLAR='${fixtureRoot}/.reqpack-data/shared/cellar' TMPDIR='${fixtureRoot}/.reqpack-data/shared/tmp' R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE RENV_AUTOLOAD_ENABLED=FALSE LC_ALL=C LANG=C LANGUAGE=C Rscript --vanilla -e 'helper <- "${fixtureRoot}/.reqpack-data/shared/helper-library"; tmp <- "${fixtureRoot}/.reqpack-data/shared/tmp"; repo <- "https://cloud.r-project.org"; dir.create(helper, recursive = TRUE, showWarnings = FALSE); dir.create(tmp, recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/renv-root", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/cache", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/source", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/binary", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/cellar", recursive = TRUE, showWarnings = FALSE); options(repos = c(CRAN = repo), renv.consent = TRUE, renv.config.autoloader.enabled = FALSE, renv.config.auto.snapshot = FALSE); .libPaths(c(helper, .libPaths())); field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(""); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(""); gsub("[\t\r\n]+", " ", value); }; row_out <- function(values) { cat(paste(vapply(values, field, ""), collapse = "\t"), "\n", sep = ""); }; if (!requireNamespace("renv", quietly = TRUE, lib.loc = helper)) utils::install.packages("renv", lib = helper, repos = repo, quiet = TRUE); library(renv, lib.loc = helper); renv::consent(provided = TRUE); project <- "${fixtureRoot}/project"; dir.create(project, recursive = TRUE, showWarnings = FALSE); project_lib <- "${fixtureRoot}/project/renv/library/reqpack-library"; dir.create(project_lib, recursive = TRUE, showWarnings = FALSE); lockfile <- "${fixtureRoot}/project/renv.lock"; if (!file.exists(file.path(project, "renv", "activate.R")) && !file.exists(file.path(project, "renv.lock"))) { renv::init(project = project, bare = TRUE, force = TRUE, restart = FALSE, load = FALSE, repos = c(CRAN = repo)); }']=],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = [=[R_LIBS_USER='${fixtureRoot}/project/renv/library/reqpack-library' RENV_PATHS_ROOT='${fixtureRoot}/.reqpack-data/shared/renv-root' RENV_PATHS_CACHE='${fixtureRoot}/.reqpack-data/shared/cache' RENV_PATHS_SOURCE='${fixtureRoot}/.reqpack-data/shared/source' RENV_PATHS_BINARY='${fixtureRoot}/.reqpack-data/shared/binary' RENV_PATHS_CELLAR='${fixtureRoot}/.reqpack-data/shared/cellar' TMPDIR='${fixtureRoot}/.reqpack-data/shared/tmp' R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE RENV_AUTOLOAD_ENABLED=FALSE LC_ALL=C LANG=C LANGUAGE=C Rscript --vanilla -e 'helper <- "${fixtureRoot}/.reqpack-data/shared/helper-library"; tmp <- "${fixtureRoot}/.reqpack-data/shared/tmp"; repo <- "https://cloud.r-project.org"; dir.create(helper, recursive = TRUE, showWarnings = FALSE); dir.create(tmp, recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/renv-root", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/cache", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/source", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/binary", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/cellar", recursive = TRUE, showWarnings = FALSE); options(repos = c(CRAN = repo), renv.consent = TRUE, renv.config.autoloader.enabled = FALSE, renv.config.auto.snapshot = FALSE); .libPaths(c(helper, .libPaths())); field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(""); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(""); gsub("[\t\r\n]+", " ", value); }; row_out <- function(values) { cat(paste(vapply(values, field, ""), collapse = "\t"), "\n", sep = ""); }; if (!requireNamespace("renv", quietly = TRUE, lib.loc = helper)) utils::install.packages("renv", lib = helper, repos = repo, quiet = TRUE); library(renv, lib.loc = helper); renv::consent(provided = TRUE); project <- "${fixtureRoot}/project"; dir.create(project, recursive = TRUE, showWarnings = FALSE); project_lib <- "${fixtureRoot}/project/renv/library/reqpack-library"; dir.create(project_lib, recursive = TRUE, showWarnings = FALSE); lockfile <- "${fixtureRoot}/project/renv.lock"; fields <- c("Priority","Description","License","URL","NeedsCompilation","Built","Depends","Imports","Suggests"); inst <- utils::installed.packages(lib.loc = project_lib, noCache = TRUE, fields = fields); if (nrow(inst) > 0L) { avail <- utils::available.packages(repos = repo, fields = c("Description","License","URL","NeedsCompilation","Repository","Depends","Imports","Suggests"), cache_user_dir = TRUE); old <- utils::old.packages(lib.loc = project_lib, repos = repo, instPkgs = inst, available = avail); if (!is.null(old) && nrow(old) > 0L) { for (i in seq_len(nrow(old))) { name <- old[i, "Package"]; row_out(list(name, old[i, "Installed"], old[i, "ReposVer"], old[i, "Repository"], old[i, "LibPath"], inst[name, "Description"], inst[name, "License"], inst[name, "URL"], inst[name, "NeedsCompilation"], inst[name, "Depends"], inst[name, "Imports"], inst[name, "Suggests"], inst[name, "Built"])); } } }']=],
      exitCode = 0,
      stdout = "digest\t0.6.31\t0.6.32\thttps://cloud.r-project.org/src/contrib\t${fixtureRoot}/project/renv/library/reqpack-library\tHash function package\tMIT\thttps://cran.r-project.org/package=digest\tno\t\t\t\tR 4.4.1\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "digest",
    resultVersion = "0.6.31",
    events = { "outdated" },
  }
}
