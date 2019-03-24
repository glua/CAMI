# Introduction
The Common Admin Mod Interface (CAMI) aims to solve two problems: admin mod intercompatibility and the inability of addons to hook into the privilege systems that many admin mods have. The two problems are detailed in the next paragraphs.

The biggest source of the admin mod incompatibility problem is usergroups. One admin mod creates a usergroup that another admin mod does not know of. Two admin mods thinking a player have different usergroups can cause quite a few bugs and confusion.

The second problem pertains third party addons. Most of them offer features that only admins or superadmins are allowed to use. Server owners might however want to customise these privileges. For example, they might want their user based `moderator` to be allowed to spawn a _PlayX_ screen entity. Many admin mods have an advanced privilege system, it would be a shame if all third party mods are limited to just user/admin/superadmin.

The solution is inspired by the [Common Prop Protection Interface](ulyssesmod.net/archive/CPPI_v1-3.pdf) (CPPI) by Ulysses. This document describes a common interface that every admin mod implements and uses so that information can be exchanged in a universal format.

# Goals
CAMI has two goals:
- Unify interfaces between existing admin mods to allow them to coexist.
- Provide an optional interface to third party addons to create and query privileges. One that works even if no admin mod is installed.

The following two sections describe what CAMI will do with usergroups and privileges to meet these goals.

# Usergroups
Usergroups are an existing concept in the Source engine. There are three default usergroups: `user`, `admin` and `superadmin`.  
Every player has exactly one usergroup. Custom usergroups must inherit either another custom group or a default usergroup. By default, `admin` inherits from `user` and `superadmin` inherits from `admin`. Mathematically, inheritance is transitive, so `superadmin` also inherits from `user`.

For convenience, inheritance is not verified, so you need not worry about the order in which usergroups are registered. Admin mods might not have a concept of inheritance in usergroups. In that case, all usergroups are to be registered as inheriting `user`. That should give the highest compatibility with other admin mods.

# Privileges
A privilege is a witness of permission to perform one or more actions. Privileges can be registered by third party mods to the currently installed admin mod(s). These third party mods can then query the admin mod(s) to see whether a player has the registered privilege. Note that the privilege part of CAMI is optional for admin mods. Fortunately, this is transparent for the third party mod: when no admin mod is installed that implements CAMI privileges, CAMI itself will have a default fallback based on whether the player is a user, admin or superadmin. This means CAMI is useful for third party addons even when no admin mod is installed.

# API
All functions, hooks and data structures are shared, which thus exist in both the client and server realm.

## Data structures

### `CAMI_USERGROUP`
- `Name` :: `string`
- `Inherits` :: `string`

### `CAMI_PRIVILEGE`
- `Name` :: `string`
- `MinAccess` :: `string`
- _(optional)_ `Description` :: `string`
- _(optional)_ `HasAccess` :: `function(privilege :: CAMI_PRIVILEGE, actor :: Player, target :: Player) :: bool, string`

## Functions
This section lists the functions that CAMI provides. It should be used as a quick reference. Detailed descriptions of the functions can be found in the [sh_cami.lua source file](./lua/autorun/sh_cami.lua).

The ‘::’ indicates the types of the parameters and the return values of the functions. Parameters in square brackets are optional.

```lua
CAMI.UsergroupInherits(usergroupName1 :: string, usergroupName2 :: string) :: bool

CAMI.InheritanceRoot(usergroupName) :: string

CAMI.RegisterUsergroup(usergroup :: CAMI_USERGROUP, source :: any) :: CAMI_USERGROUP

CAMI.UnregisterUsergroup(name :: string, source :: any) :: bool

CAMI.GetUsergroup(usergroupName :: string) :: CAMI_USERGROUP

CAMI.RegisterPrivilege(privilege :: CAMI_PRIVILEGE) :: CAMI_PRIVILEGE

CAMI.UnregisterPrivilege(name :: string) :: bool

CAMI.GetPrivilege(name :: string) :: CAMI_PRIVILEGE

CAMI.PlayerHasAccess(actor :: Player, privilege :: string, callback :: function(bool,
string)[, target :: Player, extraInfo :: table]) :: nil

CAMI.GetPlayersWithAccess(privilege :: string, callback :: function(table)[, target :: Player, extraInfo :: Table]) :: nil

CAMI.SteamIDHasAccess(actor :: SteamID, privilege :: string, callback :: function(bool, string)[, target :: SteamID, extraInfo :: table]) :: nil

CAMI.GetUsergroups() :: [CAMI_USERGROUP]

CAMI.GetPrivileges() :: [CAMI_PRIVILEGE]

CAMI.SignalUserGroupChanged(ply :: Player, old :: string, new :: string, source :: any)

CAMI.SignalSteamIDUserGroupChanged(steamId :: string , old :: string, new :: string, source :: any)
```

# Hooks
This section provides a list of hooks that CAMI calls. The types in the parentheses indicate the types of values they give the functions in the hook. When a hook is given a type, you are requested to return a value within the hook. E.g. in `CAMI.PlayerHasAccess` and `CAMI.SteamIDHasAccess`, true is to be returned when the admin mod decides whether a player has the privilege. Not returning a value will defer the decision to another admin mod or eventually CAMI itself.

```lua
CAMI.OnUsergroupRegistered(CAMI_USERGROUP)

CAMI.OnUsergroupUnregistered(CAMI_USERGROUP)

CAMI.OnPrivilegeRegistered(CAMI_PRIVILEGE)

CAMI.OnPrivilegeUnregistered(CAMI_PRIVILEGE)

CAMI.PlayerHasAccess(actor :: Player, privilege :: string, callback :: function(bool, string), target :: Player, extraInfo :: table) :: bool/nil

CAMI.SteamIDHasAccess(actor :: SteamID, privilege :: string, callback :: function(bool, string), target :: Player, extraInfo :: table) :: bool/nil

CAMI.PlayerUsergroupChanged(ply :: Player, from :: string, to :: string, source :: any)

CAMI.SteamIDUsergroupChanged(steamId :: string, from :: string, to :: string, source :: any)
```

# What to implement
Both admin mods and third party addons are to ship the [sh_cami.lua source file](./lua/autorun/sh_cami.lua), shared.  
Alongside with that, the following things should be implemented:

## Admin mods
Please perform the following steps for both the server and the client. Clients need to be in sync with the server. Bugs in CAMI supporting addons are known to occur specifically when clients don’t know they have the right CAMI privileges to perform certain actions.

- Register custom usergroups with `CAMI.RegisterUsergroup` (not `user`/`admin`/`superadmin`)
- Register the removal of custom usergroups with `CAMI.UnregisterUsergroup.`
- Listen to other admin mods creating usergroups with the `CAMI.OnUsergroupRegistered` and `CAMI.OnUsergroupUnregistered` hooks
  - Your admin mod might load after others. When loading, check if new usergroups were created earlier with the `CAMI.GetUsergroups()` function.
- Call `CAMI.SignalUserGroupChanged` when a player’s usergroup is changed through your admin mod. Note: this will cause all admin mods to store the new usergroup of the player. As such it should not be called e.g. when simply receiving a player’s usergroup from a database on InitialSpawn. Call it when it is actually changed.
- Hook to `CAMI.PlayerUsergroupChanged` so your admin mod does not go out of sync with changes made in other admin mods. Note that this hook is called when `CAMI.SignalUserGroupChanged` is called. Keep that in mind when calling that function yourself. You can prevent things from being saved twice using the `source` parameter of the `CAMI.SignalUserGroupChanged` function.
- _(optional, strongly recommended)_ Hook to `CAMI.OnPrivilegeRegistered,` this way you can let your admin mod administrate the permissions added by third party mods.
  - Your admin mod might load after others. When loading, check if new privileges were created earlier with the `CAMI.GetPrivileges()` function.
- _(optional)_ Hook to `CAMI.OnPrivilegeUnregistered.` Some third party mods might want to remove privileges once they have become redundant.
- _(optional, strongly recommended)_ Hook to `CAMI.PlayerHasAccess.` This hook allows third party addons to check whether a certain player has a privilege that they have registered. you can probably use existing logic here. Make sure to return true when your admin mod makes a decision.
- _(optional)_ Hook to `CAMI.SteamIDHasAccess` if the admin mod supports offline access queries. Make sure to return true when your admin mod makes a decision.
- **DO NOT** register the admin mod’s privileges (registering privileges is for third party mods, not for sharing privileges between admin mods)
## Third party addons
- Register custom privileges with `CAMI.RegisterPrivilege`.
- _(optional)_ Unregister custom privilege with `CAMI.UnregisterPrivilege` when one of your privileges has become redundant.
- Call `CAMI.PlayerHasAccess` to see whether a player has a privilege.
