return {
  name = "devtools outdated bioc packages",
  request = {
    action = "outdated",
    system = "devtools",
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
      match = [=[R_LIBS_USER='${fixtureRoot}/.reqpack-data/library' XDG_CACHE_HOME='${fixtureRoot}/.reqpack-data/cache' XDG_CONFIG_HOME='${fixtureRoot}/.reqpack-data/config' TMPDIR='${fixtureRoot}/.reqpack-data/tmp' R_PACKAGES_CACHE_USER_DIR=TRUE R_ENVIRON_USER=/dev/null R_PROFILE_USER=/dev/null LC_ALL=C LANG=C LANGUAGE=C Rscript --vanilla -e 'lib <- "${fixtureRoot}/.reqpack-data/library"; helper <- "${fixtureRoot}/.reqpack-data/helper-library"; repo <- "https://cloud.r-project.org"; dir.create(lib, recursive = TRUE, showWarnings = FALSE); dir.create(helper, recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CACHE_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("XDG_CONFIG_HOME"), recursive = TRUE, showWarnings = FALSE); dir.create(Sys.getenv("TMPDIR"), recursive = TRUE, showWarnings = FALSE); options(repos = c(CRAN = repo)); .libPaths(c(helper, .libPaths())); if (!requireNamespace("BiocManager", quietly = TRUE, lib.loc = helper)) utils::install.packages("BiocManager", lib = helper, repos = repo, quiet = TRUE); if (!requireNamespace("devtools", quietly = TRUE, lib.loc = helper)) utils::install.packages("devtools", lib = helper, repos = repo, quiet = TRUE); .libPaths(c(lib, helper, .libPaths())); field <- function(x) { if (length(x) == 0L || all(is.na(x))) return(""); value <- as.character(x[[1L]]); if (is.na(value) || !nzchar(value)) return(""); gsub("[\t\r\n]+", " ", value); }; row_out <- function(values) { cat(paste(vapply(values, field, ""), collapse = "\t"), "\n", sep = ""); }; fields <- eval(parse(text = "c(\"Priority\",\"Description\",\"License\",\"URL\",\"NeedsCompilation\",\"Built\",\"Depends\",\"Imports\",\"Suggests\",\"RemoteType\",\"RemoteHost\",\"RemoteRepo\",\"RemoteUsername\",\"RemoteRef\",\"RemoteSha\",\"RemoteSubdir\",\"RemoteUrl\",\"RemotePkgRef\",\"RemoteRepos\",\"RemotePkgType\",\"RemoteMirror\",\"RemoteRelease\",\"RemoteBranch\")")); inst <- utils::installed.packages(lib.loc = lib, noCache = TRUE, fields = fields); avail <- utils::available.packages(repos = repo, fields = c("Description","License","URL","NeedsCompilation","Repository","Depends","Imports","Suggests"), cache_user_dir = TRUE); if (nrow(inst) > 0L && nrow(avail) > 0L) { for (i in seq_len(nrow(inst))) { name <- inst[i, "Package"]; remote_type <- if (is.na(inst[i, "RemoteType"])) "" else as.character(inst[i, "RemoteType"]); if ((remote_type %in% c("","cran","standard","any","version")) && name %in% rownames(avail) && utils::compareVersion(as.character(inst[i, "Version"]), as.character(avail[name, "Version"])) < 0L) row_out(list(name, inst[i, "Version"], avail[name, "Version"], avail[name, "Repository"], inst[i, "LibPath"], inst[i, "Description"], inst[i, "License"], inst[i, "URL"], inst[i, "NeedsCompilation"], inst[i, "Depends"], inst[i, "Imports"], inst[i, "Suggests"], inst[i, "Built"], remote_type, inst[i, "RemotePkgRef"])); } } bioc_valid <- tryCatch(suppressWarnings(BiocManager::valid(lib.loc = lib)), error = function(e) NULL); bioc_outdated <- if (is.list(bioc_valid) && !is.null(bioc_valid$out_of_date) && nrow(bioc_valid$out_of_date) > 0L) bioc_valid$out_of_date else NULL; if (nrow(inst) > 0L && !is.null(bioc_outdated)) { for (i in seq_len(nrow(inst))) { name <- inst[i, "Package"]; remote_type <- if (is.na(inst[i, "RemoteType"])) "" else as.character(inst[i, "RemoteType"]); if ((remote_type %in% c("bioc_xgit","bioc_git2r")) && name %in% rownames(bioc_outdated)) row_out(list(name, inst[i, "Version"], bioc_outdated[name, "Version"], inst[i, "RemoteRepos"], inst[i, "LibPath"], inst[i, "Description"], inst[i, "License"], inst[i, "URL"], inst[i, "NeedsCompilation"], inst[i, "Depends"], inst[i, "Imports"], inst[i, "Suggests"], inst[i, "Built"], remote_type, inst[i, "RemotePkgRef"])); } }']=],
      exitCode = 0,
      stdout = "Biostrings\t2.72.0\t2.72.1\thttps://bioconductor.org/packages/3.20/bioc\t${fixtureRoot}/.reqpack-data/library\tEfficient manipulation of biological strings\tArtistic-2.0\thttps://bioconductor.org/packages/Biostrings\tno\tmethods\t\t\tR 4.4.1; ; 2025-05-01 12:00:00 UTC; unix\tbioc_xgit\tBiostrings\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    resultCount = 1,
    resultName = "Biostrings",
    resultVersion = "2.72.0",
    events = { "outdated" },
  }
}
