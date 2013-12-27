
class "Rally"

function Rally:__init()
    Events:Subscribe( "PlayerChat", self, self.ChatMessage )
    
    Events:Subscribe( "PlayerQuit", self, self.PlayerQuit )
    
    Events:Subscribe( "PlayerDeath", self, self.PlayerDeath )
    
    Events:Subscribe( "PostTick", self, self.PostTick )

    Events:Subscribe( "PlayerEnterVehicle", self, self.PlayerEnterVehicle )
    Events:Subscribe( "PlayerExitVehicle", self, self.PlayerExitVehicle )

    self.timer = Timer()
	self.tickTimer = Timer()
	self.resolution = 15
end

function Rally:Start(dest)
	self.players = {}
	for i,v in Server:GetPlayers() do
		self.players[v:GetId()] = {}
	end
	self:Broadcast("Rally underway! Your destination is X:" .. dest[1] .. " Y:" .. dest[2])
	self.destination = dest
	self.inRally = true
	self.timer:Reset()
	self.tickTimer:Reset()
end

function Rally:Broadcast(msg)
	Chat:Broadcast( "[Rally] " .. msg, Color(0xfff0c5b0) )
end

function Rally:ChatMessage(args)
	local msg = args.text
    local player = args.player
    
    -- If the string is't a command, we're not interested!
    if ( msg:sub(1, 1) ~= "/" ) then
        return true
    end    
    
    local cmdargs = {}
    for word in string.gmatch(msg, "[^%s]+") do
        table.insert(cmdargs, word)
    end
    
    if ( cmdargs[1] == "/rally" ) then
        if self.inRally then
			self:CancelRally()
		elseif tonumber(cmdargs[2] or "lol") and tonumber(cmdargs[3] or "lol") then
			local x,y = tonumber(cmdargs[2]), tonumber(cmdargs[3])
			if x > 0 and x < 32000 and y > 0 and y < 32000 then
				self:Start({x,y})
			else
				self:Broadcast("Bad map coords")
			end
		else
			self:Broadcast("Provide coordinates for destination")
		end
    end
    
    return false
end

function Rally:CancelRally()
	self:Broadcast("Rally Cancelled!")
	self.inRally = false
end

local function distance ( x1, y1, x2, y2 )
  local dx = x1 - x2
  local dy = y1 - y2
  return math.sqrt ( dx * dx + dy * dy )
end

function Rally:PlayerFinish(id,player)
	self.finished = self.finished or {}
	self.finished[#self.finished + 1] = id
	self:Broadcast(player:GetName() .. " reached the destination! They came in " .. #self.finished .. "st/nd/rd")
	if #self.finished == #self.players then
		self:EndRally()
	end
end

function Rally:PostTick(args)
	if self.inRally and self.tickTimer:GetSeconds() > self.resolution then
		self.tickTimer:Restart()
		for i,v in pairs(self.players) do
			local p = Player.GetById(i)
			local pos = p:GetPosition()
			table.insert(v, { type = "tick", position = {pos.x, pos.y}})
			local d = distance(self.destination[1],self.destination[2],pos.x,pos.y)
			if d < 5 then
				self:PlayerFinish(i,p)
			end
		end
	end
end

function Rally:EndRally()
	self.inRally = false
	local save = {}
	for i,v in pairs(self.players) do
		local p = Player.GetById(i)
		save[p:GetName()] = v
	end
	local f = io:open("lol.js", "w")
	f:write(JSON:encode(save))
	f:close()
end

function Rally:PlayerEnterVehicle(args)
	local player = args.player
	if self.inRally and self.players[player:GetId()] then
		local vehicle = arg.vehicle
		local pos = player:GetPosition()
		table.insert(self.players[player:GetId()], { type = "enterVehicle", vehicle = vehicle:GetName(), position = {pos.x, pos.y} })
		self:Broadcast(player:GetName() .. " entered a " .. vehicle:GetName())
	end
end

function Rally:PlayerExitVehicle(args)
	local player = args.player
	if self.inRally and self.players[player:GetId()] then
		local vehicle = arg.vehicle
		local pos = player:GetPosition()
		table.insert(self.players[player:GetId()], { type = "leftVehicle",  position = {pos.x, pos.y} })
		self:Broadcast(player:GetName() .. " left their " .. vehicle:GetName())
	end
end

function Rally:PlayerDeath(args)
	local player = args.player
	if self.inRally and self.players[player:GetId()] then
		local pos = player:GetPosition()
		table.insert(self.players[player:GetId()], { type = "death", position = {pos.x, pos.y} })
		self:Broadcast(player:GetName() .. " died. Lol")
	end
end

function Rally:PlayerQuit(args)
	local player = args.player
	if self.inRally and self.players[player:GetId()] then
		self:Broadcast(player:GetName() .. " left the game.")
		self.players[player:GetId()] = nil
	end
end

rally = Rally()