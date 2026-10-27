return {
  name = "io info git plus url target",
  request = {
    action = "info",
    system = "io",
    prompt = "git+https://github.com/IoLanguage/Range.git",
  },
  expect = {
    success = true,
    events = { "informed" },
    resultName = "Range",
    eventPayloads = {
      informed = "{description=Direct GitHub Eerie install target, homepage=https://github.com/IoLanguage/Range, installed=false, name=Range, packageId=Range, packageType=io-addon, repository=https://github.com/IoLanguage/Range, source=https://github.com/IoLanguage/Range.git, sourceUrl=https://github.com/IoLanguage/Range.git, summary=Direct GitHub Eerie install target, type=package}",
    },
  },
}
