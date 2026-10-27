plugin = {}

local PLUGIN_NAME = "Trivy"
local PLUGIN_VERSION = "0.1.0"

local function emit_event(context, name, payload)
  if context == nil or context.events == nil then
    return
  end

  local fn = context.events[name]
  if type(fn) == "function" then
    fn(payload)
  end
end

local function begin_step(context, label)
  if context == nil or context.tx == nil then
    return
  end

  local fn = context.tx.begin_step
  if type(fn) == "function" then
    fn(label)
  end
end

local function tx_success(context)
  if context == nil or context.tx == nil then
    return
  end

  local fn = context.tx.success
  if type(fn) == "function" then
    fn()
  end
end

local function tx_failed(context, message)
  if context == nil or context.tx == nil then
    return
  end

  local fn = context.tx.failed
  if type(fn) == "function" then
    fn(message)
  end
end

local function package_name(package)
  if type(package) == "table" then
    return tostring(package.name or "")
  end
  return tostring(package or "")
end

function plugin.getName()
  return PLUGIN_NAME
end

function plugin.getVersion()
  return PLUGIN_VERSION
end

function plugin.getSecurityMetadata()
  return {
    role = "security-provider",
    capabilities = { "sync" },
    ecosystemScopes = { "maven", "cargo", "deb", "rpm" },
    networkScopes = {
      { host = "ghcr.io", scheme = "https", pathPrefix = "/v2/aquasecurity/trivy-db/" },
      { host = "mirror.gcr.io", scheme = "https", pathPrefix = "/v2/aquasec/trivy-db/" },
    },
    privilegeLevel = "none",
  }
end

function plugin.getRequirements()
  return {}
end

function plugin.getCategories()
  return { "Security", "Security Provider", "Trivy" }
end

function plugin.getMissingPackages(packages)
  local missing = {}
  for _, package in ipairs(packages or {}) do
    table.insert(missing, package)
  end
  return missing
end

function plugin.install(context, packages)
  begin_step(context, "sync Trivy advisories")
  emit_event(context, "installed", packages or {})
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  tx_failed(context, "Trivy security provider does not support local installs")
  return false
end

function plugin.remove(context, packages)
  tx_failed(context, "Trivy security provider does not remove advisories through plugin runtime")
  return false
end

function plugin.update(context, packages)
  begin_step(context, "refresh Trivy advisories")
  emit_event(context, "updated", packages or {})
  tx_success(context)
  return true
end

function plugin.list(context)
  local items = {
    { name = "maven", version = PLUGIN_VERSION, type = "security-ecosystem", summary = "Sync Maven advisories from Trivy DB" },
    { name = "cargo", version = PLUGIN_VERSION, type = "security-ecosystem", summary = "Sync Cargo advisories from Trivy DB" },
    { name = "deb", version = PLUGIN_VERSION, type = "security-ecosystem", summary = "Sync Debian advisories from Trivy DB" },
    { name = "rpm", version = PLUGIN_VERSION, type = "security-ecosystem", summary = "Sync RPM advisories from Trivy DB" },
  }
  emit_event(context, "listed", items)
  return items
end

function plugin.outdated(context)
  emit_event(context, "outdated", {})
  return {}
end

function plugin.search(context, prompt)
  local normalized = string.lower(tostring(prompt or ""))
  local items = {}
  local names = { "maven", "cargo", "deb", "rpm" }
  for _, name in ipairs(names) do
    if normalized == "" or string.find(name, normalized, 1, true) ~= nil then
      table.insert(items, {
        name = name,
        version = PLUGIN_VERSION,
        type = "security-ecosystem",
        summary = "Sync " .. string.upper(name) .. " advisories from configured Trivy DB",
      })
    end
  end
  emit_event(context, "searched", items)
  return items
end

function plugin.info(context, name)
  local target = package_name(name)
  if target == "" then
    return {}
  end

  local item = {
    name = target,
    version = PLUGIN_VERSION,
    type = "security-ecosystem",
    summary = "Trivy vulnerability database sync target",
    description = "Imports advisories for requested ecosystem from Trivy vulnerability database into ReqPack shared vulnerability database.",
  }
  emit_event(context, "informed", item)
  return item
end

function plugin.shutdown()
  return true
end

return plugin
