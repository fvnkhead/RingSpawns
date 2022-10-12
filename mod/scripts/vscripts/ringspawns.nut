global function RingSpawns_Init

// approx. 1 meter in hammer units
const METER_MULTIPLIER = 52.5

struct {
    bool enabled
    float minEnemyDist
    float friendDist
    float oneVsXDist
    float lfMapDistFactor

    array<entity> playerRing = []
    table<int, entity> teamMinimapEnts = {}
} file

void function RingSpawns_Init()
{
    file.enabled = GetConVarBool("ringspawns_enabled")

    if (!file.enabled) {
        return
    }

    file.minEnemyDist = GetConVarInt("ringspawns_min_enemy_dist") * METER_MULTIPLIER
    file.friendDist = GetConVarInt("ringspawns_friend_dist") * METER_MULTIPLIER
    file.oneVsXDist = GetConVarInt("ringspawns_1vx_dist") * METER_MULTIPLIER
    file.lfMapDistFactor = GetConVarFloat("ringspawns_lf_map_dist_factor")

    // shorter distances on LF maps
    if (IsLfMap()) {
        file.minEnemyDist *= file.lfMapDistFactor
        file.friendDist *= file.lfMapDistFactor
        file.oneVsXDist *= file.lfMapDistFactor
    }

    AddCallback_OnPlayerRespawned(OnPlayerRespawned_AddPlayerToRing)
    AddCallback_OnClientDisconnected(OnClientDisconnected_RemovePlayerFromRing)

    if (!IsFFAGame()) {
        AddCallback_OnPlayerRespawned(OnPlayerRespawned_UpdateTeamMinimapEnts)
        AddCallback_OnPlayerKilled(OnPlayerKilled_UpdateTeamMinimapEnts)
    }

    // spawn funcs
    GameMode_SetPilotSpawnpointsRatingFunc(GameRules_GetGameMode(), RateSpawnpoints)
    AddSpawnpointValidationRule(CheckMinEnemyDist)
    SetSpawnZoneRatingFunc(DecideSpawnZone)
}


void function RateSpawnpoints(int checkClass, array<entity> spawnpoints, int team, entity player)
{
    // most common case spawn
    array<entity> livingFriends = GetLivingFriendsInRing(team)
    if (livingFriends.len() > 0) {
        entity lastSpawnedFriend = livingFriends[0]
        RateSpawnpointsWithFriend(checkClass, spawnpoints, team, lastSpawnedFriend)
        return
    }

    // 1vX case, less common
    array<entity> livingEnemies = GetLivingEnemiesInRing(team)
    if (livingEnemies.len() > 0) {
        RateSpawnpointsWith1vX(checkClass, spawnpoints, team, livingEnemies)
        return
    }

    // random spawn if you're alone
    foreach (entity spawnpoint in spawnpoints) {
        float rating = RandomFloat(1.0)
        spawnpoint.CalculateRating(checkClass, team, rating, rating)
    }
}

void function RateSpawnpointsWithFriend(int checkClass, array<entity> spawnpoints, int team, entity friend)
{
    foreach (entity spawnpoint in spawnpoints) {
        //float rating = 1000 - Distance(spawnpoint.GetOrigin(), friend.GetOrigin())
        float rating = ScoreLocationsByPreferredDist(spawnpoint.GetOrigin(), friend.GetOrigin(), file.friendDist)
        spawnpoint.CalculateRating(checkClass, team, rating, rating)
    }
}

void function RateSpawnpointsWith1vX(int checkClass, array<entity> spawnpoints, int team, array<entity> enemies)
{
    vector avgEnemyPos = AverageOrigin(enemies)
    foreach (entity spawnpoint in spawnpoints) {
        float rating = ScoreLocationsByPreferredDist(spawnpoint.GetOrigin(), avgEnemyPos, file.oneVsXDist)

        spawnpoint.CalculateRating(checkClass, team, rating, rating)
    }
}

// the closer the distance between a and b is to preferred, the higher the returned score
float function ScoreLocationsByPreferredDist(vector a, vector b, float preferredDist)
{
    float dist = Distance(a, b)
    float diff = fabs(preferredDist - dist)
    float rating = preferredDist - diff
    return rating
}

bool function CheckMinEnemyDist(entity spawnpoint, int team)
{
    array<entity> nearbyPlayers = GetPlayerArrayEx("any", TEAM_ANY, TEAM_ANY, spawnpoint.GetOrigin(), file.minEnemyDist)
    foreach (entity player in nearbyPlayers) {
        if (player.GetTeam() != team) {
            return false
        }
    }

    return true
}

// currently this function never gets called and idk why
entity function DecideSpawnZone(array<entity> spawnzones, int team)
{
    Log("[DecideSpawnZone] spawnzones.len() = " + spawnzones.len())
    return spawnzones[RandomInt(spawnzones.len())]
}

void function OnPlayerRespawned_UpdateTeamMinimapEnts(entity player)
{
    UpdateTeamMinimapEnt(TEAM_IMC)
    UpdateTeamMinimapEnt(TEAM_MILITIA)
}

void function OnPlayerKilled_UpdateTeamMinimapEnts(entity victim, entity attacker, var damageInfo)
{
    UpdateTeamMinimapEnt(TEAM_IMC)
    UpdateTeamMinimapEnt(TEAM_MILITIA)
}

void function UpdateTeamMinimapEnt(int team)
{
    if (team in file.teamMinimapEnts) {
        entity oldEnt = file.teamMinimapEnts[team]
        if (IsValid(oldEnt)) {
            oldEnt.Destroy()
        }
    }

    array<entity> livingPlayers = GetPlayerArrayOfTeam_Alive(team)
    if (livingPlayers.len() == 0) {
        return
    }

    vector avgTeamPos = AverageOrigin(livingPlayers)
    entity newEnt = CreatePropScript($"models/dev/empty_model.mdl", avgTeamPos)
    SetTeam(newEnt, team)

	newEnt.Minimap_SetObjectScale(0.01 * livingPlayers.len())
	newEnt.Minimap_SetAlignUpright(true)
	newEnt.Minimap_AlwaysShow(TEAM_IMC, null)
	newEnt.Minimap_AlwaysShow(TEAM_MILITIA, null)
	newEnt.Minimap_SetHeightTracking(true)
	newEnt.Minimap_SetZOrder(MINIMAP_Z_OBJECT)

	if (team == TEAM_IMC) {
		newEnt.Minimap_SetCustomState(eMinimapObject_prop_script.SPAWNZONE_IMC)
	} else {
		newEnt.Minimap_SetCustomState(eMinimapObject_prop_script.SPAWNZONE_MIL)
    }
		
	newEnt.DisableHibernation()

    file.teamMinimapEnts[team] <- newEnt
}

void function OnPlayerRespawned_AddPlayerToRing(entity player)
{
    if (file.playerRing.contains(player)) {
        file.playerRing.remove(file.playerRing.find(player))
    }

    file.playerRing.insert(0, player)
}

void function OnClientDisconnected_RemovePlayerFromRing(entity player)
{
    if (file.playerRing.contains(player)) {
        file.playerRing.remove(file.playerRing.find(player))
    }
}

array<entity> function GetLivingFriendsInRing(int team)
{
    array<entity> livingFriends = []
    foreach (player in file.playerRing) {
        if (player.GetTeam() == team && IsAlive(player)) {
            livingFriends.append(player)
        }
    }

    return livingFriends
}

array<entity> function GetLivingEnemiesInRing(int team)
{
    array<entity> livingEnemies = []
    foreach (player in file.playerRing ) {
        if (player.GetTeam() != team && IsAlive(player)) {
            livingEnemies.append(player)
        }
    }

    return livingEnemies
}

vector function AverageOrigin(array<entity> ents)
{
    
    vector averageOrigin = <0, 0, 0>
    foreach (entity ent in ents) {
        averageOrigin += ent.GetOrigin()
    }
    averageOrigin /= ents.len()

    return averageOrigin
}

//vector function GetTeamBounds(array<entity> players)
//{
//    vector maxPos = <0, 0, 0>
//    vector minPos = <0, 0, 0>
//
//    foreach (entity player in players) {
//        vector playerPos = player.GetOrigin()
//        Log("[GetTeamBounds] playerPos = " + playerPos)
//        maxPos.x = max(maxPos.x, playerPos.x)
//        maxPos.y = max(maxPos.y, playerPos.y)
//        maxPos.z = max(maxPos.z, playerPos.z)
//
//        minPos.x = min(minPos.x, playerPos.x)
//        minPos.y = min(minPos.y, playerPos.y)
//        minPos.z = min(minPos.z, playerPos.z)
//    }
//
//    return maxPos - minPos
//}

array<string> LF_MAPS = [
    "mp_lf_stacks",
    "mp_lf_deck",
    "mp_lf_township",
    "mp_lf_uma",
    "mp_lf_traffic",
    "mp_lf_meadow"
]

bool function IsLfMap()
{
    return LF_MAPS.contains(GetMapName())
}

void function Log(string msg)
{
    print("[RingSpawns] " + msg)
}
