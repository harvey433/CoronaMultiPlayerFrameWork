
--====================================================================--
-- dmc_dragdrop.lua
--
-- by David McCuskey
-- Documentation: http://docs.davidmccuskey.com/display/docs/dmc_dragdrop.lua
--====================================================================--

--[[

Copyright (C) 2011 David McCuskey. All Rights Reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in the
Software without restriction, including without limitation the rights to use, copy,
modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so, subject to the
following conditions:

The above copyright notice and this permission notice shall be included in all copies
or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

--]]



-- =========================================================
-- Imports
-- =========================================================

-- import DMC Objects file
local Objects = require( "dmc_objects" )

-- setup some aliases to make code cleaner
local inheritsFrom = Objects.inheritsFrom
local Object = Objects.Object



local coronaMetaTable = getmetatable( display.getCurrentStage() )

--- Returns true for any object returned from display.new*().
-- note that all Corona types seem to share the same metatable...
local isDisplayObject = function( object )
	return type( object ) == "table" and getmetatable( object ) == coronaMetaTable
end


local color_blue = { 25, 100, 255 }
local color_lightblue = { 90, 170, 255 }
local color_green = { 50, 255, 50 }
local color_lightgreen = { 170, 225, 170 }
local color_red = { 255, 50, 50 }
local color_lightred = { 255, 120, 120 }
local color_grey = { 180, 180, 180 }
local color_lightgrey = { 200, 200, 200 }

-- createSquare()
--
-- function to help create shapes, useful for drag/drop target examples
--
local function createSquare( size, color,letter )

	local boxGroup = display.newGroup()
	local myRoundedRect = display.newImageRect( "drawables/icecube.png",  size[1], size[2])
	myRoundedRect:setReferencePoint(display.TopLeftReferencePoint);
	myRoundedRect.x = 0
	myRoundedRect.y = 0

	local boxletter =  TextCandy.CreateText({
				fontName 	= "ICEBREAKER", 						
				x		 	= myRoundedRect.width/2,						
				y		 	= myRoundedRect.height/2,						
				text	 	= letter,	
				originX	 	= "CENTER",							
				originY	 	= "CENTER",							
				textFlow 	= "CENTER",	
				charSpacing = -5,
				lineSpacing = -4,
				wrapWidth	= 300, 								
				--showOrigin 	= true,								
				})
	--myRoundedRect:setFillColor(255, 255, 255)
	--myRoundedRect.strokeWidth = 1
	--myRoundedRect:setStrokeColor(255, 255, 255)	

	boxGroup:insert(myRoundedRect)
	boxGroup:insert(boxletter)
	boxletter.x = (myRoundedRect.width/2)
	boxletter.y = (myRoundedRect.height/2)
	boxGroup:setReferencePoint(display.CenterReferencePoint);

	return boxGroup
end



--====================================================================--
-- Drag Drop class
--====================================================================--

local DragDrop = inheritsFrom( Object )
DragDrop.NAME = "Drag Drop"

DragDrop._registered = {}	-- hash of all registered objects
DragDrop._onDragStart = {}	-- list of registered objects with dragStart()
DragDrop._onDragStop = {}	-- list of registered objects with dragStop()

-- property name holding Corona display object
DragDrop.DISPLAY_PROPERTY = "display"

DragDrop.ANIMATE_TIME_SLOW = 300
DragDrop.ANIMATE_TIME_FAST = 100


-- Drag Targets Info
-- a hash, indexed by drag target source
DragDrop._drag_targets = {}

-- Drop Target Info
-- drop_target: object being dropped on, Display Object
-- drop_target: dropped point is selected, Boolean
DragDrop.drop_target = nil
DragDrop.drop_target_accept = false


function DragDrop:setDisplayProperty( name )
	self.DISPLAY_PROPERTY = name
end

function DragDrop:register( obj, params )

	-- create our storage data structure for the object
	local ds = {}
	ds.obj = obj.box
	ds.call_with_object = false 	-- whether we call using object
	if not params then
		ds.call_with_object = true
		t = obj.box
	else
		ds.call_with_object = false
		t = params
	end

	ds.dragStart = t.dragStart or nil
	ds.dragEnter = t.dragEnter or nil
	ds.dragOver = t.dragOver or nil
	ds.dragDrop = t.dragDrop or nil
	ds.dragExit = t.dragExit or nil
	ds.dragStop = t.dragStop or nil
	ds.dragId = t.dragId or nil
	ds.proxy = t.proxy or nil

	self._registered[ obj.box ] = ds

	-- save for lookup optimization
	if ds.dragStart then
		table.insert( self._onDragStart, obj.box )
	end
	if ds.dragStop then
		table.insert( self._onDragStop, obj.box )
	end
end

function DragDrop:doDrag( drag_orgin, event, drag_op_info )

	--== process Drag Target Info params

	local drag_op_info = drag_op_info or {}

	local size = {
		drag_orgin.width,
		drag_orgin.height
	}
	drag_orgin.alpha = 0
	local copybox = drag_orgin
	local drag_proxy = drag_op_info.proxy or createSquare( {35,35}, color_lightgrey,drag_orgin[2].text);
	--local drag_proxy = drag_op_info or createSquare( size, color_lightgrey );

	--== Create data structure for this drag operation

	--[[
		source: dragged item, Display Object / dmc_object
		origin: dragged item origin object, Dislay Object
		format: dragged item data format, String
		data: any data to be sent around, <any>
		x_offset: dragged item x-offset from touch center, Integer
		y_offset: dragged item y-offset from touch center, Integer
		alpha: dragged item alpha, Number
	--]]
	local drag_info = {}

	drag_info.proxy = drag_proxy
	drag_info.origin = drag_orgin
	drag_info.format = drag_op_info.format
	drag_info.data = drag_op_info.data
	drag_info.x_offset = drag_op_info.xOffset or 0
	drag_info.y_offset = drag_op_info.yOffset or 0
	drag_info.alpha = drag_op_info.alpha or 0.75

	DragDrop._drag_targets[ drag_proxy ] = drag_info


	--== Update the Drag Target visual item

	drag_proxy.x = event.x + drag_info.x_offset
	drag_proxy.y = event.y + drag_info.y_offset
	drag_proxy.alpha = drag_info.alpha


	--== Start our drag operation
	drag_proxy.__is_dmc_drag = true
	display.getCurrentStage():setFocus( drag_proxy )

	self:_doDragStart( drag_proxy )
	self:_startListening( drag_proxy )

end


function DragDrop:_createEventStructure( obj, drag_info )

	local drag_info = drag_info or {}
	local e = {
		target = obj,
		format = drag_info.format,
		data = drag_info.data,
	}

	return e
end

function DragDrop:_doDragStart( drag_proxy )

	local drag_info = DragDrop._drag_targets[ drag_proxy ]
	local dragList = self._onDragStart
	for i=1, #dragList do

		local o = dragList[ i ]
		local ds = self._registered[ o ]
		local f = ds.dragStart
		local e = self:_createEventStructure( o, drag_info )

		if ds.call_with_object then
			f( o, e )
		else
			f( e )
		end
	end
end

function DragDrop:_doDragStop( drag_proxy )

	local drag_info = DragDrop._drag_targets[ drag_proxy ]
	local dragList = self._onDragStop
	for i=1, #dragList do

		local o = dragList[ i ]
		local ds = self._registered[ o ]
		local f = ds.dragStop
		local e = self:_createEventStructure( o, drag_info )

		if ds.call_with_object then
			f( o, e )
		else
			f( e )
		end
	end
end

function DragDrop:acceptDragDrop()
	DragDrop.drop_target_accept = true
end

function DragDrop:touch( e )

	local proxy = e.target
	local phase = e.phase
	local result = false

	local drag_info = DragDrop._drag_targets[ proxy ]

	if proxy.__is_dmc_drag then

		if ( phase == "moved" ) then

			-- keep the dragged item moving with the touch coordinates
			proxy.x = e.x + drag_info.x_offset
			proxy.y = e.y + drag_info.y_offset

			-- see if we are over any drop targets
			local newDropTarget = self:_searchDropTargets( e.x, e.y )

			if DragDrop.drop_target == newDropTarget then
				-- same object, so call dragOver()
				if DragDrop.drop_target and DragDrop.drop_target_accept then

					local o = newDropTarget
					local ds = self._registered[ o ]
					local f = ds.dragOver
					if f then
						local e = self:_createEventStructure( o, drag_info )

						if ds.call_with_object then
							result = f( o, e )
						else
							result = f( e )
						end
					end
				end

			elseif DragDrop.drop_target ~= newDropTarget then
				-- new target is nil,
				-- we exited, so call dragExit()
				if DragDrop.drop_target and DragDrop.drop_target_accept then

					local o = DragDrop.drop_target
					local ds = self._registered[ o ]
					local f = ds.dragExit
					if f then
						local e = self:_createEventStructure( o, drag_info )

						if ds.call_with_object then
							result = f( o, e )
						else
							result = f( e )
						end
					end
				end

				self.drop_target_accept = false

				-- call dragEnter on newDropTarget
				if newDropTarget then
					local o = newDropTarget
					local ds = self._registered[ newDropTarget ]
					local f = ds.dragEnter
					if f then
						local e = self:_createEventStructure( o, drag_info )

						if ds.call_with_object then
							result = f( ds.obj, e )
						else
							result = f( e )
						end
					end
				end
			end

			DragDrop.drop_target = newDropTarget

		elseif phase == "ended" or phase == "cancelled" then
			local func

			if phase == "ended" then

				if DragDrop.drop_target and DragDrop.drop_target_accept then
					-- same object, so call dragDrop()

					local o = DragDrop.drop_target
					local ds = self._registered[ o ]
					local f = ds.dragDrop
					self._registered[ o ].proxy = drag_info
					if f then
						local e = self:_createEventStructure( o, drag_info )

						if ds.call_with_object then
							result = f( o, e )
						else
							result = f( e )
						end
					end
					--func = nil
					-- keep on Drop Target, and shrink
					func = self:_createRackAnimation( { x=o.x, y=o.y,alpha=1,
						time=DragDrop.ANIMATE_TIME_FAST,
						resize=true, drag_proxy=proxy,
						owidth=35,oheight=35
					})

				else
					-- drop not accepted, so move back to drag origin
					func = self:_createEndAnimation({ x=drag_info.origin.x,
						y=drag_info.origin.y, time=DragDrop.ANIMATE_TIME_FAST,
						resize=false, drag_proxy=proxy
					})
					drag_info.origin.alpha = 1
				end

			end

			self.drop_target = nil
			self.drop_target_accept = false

			self:_doDragStop( proxy )
			self:_stopListening( proxy )
			func()

			proxy.__is_dmc_drag = nil
			display.getCurrentStage():setFocus( nil )

		end
	end

	return result
end

function DragDrop:_createEndAnimation( params )

	local params = params or {}
	local default_transition_time = 600
	local fDelete, doFunc

	local drag_proxy = params.drag_proxy

	-- create final removal
	fDelete = function( e )
		local dt = drag_proxy

		DragDrop._drag_targets[ dt ] = nil
		dt:removeSelf()
	end

	-- move and/or shrink the object

	local p = {}
	p.onComplete = fDelete
	p.time = params.time or default_transition_time
	p.x = params.x
	p.y = params.y
	if params.resize then
		p.width = 10 ; p.height = 10
	end

	doFunc = function( e )
		transition.to( drag_proxy, p )
	end

	return doFunc
end

function DragDrop:_createRackAnimation( params )

	local params = params or {}
	local default_transition_time = 600
	local fDelete, doFunc

	local drag_proxy = params.drag_proxy

	-- create final removal
	fDelete = function( e )
		print (params.owidth..' '..params.oheight)
	end

	-- move and/or shrink the object

	local p = {}
	p.onComplete = fDelete
	p.time = params.time or default_transition_time
	p.x = params.x 
	p.y = params.y 
	p.alpha = params.alpha
	--if params.resize then
		--p.width = params.owidth ; p.height = params.oheight
	--end

	doFunc = function( e )
		transition.to( drag_proxy, p )
	end

	return doFunc
end


function DragDrop:_startListening( drag_proxy )
	local drag_info = DragDrop._drag_targets[ drag_proxy ]
	drag_info.proxy:addEventListener( "touch", self )
end

function DragDrop:_stopListening( drag_proxy )
	local drag_info = DragDrop._drag_targets[ drag_proxy ]
	drag_info.proxy:removeEventListener( "touch", self )
end

function DragDrop:_searchDropTargets( x, y )
	local dropList = self._registered
	for k, _ in pairs( dropList ) do
		local o = k
		if not isDisplayObject( k ) then
			o = k[ DragDrop.DISPLAY_PROPERTY ]
			if o == nil then
				print( "\nWARNING: object not of type Corona Display nor does it have display property '" .. DragDrop.DISPLAY_PROPERTY .. "'\n" )
			end
		end
		local bounds = o.contentBounds

		local isWithinBounds =
			bounds.xMin <= x and bounds.xMax >= x and bounds.yMin <= y and bounds.yMax >= y
		if isWithinBounds then 
			--print("SET UP RIGHT")
			return k 
		end
	end

	return nil
end


return DragDrop
