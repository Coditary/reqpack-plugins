return {
  name = "renv search remote packages",
  request = {
    action = "search",
    system = "renv",
    flags = {
      "data-root=${fixtureRoot}/.reqpack-data"
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
      match = [=[R_LIBS_USER='${fixtureRoot}/.reqpack-data/shared/helper-library' RENV_PATHS_ROOT='${fixtureRoot}/.reqpack-data/shared/renv-root' RENV_PATHS_CACHE='${fixtureRoot}/.reqpack-data/shared/cache' RENV_PATHS_SOURCE='${fixtureRoot}/.reqpack-data/shared/source' RENV_PATHS_BINARY='${fixtureRoot}/.reqpack-data/shared/binary' RENV_PATHS_CELLAR='${fixtureRoot}/.reqpack-data/shared/cellar' TMPDIR='${fixtureRoot}/.reqpack-data/shared/tmp' R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null RENV_CONFIG_AUTOLOADER_ENABLED=FALSE RENV_AUTOLOAD_ENABLED=FALSE LC_ALL=C LANG=C LANGUAGE=C Rscript --vanilla -e 'helper <- "${fixtureRoot}/.reqpack-data/shared/helper-library"; tmp <- "${fixtureRoot}/.reqpack-data/shared/tmp"; repo <- "https://cloud.r-project.org"; dir.create(helper, recursive = TRUE, showWarnings = FALSE); dir.create(tmp, recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/renv-root", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/cache", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/source", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/binary", recursive = TRUE, showWarnings = FALSE); dir.create("${fixtureRoot}/.reqpack-data/shared/cellar", recursive = TRUE, showWarnings = FALSE); options(repos = c(CRAN = repo), renv.consent = TRUE, renv.config.autoloader.enabled = FALSE, renv.config.auto.snapshot = FALSE); .libPaths(c(helper, .libPaths())); field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(""); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(""); gsub("[\t\r\n]+", " ", value); }; row_out <- function(values) { cat(paste(vapply(values, field, ""), collapse = "\t"), "\n", sep = ""); }; if (!requireNamespace("renv", quietly = TRUE, lib.loc = helper)) utils::install.packages("renv", lib = helper, repos = repo, quiet = TRUE); library(renv, lib.loc = helper); renv::consent(provided = TRUE); project <- NULL; project_lib <- helper; lockfile <- NULL; target <- tolower("digest"); installed_names <- character(); fields <- c("Description","License","URL","NeedsCompilation","Repository","Depends","Imports","Suggests"); avail <- utils::available.packages(repos = repo, fields = fields, cache_user_dir = TRUE); if (nrow(avail) > 0L) { desc <- ifelse(is.na(avail[, "Description"]), "", avail[, "Description"]); mask <- grepl(target, tolower(avail[, "Package"]), fixed = TRUE) | grepl(target, tolower(desc), fixed = TRUE); rows <- which(mask); if (length(rows) > 0L) { rows <- rows[order(avail[rows, "Package"])]; if (length(rows) > 50L) rows <- rows[seq_len(50L)]; for (i in rows) row_out(list(avail[i, "Package"], avail[i, "Version"], if (avail[i, "Package"] %in% installed_names) "true" else "false", avail[i, "Description"], avail[i, "License"], avail[i, "URL"], avail[i, "Repository"], avail[i, "NeedsCompilation"], avail[i, "Depends"], avail[i, "Imports"], avail[i, "Suggests"])); } } }']=],
      exitCode = 0,
      stdout = "digest\t0.6.32\tfalse\tHash function package\tMIT\thttps://cran.r-project.org/package=digest\thttps://cloud.r-project.org/src/contrib\tno\t\t\t\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "digest",
    resultVersion = "0.6.32",
    events = { "searched" },
  }
}
