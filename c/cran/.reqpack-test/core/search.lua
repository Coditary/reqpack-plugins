return {
  name = "cran search remote packages",
  request = {
    action = "search",
    system = "cran",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    prompt = "json",
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
      match = [=[R_LIBS_USER='${fixtureRoot}/.reqpack-data/library' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-data/cache' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-data/config' TMPDIR='${fixtureRoot}/.reqpack-data/tmp' R_PACKAGES_CACHE_USER_DIR=TRUE R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null LC_ALL=C LANG=C LANGUAGE=C Rscript --vanilla -e 'lib <- "${fixtureRoot}/.reqpack-data/library"; repo <- "https://cloud.r-project.org"; dir.create(lib, recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CACHE_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CONFIG_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("TMPDIR"), recursive = TRUE, showWarnings = FALSE); options(repos = c(CRAN = repo)); field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(""); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(""); gsub("[\t\r\n]+", " ", value); }; row_out <- function(values) { cat(paste(vapply(values, field, ""), collapse = "\t"), "\n", sep = ""); }; target <- tolower("json"); fields <- c("Description","License","URL","NeedsCompilation","Repository","Depends","Imports","Suggests"); avail <- utils::available.packages(repos = repo, fields = fields, cache_user_dir = TRUE); installed <- utils::installed.packages(lib.loc = lib, noCache = TRUE); installed_names <- if (nrow(installed) > 0L) rownames(installed) else character(); if (nrow(avail) > 0L) { desc <- ifelse(is.na(avail[, "Description"]), "", avail[, "Description"]); mask <- grepl(target, tolower(avail[, "Package"]), fixed = TRUE) | grepl(target, tolower(desc), fixed = TRUE); rows <- which(mask); if (length(rows) > 0L) { rows <- rows[order(avail[rows, "Package"])]; if (length(rows) > 50L) rows <- rows[seq_len(50L)]; for (i in rows) row_out(list(avail[i, "Package"], avail[i, "Version"], if (avail[i, "Package"] %in% installed_names) "true" else "false", avail[i, "Description"], avail[i, "License"], avail[i, "URL"], avail[i, "Repository"], avail[i, "NeedsCompilation"], avail[i, "Depends"], avail[i, "Imports"], avail[i, "Suggests"])); } } }']=],
      exitCode = 0,
      stdout = "jsonlite\t1.8.9\ttrue\tA simple and robust JSON parser and generator\tMIT\thttps://jeroen.r-universe.dev/jsonlite\thttps://cloud.r-project.org/src/contrib\tno\tmethods\t\t\nndjson\t0.9.0\tfalse\tStreaming newline delimited JSON\tMIT\thttps://example.invalid/ndjson\thttps://cloud.r-project.org/src/contrib\tno\t\t\t\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 2,
    resultName = "jsonlite",
    resultVersion = "1.8.9",
    events = { "searched" },
  }
}
