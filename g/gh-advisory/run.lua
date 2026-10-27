plugin = {}

local PLUGIN_NAME = "GitHub Advisory"
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
    ecosystemScopes = { "all-github-advisory-ecosystems" },
    networkScopes = {
      { host = "codeload.github.com", scheme = "https", pathPrefix = "/github/advisory-database/" },
      { host = "github.com", scheme = "https", pathPrefix = "/github/advisory-database/" },
    },
    privilegeLevel = "none",
  }
end

function plugin.getRequirements()
  return {}
end

function plugin.getCategories()
  return { "Security", "Security Provider", "GitHub Advisory" }
end

function plugin.getMissingPackages(packages)
  local missing = {}
  for _, package in ipairs(packages or {}) do
    table.insert(missing, package)
  end
  return missing
end

function plugin.install(context, packages)
  begin_step(context, "sync GitHub advisories")
  emit_event(context, "installed", packages or {})
  tx_success(context)
  return true
end

function plugin.installLocal(context, path)
  tx_failed(context, "GitHub Advisory security provider does not support local installs")
  return false
end

function plugin.remove(context, packages)
  tx_failed(context, "GitHub Advisory security provider does not remove advisories through plugin runtime")
  return false
end

function plugin.update(context, packages)
  begin_step(context, "refresh GitHub advisories")
  emit_event(context, "updated", packages or {})
  tx_success(context)
  return true
end

function plugin.list(context)
  local items = {
    { name = "github-advisories", version = PLUGIN_VERSION, type = "security-database", summary = "Sync all ecosystems available in GitHub Advisory Database" },
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
  if normalized == "" or string.find("github-advisories", normalized, 1, true) ~= nil or string.find("github", normalized, 1, true) ~= nil then
    table.insert(items, {
      name = "github-advisories",
      version = PLUGIN_VERSION,
      type = "security-database",
      summary = "Sync all ecosystems exposed by GitHub Advisory Database",
    })
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
    type = "security-database",
    summary = "GitHub Advisory Database sync target",
    description = "Imports OSV-formatted advisories from github/advisory-database into ReqPack shared vulnerability indexes for requested ecosystems.",
  }
  emit_event(context, "informed", item)
  return item
end

function plugin.shutdown()
  return true
end

return plugin
