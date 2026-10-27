# API

## Actions

### install

Runs `mmc --make --install-prefix <prefix> lib<name>.install` in each requested source directory.

### installLocal

Same behavior as `install`, using request `localPath` as source directory.

### remove

Removes tracked library record and deletes matching files under ReqPack-owned install prefix only.

### update

Reinstalls tracked libraries from local source trees using the same `mmc --make --install-prefix` flow.

### list

Lists tracked Mercury libraries and reports install-prefix metadata.

### outdated

Returns empty list.

### search

Searches tracked library records locally by package id and source path.

### info

Returns tracked library metadata plus consumer hints for `--mld` and `--ml`.
