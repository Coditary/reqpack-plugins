# API

## Behavior Summary

- `install()`: uses existing `MaintenanceTool` or bootstraps Qt root with Qt Online Installer
- `installLocal()`: installs `.qbsp` or `.7z` compressed repositories with `--install-compressed-repository`
- `remove()`: removes exact Qt package ids with `remove`
- `update()`: updates all or selected package ids with `update`
- `list()`: parses installed package blocks from `list`
- `outdated()`: parses update XML from `check-updates`
- `search()`: parses package XML from `--type package search`
- `info()`: merges exact installed and remote search data for one package id

## Supported Flags

- `data-root=/path`
- `maintenance-tool=/path`
- `installer-url=https://...`
- `mirror=https://...`
- `repository=https://...`
- `temp-repository=https://...`
- `email=user@example.com`
- `pw=secret`

## Notes

- shared Qt installation root and metadata cache live under one ReqPack-managed data root
- `search()` can use regex prompt; blank prompt becomes `.*`
- package ids are exact and case-sensitive
