return {
  name = "renv info local remote lockfile package",
  request = {
    action = "info",
    system = "renv",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data",
      "project=${fixtureRoot}/project"
    },
    prompt = "digest",
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
      match = [=[R_LIBS_USER='${fixtureRoot}/project/renv/library/reqpack-library' RENV_PATHS_ROOT='${fixtureRoot}/.reqpack-data/shared/renv-root' RENV_PATHS_CACHE='${fixtureRoot}/.reqpack-data/shared/cache' RENV_PATHS_SOURCE='${fixtureRoot}/.reqpack-data/shared/source' RENV_PATHS_BINARY='${fixtureRoot}/.reqpack-data/shared/binary' RENV_PATHS_CELLAR='${fixtureRoot}/.reqpack-data/shared/cellar' TMPDIR='${fixtureRoot}/.reqpack-data/shared/tmp' R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE RENV_AUTOLOAD_ENABLED=FALSE LC_ALL=C LANG=C LANGUAGE=C Rscript --vanilla -e 'helper <- "${fixtureRoot}/.reqpack-data/shared/helper-library"; tmp <- "${fixtureRoot}/.reqpack-data/shared/tmp"; repo <- "https://cloud.r-project.org"; dir.create(helper, recursive = TRUE, showWarnings = FALSE); dir.create(tmp, recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/renv-root", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/cache", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/source", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/binary", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/cellar", recursive = TRUE, showWarnings = FALSE); options(repos = c(CRAN = repo), renv.consent = TRUE, renv.config.autoloader.enabled = FALSE, renv.config.auto.snapshot = FALSE); .libPaths(c(helper, .libPaths())); field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(""); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(""); gsub("[\t\r\n]+", " ", value); }; row_out <- function(values) { cat(paste(vapply(values, field, ""), collapse = "\t"), "\n", sep = ""); }; if (!requireNamespace("renv", quietly = TRUE, lib.loc = helper)) utils::install.packages("renv", lib = helper, repos = repo, quiet = TRUE); library(renv, lib.loc = helper); renv::consent(provided = TRUE); project <- "${fixtureRoot}/project"; dir.create(project, recursive = TRUE, showWarnings = FALSE); project_lib <- "${fixtureRoot}/project/renv/library/reqpack-library"; dir.create(project_lib, recursive = TRUE, showWarnings = FALSE); lockfile <- "${fixtureRoot}/project/renv.lock"; target <- "digest"; fields <- c("Priority","Description","License","URL","NeedsCompilation","Built","Depends","Imports","Suggests"); inst <- utils::installed.packages(lib.loc = project_lib, noCache = TRUE, fields = fields); if (nrow(inst) > 0L && target %in% rownames(inst)) row_out(list("local", target, inst[target, "Version"], inst[target, "LibPath"], inst[target, "Priority"], inst[target, "Description"], inst[target, "License"], inst[target, "URL"], inst[target, "NeedsCompilation"], inst[target, "Built"], inst[target, "Depends"], inst[target, "Imports"], inst[target, "Suggests"])); if (!is.null(lockfile) && file.exists(lockfile)) { lock <- renv::lockfile_read(lockfile); rec <- lock$Packages[[target]]; if (!is.null(rec)) row_out(list("lock", target, if (!is.null(rec$Version)) rec$Version else "", lockfile, if (!is.null(rec$Source)) rec$Source else "", if (!is.null(rec$Repository)) rec$Repository else "", "", "", "", "", "", "", "")); } avail <- utils::available.packages(repos = repo, fields = c("Priority","Description","License","URL","NeedsCompilation","Repository","Depends","Imports","Suggests"), cache_user_dir = TRUE); if (nrow(avail) > 0L && target %in% rownames(avail)) row_out(list("remote", target, avail[target, "Version"], avail[target, "Repository"], avail[target, "Priority"], avail[target, "Description"], avail[target, "License"], avail[target, "URL"], avail[target, "NeedsCompilation"], "", avail[target, "Depends"], avail[target, "Imports"], avail[target, "Suggests"]));']=],
      exitCode = 0,
      stdout = "local\tdigest\t0.6.31\t${fixtureRoot}/project/renv/library/reqpack-library\t\tHash function package\tMIT\thttps://cran.r-project.org/package=digest\tno\tR 4.4.1\t\t\t\nlock\tdigest\t0.6.31\t${fixtureRoot}/project/renv.lock\tRepository\tCRAN\t\t\t\t\t\t\t\nremote\tdigest\t0.6.32\thttps://cloud.r-project.org/src/contrib\t\tHash function package\tMIT\thttps://cran.r-project.org/package=digest\tno\t\t\t\t\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultName = "digest",
    resultVersion = "0.6.31",
    events = { "informed" },
  }
}
