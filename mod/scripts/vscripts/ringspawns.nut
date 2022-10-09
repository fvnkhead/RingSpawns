global function RingSpawns_Init

struct {
    bool enabled = false
    array<entity> playerRing = []
} file

void function RingSpawns_Init()
{
    file.enabled = GetConVarBool("ringspawns_enabled")

    if (!file.enabled) {
        return
    }

    AddCallback_OnPlayerRespawned(AddPlayerToRing)
    AddCallback_OnClientDisconnected(RemovePlayerFromRing)

    GameMode_SetPilotSpawnpointsRatingFunc(GameRules_GetGameMode(), RateSpawnpoints)
    SetSpawnZoneRatingFunc(DecideSpawnZone)
}


void function PrintRing()
{
    Log("[PrintRing] ----")
    foreach (entity player in file.playerRing) {
        int team = player.GetTeam()
        string alive = IsAlive(player) ? "alive" : "dead"
        string msg = format("[PrintRing] %s (team=%d) (%s)", player.GetPlayerName(), team, alive)
        Log(msg)
    }
    Log("[PrintRing] ----")
}

void function RateSpawnpoints(int checkClass, array<entity> spawnpoints, int team, entity player)
{
    Log("[RateSpawnpoints] spawnpoints.len() = " + spawnpoints.len())

    array<entity> livingFriends = GetLivingFriendsInRing(team)
    if (livingFriends.len() > 0) {
        entity lastSpawnedFriend = livingFriends[0]
        Log("[RateSpawnpoints] rating with a friend: " + lastSpawnedFriend.GetPlayerName())
        RateSpawnpointsWithFriend(checkClass, spawnpoints, team, lastSpawnedFriend)
        return
    }

    array<entity> livingEnemies = GetLivingEnemiesInRing(team)
    if (livingEnemies.len() > 0) {
        Log("[RateSpawnpoints] rating with enemies")
        RateSpawnpointsWithEnemies(checkClass, spawnpoints, team, livingEnemies)
        return
    }

    // just randomize if you're alone
    Log("[RateSpawnpoints] random rating")
    foreach (entity spawnpoint in spawnpoints) {
        float rating = RandomFloat(1.0)
        spawnpoint.CalculateRating(checkClass, team, rating, rating)
    }
}

void function RateSpawnpointsWithFriend(int checkClass, array<entity> spawnpoints, int team, entity friend)
{
    foreach (entity spawnpoint in spawnpoints) {
        float rating = 0 - Distance(spawnpoint.GetOrigin(), friend.GetOrigin())
        spawnpoint.CalculateRating(checkClass, team, rating, rating)
    }
}

void function RateSpawnpointsWithEnemies(int checkClass, array<entity> spawnpoints, int team, array<entity> enemies)
{
    const preferredDist = 3000.0 // around 60 meters from avg enemy pos

    vector avgEnemyPos = AverageOrigin(enemies)
    foreach (entity spawnpoint in spawnpoints ) {
        float dist = Distance(spawnpoint.GetOrigin(),avgEnemyPos)
        float divider = fabs(preferredDist - dist)
        divider = divider == 0.0 ? 1.0 : divider
        float rating = preferredDist / divider

        spawnpoint.CalculateRating(checkClass, team, rating, rating)
    }
}

entity function DecideSpawnZone(array<entity> spawnzones, int team)
{
    Log("[DecideSpawnZone] spawnzones.len() = " + spawnzones.len())
    return spawnzones[RandomInt(spawnzones.len())]
}

void function AddPlayerToRing(entity player)
{
    if (file.playerRing.contains(player)) {
        file.playerRing.remove(file.playerRing.find(player))
    }

    file.playerRing.insert(0, player)
    PrintRing()
}

void function RemovePlayerFromRing(entity player)
{
    if (file.playerRing.contains(player)) {
        file.playerRing.remove(file.playerRing.find(player))
    }

    PrintRing()
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

void function Log(string msg)
{
    print("[RingSpawns] " + msg)
}
