-- Twin Stick MOD (MISI mod for GTA2)
-- Original author: Dege @ https://gtamp.com/forum/viewtopic.php?t=1150
-- Description: Full controller support and twin stick mode

local exiting = false
local special = false
local pad_dpad_up = 0
local pad_dpad_down = 1
local pad_dpad_left = 2
local pad_dpad_right = 3
local pad_start = 4
local pad_back = 5
local pad_left_thumb = 6
local pad_right_thumb = 7
local pad_left_shoulder = 8
local pad_right_shoulder = 9
local pad_a = 10
local pad_b = 11
local pad_x = 12
local pad_y = 13
local pad_left_trigger = 14
local pad_right_trigger = 15

function manageXInputs(isInCar, isWalking)
	local steeringThreshold = 0.5
	local acceleratingThreshold = 0.3
	if(GetXInputConnectedDevicesNumber() > 0) then
		local input_status_left = ReadProcessMemory(0x5ecacc, 1)
		local input_status_right = ReadProcessMemory(0x5ecacd, 1)
		local lX, lY, rX, rY = GetXInputAxes()
		if(isInCar or special) then
			if(IsXInputKeyPress(pad_right_trigger) or (lY > 0.9)) then --up-forward
				input_status_left = input_status_left | 0x01
			else
				input_status_left = input_status_left & 0xFE
			end
			if(IsXInputKeyPress(pad_left_trigger) or (lY < -0.9)) then --down-backwards
				input_status_left = input_status_left | 0x02
			else
				input_status_left = input_status_left & 0xFD
			end
			if(IsXInputKeyPress(pad_dpad_left) or (lX < -steeringThreshold)) then --left-left
				input_status_left = input_status_left | 0x04
			else
				input_status_left = input_status_left & 0xFB
			end
			if(IsXInputKeyPress(pad_dpad_right) or (lX > steeringThreshold)) then --right-right
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
			if(not(IsXInputKeyPress(pad_dpad_up) or IsXInputKeyPress(pad_dpad_down))) then
				radio_change_pressed = false
			end
			if(radio_change_pressed == false) then
				if(IsXInputKeyPress(pad_dpad_up)) then
					SendInput(0x70) -- F1 - previous radio
					radio_change_pressed = true
				end
				if(IsXInputKeyPress(pad_dpad_down)) then
					SendInput(0x71) -- F2 - previous radio
					radio_change_pressed = true
				end
			end
		end
		if((IsXInputKeyPress(pad_right_trigger) and (not isInCar)) or IsXInputKeyPress(pad_b)) then --ctrl-attack
			input_status_left = input_status_left | 0x10
		else
			input_status_left = input_status_left & 0xEF
		end
		if(IsXInputKeyPress(pad_y)) then --enter-enter/exit
			input_status_left = input_status_left | 0x20
			if(exiting) then
				SendInput(0x1B) --esc
				exiting = false
			end
		else
			input_status_left = input_status_left & 0xDF
		end
		if((IsXInputKeyPress(pad_left_trigger) and (not isInCar)) or IsXInputKeyPress(pad_a)) then --space-handbrake/jump
			input_status_left = input_status_left | 0x40
			if(exiting) then
				SendInput(0x0D) --enter
				exiting = false
				wait(300)
			end
		else
			input_status_left = input_status_left & 0xBF
		end
		if(IsXInputKeyPress(pad_left_shoulder)) then --Z-previous weapon
			input_status_left = input_status_left | 0x80
		else
			input_status_left = input_status_left & 0x7F
		end
		if(IsXInputKeyPress(pad_right_shoulder)) then --X-next weapon
			input_status_right = input_status_right | 0x01
		else
			input_status_right = input_status_right & 0xFE
		end
		if(IsXInputKeyPress(pad_right_thumb)) then --TAB-special 1
			input_status_right = input_status_right | 0x02
		else
			input_status_right = input_status_right & 0xFD
		end
		if(IsXInputKeyPress(pad_back)) then --exiting
			input_status_right = input_status_right | 0x04
			if(esc_pressed == false) then
				esc_pressed = true
				SendInput(0x1B) --esc
				exiting = not exiting
			end
		else
			input_status_right = input_status_right & 0xFB
			esc_pressed = false
		end
		if(IsXInputKeyPress(pad_start)) then --pause
			if(pause_pressed == false) then
				pause_pressed = true
				SendInput(0x75) --F6
			end
		else
			pause_pressed = false
		end
		
		if(IsXInputKeyPress(pad_left_thumb) and (not isInCar)) then --show location (onfoot only)
			if(f9_pressed == false) then
				f9_pressed = true
				SendInput(0x78) -- F9
			end
		else
			f9_pressed = false
		end

		if(IsXInputKeyPress(pad_left_thumb) or IsXInputKeyPress(pad_x) --[[or (IsXInputKeyPress(pad_left_trigger) and (not isInCar))--]]) then --Left Alt-special 2
		-- if(IsXInputKeyPress(pad_x) --[[or (IsXInputKeyPress(pad_left_trigger) and (not isInCar))--]]) then --Left Alt-special 2
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
	SendMenuInput(0, IsXInputKeyPress(pad_dpad_left) or (lX < -acceleratingThreshold) or IsKeyPress(0x25))
	--right
	SendMenuInput(1, IsXInputKeyPress(pad_dpad_right) or (lX > acceleratingThreshold) or IsKeyPress(0x27))
	--up
	SendMenuInput(2, IsXInputKeyPress(pad_dpad_up) or (lY > acceleratingThreshold) or IsKeyPress(0x26))
	--down
	SendMenuInput(3, IsXInputKeyPress(pad_dpad_down) or (lY < -acceleratingThreshold) or IsKeyPress(0x28))
	--enter
	SendMenuInput(4, IsXInputKeyPress(pad_a) or IsKeyPress(0x0D)) --enter
	--esc
	SendMenuInput(5, IsXInputKeyPress(pad_b) or IsKeyPress(0x1B)) --esc
end

local gamestate = 0
local ped = 0
local walk_speed = 256
local using_xinput_controller = false;
local was_in_car = false;
local esc_pressed = false;
local enter_pressed = false;
local pause_pressed = false;
local f9_pressed = false
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
				if (IsKeyPress(0x26) or IsXInputKeyPress(pad_dpad_up)) then
					vertical = vertical + 1;
				end
				--down
				if (IsKeyPress(0x28) or IsXInputKeyPress(pad_dpad_down)) then
					vertical = vertical - 1;
				end
				--right
				if (IsKeyPress(0x27) or IsXInputKeyPress(pad_dpad_right)) then
					horizontal = horizontal + 1;
				end
				--left
				if (IsKeyPress(0x25) or IsXInputKeyPress(pad_dpad_left)) then
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