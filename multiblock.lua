-- a multiblock structure system

--[==[
	TODO:
		* saving and loading (including user data serialization?)
		* default callbacks (e.g. particles and sound when sucessfully creating multiblock and destroying it, maybe info when right clicking?)
		* when to save?
		* check if multiblock is loaded before ticking? (maybe there is sense in not checking e.g. some sort of ofscreen processors?)
--]==]
multiblock={}

existing_multiblocks={} --TODO: @performance split into two copies, one for easier enumeration, other for better spacial lookup
recipies={}

local function load_multiblocks()
	
end
local function save_multiblocks()
	
end
local mlb={}
mlb.__index=mlb
function mlb:to_local(x,y,z) -- get in local coordinates
	return {x=x-self.pos.x,y=y-self.pos.y,z=z-self.pos.z}
end
function mlb:to_global(x,y,z) -- get in global coordinates
	if type(x)=="table" then
		return {x=x.x+self.pos.x,y=x.y+self.pos.y,z=x.z+self.pos.z}
	else
		return {x=x+self.pos.x,y=y+self.pos.y,z=z+self.pos.z}
	end
end
function mlb:inside(x,y,z) --is block inside?
	local pos=self:to_local(x,y,z)
	local emi=self.extents.min
	local ema=self.extents.max
	if pos.x>=emi.x and pos.y>=emi.y and pos.z>=emi.z and
		pos.x<=ema.x and pos.y<=ema.y and pos.z<=ema.z then
		return true
	end
	return false
end
local function new_multiblock(tbl,pos,recipe)
	tbl=tbl or {}
	tbl.pos=pos
	tbl.recipe=recipe
	tbl.is_dead=false
	setmetatable (tbl,mlb)
	return tbl
end 
local function match_block(blk_type,btype,bmeta)
	if type(blk_type)=="table" then
		if blk_type.meta==-1 or blk_type.meta==nil then
			return blk_type.type==btype
		else
			return blk_type.type==btype and blk_type.meta==bmeta
		end
	else
		if  blk_type==-1 then -- -1 matches everything
			return true
		end
		return blk_type==btype
	end
end
local function check_new_multiblock(world,x,y,z,recipe)
	local min={x=999,y=999,z=999}
	local max={x=-999,y=-999,z=-999}
	for i,v in ipairs(recipe.structure) do
		local tx=x+v[1]
		local ty=y+v[2]
		local tz=z+v[3]

		if v[1]<min.x then min.x=v[1] end
		if v[2]<min.y then min.y=v[2] end
		if v[3]<min.z then min.z=v[3] end

		if v[1]>max.x then max.x=v[1] end
		if v[2]>max.y then max.y=v[2] end
		if v[3]>max.z then max.z=v[3] end

		local valid,btype,bmeta=world:GetBlockTypeMeta(tx,ty,tz)
		if not valid or not match_block({type=v[4],meta=v[5]},btype,bmeta) then
			return false,i
		end
	end

	return true,min,max
end
local function lookup_multiblock(x,y,z)
	for i,v in ipairs(existing_multiblocks) do
		if v:inside(x,y,z) then
			return v,i
		end
	end
end
local function break_block(Player, BlockX, BlockY, BlockZ, BlockFace, BlockType, BlockMeta)
	--check if part of multiblock, destroy multiblock
	local struct,id=lookup_multiblock(BlockX,BlockY,BlockZ) --TODO: @performance could be slow if server has a lot of them. need block type as key?

	if struct==nil then
		return
	end

	--callback
	if struct.recipe.break_callback then
		struct.recipe.break_callback(struct,player,struct:to_local(BlockX,BlockY,BlockZ))
	end
	--cleanup
	existing_multiblocks[id]=nil
end
local function right_click(Player, BlockX, BlockY, BlockZ, BlockFace, CursorX, CursorY, CursorZ)
	local struct,id=lookup_multiblock(BlockX,BlockY,BlockZ) --TODO: @performance could be slow if server has a lot of them. need block type as key?
	if struct==nil then
		return
	end
	--callback
	if struct.recipe.right_click_callback then
		if struct.recipe.right_click_callback(struct,Player,struct:to_local(BlockX,BlockY,BlockZ),BlockFace) then
			return true
		end
	end

end
local function block_placed(Player, BlockX, BlockY, BlockZ, BlockType, BlockMeta)
	for i,v in ipairs(recipies) do
		if match_block(v.finish_block,BlockType,BlockMeta) then
			local ok,min,max=check_new_multiblock(Player:GetWorld(),BlockX,BlockY,BlockZ,v)
			
			local struct=new_multiblock({extents={min=min,max=max}},{x=BlockX,y=BlockY,z=BlockZ},v)
			if ok then
				--check callback
				if v.created_callback then
					if v.created_callback(struct,Player,BlockX,BlockY,BlockZ) then
						return
					end
				end
				--actually create it
				table.insert(existing_multiblocks,struct)
				struct.world=Player:GetWorld()
			end

		end
	end
	
end
local function ticker(timedelta)
	--call ticks for all multiblocks, maybe limit time
	for i,v in ipairs(existing_multiblocks) do
		if v.recipe.tick_callback then
			v.recipe.tick_callback(v,timedelta)
		end
	end

	local i=1
	while i <= #existing_multiblocks do
    	if existing_multiblocks[i].is_dead then
        	table.remove(existing_multiblocks, i)
    	else
        	i = i + 1
    	end
	end
end
-- add a new multiblock recipe.
--[=[
	Fields:
		finish_block - a block type for block that finished structure. Use more rare block types for better performance
		structure - a table with {x,y,z,block_type,block_meta} for a valid structure

		break_callback(structure,player,dx,dy,dz) - happens when multiblock is broken. Automatically removed from list
		right_click_callback(structure,player,local_pos,block_face) - happens when player right clicks on any block. 0,0,0 is finish_block
		created_callback(structure,player,x,y,z) - if returns true, cancel creation
		tick_callback(structure,timedelta)

	Multiblock data:
		pos{x,y,z} - the position of last placed block. It's 0,0,0 for all the callbacks
		extents {min,max} - the bounding box of structure (in local coordinates)
		recipe - link to the recipe
		is_dead - to be removed at next tick?
		world - the world where it's placed --TODO: check if it's safe to keep this in struct

--]=]
function multiblock.add_recipe(recipe)
	table.insert(recipies,recipe) --TODO: @performance add with finish_block as key
end
function multiblock.init()
	print("Multiblock init")
	cPluginManager:AddHook(cPluginManager.HOOK_PLAYER_RIGHT_CLICK, right_click);
	cPluginManager:AddHook(cPluginManager.HOOK_PLAYER_BROKEN_BLOCK, break_block);
	cPluginManager:AddHook(cPluginManager.HOOK_PLAYER_PLACED_BLOCK, block_placed);

	cPluginManager:AddHook(cPluginManager.HOOK_TICK, ticker);

	load_multiblocks()
end
