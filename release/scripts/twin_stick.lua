--[[
-- Twin Stick MOD
-- MISI MOD for GTA2
--
-- Author: Dege
-- Date: 24 aug 2020
-- Mod version: v0.9
-- MISI since version: v0.5.0
-- Description: Full controller support and twin stick mode
]]--

local exiting = false
local special = false
function manageXInputs(isInCar, isWalking)
	local steeringThreshold = 0.5
	local acceleratingThreshold = 0.3
	if(GetXInputConnectedDevicesNumber() > 0) then
		local input_status_left = ReadProcessMemory(0x5ecacc, 1)
		local input_status_right = ReadProcessMemory(0x5ecacd, 1)
		local lX, lY, rX, rY = GetXInputAxes()
		if(isInCar or special) then
			if(IsXInputKeyPress(15) or (lY > 0.9)) then --up-forward
				input_status_left = input_status_left | 0x01
			else
				input_status_left = input_status_left & 0xFE
			end
			if(IsXInputKeyPress(14) or (lY < -0.9)) then --down-backwards
				input_status_left = input_status_left | 0x02
			else
				input_status_left = input_status_left & 0xFD
			end
			if(IsXInputKeyPress(2) or (lX < -steeringThreshold)) then --left-left
				input_status_left = input_status_left | 0x04
			else
				input_status_left = input_status_left & 0xFB
			end
			if(IsXInputKeyPress(3) or (lX > steeringThreshold)) then --right-right
				input_status_left = input_status_left | 0x08
			else
				input_status_left = input_status_left & 0xF7
			end
		else
			--remove natural movement inputs
			input_status_left = input_status_left & 0xF0
			if(isWalking) then
				input_status_left = input_status_left | 0x01
			end
		end
		--radio controls
		if(isInCar) then
			if(not(IsXInputKeyPress(0) or IsXInputKeyPress(1))) then
				radio_change_pressed = false
			end
			if(radio_change_pressed == false) then
				if(IsXInputKeyPress(0)) then
					SendInput(0x70) -- F1 - previous radio
					radio_change_pressed = true
				end
				if(IsXInputKeyPress(1)) then
					SendInput(0x71) -- F2 - previous radio
					radio_change_pressed = true
				end
			end
		end
		if((IsXInputKeyPress(15) and (not isInCar)) or IsXInputKeyPress(11)) then --ctrl-attack
			input_status_left = input_status_left | 0x10
		else
			input_status_left = input_status_left & 0xEF
		end
		if(IsXInputKeyPress(13)) then --enter-enter/exit
			input_status_left = input_status_left | 0x20
			if(exiting) then
				SendInput(0x1B)
				exiting = false
			end
		else
			input_status_left = input_status_left & 0xDF
		end
		if((IsXInputKeyPress(14) and (not isInCar)) or IsXInputKeyPress(10)) then --space-handbrake/jump
			input_status_left = input_status_left | 0x40
			if(exiting) then
				SendInput(0x0D)
				exiting = false
				wait(300)
			end
		else
			input_status_left = input_status_left & 0xBF
		end
		if(IsXInputKeyPress(8)) then --Z-previous weapon
			input_status_left = input_status_left | 0x80
		else
			input_status_left = input_status_left & 0x7F
		end
		if(IsXInputKeyPress(9)) then --X-next weapon
			input_status_right = input_status_right | 0x01
		else
			input_status_right = input_status_right & 0xFE
		end
		if(IsXInputKeyPress(7)) then --TAB-special 1
			input_status_right = input_status_right | 0x02
		else
			input_status_right = input_status_right & 0xFD
		end
		if(IsXInputKeyPress(5)) then --exiting
			input_status_right = input_status_right | 0x04
			if(esc_pressed == false) then
				esc_pressed = true
				SendInput(0x1B)
				exiting = not exiting
			end
		else
			input_status_right = input_status_right & 0xFB
			esc_pressed = false
		end
		if(IsXInputKeyPress(4)) then --pause
			if(pause_pressed == false) then
				pause_pressed = true
				SendInput(0x75)
			end
		else
			pause_pressed = false
		end
		if(IsXInputKeyPress(6) or IsXInputKeyPress(12) or (IsXInputKeyPress(14) and (not isInCar))) then --Left Alt-special 2
			special = true
			input_status_right = input_status_right | 0x04
		else
			special = false
			input_status_right = input_status_right & 0xFB
		end
		WriteProcessMemory(0x5ecacc, input_status_left, 1)
		WriteProcessMemory(0x5ecacd, input_status_right, 1)
	end
end

function manageInputs(isInCar, isWalking)
	local input_status = ReadProcessMemory(0x5ecacc, 1)
	if(isInCar) then
		if(IsKeyPress(0x26)) then --up-forward
			input_status = input_status | 0x01
		else
			input_status = input_status & 0xFE
		end
		if(IsKeyPress(0x28)) then --down-backwards
			input_status = input_status | 0x02
		else
			input_status = input_status & 0xFD
		end
		if(IsKeyPress(0x25)) then --left-left
			input_status = input_status | 0x04
		else
			input_status = input_status & 0xFB
		end
		if(IsKeyPress(0x27)) then --right-right
			input_status = input_status | 0x08
		else
			input_status = input_status & 0xF7
		end
	else
		--remove natural movement inputs
		input_status = input_status & 0xF0
		if(isWalking) then
			input_status = input_status | 0x01
		end
	end
	if(IsKeyPress(0x11)) then --ctrl-attack
		input_status = input_status | 0x10
	else
		input_status = input_status & 0xEF
	end
	if(IsKeyPress(0x0D)) then --enter-enter/exit
		input_status = input_status | 0x20
	else
		input_status = input_status & 0xDF
	end
	if(IsKeyPress(0x20)) then --space-handbrake/jump
		input_status = input_status | 0x40
	else
		input_status = input_status & 0xBF
	end
	if(IsKeyPress(0x5A)) then --Z-previous weapon
		input_status = input_status | 0x80
	else
		input_status = input_status & 0x7F
	end
	WriteProcessMemory(0x5ecacc, input_status, 1)
	manageXInputs(isInCar, isWalking)
end

function manageSecondaryAngle(ped, update_primary)
	local lX, lY, rX, rY = GetXInputAxes()
	local vertical = rY
	local horizontal = rX
	if(rX ~= 0 or rY ~= 0) then
		local angle = math.deg(math.atan(vertical, horizontal)) + 90
		if(angle < 0) then
			angle = angle + 360
		end
		SetPedSecondaryAngle(ped, angle)
		if(update_primary) then
			SetPedAngle(ped, angle)
		end
	else
		if(lX ~= 0 or lY ~= 0) then
			vertical = lY
			horizontal = lX
			local angle = math.deg(math.atan(vertical, horizontal)) + 90
			if(angle < 0) then
				angle = angle + 360
			end
			SetPedSecondaryAngle(ped, angle)
			if(update_primary) then
				SetPedAngle(ped, angle)
			end
		end
	end
end

function manageMenuXInputs()
	local acceleratingThreshold = 0.3
	local lX, lY, rX, rY = GetXInputAxes()
	--left
	SendMenuInput(0, IsXInputKeyPress(2) or (lX > acceleratingThreshold) or IsKeyPress(0x25))
	--right
	SendMenuInput(1, IsXInputKeyPress(3) or (lX < -acceleratingThreshold) or IsKeyPress(0x27))
	--up
	SendMenuInput(2, IsXInputKeyPress(0) or (lY > acceleratingThreshold) or IsKeyPress(0x26))
	--down
	SendMenuInput(3, IsXInputKeyPress(1) or (lY < -acceleratingThreshold) or IsKeyPress(0x28))
	--enter
	SendMenuInput(4, IsXInputKeyPress(10) or IsKeyPress(0x0D))
	--esc
	SendMenuInput(5, IsXInputKeyPress(11) or IsKeyPress(0x1B))
end

local gamestate = 0
local ped = 0
local walk_speed = 256
local using_xinput_controller = false;
local was_in_car = false;
local esc_pressed = false;
local enter_pressed = false;
local pause_pressed = false;
local radio_change_pressed = false;

while(true) do
	if (GetGameFrame() > 0) then
		if (gamestate == 0) then -- If start new game
			wait(100)
			for i = 1, 6, 1 do
				ped = GetPedStruct(i)
				x, y, z = GetPedPos(ped)
				if (IsPedRangeOfPoint(ped, x, y, z, 0.5)) then
					WriteInLog(string.format("ped index %d id %d struct %X\n",i,GetPedID(ped),ped))
					break
				end
			end
			gamestate = 1
		end
		if (gamestate == 1 and ped ~= 0) then
			local isInCar = ReadProcessMemory(0x5e20bc, 1) ~= 0
			was_in_car = true
			-- entering a car removes my override
			if(using_xinput_controller) then
				if(isInCar == false and was_in_car) then
					EnablePedSecondaryAngle(ped)
				elseif(isInCar and was_in_car == false) then
					DisablePedSecondaryAngle(ped)
				end
			end
			if(isInCar and was_in_car == false) then
				was_in_car = true
			elseif (isInCar == false and was_in_car) then
				was_in_car = false
			end
			local isWalking = false
			local lX, lY, rX, rY = GetXInputAxes()
			local connectedXInputControllers = GetXInputConnectedDevicesNumber()
			if ((connectedXInputControllers > 0) and using_xinput_controller == false) then
				using_xinput_controller = true
				EnablePedSecondaryAngle(ped)
			elseif ((connectedXInputControllers == 0) and using_xinput_controller == true) then
				using_xinput_controller = false
				DisablePedSecondaryAngle(ped)
			end
			if ((not isInCar) and ((using_xinput_controller and (math.abs(lX) > 0 or math.abs(lY) > 0)) or (using_xinput_controller == false and(IsKeyPress(0x25) or IsKeyPress(0x26) or IsKeyPress(0x27) or IsKeyPress(0x28))))) then
				local vertical = 0;
				local horizontal = 0;
				--up
				if (IsKeyPress(0x26) or IsXInputKeyPress(0)) then
					vertical = vertical + 1;
				end
				--down
				if (IsKeyPress(0x28) or IsXInputKeyPress(1)) then
					vertical = vertical - 1;
				end
				--right
				if (IsKeyPress(0x27) or IsXInputKeyPress(2)) then
					horizontal = horizontal + 1;
				end
				--left
				if (IsKeyPress(0x25) or IsXInputKeyPress(3)) then
					horizontal = horizontal - 1;
				end
				if(using_xinput_controller and ((math.abs(lX) > 0) or (math.abs(lY) > 0))) then
					vertical = lY
					horizontal = lX
				end
				if(vertical ~= 0 or horizontal ~= 0) then
					local angle = math.deg(math.atan(vertical, horizontal)) + 90
					if(angle < 0) then
						angle = angle + 360
					end
					SetPedAngle(ped, angle)
					isWalking = true

					local maxSpeed = GetPedMaxSpeed(ped)
					local localSpeed = math.sqrt(vertical * vertical + horizontal * horizontal)
					SetPedSpeed(ped, maxSpeed * localSpeed)
				end
			end
			if(using_xinput_controller) then
				manageSecondaryAngle(ped, (not isInCar) and (not isWalking))
				manageXInputs(isInCar, isWalking)
			else
				manageInputs(isInCar, isWalking)
			end
		end
	else
		gamestate = 0 -- If not frame to game restart or game not loaded
		exiting = false
		manageMenuXInputs()
	end
end