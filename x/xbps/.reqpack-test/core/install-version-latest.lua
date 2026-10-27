return {
  name = "xbps install latest omits comparator expression",
  request = {
    action = "install",
    system = "xbps",
    packages = {
      { name = "ripgrep", version = "latest" }
    },
  },
  fakeExec = {
    { match = "command -v xbps-install >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "command -v xbps-remove >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "command -v xbps-query >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "command -v xbps-rindex >/dev/null 2>&1", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "xbps-install -S -y -c /home/Leodoras/.cache/reqpack/xbps/cache ripgrep", exitCode = 0, stdout = "ripgrep-14.1.0_1: installed successfully.\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache --property=pkgver ripgrep", exitCode = 0, stdout = "ripgrep-14.1.0_1\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache --property=short_desc ripgrep", exitCode = 0, stdout = "Recursively search directories for text\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache --property=homepage ripgrep", exitCode = 0, stdout = "https://github.com/BurntSushi/ripgrep\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache --property=license ripgrep", exitCode = 0, stdout = "MIT\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache --property=repository ripgrep", exitCode = 0, stdout = "https://repo-default.voidlinux.org/current\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache --property=architecture ripgrep", exitCode = 0, stdout = "x86_64\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -x ripgrep", exitCode = 0, stdout = "pcre2>=0\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache --property=categories ripgrep", exitCode = 0, stdout = "utilities\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache --property=state ripgrep", exitCode = 0, stdout = "installed\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache --property=automatic-install ripgrep", exitCode = 0, stdout = "no\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache --property=hold ripgrep", exitCode = 0, stdout = "no\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache --property=repolock ripgrep", exitCode = 0, stdout = "no\n", stderr = "", success = true },
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=pkgver ripgrep", exitCode = 0, stdout = "ripgrep-14.1.0_1\n", stderr = "", success = true },
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
    { match = "xbps-query -c /home/Leodoras/.cache/reqpack/xbps/cache -R --property=repolock ripgrep", exitCode = 1, stdout = "", stderr = "", success = false }
  },
  expect = {
    success = true,
    events = { "installed", "success" },
  }
}
