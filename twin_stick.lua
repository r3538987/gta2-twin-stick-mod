-- Twin Stick MOD (MISI mod for GTA2)
-- Original author: Dege @ https://gtamp.com/forum/viewtopic.php?t=1150
-- Description: Full controller support and twin stick mode

-- === Constants ===
local PAD = {
	DPAD_UP = 0, DPAD_DOWN = 1, DPAD_LEFT = 2, DPAD_RIGHT = 3,
	START = 4, BACK = 5, L_THUMB = 6, R_THUMB = 7,
	L_SHOULDER = 8, R_SHOULDER = 9,
	A = 10, B = 11, X = 12, Y = 13,
	L_TRIGGER = 14, R_TRIGGER = 15
}

local KEYS = {
	ENTER = 0x0D, ESC = 0x1B, SPACE = 0x20, CTRL = 0x11,
	LEFT = 0x25, UP = 0x26, RIGHT = 0x27, DOWN = 0x28,
	Z = 0x5A, X = 0x58,
	F1 = 0x70, F2 = 0x71, F6 = 0x75, F7 = 0x76, F9 = 0x78
}

local MEM = {
	INPUT_LEFT = 0x5ecacc,
	INPUT_RIGHT = 0x5ecacd,
	IS_IN_CAR = 0x5e20bc
}

-- Bit positions in GTA2's two input-status bytes.
local INPUT = {
	LEFT = {
		UP = 0x01,
		DOWN = 0x02,
		LEFT = 0x04,
		RIGHT = 0x08,
		ATTACK = 0x10,
		ENTER_EXIT = 0x20,
		JUMP_HANDBRAKE = 0x40,
		PREVIOUS_WEAPON = 0x80
	},
	RIGHT = {
		NEXT_WEAPON = 0x01,
		SPECIAL_1 = 0x02,
		SPECIAL_2 = 0x04
	}
}

local THRESHOLD = {
	STEERING = 0.5,
	MENU = 0.3,
	FULL_AXIS = 0.9
}

local DPAD_BUTTONS = {
	PAD.DPAD_UP,
	PAD.DPAD_DOWN,
	PAD.DPAD_LEFT,
	PAD.DPAD_RIGHT
}

-- === Runtime State ===
local state = {
	exiting = false,
	special = false,
	escPressed = false,
	pausePressed = false,
	f7Pressed = false,
	f9Pressed = false,
	radioPressed = false,
	gameState = 0,
	ped = 0,
	usingController = false,
	controllerSyncRequired = true,
	wasInCar = false
}

-- === General Helpers ===
local function isPadPressed(button)
	return IsXInputKeyPress(button)
end

local function setBit(value, mask, enabled)
	if enabled then
		return value | mask
	end

	return value & (0xFF - mask)
end

local function anyPadPressed(buttons)
	for _, button in ipairs(buttons) do
		if isPadPressed(button) then
			return true
		end
	end

	return false
end

local function angleFromAxes(horizontal, vertical)
	local angle = math.deg(math.atan(vertical, horizontal)) + 90
	if angle < 0 then
		angle = angle + 360
	end

	return angle
end

-- === Controller Shortcuts ===
local function manageRadioControls(isInCar)
	if not isInCar then
		return
	end

	local radioUp = isPadPressed(PAD.DPAD_UP)
	local radioDown = isPadPressed(PAD.DPAD_DOWN)

	if not radioUp and not radioDown then
		state.radioPressed = false
	end

	if not state.radioPressed then
		if radioUp then
			SendInput(KEYS.F1) -- Previous radio station
			state.radioPressed = true
		end
		if radioDown then
			SendInput(KEYS.F2) -- Next radio station
			state.radioPressed = true
		end
	end
end

local function manageThumbShortcuts(leftThumb, rightThumb)
	local bothThumbs = leftThumb and rightThumb

	-- Both stick buttons show the current region (F9).
	if bothThumbs or IsKeyPress(KEYS.F9) then
		if not state.f9Pressed then
			state.f9Pressed = true
			SendInput(KEYS.F9)
			wait(33)
		end
	else
		state.f9Pressed = false
	end

	-- Left stick alone shows the mission/recent brief (F7).
	-- Latch it during the combo so releasing the right stick does not fire F7.
	local f7KeyPressed = IsKeyPress(KEYS.F7)
	if leftThumb or f7KeyPressed then
		if not state.f7Pressed and (not bothThumbs or f7KeyPressed) then
			SendInput(KEYS.F7)
			wait(33)
		end
		state.f7Pressed = true
	else
		state.f7Pressed = false
	end

	return bothThumbs
end

-- === Gameplay Input Translation ===
local function manageXInputs(isInCar, isWalking)
	if GetXInputConnectedDevicesNumber() == 0 then
		return
	end

	local inputLeft = ReadProcessMemory(MEM.INPUT_LEFT, 1)
	local inputRight = ReadProcessMemory(MEM.INPUT_RIGHT, 1)
	local leftX, leftY, rightX = GetXInputAxes()
	local leftThumb = isPadPressed(PAD.L_THUMB)
	local rightThumb = isPadPressed(PAD.R_THUMB)
	local bothThumbs = manageThumbShortcuts(leftThumb, rightThumb)

	-- On foot, the D-pad controls camera zoom while Special 2 is active.
	local dpadZoom = not isInCar and anyPadPressed(DPAD_BUTTONS)

	if isInCar or state.special or dpadZoom then
		local movingUp = isPadPressed(PAD.R_TRIGGER)
			or leftY > THRESHOLD.FULL_AXIS
			or (not isInCar and isPadPressed(PAD.DPAD_UP))
		local movingDown = isPadPressed(PAD.L_TRIGGER)
			or leftY < -THRESHOLD.FULL_AXIS
			or (not isInCar and isPadPressed(PAD.DPAD_DOWN))

		inputLeft = setBit(inputLeft, INPUT.LEFT.UP, movingUp)
		inputLeft = setBit(inputLeft, INPUT.LEFT.DOWN, movingDown)

		-- The right stick controls the turret in a car; otherwise steer normally.
		if isInCar and math.abs(rightX) > THRESHOLD.STEERING then
			inputLeft = setBit(inputLeft, INPUT.LEFT.LEFT, rightX < -THRESHOLD.STEERING)
			inputLeft = setBit(inputLeft, INPUT.LEFT.RIGHT, rightX > THRESHOLD.STEERING)
		else
			local steeringLeft = isPadPressed(PAD.DPAD_LEFT)
				or leftX < -THRESHOLD.STEERING
			local steeringRight = isPadPressed(PAD.DPAD_RIGHT)
				or leftX > THRESHOLD.STEERING

			inputLeft = setBit(inputLeft, INPUT.LEFT.LEFT, steeringLeft)
			inputLeft = setBit(inputLeft, INPUT.LEFT.RIGHT, steeringRight)
		end
	else
		-- Remove the game's natural movement and apply scripted walking.
		inputLeft = inputLeft & 0xF0
		inputLeft = setBit(inputLeft, INPUT.LEFT.UP, isWalking)
	end

	manageRadioControls(isInCar)

	local attacking = (isPadPressed(PAD.R_TRIGGER) and not isInCar)
		or isPadPressed(PAD.B)
	inputLeft = setBit(inputLeft, INPUT.LEFT.ATTACK, attacking)

	local enteringOrExiting = isPadPressed(PAD.Y)
	inputLeft = setBit(inputLeft, INPUT.LEFT.ENTER_EXIT, enteringOrExiting)
	if enteringOrExiting and state.exiting then
		SendInput(KEYS.ESC)
		state.exiting = false
	end

	local jumpingOrBraking = (isPadPressed(PAD.L_TRIGGER) and not isInCar)
		or isPadPressed(PAD.A)
	inputLeft = setBit(inputLeft, INPUT.LEFT.JUMP_HANDBRAKE, jumpingOrBraking)
	if jumpingOrBraking and state.exiting then
		SendInput(KEYS.ENTER)
		state.exiting = false
		wait(300)
	end

	inputLeft = setBit(
		inputLeft,
		INPUT.LEFT.PREVIOUS_WEAPON,
		isPadPressed(PAD.L_SHOULDER)
	)
	inputRight = setBit(
		inputRight,
		INPUT.RIGHT.NEXT_WEAPON,
		isPadPressed(PAD.R_SHOULDER)
	)

	-- Right stick click activates Special 1; the two-stick shortcut suppresses it.
	local specialOne = (rightThumb and not bothThumbs)
		or (isInCar and math.abs(rightX) > THRESHOLD.STEERING)
	inputRight = setBit(inputRight, INPUT.RIGHT.SPECIAL_1, specialOne)

	if isPadPressed(PAD.BACK) then
		inputRight = setBit(inputRight, INPUT.RIGHT.SPECIAL_2, true)
		if not state.escPressed then
			state.escPressed = true
			SendInput(KEYS.ESC)
			state.exiting = not state.exiting
		end
	else
		inputRight = setBit(inputRight, INPUT.RIGHT.SPECIAL_2, false)
		state.escPressed = false
	end

	if isPadPressed(PAD.START) then
		if not state.pausePressed then
			state.pausePressed = true
			SendInput(KEYS.F6)
		end
	else
		state.pausePressed = false
	end

	-- Holding X or a D-pad direction on foot activates Special 2.
	state.special = isPadPressed(PAD.X) or dpadZoom
	inputRight = setBit(inputRight, INPUT.RIGHT.SPECIAL_2, state.special)

	WriteProcessMemory(MEM.INPUT_LEFT, inputLeft, 1)
	WriteProcessMemory(MEM.INPUT_RIGHT, inputRight, 1)
end

local function manageKeyboardInputs(isInCar, isWalking)
	local input = ReadProcessMemory(MEM.INPUT_LEFT, 1)

	if isInCar then
		input = setBit(input, INPUT.LEFT.UP, IsKeyPress(KEYS.UP))
		input = setBit(input, INPUT.LEFT.DOWN, IsKeyPress(KEYS.DOWN))
		input = setBit(input, INPUT.LEFT.LEFT, IsKeyPress(KEYS.LEFT))
		input = setBit(input, INPUT.LEFT.RIGHT, IsKeyPress(KEYS.RIGHT))
	else
		-- Remove the game's natural movement and apply scripted walking.
		input = input & 0xF0
		input = setBit(input, INPUT.LEFT.UP, isWalking)
	end

	input = setBit(input, INPUT.LEFT.ATTACK, IsKeyPress(KEYS.CTRL))
	input = setBit(input, INPUT.LEFT.ENTER_EXIT, IsKeyPress(KEYS.ENTER))
	input = setBit(input, INPUT.LEFT.JUMP_HANDBRAKE, IsKeyPress(KEYS.SPACE))
	input = setBit(input, INPUT.LEFT.PREVIOUS_WEAPON, IsKeyPress(KEYS.Z))

	WriteProcessMemory(MEM.INPUT_LEFT, input, 1)
	manageXInputs(isInCar, isWalking)
end

-- === Twin-Stick Aiming ===
local function manageSecondaryAngle(ped, updatePrimary)
	local leftX, leftY, rightX, rightY = GetXInputAxes()
	local horizontal = rightX
	local vertical = rightY

	if rightX == 0 and rightY == 0 then
		horizontal = leftX
		vertical = leftY
	end

	if horizontal == 0 and vertical == 0 then
		return
	end

	local angle = angleFromAxes(horizontal, vertical)
	SetPedSecondaryAngle(ped, angle)
	if updatePrimary then
		SetPedAngle(ped, angle)
	end
end

-- === Menu Input ===
local function manageMenuInputs()
	local leftX, leftY = GetXInputAxes()

	SendMenuInput(0, isPadPressed(PAD.DPAD_LEFT)
		or leftX < -THRESHOLD.MENU or IsKeyPress(KEYS.LEFT))
	SendMenuInput(1, isPadPressed(PAD.DPAD_RIGHT)
		or leftX > THRESHOLD.MENU or IsKeyPress(KEYS.RIGHT))
	SendMenuInput(2, isPadPressed(PAD.DPAD_UP)
		or leftY > THRESHOLD.MENU or IsKeyPress(KEYS.UP))
	SendMenuInput(3, isPadPressed(PAD.DPAD_DOWN)
		or leftY < -THRESHOLD.MENU or IsKeyPress(KEYS.DOWN))
	SendMenuInput(4, isPadPressed(PAD.A) or IsKeyPress(KEYS.ENTER))
	SendMenuInput(5, isPadPressed(PAD.B) or IsKeyPress(KEYS.ESC))
end

-- === Player and Controller State ===
local function findPlayerPed()
	wait(100)
	local candidate = 0

	for index = 1, 6 do
		candidate = GetPedStruct(index)
		local x, y, z = GetPedPos(candidate)
		if IsPedRangeOfPoint(candidate, x, y, z, 0.5) then
			WriteInLog(string.format(
				"ped index %d id %d struct %X\n",
				index,
				GetPedID(candidate),
				candidate
			))
			break
		end
	end

	return candidate
end

local function updateCarState(ped, isInCar)
	-- Entering a car removes the secondary-angle override.
	if state.usingController then
		if not isInCar and state.wasInCar then
			EnablePedSecondaryAngle(ped)
		elseif isInCar and not state.wasInCar then
			DisablePedSecondaryAngle(ped)
		end
	end

	state.wasInCar = isInCar
end

local function updateControllerConnection(ped, isInCar)
	local controllerConnected = GetXInputConnectedDevicesNumber() > 0
	if not state.controllerSyncRequired
		and controllerConnected == state.usingController then
		return
	end

	state.usingController = controllerConnected
	state.controllerSyncRequired = false

	-- Menus and loading screens can clear the game-side angle override even
	-- while the same controller remains connected, so reapply the desired state.
	if controllerConnected and not isInCar then
		EnablePedSecondaryAngle(ped)
	else
		DisablePedSecondaryAngle(ped)
	end
end

-- === On-Foot Movement ===
local function getWalkingDirection(leftX, leftY)
	local horizontal = 0
	local vertical = 0

	if IsKeyPress(KEYS.UP) or isPadPressed(PAD.DPAD_UP) then
		vertical = vertical + 1
	end
	if IsKeyPress(KEYS.DOWN) or isPadPressed(PAD.DPAD_DOWN) then
		vertical = vertical - 1
	end
	if IsKeyPress(KEYS.RIGHT) or isPadPressed(PAD.DPAD_RIGHT) then
		horizontal = horizontal + 1
	end
	if IsKeyPress(KEYS.LEFT) or isPadPressed(PAD.DPAD_LEFT) then
		horizontal = horizontal - 1
	end

	if state.usingController and (leftX ~= 0 or leftY ~= 0) then
		horizontal = leftX
		vertical = leftY
	end

	return horizontal, vertical
end

local function updateWalking(ped, isInCar, leftX, leftY)
	if isInCar then
		return false
	end

	local controllerMoving = state.usingController and (leftX ~= 0 or leftY ~= 0)
	local keyboardMoving = not state.usingController and (
		IsKeyPress(KEYS.LEFT)
		or IsKeyPress(KEYS.UP)
		or IsKeyPress(KEYS.RIGHT)
		or IsKeyPress(KEYS.DOWN)
	)
	if not controllerMoving and not keyboardMoving then
		return false
	end

	local horizontal, vertical = getWalkingDirection(leftX, leftY)
	if horizontal == 0 and vertical == 0 then
		return false
	end

	SetPedAngle(ped, angleFromAxes(horizontal, vertical))

	local directionMagnitude = math.sqrt(vertical * vertical + horizontal * horizontal)
	SetPedSpeed(ped, GetPedMaxSpeed(ped) * directionMagnitude)
	return true
end

-- === Main Loop ===
while true do
	if GetGameFrame() > 0 then
		if state.gameState == 0 then
			state.ped = findPlayerPed()
			state.gameState = 1
		end

		if state.gameState == 1 and state.ped ~= 0 then
			local isInCar = ReadProcessMemory(MEM.IS_IN_CAR, 1) ~= 0
			local leftX, leftY = GetXInputAxes()

			updateCarState(state.ped, isInCar)
			updateControllerConnection(state.ped, isInCar)

			local isWalking = updateWalking(state.ped, isInCar, leftX, leftY)
			if state.usingController then
				manageSecondaryAngle(state.ped, not isInCar and not isWalking)
				manageXInputs(isInCar, isWalking)
			else
				manageKeyboardInputs(isInCar, isWalking)
			end
		end
	else
		state.gameState = 0
		state.exiting = false
		state.controllerSyncRequired = true
		manageMenuInputs()
	end
end
