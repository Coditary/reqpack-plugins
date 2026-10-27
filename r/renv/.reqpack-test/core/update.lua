return {
  name = "renv update package",
  request = {
    action = "update",
    system = "renv",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "project=${fixtureRoot}/project",
      "lock=true"
    },
    packages = {
      { name = "digest" }
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
      match = [=[R_LIBS_USER='${fixtureRoot}/project/renv/library/reqpack-library' RENV_PATHS_ROOT='${fixtureRoot}/.reqpack-data/shared/renv-root' RENV_PATHS_CACHE='${fixtureRoot}/.reqpack-data/shared/cache' RENV_PATHS_SOURCE='${fixtureRoot}/.reqpack-data/shared/source' RENV_PATHS_BINARY='${fixtureRoot}/.reqpack-data/shared/binary' RENV_PATHS_CELLAR='${fixtureRoot}/.reqpack-data/shared/cellar' TMPDIR='${fixtureRoot}/.reqpack-data/shared/tmp' R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE RENV_AUTOLOAD_ENABLED=FALSE LC_ALL=C LANG=C LANGUAGE=C Rscript --vanilla -e 'helper <- "${fixtureRoot}/.reqpack-data/shared/helper-library"; tmp <- "${fixtureRoot}/.reqpack-data/shared/tmp"; repo <- "https://cloud.r-project.org"; dir.create(helper, recursive = TRUE, showWarnings = FALSE); dir.create(tmp, recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/renv-root", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/cache", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/source", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/binary", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/cellar", recursive = TRUE, showWarnings = FALSE); options(repos = c(CRAN = repo), renv.consent = TRUE, renv.config.autoloader.enabled = FALSE, renv.config.auto.snapshot = FALSE); .libPaths(c(helper, .libPaths())); field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(""); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(""); gsub("[\t\r\n]+", " ", value); }; row_out <- function(values) { cat(paste(vapply(values, field, ""), collapse = "\t"), "\n", sep = ""); }; if (!requireNamespace("renv", quietly = TRUE, lib.loc = helper)) utils::install.packages("renv", lib = helper, repos = repo, quiet = TRUE); library(renv, lib.loc = helper); renv::consent(provided = TRUE); project <- "${fixtureRoot}/project"; dir.create(project, recursive = TRUE, showWarnings = FALSE); project_lib <- "${fixtureRoot}/project/renv/library/reqpack-library"; dir.create(project_lib, recursive = TRUE, showWarnings = FALSE); lockfile <- "${fixtureRoot}/project/renv.lock"; renv::update(packages = c("digest"), prompt = FALSE, project = project, library = project_lib, rebuild = FALSE, lock = TRUE);']=],
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
  }
}
