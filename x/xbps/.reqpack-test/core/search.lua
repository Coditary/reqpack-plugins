return {
  name = "xbps search remote packages",
  request = {
    action = "search",
    system = "xbps",
    prompt = "rip",
  },
  fakeExec = {
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R -s rip", exitCode = 0, stdout = "[*] ripgrep-14.1.1_1 Recursively search directories for text\n[-] ripgrep-all-0.9_1 Search helper package\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=pkgver ripgrep", exitCode = 0, stdout = "ripgrep-14.1.1_1\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=short_desc ripgrep", exitCode = 0, stdout = "Recursively search directories for text\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=homepage ripgrep", exitCode = 0, stdout = "https://github.com/BurntSushi/ripgrep\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=license ripgrep", exitCode = 0, stdout = "MIT\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=repository ripgrep", exitCode = 0, stdout = "https://repo-default.voidlinux.org/current\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=architecture ripgrep", exitCode = 0, stdout = "x86_64\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R -x ripgrep", exitCode = 0, stdout = "pcre2>=0\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=categories ripgrep", exitCode = 0, stdout = "utilities\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=state ripgrep", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=automatic-install ripgrep", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=hold ripgrep", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=repolock ripgrep", exitCode = 1, stdout = "", stderr = "", success = false },

    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=pkgver ripgrep-all", exitCode = 0, stdout = "ripgrep-all-0.9_1\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=short_desc ripgrep-all", exitCode = 0, stdout = "Search helper package\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=homepage ripgrep-all", exitCode = 0, stdout = "https://example.test/ripgrep-all\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=license ripgrep-all", exitCode = 0, stdout = "MIT\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=repository ripgrep-all", exitCode = 0, stdout = "https://repo-default.voidlinux.org/current\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=architecture ripgrep-all", exitCode = 0, stdout = "x86_64\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R -x ripgrep-all", exitCode = 0, stdout = "ripgrep>=0\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=categories ripgrep-all", exitCode = 0, stdout = "utilities\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=state ripgrep-all", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=automatic-install ripgrep-all", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=hold ripgrep-all", exitCode = 1, stdout = "", stderr = "", success = false },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=repolock ripgrep-all", exitCode = 1, stdout = "", stderr = "", success = false }
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "ripgrep",
    resultVersion = "14.1.1_1",
  }
}
