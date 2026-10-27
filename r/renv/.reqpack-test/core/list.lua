return {
  name = "renv list project packages",
  request = {
    action = "list",
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
      match = [=[R_LIBS_USER='${fixtureRoot}/project/renv/library/reqpack-library' RENV_PATHS_ROOT='${fixtureRoot}/.reqpack-data/shared/renv-root' RENV_PATHS_CACHE='${fixtureRoot}/.reqpack-data/shared/cache' RENV_PATHS_SOURCE='${fixtureRoot}/.reqpack-data/shared/source' RENV_PATHS_BINARY='${fixtureRoot}/.reqpack-data/shared/binary' RENV_PATHS_CELLAR='${fixtureRoot}/.reqpack-data/shared/cellar' TMPDIR='${fixtureRoot}/.reqpack-data/shared/tmp' R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE RENV_AUTOLOAD_ENABLED=FALSE LC_ALL=C LANG=C LANGUAGE=C Rscript --vanilla -e 'helper <- "${fixtureRoot}/.reqpack-data/shared/helper-library"; tmp <- "${fixtureRoot}/.reqpack-data/shared/tmp"; repo <- "https://cloud.r-project.org"; dir.create(helper, recursive = TRUE, showWarnings = FALSE); dir.create(tmp, recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/renv-root", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/cache", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/source", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/binary", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/cellar", recursive = TRUE, showWarnings = FALSE); options(repos = c(CRAN = repo), renv.consent = TRUE, renv.config.autoloader.enabled = FALSE, renv.config.auto.snapshot = FALSE); .libPaths(c(helper, .libPaths())); field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(""); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(""); gsub("[\t\r\n]+", " ", value); }; row_out <- function(values) { cat(paste(vapply(values, field, ""), collapse = "\t"), "\n", sep = ""); }; if (!requireNamespace("renv", quietly = TRUE, lib.loc = helper)) utils::install.packages("renv", lib = helper, repos = repo, quiet = TRUE); library(renv, lib.loc = helper); renv::consent(provided = TRUE); project <- "${fixtureRoot}/project"; dir.create(project, recursive = TRUE, showWarnings = FALSE); project_lib <- "${fixtureRoot}/project/renv/library/reqpack-library"; dir.create(project_lib, recursive = TRUE, showWarnings = FALSE); lockfile <- "${fixtureRoot}/project/renv.lock";  fields <- c("Priority","Description","License","URL","NeedsCompilation","Built","Depends","Imports","Suggests"); db <- utils::installed.packages(lib.loc = project_lib, noCache = TRUE, fields = fields); if (nrow(db) > 0L) { for (i in seq_len(nrow(db))) row_out(list(db[i, "Package"], db[i, "Version"], db[i, "LibPath"], db[i, "Priority"], db[i, "Description"], db[i, "License"], db[i, "URL"], db[i, "NeedsCompilation"], db[i, "Built"], db[i, "Depends"], db[i, "Imports"], db[i, "Suggests"])); }']=],
      exitCode = 0,
      stdout = "digest\t0.6.32\t${fixtureRoot}/project/renv/library/reqpack-library\t\tHash function package\tMIT\thttps://cran.r-project.org/package=digest\tno\tR 4.4.1\t\t\t\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "digest",
    resultVersion = "0.6.32",
    events = { "listed" },
  }
}
