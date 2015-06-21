--local mlb=require "multiblock"
local recipe = {
	finish_block=E_BLOCK_BLOCK_OF_REDSTONE,
	structure={
		{-1,0,-1,E_BLOCK_BRICK},
		{1,0,-1,E_BLOCK_BRICK},
		{1,0,1,E_BLOCK_BRICK},
		{-1,0,1,E_BLOCK_BRICK},
		{0,0,0,E_BLOCK_BLOCK_OF_REDSTONE}, --optional i think...
		{-1,0,0,E_BLOCK_BRICK},
		{0,0,-1,E_BLOCK_BRICK},
		{1,0,0,E_BLOCK_BRICK},
		{0,0,1,E_BLOCK_BRICK}
	},
	right_click_callback=function (structure,player,local_pos,block_face)
		local pos=structure:to_global(local_pos)
		player:GetWorld():BroadcastSoundEffect("mob.ghast.moan",pos.x,pos.y,pos.z,0.6,math.random()*5)
		return true
	end,
	created_callback=function (structure,player,x,y,z)
		--print("Multiblock at:",x,y,z)
	end,
	tick_callback=function ( structure,timedelta )
		structure.time=structure.time or 0
		structure.time=structure.time + timedelta
		if structure.time>1000 then
			if math.random()>0.4 then
				return
			end
			local pos=structure.pos
			structure.world:BroadcastParticleEffect("reddust",pos.x+0.5,pos.y,pos.z+0.5,0.2,2,0.2,0,10)
			structure.time=0
		end
	end
}
function sparks_init()
	multiblock.add_recipe(recipe)
end