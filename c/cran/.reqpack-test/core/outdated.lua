return {
  name = "cran outdated package",
  request = {
    action = "outdated",
    system = "cran",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
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
      match = [=[R_LIBS_USER='${fixtureRoot}/.reqpack-data/library' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-data/cache' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-data/config' TMPDIR='${fixtureRoot}/.reqpack-data/tmp' R_PACKAGES_CACHE_USER_DIR=TRUE R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null LC_ALL=C LANG=C LANGUAGE=C Rscript --vanilla -e 'lib <- "${fixtureRoot}/.reqpack-data/library"; repo <- "https://cloud.r-project.org"; dir.create(lib, recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CACHE_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CONFIG_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("TMPDIR"), recursive = TRUE, showWarnings = FALSE); options(repos = c(CRAN = repo)); field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(""); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(""); gsub("[\t\r\n]+", " ", value); }; row_out <- function(values) { cat(paste(vapply(values, field, ""), collapse = "\t"), "\n", sep = ""); }; fields <- c("Priority","Description","License","URL","NeedsCompilation","Built","Depends","Imports","Suggests"); inst <- utils::installed.packages(lib.loc = lib, noCache = TRUE, fields = fields); if (nrow(inst) > 0L) { avail <- utils::available.packages(repos = repo, fields = c("Description","License","URL","NeedsCompilation","Repository","Depends","Imports","Suggests"), cache_user_dir = TRUE); old <- utils::old.packages(lib.loc = lib, repos = repo, instPkgs = inst, available = avail); if (!is.null(old) && nrow(old) > 0L) { for (i in seq_len(nrow(old))) { name <- old[i, "Package"]; row_out(list(name, old[i, "Installed"], old[i, "ReposVer"], old[i, "Repository"], old[i, "LibPath"], inst[name, "Description"], inst[name, "License"], inst[name, "URL"], inst[name, "NeedsCompilation"], inst[name, "Depends"], inst[name, "Imports"], inst[name, "Suggests"], inst[name, "Built"])); } } }']=],
      exitCode = 0,
      stdout = "jsonlite\t1.8.8\t1.8.9\thttps://cloud.r-project.org/src/contrib\t${fixtureRoot}/.reqpack-data/library\tA simple and robust JSON parser and generator\tMIT\thttps://jeroen.r-universe.dev/jsonlite\tno\tmethods\t\t\tR 4.4.1; ; 2025-05-01 12:00:00 UTC; unix\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "jsonlite",
    resultVersion = "1.8.8",
    events = { "outdated" },
  }
}
