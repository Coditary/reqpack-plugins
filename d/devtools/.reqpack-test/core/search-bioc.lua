return {
  name = "devtools search bioc packages",
  request = {
    action = "search",
    system = "devtools",
    flags = { "data-root=${fixtureRoot}/.reqpack-data" },
    prompt = "biostr",
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
      match = [=[R_LIBS_USER='${fixtureRoot}/.reqpack-data/library' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-data/cache' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-data/config' TMPDIR='${fixtureRoot}/.reqpack-data/tmp' R_PACKAGES_CACHE_USER_DIR=TRUE R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null LC_ALL=C LANG=C LANGUAGE=C Rscript --vanilla -e 'lib <- "${fixtureRoot}/.reqpack-data/library"; helper <- "${fixtureRoot}/.reqpack-data/helper-library"; repo <- "https://cloud.r-project.org"; dir.create(lib, recursive = TRUE, showWarnings = FALSE); dir.create(helper, recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CACHE_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CONFIG_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("TMPDIR"), recursive = TRUE, showWarnings = FALSE); options(repos = c(CRAN = repo)); .libPaths(c(helper, .libPaths())); if (!requireNamespace("BiocManager", quietly = TRUE, lib.loc = helper)) utils::install.packages("BiocManager", lib = helper, repos = repo, quiet = TRUE); if (!requireNamespace("devtools", quietly = TRUE, lib.loc = helper)) utils::install.packages("devtools", lib = helper, repos = repo, quiet = TRUE); .libPaths(c(lib, helper, .libPaths())); field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(""); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(""); gsub("[\t\r\n]+", " ", value); }; row_out <- function(values) { cat(paste(vapply(values, field, ""), collapse = "\t"), "\n", sep = ""); }; target <- tolower("biostr"); fields <- eval(parse(text = "c(\"Priority\",\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Built\",\"Depends\",\"Imports\",\"Suggests\",\"RemoteType\",\"RemoteHost\",\"RemoteRepo\",\"RemoteUsername\",\"RemoteRef\",\"RemoteSha\",\"RemoteSubdir\",\"RemoteUrl\",\"RemotePkgRef\",\"RemoteRepos\",\"RemotePkgType\",\"RemoteMirror\",\"RemoteRelease\",\"RemoteBranch\")")); inst <- utils::installed.packages(lib.loc = lib, noCache = TRUE, fields = fields); avail <- utils::available.packages(repos = repo, fields = c("Description","License","URL","NeedsCompilation","Repository","Depends","Imports","Suggests"), cache_user_dir = TRUE); bioc_repos <- tryCatch(BiocManager::repositories(), error = function(e) NULL); bioc_avail <- if (!is.null(bioc_repos)) tryCatch(utils::available.packages(repos = bioc_repos, fields = c("Description","License","URL","NeedsCompilation","Repository","Depends","Imports","Suggests"), cache_user_dir = TRUE), error = function(e) NULL) else NULL; remote_hits <- character(); if (nrow(avail) > 0L) { desc <- ifelse(is.na(avail[, "Description"]), "", avail[, "Description"]); mask <- grepl(target, tolower(avail[, "Package"]), fixed = TRUE) | grepl(target, tolower(desc), fixed = TRUE); rows <- which(mask); if (length(rows) > 0L) { rows <- rows[order(avail[rows, "Package"])]; if (length(rows) > 50L) rows <- rows[seq_len(50L)]; remote_hits <- avail[rows, "Package"]; installed_names <- if (nrow(inst) > 0L) rownames(inst) else character(); for (i in rows) row_out(list("remote", avail[i, "Package"], avail[i, "Version"], if (avail[i, "Package"] %in% installed_names) "true" else "false", avail[i, "Description"], avail[i, "License"], avail[i, "URL"], avail[i, "Repository"], avail[i, "NeedsCompilation"], avail[i, "Depends"], avail[i, "Imports"], "cran", "", "", "")); } } } if (!is.null(bioc_avail) && nrow(bioc_avail) > 0L) { desc <- ifelse(is.na(bioc_avail[, "Description"]), "", bioc_avail[, "Description"]); mask <- grepl(target, tolower(bioc_avail[, "Package"]), fixed = TRUE) | grepl(target, tolower(desc), fixed = TRUE); rows <- which(mask); if (length(rows) > 0L) { rows <- rows[order(bioc_avail[rows, "Package"])]; if (length(rows) > 50L) rows <- rows[seq_len(50L)]; installed_names <- if (nrow(inst) > 0L) rownames(inst) else character(); for (i in rows) { pkg <- bioc_avail[i, "Package"]; if (!(pkg %in% remote_hits)) { remote_hits <- c(remote_hits, pkg); row_out(list("remote", pkg, bioc_avail[i, "Version"], if (pkg %in% installed_names) "true" else "false", bioc_avail[i, "Description"], bioc_avail[i, "License"], bioc_avail[i, "URL"], bioc_avail[i, "Repository"], bioc_avail[i, "NeedsCompilation"], bioc_avail[i, "Depends"], bioc_avail[i, "Imports"], "bioc", "", "", "")); } } } } if (nrow(inst) > 0L) { desc <- ifelse(is.na(inst[, "Description"]), "", inst[, "Description"]); mask <- grepl(target, tolower(rownames(inst)), fixed = TRUE) | grepl(target, tolower(desc), fixed = TRUE); rows <- which(mask); if (length(rows) > 0L) { rows <- rows[order(rownames(inst)[rows])]; for (i in rows) { pkg <- rownames(inst)[i]; if (!(pkg %in% remote_hits)) row_out(list("local", pkg, inst[i, "Version"], "true", inst[i, "Description"], inst[i, "License"], inst[i, "URL"], inst[i, "RemoteRepos"], inst[i, "NeedsCompilation"], inst[i, "Depends"], inst[i, "Imports"], inst[i, "RemoteType"], inst[i, "RemoteRepo"], inst[i, "RemoteUrl"], inst[i, "RemotePkgRef"])); } } } }']=],
      exitCode = 0,
      stdout = "remote\tBiostrings\t2.72.1\tfalse\tEfficient manipulation of biological strings\tArtistic-2.0\thttps://bioconductor.org/packages/Biostrings\thttps://bioconductor.org/packages/3.20/bioc\tno\t\t\tbioc\t\t\t\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "Biostrings",
    resultVersion = "2.72.1",
    events = { "searched" },
  }
}
