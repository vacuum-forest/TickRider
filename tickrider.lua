--[[

Tick Rider:
A shadowy flight into the dangerous world of a cyborg who does not exist (soaring on god's wings of spoiled pudding.)

Kurinn takes no responsibility and all of the credit for this abomination!

Version 0.1ß: Feb. 15, 2021

Instructions/Controls:
Press the action key to mount or dismount from a tick. Aim carefully and possibly get a running start? Try hopping from tick to tick, remembering to press action again to grab on.
Pressing and/or holding the mic key will allow the player to perform their best imitation of a tick call, which sould lure some over to you.
Whilst riding a tick, pressing both weapon cycle keys simultaneously will perform some 'gentle persuasion' on the tick and possibly get it to go somewheres else.

]]

Triggers = {}

Game.proper_item_accounting = true

CollectionsUsed = { 3 }		-- For the Ticks!

-- Happy User-friendly-ish Configurables For Easy Relaxation and Prosperity:
-------------------------------------------------------------------------------

maxTickMountDistance = 3.5 	-- Max. distances, angle off player.yaw to attempt mounting a nearby tick
maxTickMountHeight = 2.5
maxTickMountAngle = 90
graspReach = 2
jumpForce = 0.15
verticalCoefficient = 1.25

tickCallDistance = 20		-- Maximum range of the Tick Whistle®

exclusionHeight = 1.5		-- This will attempt to discourage tick infiltration into certain polygons with less vertical span
saddleHeight = 0.375		-- Height of rider.z relative to tick.z
downDraft = 0.015			-- Vertical velocity (down) increment per tick to avoid head-in-void syndrome

spareTicks = 50				-- Always have at least this many free ticks around. (Warning: too many ticks can cause problems, some of which may be /fun/!)

kamikazeOdds = 7			-- 1 in n chance that next tick will be a kamikaze
majorOdds = 5				-- 1 in n chance that next tick that isn't a kamikaze will be a major

tickWrathDuration = 3600	-- How long in ticks the player will be hated by ticks after beating their tick to death
tickRageRadius = 500		-- Distance in WU for a tick to attempt revenge
tickAttackFrequency = 45

maxTickStability = 1000		-- Time divided probability of tick spontaneous explosion (kamikaze w/ rider)
maxTickImpatience = 45		-- Time in ticks before new destination for stuck ticks

MonsterTypes["minor tick"]._maxLife = 30
MonsterTypes["major tick"]._maxLife = 60
MonsterTypes["kamikaze tick"]._maxLife = 90



-- Trigger Functions
-----------------------------------------------------------

function Triggers.init()
	
	initialKamikazeOdds = kamikazeOdds

	tickSafePolygons = {}
	
	for p in Polygons() do
		
		if not polygonIsTickSafe(p) then
			if p.type == "normal" then
				p.type = "monster impassable"	-- Try to keep ticks from pathing into tricky spots
			end
			tickSafePolygons[p.index] = false
		else
			tickSafePolygons[p.index] = p
		end
		
	end

	for p in Players() do
		
		-- Avoid tick-unfriendly starting positions
		if not polygonIsTickSafe(p.polygon) then
			local polygon = pickRandomSafePolygon()
			p:position(polygon.x, polygon.y, polygon.floor.z, polygon)
		end

		p._tickVengeanceLevel = 0
		p._tickCallCooldown = 0
		p._grabTick = false
	
	end
	
	-- You get a tick, and you get a tick! Everybody gets a tick!
	for m in Monsters() do
		if m.type.class ~= "tick" then
			giveTick(m)
		end
	end

end


function Triggers.player_revived(p)

	giveTick(p)

end


function Triggers.monster_damaged(monster, aggressor_monster, damage_type, damage_amount, projectile)
	
	if monster.type.class == "tick" then
		
		if aggressor_monster ~= nil then
			
			if monster._rider ~= nil then
		
				-- Comment this part out to enable 'friendly' fire while riding.
				if aggressor_monster.player == monster._rider or aggressor_monster == monster._rider then
					monster.life = monster.life + damage_amount
				end
		
			end

		-- Tick Abuse Protocol
		elseif damage_type == "fusion" then
			
			if monster.life > 0 then
			
				monster:play_sound("fist hitting")
			
			else
		
				monster:play_sound("crushed")

				-- Tick abuse may result in a tick vendetta! You have been warned!
				if monster._rider ~= nil then
					monster._rider._tickVengeanceLevel = monster._rider._tickVengeanceLevel + tickWrathDuration
				end

				-- Spawn kamikazes more often whenever someone beats a dead tick
				if kamikazeOdds > 2 then
					kamikazeOdds = kamikazeOdds - 1
				end
				
			end

		end
		
		if monster.life <= 0 and not monster._deathNoted then
			
			if aggressor_monster == nil then
				
				if damage_type == "lava" then
					Players.print(monster._name .. " just got turned into tick stew in the lava!")
				elseif damage_type == "fusion" then
					Players.print(monster._name .. " was abused to death by " .. tostring(monster._rider.name) .. "! That monster!")
				elseif damage_type == "explosion" then
					Players.print(monster._name .. " was blasted to death in an explosion!")
				end
				
			else
				
				local killer
				if aggressor_monster.player then
					killer = aggressor_monster.player.name
				else
					killer = "a " .. tostring(aggressor_monster.type)
				end
				
				Players.print(monster._name .. " was killed by " .. tostring(killer) .. " with a " .. tostring(projectile.type) .. "!")
				
			end
			
			-- Funny(?) death reactions
			if string.find(monster._name, "Kenny") then
				Players.print("Oh my god, you killed Kenny! You bastards!")
			elseif string.find(monster._name, "Homer") then
				Players.print("D'oh!")
			elseif string.find(monster._name, "King") then
				Players.print("The king is dead! Long live the king!")
			end
			
			monster._deathNoted = true
			
		end
		
	end
	
end


function Triggers.monster_killed(monster, aggressor_player, projectile)
	
	-- Remove corpses from back of tick, yes?
	if monster._tick or monster._rider then
		
		dismountTick(monster)
		
	end
		
	if monster.type.class == "tick" then
		
		if aggressor_player then
		
			-- Add to tick rage cooldown if tick abuser wastes a tick while under tick vendetta
			if aggressor_player._tickVengeanceLevel > 0 then
				aggressor_player._tickVengeanceLevel = aggressor_player._tickVengeanceLevel + 450
			end
		
		end
		
	end
	
end


function Triggers.idle()

	angryTicks = false
	ticksAlive = 0
	monstersAlive = 0
	
	timersIdleUpkeep()

	for m in Monsters() do
		
		if m.life >= 0 and m.valid and not m.player then
		
			m.active = true
		
			if m.type.class == "tick" then

				ticksAlive = ticksAlive + 1
				
				updateTick(m)
				
			else
				
				monstersAlive = monstersAlive + 1
				
			end
		
		end
		
	end
	
	for p in Players() do
		
		updatePlayer(p)

		updateOverlays(p)
		
	end

	-- If no players have angered the tick gods, ease off on the exploding ticks
	if not angryTicks then
		kamikazeOdds = initialKamikazeOdds
	end
	
	-- Maintain a steady population of available ticks
	if ticksAlive - monstersAlive < # Players + spareTicks then
		summonTick()
	end
	
end



-- Tick Functions
-----------------------------------------------------------

function createTick(x, y, z, polygon, safe)

	if Game.random(kamikazeOdds) == 0 and not safe then
		tickBreed = "kamikaze tick"
	elseif Game.random(majorOdds) == 0 then
		tickBreed = "major tick"
	else
		tickBreed = "minor tick"
	end
	
	local tick = Monsters.new(x, y, z, polygon, tickBreed)
	tick:position(x, y, z, polygon)
	
	tick._name = tickName(tick)
	
	if string.find(tick._name, "Impervious") then
		tick.life = 3000
	elseif string.find(tick._name, "Titanium") then
		tick.life = 500
	elseif string.find(tick._name, "Hardy") then
		tick.life = 200
	else
		tick.life = tick.type._maxLife
	end
	
	tick._maxLife = tick.life
	tick._impatienceLevel = 0
	tick._lastPosition = {}
	tick._lastPosition.x = tick.x
	tick._lastPosition.y = tick.y
	tick._lastDestination = tick.polygon
	tick._nextDestination = tick.polygon
	tick._stabilityLevel = maxTickStability
	tick._attackCooldown = 0
	
	return tick
	
end


function summonTick()
	
	local polygon = pickRandomSafePolygon()
	
	-- randomize start heights here but check if there's a rider?
	
	local z
	if polygon.media then
		z = polygon.media.height + 0.5
	else
		z = polygon.floor.z + 0.5
	end
	
	boof(polygon.x, polygon.y, z, polygon)
	local tick = createTick(polygon.x, polygon.y, z, polygon)
	
end


function giveTick(monster)

	local tick = createTick(monster.x, monster.y, monster.z, monster.polygon, true)
	
	if monster.player then
		mountTick(monster.player, tick)
	else
		mountTick(monster, tick)
	end
	
end


function mountTick(rider, tick)
	
	tick._rider = rider
	rider._tick = tick
	
	tick:accelerate(0, 0, -0.01)
	
	moveTick(tick)
	
end


function dismountTick(monster)

	if monster._rider then
		monster._rider._tick = nil
		monster._rider = nil
	elseif monster._tick then
		monster._tick._rider = nil
		monster._tick = nil
	end
	
end


function moveTick(tick)
	
	if tick then
		if not tick.valid then
			return
		end
	else
		return
	end
	
	local targetPolygon = pickRandomSafePolygon()
	
	if not targetPolygon then
		return moveTick(tick)
	end
	
	tick:move_by_path(targetPolygon)
	
	tick._previousDestination = tick.polygon
	
	tick._nextDestination = targetPolygon
	
	tick._impatienceLevel = 0
	
end


function updateTick(tick)
	
	if tick._lastPosition.x == tick.x and tick._lastPosition.y and math.abs(tick.vertical_velocity) < 0.07 then
		tick._impatienceLevel = tick._impatienceLevel + 1
	end
	
	tick._lastPosition.x = tick.x 
	tick._lastPosition.y = tick.y
	
	if tick._impatienceLevel >= maxTickImpatience then
		
		if tick.type == "kamikaze tick" then
			tick:damage(0)
		end
		
		tick.polygon:play_sound(tick.x, tick.y, tick.z, "tick chatter", 0.5)
		
		moveTick(tick)
		
	end
	
	-- For ticks with a rider aboard:
	if tick._rider then
		
		local rider = tick._rider
		
		-- Keep rider positioned above tick
		rider:position(tick.x, tick.y, tick.z + saddleHeight, tick.polygon)
		
		-- Not sure if this matters, but what the hell
		if rider.monster == nil then
			rider.vertical_velocity = tick.vertical_velocity
		end
		
		-- Avoid inserting rider head into ceiling
		local riderHeight = rider.monster == nil and tick._rider.type.height or tick._rider.monster.type.height
		if rider.z + riderHeight >= tick.polygon.ceiling.z - 0.1 then
			tick.vertical_velocity = tick.vertical_velocity - downDraft
		end	
		
		-- Keep ticks moving to new and exciting locations!
		if tick.polygon == tick._nextDestination then
			
			moveTick(tick)
				
		end
		
		-- Some might say they're... unstable?
		if tick.type == "kamikaze tick" then
			if tick._stabilityLevel > 2 then
				tick._stabilityLevel = tick._stabilityLevel - 1
			end
			if Game.random(tick._stabilityLevel) == 0 then
				tick:play_sound("rocket exploding")
				Effects.new(tick.x, tick.y, tick.z, tick.polygon, "rocket explosion")
				rider:damage(100,"explosion")
				tick:damage(100)
			end
		end
		
	else
		
		-- Riderless tick stuff goes here
	
	end
	
	-- Kamikaze tick stuff
	if tick.type == "kamikaze tick" then
		
		-- Tick Vengeance Protocol:
		
		if Game.ticks % 15 == 0 then
		
			tick._targetTickAbuser = nil
			local closestJerkfaceDistance = 666
		
			for p in Players() do
			
				if p._tickVengeanceLevel > 0 then
				
					local buttheadRange = getDistance3(tick.x, tick.y, tick.z, p)
				
					if buttheadRange <= tickRageRadius and buttheadRange < closestJerkfaceDistance then
						tick._targetTickAbuser = p
						closestJerkfaceDistance = buttheadRange
					end

				end	
			
			end
			
		end
			
		if tick._targetTickAbuser then
		
			if tick.polygon ~= tick._targetTickAbuser.polygon then
				if Game.ticks % 300 == 0 then
					tick:move_by_path(tick._targetTickAbuser.polygon)
					tick:play_sound("tick chatter")
				end
			else
				if not tick._attackTimer then
					local sicEm = function()
						tick:play_sound("tick chatter")
						tick:attack(tick._targetTickAbuser.monster)
					end
					tick._attackTimer = createTimer(tickAttackFrequency, false, sicEm)
				end
			end
			
		end
		
	end
	
	-- Special case behaviors...
	if string.find(tick._name, "Flatulent") and Game.random(30) == 7 then
	
		local fart = Effects.new(tick.x, tick.y, tick.z, tick.polygon, "juggernaut missile contrail") 
		tick.polygon:play_sound(tick.x, tick.y, tick.z, "absorbed", 0.5)
		
	elseif string.find(tick._name, "Saint") and Game.random(300) == 7 then
		
		if tick._rider then
			if tick._rider.life < 100 and tick._rider.monster then
				tick._rider.life = tick._rider.life + 10 + Game.random(30)
				tick:play_sound("tick chatter")
				tick._rider:fade_screen("white")
				if tick._rider.life > 100 then
					tick._rider.life = 100
				end
			end
		end
		
	elseif string.find(tick._name, "Magical") and Game.ticks % 900 == 0 then
		
		if tick._rider.monster then
			
			local diceRoll = Game.random(7)
			castWonder(diceRoll, tick._rider)
				
		end
		
	elseif string.find(tick._name, "Fun Robert") and Game.ticks % 150 == 0 then
		
		if Game.random(2) == 0 then
			tick.polygon:play_sound(tick.x, tick.y, tick.z, "assimilated vacbob chatter", 0.5)
		end
		
	end
	
end



-- Player Functions
-----------------------------------------------------------

function updatePlayer(player)

	-- Tick vendetta decrementation
	if player._tickVengeanceLevel > 0 then
		angryTicks = true
		player._tickVengeanceLevel = player._tickVengeanceLevel - 1
	end
	
	if player._tickCallCooldown > 0 then
		player._tickCallCooldown = player._tickCallCooldown - 1
	end
	
	-- Avoid riding dead ticks, it's bad for you!
	if player._tick then
		if not player._tick.valid then
			dismountTick(player)
		end
	end
	
	-- Corpses can't ride a tick
	if player.dead then
		
		dismountTick(player)
		
	-- How to get on a tick?	
	elseif player._grabTick then
		
		local ticksAbout = false
		
		-- (NOTE: There's a better way to do this, probably. It just grabs the first tick it 'sees' and is good enough, but that may not be the closest one!)
		
		for m in Monsters() do
			if m.type.class == "tick" then
				if isRideableTick(m) then
					if getDistance3(m.x, m.y, m.z, player) <= graspReach then
				
						if math.abs(angleDifference(getBearing(player, m), player.yaw)) < 70 then
							mountTick(player, m)
							m:play_sound("tick chatter")
							player._grabTick = false
							break
						end
						
					elseif getDistance3(m.x, m.y, m.z, player) <= maxTickMountDistance then
						
						ticksAbout = true
						
					end
				end
			end
		end
		
		if not ticksAbout then
			player._grabTick = false
		end
		
 	-- Mount/dismount
	elseif player.action_flags.action_trigger then
		
			if player._tick then
				dismountTick(player)
				bigLeap(player, true)
			else
				rideTick(player)
			end
	
	-- The mic button sucks but it's what we've got right now. Hawtkeyz nao plz~
	elseif player.action_flags.microphone_button then

		player.action_flags.microphone_button = false
		
		callTick(player)

	-- Tick abuse protocol:
	elseif player.action_flags.cycle_weapons_backward and player.action_flags.cycle_weapons_forward then
		
		if player._tick ~= nil then
			player.action_flags.action_trigger = false
			if Game.random(3) == 1 then
				player._tick:play_sound("tick chatter")
			end
			player._tick:damage(1, "fusion")
			moveTick(player._tick)
		end	
		
	end
	
end


function rideTick(player)

	if player._grabTick then
		return
	end

	for m in Monsters() do
		
		if m.type.class == "tick" then
			
			local xyDistance = getDistance2(m.x, m.y, player)
			local zDistance = m.z - player.z
			
			if xyDistance <= maxTickMountDistance and zDistance <= maxTickMountHeight and isRideableTick(m) then
				
				local bearing = getBearing(player, m)
				local alpha = angleDifference(bearing, player.yaw)
				
				if math.abs(alpha) <= maxTickMountAngle then
					
					player._grabTick = true
					bigLeap(player)
					
				end
	
			end
		end
	end
	
	player:play_sound("cant toggle switch", 1.5)
	
end

--[[
The following is not the best possible implementation, but it's something.
Note that jumps on dismounts get a bit more oomph because for whatever reason those jumps need it to get the same results
as jumping from the ground? May be a good reason for this but I'm too tired to consider it in depth...
]]

function bigLeap(player, dismount)
	
	local pitch = player.pitch
	
	local verticalMinimum = 0.02
	if dismount then
		verticalMinimum = 0.175
	end
		
	local fThrust = jumpForce * math.cos(math.rad(pitch))
	local vThrust = math.max(jumpForce * math.sin(math.rad(pitch)) * verticalCoefficient, verticalMinimum)

	if player.z == player.polygon.z or dismount then
		player:accelerate(player.yaw, fThrust, vThrust)
	end

end


--(NOTE: Maybe add some more color pallettes for the icon to indicate TICK RAGE or something, I dunno.)

function updateOverlays(player)
	
	for i = 0, 5 do
		player.overlays[i]:clear()
	end

	if player._tick ~= nil then
	
		local tickHealth = player._tick.life / player._tick._maxLife * 100
		local healthSpace
		if tickHealth == 100 then
			healthSpace = "         "
		elseif tickHealth >= 10 then
			healthSpace = "          "
		else
			healthSpace = "           "
		end
	
		player.overlays[0].text = healthSpace .. string.format("%i", tickHealth) .. "%"
	
		if tickHealth >= 90 then 
			player.overlays[0].color = "dark green"
		elseif tickHealth >= 70 then
			player.overlays[0].color = "green"
		elseif tickHealth >= 30 then
			player.overlays[0].color = "yellow"
		elseif tickHealth >= 15 then
			player.overlays[0].color = "red"
		else
			if Game.ticks % 30 > 15 then
				player.overlays[0].color = "red"
			else
				player.overlays[0].color = "dark red"
			end
		end
	
		player.overlays[1].icon = iconTick
	
		player.overlays[1].text = " " .. player._tick._name
	
		if player._tick.type == "minor tick" then
			player.overlays[1].color = "green"
		elseif player._tick.type == "major tick" then
			player.overlays[1].color = "blue"
		elseif player._tick.type == "kamikaze tick" then
			player.overlays[1].color = "red"
		else
			player.overlays[1].color = "cyan"
		end
	
	end

end


function callTick(player)

	if player._tickCallCooldown == 0 then

		for m in Monsters() do
			if m.type.class == "tick" and m.type then
				if m._rider == nil and m._targetTickAbuser == nil and m.life > 0 and m.valid and getDistance3(m.x, m.y, m.z, player) <= tickCallDistance then
					
					if m.polygon ~= player.polygon then
						m:move_by_path(player.polygon)
					else
						m:attack(player.monster)
					end
			
				end
			end
		end
		
		player.polygon:play_sound(player.x, player.y, player.z, "tick chatter", 3)

		player._tickCallCooldown = 60
		
	end
	
end



-- Timers
-----------------------------------------------------------

Timers = {}

TimerList = {}

function createTimer(period, repeating, action)

	local timer = Timers:new()
	
	timer.period = period - 1
	timer.repeating = repeating
	timer.action = action
	
	timer.count = period
	timer.status = "live"
	
	table.insert(TimerList, timer)
	
	return timer
	
end


function Timers:execute()

	self.action()

	if self.repeating then
	
		self:reset()
	
	else
		
		self.status = "dead"
		
	end
	
end


function Timers:reset()
	
	self.count = self.period
	
end


function Timers:kill()

	self.status = "dead"

end


function Timers:evaluate()

	if self.status == "dead" then
		self = nil
		return
	end

	if self.count <= 0 then
		self:execute()
		return
	end
	
	self.count = self.count - 1
	
end


function Timers:new()
	
	o = {}
    setmetatable(o, self)
    self.__index = self
	return o
	
end


function timersIdleUpkeep()

	local newSet = {}

	for i = 1, # TimerList, 1 do
		
		TimerList[i]:evaluate()
		if TimerList[i].status == "live" then
			table.insert(newSet, TimerList[i])
		end
		
	end

	TimerList = newSet
	
end



-- Assorted Functions and Errata
-----------------------------------------------------------

function getDistance2(x, y, object)
	
	return math.sqrt((object.x - x)^2 + (object.y - y)^2)
	
end


function getDistance3(x, y, z, object)
	
	return math.sqrt(getDistance2(x, y, object)^2 + (object.z - z)^2)
	
end


function getBearing(from, to)
	
	local x = to.x - from.x
	local y = to.y - from.y
	local theta = math.deg(math.atan(y/x))
	if x < 0 then
		return theta + 180
	elseif y < 0 then
		return theta + 360
	else
		return theta
	end
	
end


function angleDifference(a, b)

	return (a - b + 540) % 360 - 180

end


function polygonIsTickSafe(polygon)
	
	if polygon.media then
		if polygon.media.height >= polygon.ceiling.z or polygon.ceiling.z - polygon.media.height < exclusionHeight then
			return false
		end
	end
	
	return polygon.ceiling.z - polygon.floor.z >= exclusionHeight and polygon.area > 0.1
	
end


function pickRandomSafePolygon()

	local safePolygon = tickSafePolygons[Game.random(# tickSafePolygons)]
	
	if not safePolygon then
		return pickRandomSafePolygon()
	else
		return safePolygon
	end
	
end


function boof(x, y, z, polygon)
	
	local boof = Effects.new(x, y, z, polygon, "rocket contrail")
	boof:play_sound("enforcer exploding")
	
end


function isRideableTick(tick)
	
	return tick._rider == nil and tick.life > 0 and tick.valid
	
end


function tickName(tick)

	local a = Game.random(# TickNames) + 1
	local b = "Unidentifiable"
	if tick.type == "minor tick" then
		b = TickAdjectivesMediocre[Game.random(# TickAdjectivesMediocre) + 1]
	elseif tick.type == "major tick" then
		b = TickAdjectivesGood[Game.random(# TickAdjectivesGood) + 1]
	elseif tick.type == "kamikaze tick" then
		b = TickAdjectivesUgly[Game.random(# TickAdjectivesUgly) + 1]
	end

	return b .. " " .. TickNames[a]
	
end

TickNames = {

	"Jimmy","Rosie","Slim","Suzy","Ozzy","Becky","Chuck","Lucy","Red","Pinto","Orville","Jenny","Ted","Missy","Bart","Rex","Tom","Boz","Corky","Fido","Iggy","Chet","Buddy","Dan","Ralph",
	"Lenny","Gus","Ronnie","Marie","Baxter","Chester","Dexter","Laszlo","Rufus","Hector","Hannibal","Cameron","Bingo","Mary","Sam","Al","John","Jessie","Karen","Leonardo","Puck","Alfonso",
	"Lizzie","Peg","Anna","Tina","Olga","Elsie","Bessy","Agnes","Bertha","Bridget","Mavis","Daisy","Dolores","Eunice","Glynis","Helga","Maude","Mildred","Penelope","Roxanne","Tammy","Arthur",
	"Felix","Harry","Homer","Marge","Jasper","Rupert","Oscar","Simon","Jules","Gideon","Howard","Holden","Spencer","Benny","Mikey","Leo","Bert","Ray","Moppy","Lonny","Ike","Abe","Joe","Kenny",
	"Andy","Randy","Carl","Bixby","Bill","Sonny","Frannie","Francis","Frankie","Robert"
	
}

TickAdjectivesMediocre = {
	
	"Fat","Fluffy","Ugly","Chubby","Impetuous","Curious","Cotton Eye","Soggy","Queazy","Scuzzy","Corpulent","Expendable","Lazy Eyed","Ham-fisted","Sad-sack","Sickly","Antsy","Nauseous","Scared",
	"Giddy","Needy","Pandering","Wandering","Sleepy","Bashful","Indeterminate","Paranoid","Lazy","Generic","Standard-issue","Fake Teeth","Drunk","Ancient","Wet","Smelly","Incontinent","Incompetent",
	"Economical","Slow","Lil'","Sorry","Weepy","Shaky","Cashed Out","Sloppy","Forgetable","Milquetoast","Mild","Childproof","Dorky","Counterfeit","Corroded","Inexperienced","Saggy","Poopy-pants",
	"Humble","Soft Serve","Impotent","Dandruff","Waterlogged","Stressful","Flatulent","Hungry Hungry","Cool Ranch","Sweet & Sour","Low Calorie","Low Sodium","Lactose-free","No MSG","Aggregate-grade",
	"Feckless","Fun","Dirty","Fun-size","Chintzy","Dandruff","Mildew","Pet Odor","Lyme Disease","Petulant","Two-bit","Five & Dime","Bargain-bin","Best-by Last Week","Discount","Cut-rate","Fly-by-Nite",
	"Bald Spot","Sooty"
	
}

TickAdjectivesGood = {
	
	"Slick","Lovely","Most Honorable","Harmonious","Lucky","Cromulent","Savvy","Fun Lovin'","Fantastic","Dead-eye","Rugged","Dreamy","Can-do","Superlative","Gutsy","Sincere","The Incredible",
	"Super-duper","Resolute","Heroic","Hardcore","Serious","Impervious","Magical","Resplendent","Outstanding","God-hand","Major","No-guff","Legendary","Wholesome","Deluxe","Emperor","Bad-ass",
	"Majestic","Mysterious","Helpful","Hardy","Heavy-duty","Radical","Darling","Wunderkind","Captain","Lord","Saint","Titanium","Royal","Ingenious","Clever","Sporty","Luxurious","Infinite","King",
	"Duke","Slammin'","Bushwhacker","Tireless","Peerless","The One and Only","Top-class","Elegant"
	
}

TickAdjectivesUgly = {
	
	"Grumpy","Touchy","Crazy","Cantankerous","Sleazy","Sketchy","Shady","Hateful","Impish","Evil","Malevolent","Psychotic","Awful","Rotten","Vile","Laviscious","Rude","Rueful","Ghastly",
	"Cold-hearted","Facetious","Slimy","Raunchy","Loathesome","Rotten","Excitable","Nightmare","Murderous","Baby-eating","Scandalous","Terrible","Horror-show","Killer","Villainous","Wicked",
	"Insane","Yellow-bellied","Damnable","Sinful","Thuggish","Graverobber","Felonious","Dangerous","Poisonous","War Criminal","That No-good","Dastardly","Con Artist","Deathly","Cannibalistic",
	"Delinquent","Heinous","Foul-mouthed","Inexcusable","Ravenous","Violent","Vicious"
}


function castWonder(diceRoll, player)

	if diceRoll == 0 then
		player.infravision_duration = 900
	elseif diceRoll == 1 then
		player.invincibility_duration = 900
	elseif diceRoll == 2 then
		player.invisibility_duration = 900
	elseif diceRoll == 3 then
		player.extravision_duration = 900
	elseif diceRoll == 4 then
		player.life = player.life + 100 + Game.random(100)
	elseif diceRoll == 5 then
		for i in ItemTypes() do
			if string.find(i.mnemonic,"ammo") then
				player.items[i] = player.items[i] + Game.random(7)
			end
		end
	else
		-- Add some other ridiculous thing here
	end
	
	player:fade_screen("dodge purple")
	player:play_sound("destroy control panel")

end


function showTicks()
	for m in Monsters() do
		if m._name then
			Players[0]:print(m._name)
		end
	end
end


function killTicks()
	for m in Monsters() do
		if m.type.class == "tick" then
			m:damage(1000)
		end
	end
end


iconTick =
[[
22
,a0a1a4
.2f3137
a633e38
b604038
c865b4a
d49322c
eab725b
f936250
g4e3028
h694034
i392522
j402522
k452820
l543731
m432b22
n7a4b3d
o936250
p2d1b15
q261a19
r402d29
s5a413d
t7d574a
,,,,,,,,,,,,,,,,
,..............,
,......abcd....,
,.....eeefc....,
,....ghhaiji...,
,....gklgjlm...,
,....gnnogjp...,
,.....ppkjj....,
,....i.i.q.r...,
,...s..s.q..q..,
,..s..s...q..s.,
,..m.tf....d.f.,
,bg..e......lte,
,h...f.......sc,
,..............,
,,,,,,,,,,,,,,,,
]]
