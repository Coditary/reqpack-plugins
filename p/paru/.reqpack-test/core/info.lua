return {
  name = "paru info",
  request = {
    action = "info",
    system = "paru",
    prompt = "ripgrep-all",
  },
  fakeExec = {
    {
      match = "command -v paru >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "NO_COLOR=1 LC_ALL=C LANG=C LANGUAGE=C SHELL=/bin/sh HOME=\"$HOME\" XDG_CONFIG_HOME=\"$HOME/.config\" XDG_CACHE_HOME=\"$HOME/.cache\" XDG_DATA_HOME=\"$HOME/.local/share\" XDG_STATE_HOME=\"$HOME/.local/state\" AURDEST=\"$HOME/.cache/paru\" paru -Si ripgrep-all",
      exitCode = 0,
      stdout = "Repository      : aur\nName            : ripgrep-all\nVersion         : 0.10.6-1\nDescription     : ripgrep, but also search in PDFs and Office documents\nArchitecture    : any\nURL             : https://example.org/ripgrep-all\nAUR URL         : https://aur.archlinux.org/packages/ripgrep-all\nLicenses        : MIT\nDepends On      : ripgrep  poppler\nMaintainer      : alice\nFirst Submitted : 1700000000\nLast Modified   : 1700003600\nInstalled Size  : 12.0 MiB\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "informed" },
    eventPayloads = {
      informed = "{architecture=any, conflicts=<lua-value>, dependencies=<lua-value>, description=ripgrep, but also search in PDFs and Office documents, homepage=https://example.org/ripgrep-all, installedSize=12.0 MiB, latestVersion=0.10.6-1, license=MIT, maintainer=alice, name=ripgrep-all, optionalDependencies=<lua-value>, packageId=ripgrep-all, packageType=package, provides=<lua-value>, publishedAt=1700000000, repository=aur, size=12.0 MiB, sourceUrl=https://aur.archlinux.org/packages/ripgrep-all, summary=ripgrep, but also search in PDFs and Office documents, type=package, updatedAt=1700003600, version=0.10.6-1}"
    },
    resultCount = 1,
    resultName = "ripgrep-all",
    resultVersion = "0.10.6-1",
  }
}
