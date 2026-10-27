return {
  name = "cran info local and remote package",
  request = {
    action = "info",
    system = "cran",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    prompt = "jsonlite",
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
      match = [=[R_LIBS_USER='${fixtureRoot}/.reqpack-data/library' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-data/cache' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-data/config' TMPDIR='${fixtureRoot}/.reqpack-data/tmp' R_PACKAGES_CACHE_USER_DIR=TRUE R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null LC_ALL=C LANG=C LANGUAGE=C Rscript --vanilla -e 'lib <- "${fixtureRoot}/.reqpack-data/library"; repo <- "https://cloud.r-project.org"; dir.create(lib, recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CACHE_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CONFIG_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("TMPDIR"), recursive = TRUE, showWarnings = FALSE); options(repos = c(CRAN = repo)); field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(""); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(""); gsub("[\t\r\n]+", " ", value); }; row_out <- function(values) { cat(paste(vapply(values, field, ""), collapse = "\t"), "\n", sep = ""); }; target <- "jsonlite"; fields <- c("Priority","Description","License","URL","NeedsCompilation","Built","Depends","Imports","Suggests"); inst <- utils::installed.packages(lib.loc = lib, noCache = TRUE, fields = fields); if (nrow(inst) > 0L && target %in% rownames(inst)) row_out(list("local", target, inst[target, "Version"], inst[target, "LibPath"], inst[target, "Priority"], inst[target, "Description"], inst[target, "License"], inst[target, "URL"], inst[target, "NeedsCompilation"], inst[target, "Built"], inst[target, "Depends"], inst[target, "Imports"], inst[target, "Suggests"])); avail <- utils::available.packages(repos = repo, fields = c("Priority","Description","License","URL","NeedsCompilation","Repository","Depends","Imports","Suggests"), cache_user_dir = TRUE); if (nrow(avail) > 0L && target %in% rownames(avail)) row_out(list("remote", target, avail[target, "Version"], avail[target, "Repository"], avail[target, "Priority"], avail[target, "Description"], avail[target, "License"], avail[target, "URL"], avail[target, "NeedsCompilation"], "", avail[target, "Depends"], avail[target, "Imports"], avail[target, "Suggests"]));']=],
      exitCode = 0,
      stdout = "local\tjsonlite\t1.8.8\t${fixtureRoot}/.reqpack-data/library\t\tA simple and robust JSON parser and generator\tMIT\thttps://jeroen.r-universe.dev/jsonlite\tno\tR 4.4.1; ; 2025-05-01 12:00:00 UTC; unix\tmethods\t\t\nremote\tjsonlite\t1.8.9\thttps://cloud.r-project.org/src/contrib\t\tA simple and robust JSON parser and generator\tMIT\thttps://jeroen.r-universe.dev/jsonlite\tno\t\tmethods\t\t\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultName = "jsonlite",
    resultVersion = "1.8.8",
    events = { "informed" },
  }
}
