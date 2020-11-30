--[[
CAMI - Common Admin Mod Interface.
Copyright 2020 CAMI Contributors

Makes admin mods intercompatible and provides an abstract privilege interface
for third party addons.

Follows the specification on this page:
https://github.com/glua/CAMI/blob/master/README.md

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

-- Version number in YearMonthDay format.
local version = 20201130

if CAMI and CAMI.Version >= version then return end

CAMI = CAMI or {}
CAMI.Version = version


--- @class CAMI_USERGROUP
--- defines the charactaristics of a usergroup
--- @field Name string @The name of the usergroup
--- @field Inherits string @The name of the usergroup this usergroup inherits from

--- @class CAMI_PRIVILEGE
--- defines the charactaristics of a privilege
--- @field Name string @The name of the privilege
--- @field MinAccess "'user'" | "'admin'" | "'superadmin'"
--- @field Description string | nil @Optional text describing the purpose of the privilege
local CAMI_PRIVILEGE = {}
--- Optional function that decides whether a player can execute this privilege,
--- optionally on another player (target).
--- @param actor GPlayer
--- @param target GPlayer | nil
function CAMI_PRIVILEGE:HasAccess(actor, target)
end

--- Contains the registered CAMI_USERGROUP usergroup structures.
--- Indexed by usergroup name.
--- @type CAMI_USERGROUP[]
local usergroups = CAMI.GetUsergroups and CAMI.GetUsergroups() or {
    user = {
        Name = "user",
        Inherits = "user"
    },
    admin = {
        Name = "admin",
        Inherits = "user"
    },
    superadmin = {
        Name = "superadmin",
        Inherits = "admin"
    }
}

--- Contains the registered CAMI_PRIVILEGE privilege structures.
--- Indexed by privilege name.
--- @type CAMI_PRIVILEGE[]
local privileges = CAMI.GetPrivileges and CAMI.GetPrivileges() or {}

--- Registers a usergroup with CAMI.
---
--- Use the source parameter to make sure CAMI.RegisterUsergroup function and
--- the CAMI.OnUsergroupRegistered hook don't cause an infinite loop
--- @param usergroup CAMI_USERGROUP @The structure for the usergroup you want to register
--- @param source any @Identifier for your own admin mod. Can be anything.
--- @return CAMI_USERGROUP @The usergroup given as an argument
function CAMI.RegisterUsergroup(usergroup, source)
    usergroups[usergroup.Name] = usergroup

    hook.Call("CAMI.OnUsergroupRegistered", nil, usergroup, source)
    return usergroup
end

--- Unregisters a usergroup from CAMI. This will call a hook that will notify
--- all other admin mods of the removal.
---
--- Call only when the usergroup is to be permanently removed.
---
--- Use the source parameter to make sure CAMI.UnregisterUsergroup function and
--- the CAMI.OnUsergroupUnregistered hook don't cause an infinite loop
--- @param usergroupName string @The name of the usergroup.
--- @param source any @Identifier for your own admin mod. Can be anything.
--- @return boolean @Whether the unregistering succeeded.
function CAMI.UnregisterUsergroup(usergroupName, source)
    if not usergroups[usergroupName] then return false end

    local usergroup = usergroups[usergroupName]
    usergroups[usergroupName] = nil

    hook.Call("CAMI.OnUsergroupUnregistered", nil, usergroup, source)

    return true
end

--- Retrieves all registered usergroups.
--- @return CAMI_USERGROUP[] @Table of CAMI_USERGROUP, indexed by their names.
function CAMI.GetUsergroups()
    return usergroups
end

--- Receives information about a usergroup.
--- @param usergroupName string
--- @return CAMI_USERGROUP | nil @Returns nil when the usergroup does not exist.
function CAMI.GetUsergroup(usergroupName)
    return usergroups[usergroupName]
end

--- Returns true when usergroupName1 inherits usergroupName2.
--- Note that usergroupName1 does not need to be a direct child.
--- Every usergroup trivially inherits itself.
--- @param usergroupName1 string @The name of the usergroup that is queried.
--- @param usergroupName2 string @The name of the usergroup of which is queried whether usergroupName inherits from.
--- @return boolean @Whether usergroupName1 inherits usergroupName2.
function CAMI.UsergroupInherits(usergroupName1, usergroupName2)
    repeat
        if usergroupName1 == usergroupName2 then return true end

        usergroupName1 = usergroups[usergroupName1] and
                         usergroups[usergroupName1].Inherits or
                         usergroupName1
    until not usergroups[usergroupName1] or
          usergroups[usergroupName1].Inherits == usergroupName1

    -- One can only be sure the usergroup inherits from user if the
    -- usergroup isn't registered.
    return usergroupName1 == usergroupName2 or usergroupName2 == "user"
end

--- All usergroups must eventually inherit either user, admin or superadmin.
--- Regardless of what inheritance mechism an admin may or may not have, this
--- always applies.
---
--- This method always returns either user, admin or superadmin, based on what
--- usergroups eventually inherit.
--- @param usergroupName string @The name of the usergroup of which the root of inheritance is requested
--- @return string @The name of the root usergroup (either user, admin or superadmin)
function CAMI.InheritanceRoot(usergroupName)
    if not usergroups[usergroupName] then return end

    local inherits = usergroups[usergroupName].Inherits
    while inherits ~= usergroups[usergroupName].Inherits do
        usergroupName = usergroups[usergroupName].Inherits
    end

    return usergroupName
end

--- Registers a privilege with CAMI.
---
--- **Note**: do NOT register all your admin mod's privileges with this function!
--- This function is for third party addons to register privileges
--- with admin mods, not for admin mods sharing the privileges amongst one
--- another.
--- @param privilege CAMI_PRIVILEGE
--- @return CAMI_PRIVILEGE @The privilege given as argument.
function CAMI.RegisterPrivilege(privilege)
    privileges[privilege.Name] = privilege

    hook.Call("CAMI.OnPrivilegeRegistered", nil, privilege)

    return privilege
end

--- Unregisters a privilege from CAMI. This will call a hook that will notify
--- all other admin mods of the removal.
---
--- Call only when the privilege is to be permanently removed.
--- @param privilegeName string @The name of the privilege.
--- @return boolean @Whether the unregistering succeeded.
function CAMI.UnregisterPrivilege(privilegeName)
    if not privileges[privilegeName] then return false end

    local privilege = privileges[privilegeName]
    privileges[privilegeName] = nil

    hook.Call("CAMI.OnPrivilegeUnregistered", nil, privilege)

    return true
end

--- Retrieves all registered privileges.
--- @return CAMI_PRIVILEGE[] @Table of CAMI_PRIVILEGE, indexed by their names.
function CAMI.GetPrivileges()
    return privileges
end

--- Receives information about a privilege.
--- @param privilegeName string
--- @return CAMI_PRIVILEGE | nil
function CAMI.GetPrivilege(privilegeName)
    return privileges[privilegeName]
end

-- Default access handler
local defaultAccessHandler = {["CAMI.PlayerHasAccess"] =
    function(_, actorPly, privilegeName, callback, targetPly, extraInfoTbl)
        -- The server always has access in the fallback
        if not IsValid(actorPly) then return callback(true, "Fallback.") end

        local priv = privileges[privilegeName]

        local fallback = extraInfoTbl and (
            not extraInfoTbl.Fallback and actorPly:IsAdmin() or
            extraInfoTbl.Fallback == "user" and true or
            extraInfoTbl.Fallback == "admin" and actorPly:IsAdmin() or
            extraInfoTbl.Fallback == "superadmin" and actorPly:IsSuperAdmin())


        if not priv then return callback(fallback, "Fallback.") end

        local hasAccess =
            priv.MinAccess == "user" or
            priv.MinAccess == "admin" and actorPly:IsAdmin() or
            priv.MinAccess == "superadmin" and actorPly:IsSuperAdmin()

        if hasAccess and priv.HasAccess then
            hasAccess = priv:HasAccess(actorPly, targetPly)
        end

        callback(hasAccess, "Fallback.")
    end,
    ["CAMI.SteamIDHasAccess"] =
    function(_, _, _, callback)
        callback(false, "No information available.")
    end
}

--- @class CAMI_ACCESS_EXTRA_INFO
--- @field Fallback "'user'" | "'admin'" | "'superadmin'" @When no admin mod replies, the decision is based on the admin status of the user. Defaults to admin if not given.
--- @field IgnoreImmunity boolean @Ignore any immunity mechanisms an admin mod might have.
--- @field CommandArguments table @Extra arguments that were given to the privilege command.

--- Queries whether a certain player has the right to perform a certain action.
---
--- Give an explicit nil for callback to get an answer immediately
--- **Important note**: May throw an error when the admin mod doesn't give an answer immediately!
---
--- @param actorPly GPlayer @The player of which is requested whether they have the privilege.
--- @param privilegeName string @The name of the privilege.
--- @param callback fun(hasAccess: boolean, reason: string|nil) @This function will be called with the answer
--- @param targetPly GPlayer | nil @The player on which the privilege is executed.
--- @param extraInfoTbl CAMI_ACCESS_EXTRA_INFO | nil @Table containing extra information.
--- @return boolean | nil @Whether the player has access
--- @return string | nil @The reason why a player does or does not have access.
function CAMI.PlayerHasAccess(actorPly, privilegeName, callback, targetPly,
extraInfoTbl)
    local hasAccess, reason = nil, nil
    local callback_ = callback or function(hA, r) hasAccess, reason = hA, r end

    hook.Call("CAMI.PlayerHasAccess", defaultAccessHandler, actorPly,
        privilegeName, callback_, targetPly, extraInfoTbl)

    if callback ~= nil then return end

    if hasAccess == nil then
        local err = [[The function CAMI.PlayerHasAccess was used to find out
        whether Player %s has privilege "%s", but an admin mod did not give an
        immediate answer!]]
        error(string.format(err,
            actorPly:IsPlayer() and actorPly:Nick() or tostring(actorPly),
            privilegeName))
    end

    return hasAccess, reason
end

--- Finds the list of currently joined players who have the right to perform a
--- certain action.
---
--- **NOTE**: this function will NOT return an immediate result!
--- The result is in the callback!
--- @param privilegeName string @The name of the privilege.
--- @param callback fun(players: GPlayer[]) @This function will be called with the list of players with access.
--- @param targetPly GPlayer | nil @The player on which the privilege is executed.
--- @param extraInfoTbl CAMI_ACCESS_EXTRA_INFO | nil @Table containing extra information.
function CAMI.GetPlayersWithAccess(privilegeName, callback, targetPly,
extraInfoTbl)
    local allowedPlys = {}
    local allPlys = player.GetAll()
    local countdown = #allPlys

    local function onResult(ply, hasAccess, _)
        countdown = countdown - 1

        if hasAccess then table.insert(allowedPlys, ply) end
        if countdown == 0 then callback(allowedPlys) end
    end

    for _, ply in ipairs(allPlys) do
        CAMI.PlayerHasAccess(ply, privilegeName,
            function(...) onResult(ply, ...) end,
            targetPly, extraInfoTbl)
    end
end

--- @class CAMI_STEAM_ACCESS_EXTRA_INFO
--- @field IgnoreImmunity boolean @Ignore any immunity mechanisms an admin mod might have.
--- @field CommandArguments table @Extra arguments that were given to the privilege command.

--- Queries whether a player with a steam ID has the right to perform a certain
--- action.
--- Note: the player does not need to be in the server for this to
--- work.
---
--- **Note**: this function does NOT return an immediate result!
--- The result is in the callback!
--- @param actorSteam string | nil @The SteamID of the player of which is requested whether they have the privilege.
--- @param privilegeName string @The name of the privilege.
--- @param callback fun(hasAccess: boolean, reason: string|nil) @This function will be called with the answer
--- @param targetSteam string | nil @The SteamID of the player on which the privilege is executed.
--- @param extraInfoTbl CAMI_STEAM_ACCESS_EXTRA_INFO | nil @Table containing extra information.
function CAMI.SteamIDHasAccess(actorSteam, privilegeName, callback,
targetSteam, extraInfoTbl)
    hook.Call("CAMI.SteamIDHasAccess", defaultAccessHandler, actorSteam,
        privilegeName, callback, targetSteam, extraInfoTbl)
end

--- Signify that your admin mod has changed the usergroup of a player. This
--- function communicates to other admin mods what it thinks the usergroup
--- of a player should be.
---
--- Listen to the hook to receive the usergroup changes of other admin mods.
--- @param ply GPlayer @The player for which the usergroup is changed
--- @param old string @The previous usergroup of the player.
--- @param new string @The new usergroup of the player.
--- @param source any @Identifier for your own admin mod. Can be anything.
function CAMI.SignalUserGroupChanged(ply, old, new, source)
    hook.Call("CAMI.PlayerUsergroupChanged", nil, ply, old, new, source)
end

--- Signify that your admin mod has changed the usergroup of a disconnected
--- player. This communicates to other admin mods what it thinks the usergroup
--- of a player should be.
---
--- Listen to the hook to receive the usergroup changes of other admin mods.
--- @param steamId string @The steam ID of the player for which the usergroup is changed
--- @param old string @The previous usergroup of the player.
--- @param new string @The new usergroup of the player.
--- @param source any @Identifier for your own admin mod. Can be anything.
function CAMI.SignalSteamIDUserGroupChanged(steamId, old, new, source)
    hook.Call("CAMI.SteamIDUsergroupChanged", nil, steamId, old, new, source)
end
