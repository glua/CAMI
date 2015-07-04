--[[

Structures:
	CAMI_USERGROUP, defines the charactaristics of a usergroup:
	{
		Name = (string, the name of the usergroup),
		Inherits = (string, the name of the usergroup this usergroup inherits from)
	}

	CAMI_PRIVILEGE, defines the charactaristics of a privilege:
	{
		Name = (string, the name of the privilege),
		MinAccess = (string, one of the following three: user/admin/superadmin),
		HasAccess = (optional, function(privilege :: CAMI_PRIVILEGE, actor :: Player, target :: Player) :: bool,
					 function that decides whether a player can execute this privilege.)
	}
]]

-- Version number in YearMonthDay format
local version = 20150704

if CAMI and CAMI.Version > version then return end

CAMI = CAMI or {}
CAMI.Version = version


local usergroups = {}
local privileges = {}

--[[
CAMI.RegisterUsergroup
	Registers a usergroup with CAMI.
	Parameters:
		usergroup: CAMI_USERGROUP (see CAMI_USERGROUP structure)
]]
function CAMI.RegisterUsergroup(usergroup)
	usergroups[usergroup.Name] = usergroup

	return usergroup
end

-- Default user usergroup
CAMI.RegisterUsergroup{
	Name = "user",
	Inherits = "user"
}

-- Default admin usergroup
CAMI.RegisterUsergroup{
	Name = "admin",
	Inherits = "admin"
}

-- Default superadmin usergroup
CAMI.RegisterUsergroup{
	Name = "superadmin",
	Inherits = "superadmin"
}

--[[
CAMI.UnregisterUsergroup
	Unregisters a usergroup from CAMI. This will call a hook that will notify
	all other admin mods of the removal.

	Call only when the usergroup is to be permanently removed.
]]
function CAMI.UnregisterUsergroup(usergroupName)
	if not usergroups[usergroupName] then return false end

	usergroups[usergroupName] = nil

	return true
end

--[[
CAMI.GetUsergroup
	Receives information about a usergroup.
	Returns nil when the usergroup does not exist.
]]
function CAMI.GetUsergroup(usergroupName)
	return usergroups[usergroupName]
end