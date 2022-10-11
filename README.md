RingSpawns
================================================================================

A different spawn algorithm for Northstar. (work in progress)

Name
--------------------------------------------------------------------------------

It's called _RingSpawns_ because you spawn near your most recently spawned
teammate, and the next teammate who dies spawns near you, and so on.

Goals
--------------------------------------------------------------------------------

 1. Not spawning so close to enemies you die instantly
 2. Not spawning so far from enemies you have to run across the map
 3. Not playing in the same area of the map for the whole match
 4. Making big maps fun to play even with just a few players

How the goals are achieved
--------------------------------------------------------------------------------

### Not spawning close to enemies

There is a minimum enemy distance of 20 meters at spawn, which should avoid
very close spawns.

### Not spawning far from enemies

You spawn near your _most recently_ spawned teammate, which,
on the average, puts you close to your team where the action is occurring.
If there are no teammates alive or in the game, the algorithm tries to put
you at a 60 meter distance from the average enemy position.

### Not playing in the same area

When spawns depend on other players' positions and every player spawns near
their previously spawned teammate, the fights tend to slowly shift around the
map in interesting ways, sometimes occurring in non-standard locations like
the backyard area on Exoplanet, or the dock area on Angel City.

### Making big maps fun with few players

Since spawns depend on your teammates, you spawn close to your friends, and
same for the enemies. This means 2v2 or 3v3 on a big map like Angel City
can still be entertaining, where both teams fight in a smaller area of the map.
The minimap "spawn zone" indicator also adjusts to the average team location at
every death and respawn, which means it's easier to find your enemies.

Caveats
--------------------------------------------------------------------------------

 * This affects pilot spawns only, titans are unaffected
 * Has only been tested on Pilots vs. Pilots
 * TF2 and Northstar add some randomization to spawns, so it's hard to write a very accurate algorithm

ConVars
--------------------------------------------------------------------------------

See `mod.json` for what to tune and why.
