local input_service = game:GetService('UserInputService');
local text_service = game:GetService('TextService');
local core_gui = game:GetService('CoreGui');
local teams = game:GetService('Teams');
local players = game:GetService('Players');
local run_service = game:GetService('RunService');
local tween_service = game:GetService('TweenService');
local render_stepped = run_service.RenderStepped;
local local_player = players.LocalPlayer;
local mouse = local_player:GetMouse();
local proximity_prompt_service = game:GetService('ProximityPromptService');
local holding_prompt = false;
proximity_prompt_service.PromptButtonHoldBegan:Connect(function(prompt)
	holding_prompt = true;
	render_stepped:Wait();
	holding_prompt = false;
end);
local protect_gui = protectgui or (syn and syn.protect_gui) or (function() end);

local screen_gui = Instance.new('ScreenGui');
protect_gui(screen_gui);

screen_gui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
screen_gui.Parent = gethui();
screen_gui.DisplayOrder = 10;

local toggles = {};
local options = {};

getgenv().Toggles = toggles;
getgenv().Options = options;

local library = {
	registry = {};
	registry_map = {};
	hud_registry = {};

	font = Enum.Font.GothamMedium;
	font_small = Enum.Font.Gotham;

	font_color       = Color3.fromRGB(225, 225, 235);
	main_color       = Color3.fromRGB(26, 26, 36);
	background_color = Color3.fromRGB(17, 17, 25);
	accent_color     = Color3.fromRGB(55, 40, 140);
	outline_color    = Color3.fromRGB(48, 48, 68);
	risk_color       = Color3.fromRGB(255, 65, 65);
	subtle_color     = Color3.fromRGB(120, 120, 145);

	black = Color3.new(0, 0, 0);

	opened_frames = {};
	dependency_boxes = {};
	signals = {};
	screen_gui = screen_gui;
};

local function dim_color(c, factor)
	local h, s, v = Color3.toHSV(c);
	return Color3.fromHSV(h, s, v * (factor or 0.65));
end;

local function blend_color(c, amount)
	local h, s, v = Color3.toHSV(c);
	return Color3.fromHSV(h, math.max(0, s - amount), math.min(1, v + amount));
end;

library.accent_color_dark  = dim_color(library.accent_color, 0.55);
library.accent_color_light = blend_color(library.accent_color, 0.1);
library.hover_color        = Color3.fromRGB(32, 32, 46);

local rainbow_step = 0;
local hue = 0;

table.insert(library.signals, render_stepped:Connect(function(delta)
	rainbow_step = rainbow_step + delta;
	if rainbow_step >= (1 / 60) then
		rainbow_step = 0;
		hue = hue + (1 / 400);
		if hue > 1 then hue = 0 end;
		library.current_rainbow_hue = hue;
		library.current_rainbow_color = Color3.fromHSV(hue, 0.8, 1);
	end;
end));

local function get_players_string()
	local list = players:GetPlayers();
	for i = 1, #list do list[i] = list[i].Name end;
	table.sort(list, function(a, b) return a < b end);
	return list;
end;

local function get_teams_string()
	local list = teams:GetTeams();
	for i = 1, #list do list[i] = list[i].Name end;
	table.sort(list, function(a, b) return a < b end);
	return list;
end;

local function tween(inst, props, t, style, dir)
	tween_service:Create(inst,
		TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out),
		props
	):Play();
end;

local function make_corner(radius)
	local c = Instance.new('UICorner');
	c.CornerRadius = UDim.new(0, radius or 4);
	return c;
end;

function library:safe_callback(f, ...)
	if not f then return end;
	if not library.notify_on_error then return f(...) end;
	local ok, err = pcall(f, ...);
	if not ok then
		local _, i = err:find(':%d+: ');
		return library:notify(i and err:sub(i + 1) or err, 3);
	end;
end;

function library:attempt_save()
	if library.save_manager then library.save_manager:Save() end;
end;

function library:create(class, properties)
	local inst = type(class) == 'string' and Instance.new(class) or class;
	for k, v in next, properties do inst[k] = v end;
	return inst;
end;

function library:apply_text_stroke(inst)
	inst.TextStrokeTransparency = 1;
	library:create('UIStroke', {
		Color = Color3.new(0, 0, 0);
		Thickness = 1;
		LineJoinMode = Enum.LineJoinMode.Miter;
		Parent = inst;
	});
end;

function library:create_label(properties, is_hud)
	local inst = library:create('TextLabel', {
		BackgroundTransparency = 1;
		Font = library.font;
		TextColor3 = library.font_color;
		TextSize = 13;
		TextStrokeTransparency = 0;
	});
	library:apply_text_stroke(inst);
	library:add_to_registry(inst, { TextColor3 = 'font_color' }, is_hud);
	return library:create(inst, properties);
end;

function library:make_draggable(frame, cutoff)
	frame.Active = true;
	local outline;
	local dragging = false;

	frame.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end;
		local abs_pos = frame.AbsolutePosition;
		local mouse_offset = Vector2.new(mouse.X - abs_pos.X, mouse.Y - abs_pos.Y);
		if mouse_offset.Y > (cutoff or 40) then return end;

		if not outline then
			outline = Instance.new('Frame');
			outline.Size = frame.Size;
			outline.Position = frame.Position;
			outline.AnchorPoint = frame.AnchorPoint;
			outline.BackgroundTransparency = 1;
			outline.BorderSizePixel = 0;
			outline.ZIndex = 1000;
			outline.Parent = frame.Parent;

			local stroke = Instance.new('UIStroke');
			stroke.Thickness = 1;
			stroke.Color = library.accent_color;
			stroke.Transparency = 0.3;
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
			stroke.Parent = outline;

			make_corner(6).Parent = outline;
		end;

		dragging = true;
		while input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
			local parent_pos = frame.Parent.AbsolutePosition;
			local anchor = frame.AnchorPoint;
			local size = frame.AbsoluteSize;
			local new_x = mouse.X - mouse_offset.X - parent_pos.X + (size.X * anchor.X);
			local new_y = mouse.Y - mouse_offset.Y - parent_pos.Y + (size.Y * anchor.Y);
			outline.Position = UDim2.new(0, new_x, 0, new_y);
			render_stepped:Wait();
		end;

		if dragging and outline then
			frame.Position = outline.Position;
			outline:Destroy();
			outline = nil;
			dragging = false;
		end;
	end);
end;

function library:make_resizable(frame, min_size, max_size)
	min_size = min_size or Vector2.new(300, 300);
	max_size = max_size or Vector2.new(900, 800);

	local resizing = false;
	local outline = nil;
	local handle_size = 16;

	local handle = library:create('Frame', {
		BackgroundTransparency = 1;
		AnchorPoint = Vector2.new(1, 1);
		Position = UDim2.new(1, 0, 1, 0);
		Size = UDim2.new(0, handle_size, 0, handle_size);
		ZIndex = frame.ZIndex + 10;
		Parent = frame;
	});

	for row = 1, 3 do
		for col = 1, 3 do
			if row + col >= 4 then
				library:create('Frame', {
					BackgroundColor3 = library.subtle_color;
					BackgroundTransparency = 0.4;
					BorderSizePixel = 0;
					AnchorPoint = Vector2.new(0.5, 0.5);
					Position = UDim2.fromOffset(col * 4 - 2, row * 4 - 2);
					Size = UDim2.fromOffset(2, 2);
					ZIndex = handle.ZIndex;
					Parent = handle;
				});
			end;
		end;
	end;

	handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end;

		local start_mouse = Vector2.new(mouse.X, mouse.Y);
		local start_size = frame.AbsoluteSize;
		local anchor = frame.AnchorPoint;
		local abs_pos = frame.AbsolutePosition;
		local top_left_x = abs_pos.X + anchor.X * start_size.X;
		local top_left_y = abs_pos.Y + anchor.Y * start_size.Y;
		local parent_abs_pos = frame.Parent.AbsolutePosition;

		if not outline then
			outline = Instance.new('Frame');
			outline.AnchorPoint = Vector2.new(0, 0);
			outline.Position = UDim2.fromOffset(top_left_x - parent_abs_pos.X, top_left_y - parent_abs_pos.Y);
			outline.Size = UDim2.fromOffset(start_size.X, start_size.Y);
			outline.BackgroundTransparency = 1;
			outline.BorderSizePixel = 0;
			outline.ZIndex = 1000;
			outline.Parent = frame.Parent;

			local stroke = Instance.new('UIStroke');
			stroke.Thickness = 1;
			stroke.Color = library.accent_color;
			stroke.Transparency = 0.3;
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
			stroke.Parent = outline;

			make_corner(7).Parent = outline;
		end;

		resizing = true;
		while input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
			local delta = Vector2.new(mouse.X - start_mouse.X, mouse.Y - start_mouse.Y);
			local new_x = math.clamp(start_size.X + delta.X, min_size.X, max_size.X);
			local new_y = math.clamp(start_size.Y + delta.Y, min_size.Y, max_size.Y);
			outline.Size = UDim2.fromOffset(new_x, new_y);
			render_stepped:Wait();
		end;

		if resizing and outline then
			local new_abs_x = outline.AbsoluteSize.X;
			local new_abs_y = outline.AbsoluteSize.Y;
			frame.AnchorPoint = Vector2.new(0, 0);
			frame.Position = UDim2.fromOffset(top_left_x - parent_abs_pos.X, top_left_y - parent_abs_pos.Y);
			frame.Size = UDim2.fromOffset(new_abs_x, new_abs_y);
			outline:Destroy();
			outline = nil;
			resizing = false;
		end;
	end);
end;

function library:add_tooltip(info_str, hover_instance)
	local x, y = library:get_text_bounds(info_str, library.font, 13);
	local tooltip = library:create('Frame', {
		BackgroundColor3 = library.main_color;
		BorderSizePixel = 0;
		Size = UDim2.fromOffset(x + 12, y + 8);
		ZIndex = 100;
		Parent = library.screen_gui;
		Visible = false;
	});
	make_corner(4).Parent = tooltip;
	library:create('UIStroke', {
		Color = library.outline_color;
		Thickness = 1;
		Parent = tooltip;
	});
	local label = library:create_label({
		Position = UDim2.fromOffset(6, 4);
		Size = UDim2.fromOffset(x, y);
		TextSize = 13;
		Text = info_str;
		TextColor3 = library.subtle_color;
		TextXAlignment = Enum.TextXAlignment.Left;
		ZIndex = tooltip.ZIndex + 1;
		Parent = tooltip;
	});
	library:add_to_registry(tooltip, { BackgroundColor3 = 'main_color' });
	library:add_to_registry(label, { TextColor3 = 'subtle_color' });

	local is_hovering = false;
	hover_instance.MouseEnter:Connect(function()
		if library:mouse_is_over_opened_frame() then return end;
		is_hovering = true;
		tooltip.Position = UDim2.fromOffset(mouse.X + 15, mouse.Y + 12);
		tooltip.Visible = true;
		while is_hovering do
			RunService.Heartbeat:Wait();
			tooltip.Position = UDim2.fromOffset(mouse.X + 15, mouse.Y + 12);
		end;
	end);
	hover_instance.MouseLeave:Connect(function()
		is_hovering = false;
		tooltip.Visible = false;
	end);
end;

function library:on_highlight(highlight_instance, instance, properties, properties_default)
	highlight_instance.MouseEnter:Connect(function()
		local reg = library.registry_map[instance];
		for property, color_idx in next, properties do
			instance[property] = library[color_idx] or color_idx;
			if reg and reg.properties[property] then reg.properties[property] = color_idx end;
		end;
	end);
	highlight_instance.MouseLeave:Connect(function()
		local reg = library.registry_map[instance];
		for property, color_idx in next, properties_default do
			instance[property] = library[color_idx] or color_idx;
			if reg and reg.properties[property] then reg.properties[property] = color_idx end;
		end;
	end);
end;

function library:mouse_is_over_opened_frame()
	for frame, _ in next, library.opened_frames do
		local abs_pos, abs_size = frame.AbsolutePosition, frame.AbsoluteSize;
		if mouse.X >= abs_pos.X and mouse.X <= abs_pos.X + abs_size.X
			and mouse.Y >= abs_pos.Y and mouse.Y <= abs_pos.Y + abs_size.Y then
			return true;
		end;
	end;
end;

function library:refresh_keybinds()
	if not self.keybind_frame then return end;
	for _, child in ipairs(self.keybind_frame:GetChildren()) do
		if child:IsA('Frame') then
			local label = child:FindFirstChildOfClass('TextLabel');
			if label then
				for _, option in pairs(options) do
					if option.keybind and option.keybind == child then
						child.Visible = not option.no_ui;
						break;
					end;
					if option.text and label.Text and label.Text:lower():find(option.text:lower()) then
						if option.keybind then
							child.Visible = not option.keybind.no_ui;
						end;
						break;
					end;
				end;
			end;
		end;
	end;
end;

function library:is_mouse_over_frame(frame)
	local abs_pos, abs_size = frame.AbsolutePosition, frame.AbsoluteSize;
	if mouse.X >= abs_pos.X and mouse.X <= abs_pos.X + abs_size.X
		and mouse.Y >= abs_pos.Y and mouse.Y <= abs_pos.Y + abs_size.Y then
		return true;
	end;
end;

function library:update_dependency_boxes()
	for _, depbox in next, library.dependency_boxes do depbox:update() end;
end;

function library:map_value(value, min_a, max_a, min_b, max_b)
	return (1 - ((value - min_a) / (max_a - min_a))) * min_b + ((value - min_a) / (max_a - min_a)) * max_b;
end;

function library:get_text_bounds(text, font, size, resolution)
	local bounds = text_service:GetTextSize(text, size, font, resolution or Vector2.new(1920, 1080));
	return bounds.X, bounds.Y;
end;

function library:get_darker_color(color)
	local h, s, v = Color3.toHSV(color);
	return Color3.fromHSV(h, s, v / 1.5);
end;

function library:add_to_registry(instance, properties, is_hud)
	local idx = #library.registry + 1;
	local data = { instance = instance; properties = properties; idx = idx };
	table.insert(library.registry, data);
	library.registry_map[instance] = data;
	if is_hud then table.insert(library.hud_registry, data) end;
end;

function library:remove_from_registry(instance)
	local data = library.registry_map[instance];
	if data then
		for idx = #library.registry, 1, -1 do
			if library.registry[idx] == data then table.remove(library.registry, idx) end;
		end;
		for idx = #library.hud_registry, 1, -1 do
			if library.hud_registry[idx] == data then table.remove(library.hud_registry, idx) end;
		end;
		library.registry_map[instance] = nil;
	end;
end;

function library:update_colors_using_registry()
	for _, object in next, library.registry do
		for property, color_idx in next, object.properties do
			if type(color_idx) == 'string' then
				object.instance[property] = library[color_idx];
			elseif type(color_idx) == 'function' then
				object.instance[property] = color_idx();
			end;
		end;
	end;
end;

function library:give_signal(signal)
	table.insert(library.signals, signal);
end;

function library:unload()
	for idx = #library.signals, 1, -1 do
		local connection = table.remove(library.signals, idx);
		connection:Disconnect();
	end;
	if library.on_unload then library.on_unload() end;
	screen_gui:Destroy();
end;

function library:on_unload(callback)
	library.on_unload = callback;
end;

library:give_signal(screen_gui.DescendantRemoving:Connect(function(instance)
	if library.registry_map[instance] then library:remove_from_registry(instance) end;
end));

local base_addons = {};

do
	local funcs = {};

	function funcs:add_color_picker(idx, info)
		local toggle_label = self.text_label;
		assert(info.default, 'add_color_picker: missing default value.');

		local color_picker = {
			value = info.default;
			transparency = info.transparency or 0;
			type = 'ColorPicker';
			title = type(info.title) == 'string' and info.title or 'Color';
			callback = info.callback or function() end;
		};

		function color_picker:set_hsv_from_rgb(color)
			local h, s, v = Color3.toHSV(color);
			color_picker.hue = h;
			color_picker.sat = s;
			color_picker.vib = v;
		end;
		color_picker:set_hsv_from_rgb(color_picker.value);

		local display_outer = library:create('Frame', {
			BackgroundColor3 = Color3.new(0, 0, 0);
			BorderSizePixel = 0;
			Size = UDim2.new(0, 26, 0, 14);
			ZIndex = 6;
			Parent = toggle_label;
		});
		make_corner(3).Parent = display_outer;

		local display_frame = library:create('Frame', {
			BackgroundColor3 = color_picker.value;
			BorderSizePixel = 0;
			Size = UDim2.new(1, -2, 1, -2);
			Position = UDim2.new(0, 1, 0, 1);
			ZIndex = 6;
			Parent = display_outer;
		});
		make_corner(2).Parent = display_frame;

		local checker_frame = library:create('ImageLabel', {
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 5;
			Image = 'http://www.roblox.com/asset/?id=12977615774';
			Visible = not not info.transparency;
			Parent = display_frame;
		});
		make_corner(2).Parent = checker_frame;

		local picker_outer = library:create('Frame', {
			Name = 'Color';
			BackgroundColor3 = Color3.new(0, 0, 0);
			BorderSizePixel = 0;
			Position = UDim2.fromOffset(display_frame.AbsolutePosition.X, display_frame.AbsolutePosition.Y + 20);
			Size = UDim2.fromOffset(236, info.transparency and 278 or 260);
			Visible = false;
			ZIndex = 15;
			Parent = screen_gui;
		});
		make_corner(6).Parent = picker_outer;

		display_frame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
			picker_outer.Position = UDim2.fromOffset(display_frame.AbsolutePosition.X, display_frame.AbsolutePosition.Y + 20);
		end);

		local picker_inner = library:create('Frame', {
			BackgroundColor3 = library.background_color;
			BorderSizePixel = 0;
			Size = UDim2.new(1, -2, 1, -2);
			Position = UDim2.new(0, 1, 0, 1);
			ZIndex = 16;
			Parent = picker_outer;
		});
		make_corner(5).Parent = picker_inner;

		local highlight = library:create('Frame', {
			BackgroundColor3 = library.accent_color;
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 0, 2);
			ZIndex = 17;
			Parent = picker_inner;
		});
		make_corner(5).Parent = highlight;
		library:create('UIGradient', {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, library.accent_color),
				ColorSequenceKeypoint.new(1, library.accent_color_dark),
			});
			Rotation = 0;
			Parent = highlight;
		});
		library:add_to_registry(highlight, { BackgroundColor3 = 'accent_color' });

		library:create('UIStroke', {
			Color = library.outline_color;
			Thickness = 1;
			Parent = picker_inner;
		});

		local sat_vib_outer = library:create('Frame', {
			BorderSizePixel = 0;
			Position = UDim2.new(0, 6, 0, 26);
			Size = UDim2.new(0, 196, 0, 196);
			ZIndex = 17;
			Parent = picker_inner;
		});
		make_corner(4).Parent = sat_vib_outer;

		local sat_vib_inner = library:create('Frame', {
			BackgroundColor3 = library.background_color;
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 18;
			Parent = sat_vib_outer;
		});
		make_corner(4).Parent = sat_vib_inner;
		library:add_to_registry(sat_vib_inner, { BackgroundColor3 = 'background_color' });

		local sat_vib_map = library:create('ImageLabel', {
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 18;
			Image = 'rbxassetid://4155801252';
			Parent = sat_vib_inner;
		});
		make_corner(4).Parent = sat_vib_map;

		local cursor_outer = library:create('ImageLabel', {
			AnchorPoint = Vector2.new(0.5, 0.5);
			Size = UDim2.new(0, 8, 0, 8);
			BackgroundTransparency = 1;
			Image = 'http://www.roblox.com/asset/?id=9619665977';
			ImageColor3 = Color3.new(0, 0, 0);
			ZIndex = 19;
			Parent = sat_vib_map;
		});
		local cursor_inner = library:create('ImageLabel', {
			Size = UDim2.new(0, 6, 0, 6);
			Position = UDim2.new(0, 1, 0, 1);
			BackgroundTransparency = 1;
			Image = 'http://www.roblox.com/asset/?id=9619665977';
			ZIndex = 20;
			Parent = cursor_outer;
		});

		local hue_selector_outer = library:create('Frame', {
			BorderSizePixel = 0;
			Position = UDim2.new(0, 206, 0, 26);
			Size = UDim2.new(0, 14, 0, 196);
			ZIndex = 17;
			Parent = picker_inner;
		});
		make_corner(4).Parent = hue_selector_outer;

		local hue_selector_inner = library:create('Frame', {
			BackgroundColor3 = Color3.new(1, 1, 1);
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 18;
			Parent = hue_selector_outer;
		});
		make_corner(4).Parent = hue_selector_inner;

		local hue_cursor = library:create('Frame', {
			BackgroundColor3 = Color3.new(1, 1, 1);
			AnchorPoint = Vector2.new(0, 0.5);
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 0, 2);
			ZIndex = 18;
			Parent = hue_selector_inner;
		});

		local sequence_table = {};
		for h = 0, 1, 0.1 do
			table.insert(sequence_table, ColorSequenceKeypoint.new(h, Color3.fromHSV(h, 1, 1)));
		end;
		library:create('UIGradient', {
			Color = ColorSequence.new(sequence_table);
			Rotation = 90;
			Parent = hue_selector_inner;
		});

		local hex_box_outer = library:create('Frame', {
			BorderSizePixel = 0;
			Position = UDim2.fromOffset(6, 228);
			Size = UDim2.new(0.5, -9, 0, 20);
			ZIndex = 18;
			Parent = picker_inner;
		});
		make_corner(3).Parent = hex_box_outer;

		local hex_box_inner = library:create('Frame', {
			BackgroundColor3 = library.main_color;
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 18;
			Parent = hex_box_outer;
		});
		make_corner(3).Parent = hex_box_inner;
		library:add_to_registry(hex_box_inner, { BackgroundColor3 = 'main_color' });
		library:create('UIGradient', {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 210, 210)),
			});
			Rotation = 90;
			Parent = hex_box_inner;
		});

		local hex_box = library:create('TextBox', {
			BackgroundTransparency = 1;
			Position = UDim2.new(0, 5, 0, 0);
			Size = UDim2.new(1, -5, 1, 0);
			Font = library.font;
			PlaceholderColor3 = Color3.fromRGB(130, 130, 150);
			PlaceholderText = 'Hex';
			Text = '#FFFFFF';
			TextColor3 = library.font_color;
			TextSize = 12;
			TextStrokeTransparency = 0;
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex = 20;
			Parent = hex_box_inner;
		});
		library:apply_text_stroke(hex_box);
		library:add_to_registry(hex_box, { TextColor3 = 'font_color' });

		local rgb_box_outer = library:create('Frame', {
			BorderSizePixel = 0;
			Position = UDim2.new(0.5, 3, 0, 228);
			Size = UDim2.new(0.5, -9, 0, 20);
			ZIndex = 18;
			Parent = picker_inner;
		});
		make_corner(3).Parent = rgb_box_outer;

		local rgb_box_inner = library:create('Frame', {
			BackgroundColor3 = library.main_color;
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 18;
			Parent = rgb_box_outer;
		});
		make_corner(3).Parent = rgb_box_inner;
		library:add_to_registry(rgb_box_inner, { BackgroundColor3 = 'main_color' });
		library:create('UIGradient', {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 210, 210)),
			});
			Rotation = 90;
			Parent = rgb_box_inner;
		});

		local rgb_box = library:create('TextBox', {
			BackgroundTransparency = 1;
			Position = UDim2.new(0, 5, 0, 0);
			Size = UDim2.new(1, -5, 1, 0);
			Font = library.font;
			PlaceholderColor3 = Color3.fromRGB(130, 130, 150);
			PlaceholderText = 'R, G, B';
			Text = '255, 255, 255';
			TextColor3 = library.font_color;
			TextSize = 12;
			TextStrokeTransparency = 0;
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex = 20;
			Parent = rgb_box_inner;
		});
		library:apply_text_stroke(rgb_box);
		library:add_to_registry(rgb_box, { TextColor3 = 'font_color' });

		local trans_box_outer, trans_box_inner, trans_cursor;
		if info.transparency then
			trans_box_outer = library:create('Frame', {
				BorderSizePixel = 0;
				Position = UDim2.fromOffset(6, 253);
				Size = UDim2.new(1, -12, 0, 14);
				ZIndex = 19;
				Parent = picker_inner;
			});
			make_corner(3).Parent = trans_box_outer;

			trans_box_inner = library:create('Frame', {
				BackgroundColor3 = color_picker.value;
				BorderSizePixel = 0;
				Size = UDim2.new(1, 0, 1, 0);
				ZIndex = 19;
				Parent = trans_box_outer;
			});
			make_corner(3).Parent = trans_box_inner;
			library:add_to_registry(trans_box_inner, {});

			library:create('ImageLabel', {
				BackgroundTransparency = 1;
				Size = UDim2.new(1, 0, 1, 0);
				Image = 'http://www.roblox.com/asset/?id=12978095818';
				ZIndex = 20;
				Parent = trans_box_inner;
			});

			trans_cursor = library:create('Frame', {
				BackgroundColor3 = Color3.new(1, 1, 1);
				AnchorPoint = Vector2.new(0.5, 0);
				BorderSizePixel = 0;
				Size = UDim2.new(0, 2, 1, 0);
				ZIndex = 21;
				Parent = trans_box_inner;
			});
			make_corner(1).Parent = trans_cursor;
		end;

		local display_label = library:create_label({
			Size = UDim2.new(1, 0, 0, 14);
			Position = UDim2.fromOffset(6, 6);
			TextXAlignment = Enum.TextXAlignment.Left;
			TextSize = 12;
			Text = color_picker.title;
			TextWrapped = false;
			ZIndex = 16;
			Parent = picker_inner;
		});
		library:add_to_registry(display_label, { TextColor3 = 'subtle_color' });

		local context_menu = {};
		do
			context_menu.options = {};
			context_menu.container = library:create('Frame', {
				BorderSizePixel = 0;
				ZIndex = 14;
				Visible = false;
				Parent = screen_gui;
			});
			make_corner(4).Parent = context_menu.container;

			context_menu.inner = library:create('Frame', {
				BackgroundColor3 = library.background_color;
				BorderSizePixel = 0;
				Size = UDim2.fromScale(1, 1);
				ZIndex = 15;
				Parent = context_menu.container;
			});
			make_corner(4).Parent = context_menu.inner;
			library:create('UIStroke', { Color = library.outline_color; Thickness = 1; Parent = context_menu.inner });

			library:create('UIListLayout', {
				Name = 'Layout';
				FillDirection = Enum.FillDirection.Vertical;
				SortOrder = Enum.SortOrder.LayoutOrder;
				Parent = context_menu.inner;
			});
			library:create('UIPadding', {
				Name = 'Padding';
				PaddingLeft = UDim.new(0, 6);
				PaddingRight = UDim.new(0, 6);
				Parent = context_menu.inner;
			});

			local function update_menu_position()
				context_menu.container.Position = UDim2.fromOffset(
					(display_frame.AbsolutePosition.X + display_frame.AbsoluteSize.X) + 5,
					display_frame.AbsolutePosition.Y + 1
				);
			end;
			local function update_menu_size()
				local menu_width = 70;
				for _, label in next, context_menu.inner:GetChildren() do
					if label:IsA('TextLabel') then
						menu_width = math.max(menu_width, label.TextBounds.X + 12);
					end;
				end;
				context_menu.container.Size = UDim2.fromOffset(menu_width, context_menu.inner.Layout.AbsoluteContentSize.Y + 6);
			end;

			display_frame:GetPropertyChangedSignal('AbsolutePosition'):Connect(update_menu_position);
			context_menu.inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(update_menu_size);
			task.spawn(update_menu_position);
			task.spawn(update_menu_size);

			library:add_to_registry(context_menu.inner, { BackgroundColor3 = 'background_color' });

			function context_menu:show() self.container.Visible = true end;
			function context_menu:hide() self.container.Visible = false end;
			function context_menu:add_option(str, callback)
				if type(callback) ~= 'function' then callback = function() end end;
				local btn = library:create_label({
					Active = false;
					Size = UDim2.new(1, 0, 0, 16);
					TextSize = 12;
					Text = str;
					ZIndex = 16;
					Parent = self.inner;
					TextXAlignment = Enum.TextXAlignment.Left;
				});
				library:on_highlight(btn, btn,
					{ TextColor3 = 'accent_color' },
					{ TextColor3 = 'font_color' }
				);
				btn.InputBegan:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end;
					callback();
				end);
			end;

			context_menu:add_option('Copy color', function()
				library.color_clipboard = color_picker.value;
				library:notify('Copied color!', 2);
			end);
			context_menu:add_option('Paste color', function()
				if not library.color_clipboard then return library:notify('No color copied.', 2) end;
				color_picker:set_value_rgb(library.color_clipboard);
			end);
			context_menu:add_option('Copy HEX', function()
				pcall(setclipboard, color_picker.value:ToHex());
				library:notify('Copied hex!', 2);
			end);
			context_menu:add_option('Copy RGB', function()
				pcall(setclipboard, table.concat({
					math.floor(color_picker.value.R * 255),
					math.floor(color_picker.value.G * 255),
					math.floor(color_picker.value.B * 255),
				}, ', '));
				library:notify('Copied RGB!', 2);
			end);
		end;

		library:add_to_registry(picker_inner, { BackgroundColor3 = 'background_color' });
		library:add_to_registry(sat_vib_inner, { BackgroundColor3 = 'background_color' });
		library:add_to_registry(hex_box_inner, { BackgroundColor3 = 'main_color' });
		library:add_to_registry(rgb_box_inner, { BackgroundColor3 = 'main_color' });

		hex_box.FocusLost:Connect(function(enter)
			if enter then
				local ok, result = pcall(Color3.fromHex, hex_box.Text);
				if ok and typeof(result) == 'Color3' then
					color_picker.hue, color_picker.sat, color_picker.vib = Color3.toHSV(result);
				end;
			end;
			color_picker:display();
		end);

		rgb_box.FocusLost:Connect(function(enter)
			if enter then
				local r, g, b = rgb_box.Text:match('(%d+),%s*(%d+),%s*(%d+)');
				if r and g and b then
					color_picker.hue, color_picker.sat, color_picker.vib = Color3.toHSV(Color3.fromRGB(r, g, b));
				end;
			end;
			color_picker:display();
		end);

		function color_picker:display()
			color_picker.value = Color3.fromHSV(color_picker.hue, color_picker.sat, color_picker.vib);
			sat_vib_map.BackgroundColor3 = Color3.fromHSV(color_picker.hue, 1, 1);
			display_frame.BackgroundColor3 = color_picker.value;
			display_frame.BackgroundTransparency = color_picker.transparency;
			display_outer.BackgroundColor3 = dim_color(color_picker.value, 0.5);
			if trans_box_inner then
				trans_box_inner.BackgroundColor3 = color_picker.value;
				trans_cursor.Position = UDim2.new(1 - color_picker.transparency, 0, 0, 0);
			end;
			cursor_outer.Position = UDim2.new(color_picker.sat, 0, 1 - color_picker.vib, 0);
			hue_cursor.Position = UDim2.new(0, 0, color_picker.hue, 0);
			hex_box.Text = '#' .. color_picker.value:ToHex();
			rgb_box.Text = table.concat({
				math.floor(color_picker.value.R * 255),
				math.floor(color_picker.value.G * 255),
				math.floor(color_picker.value.B * 255),
			}, ', ');
			library:safe_callback(color_picker.callback, color_picker.value);
			library:safe_callback(color_picker.changed, color_picker.value);
		end;

		function color_picker:on_changed(func)
			color_picker.changed = func;
			func(color_picker.value);
		end;

		function color_picker:show()
			for frame, _ in next, library.opened_frames do
				if frame.Name == 'Color' then
					frame.Visible = false;
					library.opened_frames[frame] = nil;
				end;
			end;
			picker_outer.Visible = true;
			library.opened_frames[picker_outer] = true;
		end;

		function color_picker:hide()
			picker_outer.Visible = false;
			library.opened_frames[picker_outer] = nil;
		end;

		function color_picker:set_value(hsv, transparency)
			local color = Color3.fromHSV(hsv[1], hsv[2], hsv[3]);
			color_picker.transparency = transparency or 0;
			color_picker:set_hsv_from_rgb(color);
			color_picker:display();
		end;

		function color_picker:set_value_rgb(color, transparency)
			color_picker.transparency = transparency or 0;
			color_picker:set_hsv_from_rgb(color);
			color_picker:display();
		end;

		sat_vib_map.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				while input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
					local min_x = sat_vib_map.AbsolutePosition.X;
					local max_x = min_x + sat_vib_map.AbsoluteSize.X;
					local mouse_x = math.clamp(mouse.X, min_x, max_x);
					local min_y = sat_vib_map.AbsolutePosition.Y;
					local max_y = min_y + sat_vib_map.AbsoluteSize.Y;
					local mouse_y = math.clamp(mouse.Y, min_y, max_y);
					color_picker.sat = (mouse_x - min_x) / (max_x - min_x);
					color_picker.vib = 1 - ((mouse_y - min_y) / (max_y - min_y));
					color_picker:display();
					render_stepped:Wait();
				end;
				library:attempt_save();
			end;
		end);

		hue_selector_inner.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				while input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
					local min_y = hue_selector_inner.AbsolutePosition.Y;
					local max_y = min_y + hue_selector_inner.AbsoluteSize.Y;
					local mouse_y = math.clamp(mouse.Y, min_y, max_y);
					color_picker.hue = (mouse_y - min_y) / (max_y - min_y);
					color_picker:display();
					render_stepped:Wait();
				end;
				library:attempt_save();
			end;
		end);

		display_frame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and not library:mouse_is_over_opened_frame() then
				if picker_outer.Visible then color_picker:hide();
				else context_menu:hide(); color_picker:show() end;
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 and not library:mouse_is_over_opened_frame() then
				context_menu:show(); color_picker:hide();
			end;
		end);

		if trans_box_inner then
			trans_box_inner.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					while input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
						local min_x = trans_box_inner.AbsolutePosition.X;
						local max_x = min_x + trans_box_inner.AbsoluteSize.X;
						local mouse_x = math.clamp(mouse.X, min_x, max_x);
						color_picker.transparency = 1 - ((mouse_x - min_x) / (max_x - min_x));
						color_picker:display();
						render_stepped:Wait();
					end;
					library:attempt_save();
				end;
			end);
		end;

		library:give_signal(input_service.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local abs_pos, abs_size = picker_outer.AbsolutePosition, picker_outer.AbsoluteSize;
				if mouse.X < abs_pos.X or mouse.X > abs_pos.X + abs_size.X
					or mouse.Y < (abs_pos.Y - 20 - 1) or mouse.Y > abs_pos.Y + abs_size.Y then
					color_picker:hide();
				end;
				if not library:is_mouse_over_frame(context_menu.container) then context_menu:hide() end;
			end;
			if input.UserInputType == Enum.UserInputType.MouseButton2 and context_menu.container.Visible then
				if not library:is_mouse_over_frame(context_menu.container) and not library:is_mouse_over_frame(display_frame) then
					context_menu:hide();
				end;
			end;
		end));

		color_picker:display();
		color_picker.display_frame = display_frame;
		options[idx] = color_picker;
		return self;
	end;

	function funcs:add_key_picker(idx, info)
		local parent_obj = self;
		local toggle_label = self.text_label;
		assert(info.default, 'add_key_picker: missing default value.');

		local key_picker = {
			value = info.default;
			toggled = false;
			mode = info.mode or 'Toggle';
			type = 'KeyPicker';
			callback = info.callback or function() end;
			changed_callback = info.changed_callback or function() end;
			sync_toggle_state = info.sync_toggle_state or false;
		};

		if key_picker.sync_toggle_state then
			info.modes = { 'Toggle' };
			info.mode = 'Toggle';
		end;

		local pick_outer = library:create('Frame', {
			BackgroundColor3 = Color3.new(0, 0, 0);
			BorderSizePixel = 0;
			Size = UDim2.new(0, 30, 0, 14);
			ZIndex = 6;
			Parent = toggle_label;
		});
		make_corner(3).Parent = pick_outer;

		local pick_inner = library:create('Frame', {
			BackgroundColor3 = library.main_color;
			BorderSizePixel = 0;
			Size = UDim2.new(1, -2, 1, -2);
			Position = UDim2.new(0, 1, 0, 1);
			ZIndex = 7;
			Parent = pick_outer;
		});
		make_corner(2).Parent = pick_inner;
		library:add_to_registry(pick_inner, { BackgroundColor3 = 'main_color' });

		local display_label = library:create_label({
			Size = UDim2.new(1, 0, 1, 0);
			TextSize = 11;
			Text = info.default;
			TextWrapped = true;
			ZIndex = 8;
			Parent = pick_inner;
		});

		local mode_select_outer = library:create('Frame', {
			BorderSizePixel = 0;
			Position = UDim2.fromOffset(toggle_label.AbsolutePosition.X + toggle_label.AbsoluteSize.X + 5, toggle_label.AbsolutePosition.Y + 1);
			Size = UDim2.new(0, 65, 0, 0);
			Visible = false;
			ZIndex = 14;
			Parent = screen_gui;
		});
		make_corner(4).Parent = mode_select_outer;

		toggle_label:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
			mode_select_outer.Position = UDim2.fromOffset(toggle_label.AbsolutePosition.X + toggle_label.AbsoluteSize.X + 5, toggle_label.AbsolutePosition.Y + 1);
		end);

		local mode_select_inner = library:create('Frame', {
			BackgroundColor3 = library.background_color;
			BorderSizePixel = 0;
			Size = UDim2.new(1, -2, 1, -2);
			Position = UDim2.new(0, 1, 0, 1);
			ZIndex = 15;
			Parent = mode_select_outer;
		});
		make_corner(4).Parent = mode_select_inner;
		library:create('UIStroke', { Color = library.outline_color; Thickness = 1; Parent = mode_select_inner });
		library:add_to_registry(mode_select_inner, { BackgroundColor3 = 'background_color' });

		library:create('UIListLayout', {
			FillDirection = Enum.FillDirection.Vertical;
			SortOrder = Enum.SortOrder.LayoutOrder;
			Padding = UDim.new(0, 1);
			Parent = mode_select_inner;
		});
		library:create('UIPadding', {
			PaddingTop = UDim.new(0, 3);
			PaddingBottom = UDim.new(0, 3);
			Parent = mode_select_inner;
		});

		local container_label = library:create_label({
			TextXAlignment = Enum.TextXAlignment.Left;
			Size = UDim2.new(1, 0, 0, 17);
			TextSize = 12;
			Visible = false;
			ZIndex = 110;
			Parent = library.keybind_container;
		}, true);

		local modes = info.modes or { 'Always', 'Toggle', 'Hold' };
		local mode_buttons = {};

		local mode_count = #modes;
		mode_select_outer.Size = UDim2.new(0, 65, 0, mode_count * 16 + 8);

		for _, mode in next, modes do
			local mode_btn = {};
			local label = library:create_label({
				Active = false;
				Size = UDim2.new(1, 0, 0, 16);
				TextSize = 12;
				Text = mode;
				ZIndex = 16;
				Parent = mode_select_inner;
			});

			function mode_btn:select()
				for _, btn in next, mode_buttons do btn:deselect() end;
				key_picker.mode = mode;
				label.TextColor3 = library.accent_color;
				library.registry_map[label].properties.TextColor3 = 'accent_color';
				mode_select_outer.Visible = false;
			end;

			function mode_btn:deselect()
				key_picker.mode = nil;
				label.TextColor3 = library.font_color;
				library.registry_map[label].properties.TextColor3 = 'font_color';
			end;

			label.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					mode_btn:select();
					library:attempt_save();
				end;
			end);

			if mode == key_picker.mode then mode_btn:select() end;
			mode_buttons[mode] = mode_btn;
		end;

		function key_picker:update()
			if key_picker.no_ui then
				container_label.Visible = false;
				return;
			end;
			local state = key_picker:get_state();
			container_label.Text = string.format('[%s] %s (%s)', key_picker.value, info.text, key_picker.mode);
			container_label.Visible = true;
			container_label.TextColor3 = state and library.accent_color or library.font_color;
			library.registry_map[container_label].properties.TextColor3 = state and 'accent_color' or 'font_color';
			local y_size, x_size = 0, 0;
			for _, label in next, library.keybind_container:GetChildren() do
				if label:IsA('TextLabel') and label.Visible then
					y_size = y_size + 17;
					if label.TextBounds.X > x_size then x_size = label.TextBounds.X end;
				end;
			end;
			library.keybind_frame.Size = UDim2.new(0, math.max(x_size + 12, 210), 0, y_size + 26);
		end;

		function key_picker:get_state()
			if key_picker.mode == 'Always' then return true;
			elseif key_picker.mode == 'Hold' then
				if key_picker.value == 'None' or key_picker.value == '' or key_picker.value == nil then return false end;
				local key = key_picker.value;
				if key == 'MB1' or key == 'MB2' then
					return key == 'MB1' and input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
						or key == 'MB2' and input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton2);
				else
					local key_enum = Enum.KeyCode[key];
					return key_enum and input_service:IsKeyDown(key_enum) or false;
				end;
			else
				return key_picker.toggled;
			end;
		end;

		function key_picker:get_keybind()
			return key_picker.value;
		end;

		function key_picker:get_mode()
			return key_picker.mode;
		end;
		
		function key_picker:set_value(data)
			local key, mode = data[1], data[2];
			display_label.Text = key;
			key_picker.value = key;
			mode_buttons[mode]:select();
			key_picker:update();
		end;

		function key_picker:on_click(callback) key_picker.clicked = callback end;
		function key_picker:on_changed(callback) key_picker.changed = callback; callback(key_picker.value) end;

		if parent_obj.addons then table.insert(parent_obj.addons, key_picker) end;

		function key_picker:do_click()
			if parent_obj.type == 'Toggle' and key_picker.sync_toggle_state then
				parent_obj:set_value(not parent_obj.value);
			end;
			library:safe_callback(key_picker.callback, key_picker.toggled);
			library:safe_callback(key_picker.clicked, key_picker.toggled);
		end;

		local picking = false;
		library:give_signal(input_service.InputBegan:Connect(function(input, gpe)
			if input_service:GetFocusedTextBox() and gpe then return end;
			if holding_prompt then return end;
			if not picking then
				if key_picker.mode == 'Toggle' then
					local key = key_picker.value;
					if key == '' or key == nil then
						key_picker.toggled = false; key_picker:do_click();
					elseif key == 'MB1' or key == 'MB2' then
						if key == 'MB1' and input.UserInputType == Enum.UserInputType.MouseButton1
							or key == 'MB2' and input.UserInputType == Enum.UserInputType.MouseButton2 then
							key_picker.toggled = not key_picker.toggled; key_picker:do_click();
						end;
					elseif input.UserInputType == Enum.UserInputType.Keyboard then
						if input.KeyCode.Name == key then
							key_picker.toggled = not key_picker.toggled; key_picker:do_click();
						end;
					end;
				end;
				key_picker:update();
			end;
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local abs_pos, abs_size = mode_select_outer.AbsolutePosition, mode_select_outer.AbsoluteSize;
				if mouse.X < abs_pos.X or mouse.X > abs_pos.X + abs_size.X
					or mouse.Y < (abs_pos.Y - 20 - 1) or mouse.Y > abs_pos.Y + abs_size.Y then
					mode_select_outer.Visible = false;
				end;
			end;
		end));

		library:give_signal(input_service.InputEnded:Connect(function(input)
			if input_service:GetFocusedTextBox() then return end;
			if not picking then key_picker:update() end;
		end));

		pick_outer.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and not library:mouse_is_over_opened_frame() then
				picking = true;
				display_label.Text = '';
				local should_break, text = false, '';
				task.spawn(function()
					while not should_break do
						if text == '...' then text = '' end;
						text = text .. '.';
						display_label.Text = text;
						wait(0.35);
					end;
				end);
				wait(0.2);
				local event;
				event = input_service.InputBegan:Connect(function(input)
					local key;
					if input.UserInputType == Enum.UserInputType.Keyboard then key = input.KeyCode.Name;
					elseif input.UserInputType == Enum.UserInputType.MouseButton1 then key = 'MB1';
					elseif input.UserInputType == Enum.UserInputType.MouseButton2 then key = 'MB2' end;
					if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Escape then key = '' end;
					should_break = true; picking = false;
					display_label.Text = key;
					key_picker.value = key;
					library:safe_callback(key_picker.changed_callback, input.KeyCode or input.UserInputType);
					library:safe_callback(key_picker.changed, input.KeyCode or input.UserInputType);
					library:attempt_save();
					event:Disconnect();
				end);
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 and not library:mouse_is_over_opened_frame() then
				mode_select_outer.Visible = true;
			end;
		end);

		key_picker:update();
		options[idx] = key_picker;
		return self;
	end;

	base_addons.__index = funcs;
	base_addons.__namecall = function(t, key, ...) return funcs[key](...) end;
end;

local base_groupbox = {};

do
	local funcs = {};

	function funcs:add_blank(size)
		library:create('Frame', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 0, size);
			ZIndex = 1;
			Parent = self.container;
		});
	end;

	function funcs:add_label(text, does_wrap)
		local label = {};
		local groupbox = self;
		local container = groupbox.container;

		local text_label = library:create_label({
			Size = UDim2.new(1, -4, 0, 15);
			TextSize = 13;
			Text = text;
			TextWrapped = does_wrap or false;
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex = 5;
			Parent = container;
		});

		if does_wrap then
			local y = select(2, library:get_text_bounds(text, library.font, 13, Vector2.new(text_label.AbsoluteSize.X, math.huge)));
			text_label.Size = UDim2.new(1, -4, 0, y);
		else
			library:create('UIListLayout', {
				Padding = UDim.new(0, 4);
				FillDirection = Enum.FillDirection.Horizontal;
				HorizontalAlignment = Enum.HorizontalAlignment.Right;
				SortOrder = Enum.SortOrder.LayoutOrder;
				Parent = text_label;
			});
		end;

		label.text_label = text_label;
		label.container = container;

		function label:set_text(text)
			text_label.Text = text;
			if does_wrap then
				local y = select(2, library:get_text_bounds(text, library.font, 13, Vector2.new(text_label.AbsoluteSize.X, math.huge)));
				text_label.Size = UDim2.new(1, -4, 0, y);
			end;
			groupbox:resize();
		end;

		if not does_wrap then setmetatable(label, base_addons) end;
		groupbox:add_blank(4);
		groupbox:resize();
		return label;
	end;

	function funcs:add_button(...)
		local button = {};
		local function process_button_params(_, obj, ...)
			local props = select(1, ...);
			if type(props) == 'table' then
				obj.text = props.Text;
				obj.func = props.Func;
				obj.double_click = props.DoubleClick;
				obj.tooltip = props.Tooltip;
			else
				obj.text = select(1, ...);
				obj.func = select(2, ...);
			end;
			assert(type(obj.func) == 'function', 'add_button: `func` callback is missing.');
		end;
		process_button_params('button', button, ...);

		local groupbox = self;
		local container = groupbox.container;

		local function create_base_button(btn)
			local outer = library:create('Frame', {
				BackgroundColor3 = Color3.new(0, 0, 0);
				BorderSizePixel = 0;
				Size = UDim2.new(1, -4, 0, 22);
				ZIndex = 5;
			});
			make_corner(4).Parent = outer;

			local inner = library:create('Frame', {
				BackgroundColor3 = library.main_color;
				BorderSizePixel = 0;
				Size = UDim2.new(1, -2, 1, -2);
				Position = UDim2.new(0, 1, 0, 1);
				ZIndex = 6;
				Parent = outer;
			});
			make_corner(3).Parent = inner;
			library:add_to_registry(inner, { BackgroundColor3 = 'main_color' });

			library:create('UIGradient', {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210)),
				});
				Rotation = 90;
				Parent = inner;
			});

			local label = library:create_label({
				Size = UDim2.new(1, 0, 1, 0);
				TextSize = 13;
				Text = btn.text;
				ZIndex = 6;
				Parent = inner;
			});

			local hover_strip = library:create('Frame', {
				BackgroundColor3 = library.accent_color;
				BackgroundTransparency = 1;
				BorderSizePixel = 0;
				Size = UDim2.new(1, 0, 0, 1);
				Position = UDim2.new(0, 0, 1, -1);
				ZIndex = 7;
				Parent = inner;
			});
			make_corner(3).Parent = hover_strip;
			library:add_to_registry(hover_strip, { BackgroundColor3 = 'accent_color' });

			outer.MouseEnter:Connect(function()
				tween(hover_strip, { BackgroundTransparency = 0 }, 0.12);
				tween(inner, { BackgroundColor3 = library.hover_color }, 0.12);
			end);
			outer.MouseLeave:Connect(function()
				tween(hover_strip, { BackgroundTransparency = 1 }, 0.12);
				tween(inner, { BackgroundColor3 = library.main_color }, 0.12);
			end);

			return outer, inner, label;
		end;

		local function init_events(btn)
			local function wait_for_event(event, timeout, validator)
				local bindable = Instance.new('BindableEvent');
				local connection = event:Once(function(...)
					if type(validator) == 'function' and validator(...) then bindable:Fire(true);
					else bindable:Fire(false) end;
				end);
				task.delay(timeout, function() connection:disconnect(); bindable:Fire(false) end);
				return bindable.Event:Wait();
			end;

			local function validate_click(input)
				if library:mouse_is_over_opened_frame() then return false end;
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return false end;
				return true;
			end;

			btn.outer.InputBegan:Connect(function(input)
				if not validate_click(input) then return end;
				if btn.locked then return end;

				tween(btn.inner, { Size = UDim2.new(1, -2, 1, -3), Position = UDim2.new(0, 1, 0, 2) }, 0.06);
				task.delay(0.06, function()
					tween(btn.inner, { Size = UDim2.new(1, -2, 1, -2), Position = UDim2.new(0, 1, 0, 1) }, 0.08);
				end);

				if btn.double_click then
					library:remove_from_registry(btn.label);
					library:add_to_registry(btn.label, { TextColor3 = 'accent_color' });
					btn.label.TextColor3 = library.accent_color;
					btn.label.Text = 'Are you sure?';
					btn.locked = true;
					local clicked = wait_for_event(btn.outer.InputBegan, 0.5, validate_click);
					library:remove_from_registry(btn.label);
					library:add_to_registry(btn.label, { TextColor3 = 'font_color' });
					btn.label.TextColor3 = library.font_color;
					btn.label.Text = btn.text;
					task.defer(rawset, btn, 'locked', false);
					if clicked then library:safe_callback(btn.func) end;
					return;
				end;

				library:safe_callback(btn.func);
			end);
		end;

		button.outer, button.inner, button.label = create_base_button(button);
		button.outer.Parent = container;
		init_events(button);

		function button:add_tooltip(tooltip)
			if type(tooltip) == 'string' then library:add_tooltip(tooltip, self.outer) end;
			return self;
		end;

		function button:add_button(...)
			local sub_button = {};
			process_button_params('sub_button', sub_button, ...);
			self.outer.Size = UDim2.new(0.5, -2, 0, 22);
			sub_button.outer, sub_button.inner, sub_button.label = create_base_button(sub_button);
			sub_button.outer.Position = UDim2.new(1, 3, 0, 0);
			sub_button.outer.Size = UDim2.fromOffset(self.outer.AbsoluteSize.X - 2, self.outer.AbsoluteSize.Y);
			sub_button.outer.Parent = self.outer;
			function sub_button:add_tooltip(tooltip)
				if type(tooltip) == 'string' then library:add_tooltip(tooltip, self.outer) end;
				return sub_button;
			end;
			if type(sub_button.tooltip) == 'string' then sub_button:add_tooltip(sub_button.tooltip) end;
			init_events(sub_button);
			return sub_button;
		end;

		if type(button.tooltip) == 'string' then button:add_tooltip(button.tooltip) end;
		groupbox:add_blank(4);
		groupbox:resize();
		return button;
	end;

	function funcs:add_divider()
		local groupbox = self;
		local container = self.container;
		groupbox:add_blank(2);

		local divider_outer = library:create('Frame', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, -4, 0, 1);
			ZIndex = 5;
			Parent = container;
		});

		local divider_line = library:create('Frame', {
			BackgroundColor3 = library.outline_color;
			BorderSizePixel = 0;
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 6;
			Parent = divider_outer;
		});
		library:create('UIGradient', {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
				ColorSequenceKeypoint.new(0.1, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(0.9, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
			});
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.08, 0),
				NumberSequenceKeypoint.new(0.92, 0),
				NumberSequenceKeypoint.new(1, 1),
			});
			Parent = divider_line;
		});
		library:add_to_registry(divider_line, { BackgroundColor3 = 'outline_color' });

		groupbox:add_blank(3);
		groupbox:resize();
	end;

	function funcs:add_input(idx, info)
		local textbox = {
			value = info.default or '';
			numeric = info.numeric or false;
			finished = info.finished or false;
			type = 'Input';
			callback = info.callback or function() end;
		};

		local groupbox = self;
		local container = groupbox.container;

		if info.text and info.text ~= '' then
			library:create_label({
				Size = UDim2.new(1, 0, 0, 14);
				TextSize = 12;
				Text = info.text;
				TextXAlignment = Enum.TextXAlignment.Left;
				ZIndex = 5;
				Parent = container;
			});
			groupbox:add_blank(1);
		end;

		local textbox_outer = library:create('Frame', {
			BackgroundColor3 = Color3.new(0, 0, 0);
			BorderSizePixel = 0;
			Size = UDim2.new(1, -4, 0, 22);
			ZIndex = 5;
			Parent = container;
		});
		make_corner(4).Parent = textbox_outer;

		local textbox_inner = library:create('Frame', {
			BackgroundColor3 = library.main_color;
			BorderSizePixel = 0;
			Size = UDim2.new(1, -2, 1, -2);
			Position = UDim2.new(0, 1, 0, 1);
			ZIndex = 6;
			Parent = textbox_outer;
		});
		make_corner(3).Parent = textbox_inner;
		library:add_to_registry(textbox_inner, { BackgroundColor3 = 'main_color' });

		library:create('UIGradient', {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210)),
			});
			Rotation = 90;
			Parent = textbox_inner;
		});

		local focus_stroke = library:create('UIStroke', {
			Color = library.outline_color;
			Thickness = 1;
			Parent = textbox_inner;
		});

		if type(info.tooltip) == 'string' then library:add_tooltip(info.tooltip, textbox_outer) end;

		local box_container = library:create('Frame', {
			BackgroundTransparency = 1;
			ClipsDescendants = true;
			Position = UDim2.new(0, 6, 0, 0);
			Size = UDim2.new(1, -6, 1, 0);
			ZIndex = 7;
			Parent = textbox_inner;
		});

		local box = library:create('TextBox', {
			BackgroundTransparency = 1;
			Position = UDim2.fromOffset(0, 0);
			Size = UDim2.fromScale(5, 1);
			Font = library.font;
			PlaceholderColor3 = Color3.fromRGB(100, 100, 120);
			PlaceholderText = info.placeholder or '';
			Text = info.default or '';
			TextColor3 = library.font_color;
			TextSize = 13;
			TextStrokeTransparency = 0;
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex = 7;
			Parent = box_container;
		});
		library:apply_text_stroke(box);
		library:add_to_registry(box, { TextColor3 = 'font_color' });

		box.Focused:Connect(function()
			tween(focus_stroke, { Color = library.accent_color }, 0.15);
		end);
		box.FocusLost:Connect(function()
			tween(focus_stroke, { Color = library.outline_color }, 0.15);
		end);

		function textbox:set_value(text)
			if info.max_length and #text > info.max_length then text = text:sub(1, info.max_length) end;
			if textbox.numeric then
				if not tonumber(text) and text:len() > 0 then text = textbox.value end;
			end;
			textbox.value = text;
			box.Text = text;
			library:safe_callback(textbox.callback, textbox.value);
			library:safe_callback(textbox.changed, textbox.value);
		end;

		if textbox.finished then
			box.FocusLost:Connect(function(enter)
				if not enter then return end;
				textbox:set_value(box.Text);
				library:attempt_save();
			end);
		else
			box:GetPropertyChangedSignal('Text'):Connect(function()
				textbox:set_value(box.Text);
				library:attempt_save();
			end);
		end;

		local function update()
			local padding = 2;
			local reveal = box_container.AbsoluteSize.X;
			if not box:IsFocused() or box.TextBounds.X <= reveal - 2 * padding then
				box.Position = UDim2.new(0, padding, 0, 0);
			else
				local cursor = box.CursorPosition;
				if cursor ~= -1 then
					local subtext = string.sub(box.Text, 1, cursor - 1);
					local width = text_service:GetTextSize(subtext, box.TextSize, box.Font, Vector2.new(math.huge, math.huge)).X;
					local current_cursor_pos = box.Position.X.Offset + width;
					if current_cursor_pos < padding then
						box.Position = UDim2.fromOffset(padding - width, 0);
					elseif current_cursor_pos > reveal - padding - 1 then
						box.Position = UDim2.fromOffset(reveal - width - padding - 1, 0);
					end;
				end;
			end;
		end;

		task.spawn(update);
		box:GetPropertyChangedSignal('Text'):Connect(update);
		box:GetPropertyChangedSignal('CursorPosition'):Connect(update);
		box.FocusLost:Connect(update);
		box.Focused:Connect(update);

		function textbox:on_changed(func) textbox.changed = func; func(textbox.value) end;

		groupbox:add_blank(4);
		groupbox:resize();
		options[idx] = textbox;
		return textbox;
	end;

	function funcs:add_toggle(idx, info)
		assert(info.text, 'add_toggle: missing `text` string.');

		local toggle = {
			value = info.default or false;
			type = 'Toggle';
			callback = info.callback or function() end;
			addons = {};
			risky = info.risky;
		};

		local groupbox = self;
		local container = groupbox.container;

		local toggle_outer = library:create('Frame', {
			BackgroundColor3 = library.main_color;
			BorderSizePixel = 0;
			Size = UDim2.new(0, 14, 0, 14);
			ZIndex = 5;
			Parent = container;
		});
		make_corner(3).Parent = toggle_outer;

		local toggle_stroke = library:create('UIStroke', {
			Color = library.outline_color;
			Thickness = 1;
			Parent = toggle_outer;
		});
		library:add_to_registry(toggle_outer, { BackgroundColor3 = 'main_color' });

		local checkmark = library:create('ImageLabel', {
			BackgroundTransparency = 1;
			Size = UDim2.new(0, 8, 0, 8);
			Position = UDim2.new(0.5, -4, 0.5, -4);
			ImageColor3 = library.accent_color;
			ImageTransparency = 1;
			ZIndex = 7;
			Parent = toggle_outer;
		});

		local toggle_label = library:create_label({
			Size = UDim2.new(0, 210, 1, 0);
			Position = UDim2.new(1, 7, 0, 0);
			TextSize = 13;
			Text = info.text;
			TextXAlignment = Enum.TextXAlignment.Left;
			ZIndex = 6;
			Parent = toggle_outer;
			RichText = true;
		});

		library:create('UIListLayout', {
			Padding = UDim.new(0, 4);
			FillDirection = Enum.FillDirection.Horizontal;
			HorizontalAlignment = Enum.HorizontalAlignment.Right;
			SortOrder = Enum.SortOrder.LayoutOrder;
			Parent = toggle_label;
		});

		local toggle_region = library:create('Frame', {
			BackgroundTransparency = 1;
			Size = UDim2.new(0, 165, 1, 0);
			ZIndex = 8;
			Parent = toggle_outer;
		});

		toggle_region.MouseEnter:Connect(function()
			if not toggle.value then
				tween(toggle_outer, { BackgroundColor3 = library.hover_color }, 0.1);
			end;
		end);
		toggle_region.MouseLeave:Connect(function()
			if not toggle.value then
				tween(toggle_outer, { BackgroundColor3 = library.main_color }, 0.1);
			end;
		end);

		if type(info.tooltip) == 'string' then library:add_tooltip(info.tooltip, toggle_region) end;

		function toggle:update_colors() toggle:display() end;

		function toggle:display()
			if toggle.value then
				tween(toggle_outer, { BackgroundColor3 = library.accent_color }, 0.12);
				tween(checkmark, { ImageTransparency = 0 }, 0.12);
				tween(toggle_stroke, { Transparency = 1 }, 0.12);
				library.registry_map[toggle_outer].properties.BackgroundColor3 = 'accent_color';
			else
				tween(toggle_outer, { BackgroundColor3 = library.main_color }, 0.12);
				tween(checkmark, { ImageTransparency = 1 }, 0.12);
				tween(toggle_stroke, { Transparency = 0 }, 0.12);
				library.registry_map[toggle_outer].properties.BackgroundColor3 = 'main_color';
			end;
		end;

		function toggle:on_changed(func) toggle.changed = func; func(toggle.value) end;

		function toggle:set_value(bool)
			bool = not not bool;
			toggle.value = bool;
			toggle:display();
			for _, addon in next, toggle.addons do
				if addon.type == 'KeyPicker' and addon.sync_toggle_state then
					addon.toggled = bool; addon:update();
				end;
			end;
			library:safe_callback(toggle.callback, toggle.value);
			library:safe_callback(toggle.changed, toggle.value);
			setthreadidentity(8);
			library:update_dependency_boxes();
		end;

		toggle_region.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and not library:mouse_is_over_opened_frame() then
				toggle:set_value(not toggle.value);
				library:attempt_save();
			end;
		end);

		if toggle.risky then
			library:remove_from_registry(toggle_label);
			toggle_label.TextColor3 = library.risk_color;
			library:add_to_registry(toggle_label, { TextColor3 = 'risk_color' });
		end;

		toggle:display();
		groupbox:add_blank(info.blank_size or 6);
		groupbox:resize();

		toggle.text_label = toggle_label;
		toggle.container = container;
		setmetatable(toggle, base_addons);

		toggles[idx] = toggle;
		library:update_dependency_boxes();
		return toggle;
	end;

	function funcs:add_slider(idx, info)
		assert(info.default, 'add_slider: missing default value.');
		assert(info.text, 'add_slider: missing slider text.');
		assert(info.min, 'add_slider: missing minimum value.');
		assert(info.max, 'add_slider: missing maximum value.');
		assert(info.rounding ~= nil, 'add_slider: missing rounding value.');

		local slider = {
			value = info.default;
			min = info.min;
			max = info.max;
			rounding = info.rounding;
			max_size = 228;
			type = 'Slider';
			callback = info.callback or function() end;
		};

		local groupbox = self;
		local container = groupbox.container;

		if not info.compact then
			library:create_label({
				Size = UDim2.new(1, 0, 0, 10);
				TextSize = 12;
				Text = info.text;
				TextXAlignment = Enum.TextXAlignment.Left;
				TextYAlignment = Enum.TextYAlignment.Bottom;
				ZIndex = 5;
				Parent = container;
			});
			groupbox:add_blank(3);
		end;

		local slider_outer = library:create('Frame', {
			BackgroundColor3 = Color3.new(0, 0, 0);
			BorderSizePixel = 0;
			Size = UDim2.new(1, -4, 0, 14);
			ZIndex = 5;
			Parent = container;
		});
		make_corner(4).Parent = slider_outer;
		library:add_to_registry(slider_outer, {});

		local slider_track = library:create('Frame', {
			BackgroundColor3 = library.main_color;
			BorderSizePixel = 0;
			Size = UDim2.new(1, -2, 1, -2);
			Position = UDim2.new(0, 1, 0, 1);
			ZIndex = 6;
			Parent = slider_outer;
		});
		make_corner(3).Parent = slider_track;
		library:add_to_registry(slider_track, { BackgroundColor3 = 'main_color' });

		local fill = library:create('Frame', {
			BackgroundColor3 = library.accent_color;
			BorderSizePixel = 0;
			Size = UDim2.new(0, 0, 1, 0);
			ZIndex = 7;
			Parent = slider_track;
		});
		make_corner(3).Parent = fill;
		library:add_to_registry(fill, { BackgroundColor3 = 'accent_color' });

		library:create('UIGradient', {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, library.accent_color_light),
				ColorSequenceKeypoint.new(1, library.accent_color),
			});
			Rotation = 0;
			Parent = fill;
		});

		local thumb = library:create('Frame', {
			BackgroundColor3 = Color3.new(1, 1, 1);
			BorderSizePixel = 0;
			AnchorPoint = Vector2.new(0.5, 0.5);
			Size = UDim2.new(0, 6, 0, 10);
			Position = UDim2.new(0, 0, 0.5, 0);
			ZIndex = 9;
			Parent = slider_track;
		});
		make_corner(2).Parent = thumb;

		local display_label = library:create_label({
			Size = UDim2.new(1, 0, 1, 0);
			TextSize = 11;
			Text = '';
			ZIndex = 9;
			Parent = slider_track;
		});

		if type(info.tooltip) == 'string' then library:add_tooltip(info.tooltip, slider_outer) end;

		slider_outer.MouseEnter:Connect(function()
			tween(fill, { BackgroundColor3 = library.accent_color_light }, 0.1);
		end);
		slider_outer.MouseLeave:Connect(function()
			tween(fill, { BackgroundColor3 = library.accent_color }, 0.1);
		end);

		function slider:update_colors()
			fill.BackgroundColor3 = library.accent_color;
		end;

		function slider:display()
			local suffix = info.suffix or '';
			if info.compact then
				display_label.Text = info.text .. ': ' .. slider.value .. suffix;
			elseif info.hide_max then
				display_label.Text = tostring(slider.value) .. suffix;
			else
				display_label.Text = string.format('%s/%s', slider.value .. suffix, slider.max .. suffix);
			end;
			local x = math.ceil(library:map_value(slider.value, slider.min, slider.max, 0, slider.max_size));
			fill.Size = UDim2.new(0, x, 1, 0);
			thumb.Position = UDim2.new(0, x, 0.5, 0);
			thumb.Visible = x > 0;
		end;

		function slider:on_changed(func) slider.changed = func; func(slider.value) end;

		local function round(value)
			if slider.rounding == 0 then return math.floor(value) end;
			return tonumber(string.format('%.' .. slider.rounding .. 'f', value));
		end;

		function slider:get_value_from_x_offset(x)
			return round(library:map_value(x, 0, slider.max_size, slider.min, slider.max));
		end;

		function slider:set_value(str)
			local num = tonumber(str);
			if not num then return end;
			num = math.clamp(num, slider.min, slider.max);
			slider.value = num;
			slider:display();
			library:safe_callback(slider.callback, slider.value);
			library:safe_callback(slider.changed, slider.value);
		end;

		slider_track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and not library:mouse_is_over_opened_frame() then
				local m_pos = mouse.X;
				local g_pos = fill.Size.X.Offset;
				local diff = m_pos - (fill.AbsolutePosition.X + g_pos);

				while input_service:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
					local n_m_pos = mouse.X;
					local n_x = math.clamp(g_pos + (n_m_pos - m_pos) + diff, 0, slider.max_size);
					local n_value = slider:get_value_from_x_offset(n_x);
					local old_value = slider.value;
					slider.value = n_value;
					slider:display();
					if n_value ~= old_value then
						library:safe_callback(slider.callback, slider.value);
						library:safe_callback(slider.changed, slider.value);
					end;
					render_stepped:Wait();
				end;
				library:attempt_save();
			end;
		end);

		slider:display();
		groupbox:add_blank(info.blank_size or 6);
		groupbox:resize();
		options[idx] = slider;
		return slider;
	end;

	function funcs:add_dropdown(idx, info)
		if info.special_type == 'Player' then info.values = get_players_string(); info.allow_null = true;
		elseif info.special_type == 'Team' then info.values = get_teams_string(); info.allow_null = true end;

		assert(info.values, 'add_dropdown: missing dropdown value list.');
		assert(info.allow_null or info.default, 'add_dropdown: missing default value.');
		if not info.text then info.compact = true end;

		local dropdown = {
			values = info.values;
			value = info.multi and {};
			multi = info.multi;
			type = 'Dropdown';
			special_type = info.special_type;
			callback = info.callback or function() end;
		};

		local groupbox = self;
		local container = groupbox.container;

		if not info.compact then
			library:create_label({
				Size = UDim2.new(1, 0, 0, 10);
				TextSize = 12;
				Text = info.text;
				TextXAlignment = Enum.TextXAlignment.Left;
				TextYAlignment = Enum.TextYAlignment.Bottom;
				ZIndex = 5;
				Parent = container;
			});
			groupbox:add_blank(3);
		end;

		local dropdown_outer = library:create('Frame', {
			BackgroundColor3 = Color3.new(0, 0, 0);
			BorderSizePixel = 0;
			Size = UDim2.new(1, -4, 0, 22);
			ZIndex = 5;
			Parent = container;
		});
		make_corner(4).Parent = dropdown_outer;
		library:add_to_registry(dropdown_outer, {});

		local dropdown_inner = library:create('Frame', {
			BackgroundColor3 = library.main_color;
			BorderSizePixel = 0;
			Size = UDim2.new(1, -2, 1, -2);
			Position = UDim2.new(0, 1, 0, 1);
			ZIndex = 6;
			Parent = dropdown_outer;
		});
		make_corner(3).Parent = dropdown_inner;
		library:add_to_registry(dropdown_inner, { BackgroundColor3 = 'main_color' });
		library:create('UIGradient', {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210)),
			});
			Rotation = 90;
			Parent = dropdown_inner;
		});

		local dropdown_arrow = library:create('ImageLabel', {
			AnchorPoint = Vector2.new(0, 0.5);
			BackgroundTransparency = 1;
			Position = UDim2.new(1, -17, 0.5, 0);
			Size = UDim2.new(0, 12, 0, 12);
			Image = 'http://www.roblox.com/asset/?id=6282522798';
			ZIndex = 8;
			Parent = dropdown_inner;
		});

		local item_list = library:create_label({
			Position = UDim2.new(0, 6, 0, 0);
			Size = UDim2.new(1, -22, 1, 0);
			TextSize = 13;
			Text = '--';
			TextXAlignment = Enum.TextXAlignment.Left;
			TextWrapped = true;
			ZIndex = 7;
			Parent = dropdown_inner;
		});

		dropdown_outer.MouseEnter:Connect(function()
			tween(dropdown_inner, { BackgroundColor3 = library.hover_color }, 0.1);
		end);
		dropdown_outer.MouseLeave:Connect(function()
			tween(dropdown_inner, { BackgroundColor3 = library.main_color }, 0.1);
		end);

		if type(info.tooltip) == 'string' then library:add_tooltip(info.tooltip, dropdown_outer) end;

		local max_dropdown_items = 8;

		local list_outer = library:create('Frame', {
			BackgroundColor3 = Color3.new(0, 0, 0);
			BorderSizePixel = 0;
			ZIndex = 20;
			Visible = false;
			Parent = screen_gui;
		});
		make_corner(5).Parent = list_outer;

		local function recalculate_list_position()
			list_outer.Position = UDim2.fromOffset(dropdown_outer.AbsolutePosition.X, dropdown_outer.AbsolutePosition.Y + dropdown_outer.Size.Y.Offset + 2);
		end;
		local function recalculate_list_size(y_size)
			list_outer.Size = UDim2.fromOffset(dropdown_outer.AbsoluteSize.X, y_size or (max_dropdown_items * 20 + 2));
		end;
		recalculate_list_position(); recalculate_list_size();
		dropdown_outer:GetPropertyChangedSignal('AbsolutePosition'):Connect(recalculate_list_position);

		local list_inner = library:create('Frame', {
			BackgroundColor3 = library.background_color;
			BorderSizePixel = 0;
			Size = UDim2.new(1, -2, 1, -2);
			Position = UDim2.new(0, 1, 0, 1);
			ZIndex = 21;
			Parent = list_outer;
		});
		make_corner(4).Parent = list_inner;
		library:create('UIStroke', { Color = library.outline_color; Thickness = 1; Parent = list_inner });
		library:add_to_registry(list_inner, { BackgroundColor3 = 'background_color' });

		local scrolling = library:create('ScrollingFrame', {
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			CanvasSize = UDim2.new(0, 0, 0, 0);
			Size = UDim2.new(1, 0, 1, 0);
			ZIndex = 21;
			Parent = list_inner;
			TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
			BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
			ScrollBarThickness = 2;
			ScrollBarImageColor3 = library.accent_color;
		});
		library:add_to_registry(scrolling, { ScrollBarImageColor3 = 'accent_color' });
		library:create('UIListLayout', {
			Padding = UDim.new(0, 0);
			FillDirection = Enum.FillDirection.Vertical;
			SortOrder = Enum.SortOrder.LayoutOrder;
			Parent = scrolling;
		});

		function dropdown:display()
			local str = '';
			if info.multi then
				for _, value in next, dropdown.values do
					if dropdown.value[value] then str = str .. value .. ', ' end;
				end;
				str = str:sub(1, #str - 2);
			else
				str = dropdown.value or '';
			end;
			item_list.Text = (str == '' and '--' or str);
		end;

		function dropdown:get_active_values()
			if info.multi then
				local t = {};
				for value, _ in next, dropdown.value do table.insert(t, value) end;
				return t;
			else
				return dropdown.value and 1 or 0;
			end;
		end;

		function dropdown:build_dropdown_list()
			for _, element in next, scrolling:GetChildren() do
				if not element:IsA('UIListLayout') then element:Destroy() end;
			end;
			local count = 0;
			local buttons = {};

			for _, value in next, dropdown.values do
				local tbl = {};
				count = count + 1;

				local btn = library:create('Frame', {
					BackgroundColor3 = library.main_color;
					BorderSizePixel = 0;
					Size = UDim2.new(1, 0, 0, 20);
					ZIndex = 23;
					Active = true;
					Parent = scrolling;
				});
				library:add_to_registry(btn, { BackgroundColor3 = 'main_color' });

				local select_strip = library:create('Frame', {
					BackgroundColor3 = library.accent_color;
					BorderSizePixel = 0;
					Size = UDim2.new(0, 2, 1, 0);
					ZIndex = 24;
					BackgroundTransparency = 1;
					Parent = btn;
				});
				library:add_to_registry(select_strip, { BackgroundColor3 = 'accent_color' });

				local btn_label = library:create_label({
					Active = false;
					Size = UDim2.new(1, -10, 1, 0);
					Position = UDim2.new(0, 8, 0, 0);
					TextSize = 13;
					Text = value;
					TextXAlignment = Enum.TextXAlignment.Left;
					ZIndex = 25;
					Parent = btn;
				});

				btn.MouseEnter:Connect(function()
					tween(btn, { BackgroundColor3 = library.hover_color }, 0.08);
				end);
				btn.MouseLeave:Connect(function()
					local selected = info.multi and dropdown.value[value] or dropdown.value == value;
					if not selected then
						tween(btn, { BackgroundColor3 = library.main_color }, 0.08);
					end;
				end);

				local selected = info.multi and dropdown.value[value] or dropdown.value == value;

				function tbl:update_button()
					if info.multi then selected = dropdown.value[value];
					else selected = dropdown.value == value end;
					btn_label.TextColor3 = selected and library.accent_color or library.font_color;
					library.registry_map[btn_label].properties.TextColor3 = selected and 'accent_color' or 'font_color';
					tween(select_strip, { BackgroundTransparency = selected and 0 or 1 }, 0.1);
					if selected then
						tween(btn, { BackgroundColor3 = library.hover_color }, 0.1);
					else
						tween(btn, { BackgroundColor3 = library.main_color }, 0.1);
					end;
				end;

				btn_label.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						local try = not selected;
						if dropdown:get_active_values() == 1 and not try and not info.allow_null then
						else
							if info.multi then
								selected = try;
								if selected then dropdown.value[value] = true;
								else dropdown.value[value] = nil end;
							else
								selected = try;
								if selected then dropdown.value = value;
								else dropdown.value = nil end;
								for _, other_btn in next, buttons do other_btn:update_button() end;
							end;
							tbl:update_button();
							dropdown:display();
							library:safe_callback(dropdown.callback, dropdown.value);
							library:safe_callback(dropdown.changed, dropdown.value);
							library:attempt_save();
						end;
					end;
				end);

				tbl:update_button();
				buttons[btn] = tbl;
			end;

			dropdown:display();
			scrolling.CanvasSize = UDim2.fromOffset(0, count * 20 + 1);
			local y = math.clamp(count * 20, 0, max_dropdown_items * 20) + 1;
			recalculate_list_size(y);
		end;

		function dropdown:set_values(new_values)
			if new_values then dropdown.values = new_values end;
			dropdown:build_dropdown_list();
		end;

		function dropdown:open_dropdown()
			list_outer.Visible = true;
			library.opened_frames[list_outer] = true;
			tween(dropdown_arrow, { Rotation = 180 }, 0.15);
		end;

		function dropdown:close_dropdown()
			list_outer.Visible = false;
			library.opened_frames[list_outer] = nil;
			tween(dropdown_arrow, { Rotation = 0 }, 0.15);
		end;

		function dropdown:on_changed(func) dropdown.changed = func; func(dropdown.value) end;

		function dropdown:set_value(val)
			if dropdown.multi then
				local n_table = {};
				for value, _ in next, val do
					if table.find(dropdown.values, value) then n_table[value] = true end;
				end;
				dropdown.value = n_table;
			else
				if not val then dropdown.value = nil;
				elseif table.find(dropdown.values, val) then dropdown.value = val end;
			end;
			dropdown:build_dropdown_list();
			library:safe_callback(dropdown.callback, dropdown.value);
			library:safe_callback(dropdown.changed, dropdown.value);
		end;

		dropdown_outer.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and not library:mouse_is_over_opened_frame() then
				if list_outer.Visible then dropdown:close_dropdown();
				else dropdown:open_dropdown() end;
			end;
		end);

		input_service.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local abs_pos, abs_size = list_outer.AbsolutePosition, list_outer.AbsoluteSize;
				if mouse.X < abs_pos.X or mouse.X > abs_pos.X + abs_size.X
					or mouse.Y < (abs_pos.Y - 20 - 1) or mouse.Y > abs_pos.Y + abs_size.Y then
					dropdown:close_dropdown();
				end;
			end;
		end);

		dropdown:build_dropdown_list();
		dropdown:display();

		local defaults = {};
		if type(info.default) == 'string' then
			local i = table.find(dropdown.values, info.default);
			if i then table.insert(defaults, i) end;
		elseif type(info.default) == 'table' then
			for _, value in next, info.default do
				local i = table.find(dropdown.values, value);
				if i then table.insert(defaults, i) end;
			end;
		elseif type(info.default) == 'number' and dropdown.values[info.default] ~= nil then
			table.insert(defaults, info.default);
		end;

		if next(defaults) then
			for i = 1, #defaults do
				local index = defaults[i];
				if info.multi then dropdown.value[dropdown.values[index]] = true;
				else dropdown.value = dropdown.values[index] end;
				if not info.multi then break end;
			end;
			dropdown:build_dropdown_list();
			dropdown:display();
		end;

		groupbox:add_blank(info.blank_size or 4);
		groupbox:resize();
		options[idx] = dropdown;
		return dropdown;
	end;

	function funcs:add_dependency_box()
		local depbox = { dependencies = {} };
		local groupbox = self;
		local container = groupbox.container;

		local holder = library:create('Frame', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 0, 0);
			Visible = false;
			Parent = container;
		});

		local frame = library:create('Frame', {
			BackgroundTransparency = 1;
			Size = UDim2.new(1, 0, 1, 0);
			Visible = true;
			Parent = holder;
		});

		local layout = library:create('UIListLayout', {
			FillDirection = Enum.FillDirection.Vertical;
			SortOrder = Enum.SortOrder.LayoutOrder;
			Parent = frame;
		});

		function depbox:resize()
			holder.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y);
			groupbox:resize();
		end;

		layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function() depbox:resize() end);
		holder:GetPropertyChangedSignal('Visible'):Connect(function() depbox:resize() end);

		function depbox:update()
			for _, dependency in next, depbox.dependencies do
				local elem, value = dependency[1], dependency[2];
				if elem.type == 'Toggle' and elem.value ~= value then
					holder.Visible = false; depbox:resize(); return;
				end;
			end;
			holder.Visible = true; depbox:resize();
		end;

		function depbox:setup_dependencies(dependencies)
			for _, dependency in next, dependencies do
				assert(type(dependency) == 'table');
				assert(dependency[1]);
				assert(dependency[2] ~= nil);
			end;
			depbox.dependencies = dependencies;
			depbox:update();
		end;

		depbox.container = frame;
		setmetatable(depbox, base_groupbox);
		table.insert(library.dependency_boxes, depbox);
		return depbox;
	end;

	base_groupbox.__index = funcs;
	base_groupbox.__namecall = function(t, key, ...) return funcs[key](...) end;
end;

do
	library.notification_area = library:create('Frame', {
		BackgroundTransparency = 1;
		Position = UDim2.new(0, 0, 0, 40);
		Size = UDim2.new(0, 300, 0, 200);
		ZIndex = 100;
		Parent = screen_gui;
	});
	library:create('UIListLayout', {
		Padding = UDim.new(0, 5);
		FillDirection = Enum.FillDirection.Vertical;
		SortOrder = Enum.SortOrder.LayoutOrder;
		Parent = library.notification_area;
	});

	local watermark_outer = library:create('Frame', {
		BorderSizePixel = 0;
		Position = UDim2.new(0, 100, 0, -28);
		Size = UDim2.new(0, 213, 0, 22);
		ZIndex = 200;
		Visible = false;
		Parent = screen_gui;
	});
	make_corner(4).Parent = watermark_outer;

	local watermark_inner = library:create('Frame', {
		BackgroundColor3 = library.main_color;
		BorderSizePixel = 0;
		Size = UDim2.new(1, -2, 1, -2);
		Position = UDim2.new(0, 1, 0, 1);
		ZIndex = 201;
		Parent = watermark_outer;
	});
	make_corner(3).Parent = watermark_inner;
	library:create('UIStroke', { Color = library.accent_color; Thickness = 1; Transparency = 0.3; Parent = watermark_inner });
	library:add_to_registry(watermark_inner, {});

	local wm_highlight = library:create('Frame', {
		BackgroundColor3 = library.accent_color;
		BorderSizePixel = 0;
		Size = UDim2.new(1, 0, 0, 2);
		ZIndex = 202;
		Parent = watermark_inner;
	});
	make_corner(3).Parent = wm_highlight;
	library:create('UIGradient', {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, library.accent_color),
			ColorSequenceKeypoint.new(1, library.accent_color_dark),
		});
		Rotation = 0;
		Parent = wm_highlight;
	});
	library:add_to_registry(wm_highlight, { BackgroundColor3 = 'accent_color' });

	local inner_bg = library:create('Frame', {
		BackgroundColor3 = library.background_color;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 0, 0, 2);
		Size = UDim2.new(1, 0, 1, -2);
		ZIndex = 201;
		Parent = watermark_inner;
	});
	make_corner(3).Parent = inner_bg;
	library:add_to_registry(inner_bg, { BackgroundColor3 = 'background_color' });

	local watermark_label = library:create_label({
		Position = UDim2.new(0, 6, 0, 0);
		Size = UDim2.new(1, -6, 1, 0);
		TextSize = 13;
		TextXAlignment = Enum.TextXAlignment.Left;
		ZIndex = 203;
		Parent = inner_bg;
	});

	library.watermark = watermark_outer;
	library.watermark_text = watermark_label;
	library:make_draggable(library.watermark);

	local keybind_outer = library:create('Frame', {
		AnchorPoint = Vector2.new(0, 0.5);
		BorderSizePixel = 0;
		Position = UDim2.new(0, 10, 0.5, 0);
		Size = UDim2.new(0, 210, 0, 22);
		Visible = false;
		ZIndex = 100;
		Parent = screen_gui;
	});
	make_corner(5).Parent = keybind_outer;

	local keybind_inner = library:create('Frame', {
		BackgroundColor3 = library.main_color;
		BorderSizePixel = 0;
		Size = UDim2.new(1, -2, 1, -2);
		Position = UDim2.new(0, 1, 0, 1);
		ZIndex = 101;
		Parent = keybind_outer;
	});
	make_corner(4).Parent = keybind_inner;
	library:create('UIStroke', { Color = library.outline_color; Thickness = 1; Parent = keybind_inner });
	library:add_to_registry(keybind_inner, { BackgroundColor3 = 'main_color' }, true);

	local color_frame = library:create('Frame', {
		BackgroundColor3 = library.accent_color;
		BorderSizePixel = 0;
		Size = UDim2.new(1, 0, 0, 2);
		ZIndex = 102;
		Parent = keybind_inner;
	});
	make_corner(4).Parent = color_frame;
	library:create('UIGradient', {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, library.accent_color),
			ColorSequenceKeypoint.new(1, library.accent_color_dark),
		});
		Rotation = 0;
		Parent = color_frame;
	});
	library:add_to_registry(color_frame, { BackgroundColor3 = 'accent_color' }, true);

	local keybind_label = library:create_label({
		Size = UDim2.new(1, 0, 0, 20);
		Position = UDim2.fromOffset(6, 3);
		TextXAlignment = Enum.TextXAlignment.Left;
		Text = 'keybinds';
		TextSize = 12;
		ZIndex = 104;
		Parent = keybind_inner;
	});
	library:add_to_registry(keybind_label, { TextColor3 = 'subtle_color' });

	local keybind_container = library:create('Frame', {
		BackgroundTransparency = 1;
		Size = UDim2.new(1, 0, 1, -22);
		Position = UDim2.new(0, 0, 0, 22);
		ZIndex = 1;
		Parent = keybind_inner;
	});
	library:create('UIListLayout', {
		FillDirection = Enum.FillDirection.Vertical;
		SortOrder = Enum.SortOrder.LayoutOrder;
		Parent = keybind_container;
	});
	library:create('UIPadding', {
		PaddingLeft = UDim.new(0, 6);
		Parent = keybind_container;
	});

	library.keybind_frame = keybind_outer;
	library.keybind_container = keybind_container;
	library:make_draggable(keybind_outer);
end;

function library:set_watermark_visibility(bool)
	library.watermark.Visible = bool;
end;

function library:set_watermark(text)
	local x, y = library:get_text_bounds(text, library.font, 13);
	library.watermark.Size = UDim2.new(0, x + 18, 0, (y * 1.5) + 5);
	library:set_watermark_visibility(true);
	library.watermark_text.Text = text;
end;

function library:notify(text, time)
	local x_size, y_size = library:get_text_bounds(text, library.font, 13);
	y_size = y_size + 10;

	local notify_outer = library:create('Frame', {
		BorderSizePixel = 0;
		Position = UDim2.new(0, 100, 0, 10);
		Size = UDim2.new(0, 0, 0, y_size);
		ClipsDescendants = true;
		ZIndex = 100;
		Parent = library.notification_area;
	});
	make_corner(5).Parent = notify_outer;

	local notify_inner = library:create('Frame', {
		BackgroundColor3 = library.background_color;
		BorderSizePixel = 0;
		Size = UDim2.new(1, -2, 1, -2);
		Position = UDim2.new(0, 1, 0, 1);
		ZIndex = 101;
		Parent = notify_outer;
	});
	make_corner(4).Parent = notify_inner;
	library:create('UIStroke', { Color = library.outline_color; Thickness = 1; Transparency = 0.5; Parent = notify_inner });
	library:add_to_registry(notify_inner, { BackgroundColor3 = 'background_color' }, true);

	local left_glow = library:create('Frame', {
		BackgroundColor3 = library.accent_color;
		BackgroundTransparency = 0.55;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 0, 0, 0);
		Size = UDim2.new(0, 5, 1, 0);
		ZIndex = 103;
		Parent = notify_outer;
	});
	make_corner(3).Parent = left_glow;
	library:add_to_registry(left_glow, { BackgroundColor3 = 'accent_color' }, true);

	local left_color = library:create('Frame', {
		BackgroundColor3 = library.accent_color;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 0, 0, 0);
		Size = UDim2.new(0, 2, 1, 0);
		ZIndex = 104;
		Parent = notify_outer;
	});
	make_corner(2).Parent = left_color;
	library:add_to_registry(left_color, { BackgroundColor3 = 'accent_color' }, true);

	local notify_label = library:create_label({
		Position = UDim2.new(0, 10, 0, 0);
		Size = UDim2.new(1, -14, 1, 0);
		Text = text;
		TextXAlignment = Enum.TextXAlignment.Left;
		TextSize = 13;
		ZIndex = 103;
		Parent = notify_inner;
	});

	pcall(notify_outer.TweenSize, notify_outer, UDim2.new(0, x_size + 20, 0, y_size), 'Out', 'Quart', 0.3, true);

	task.spawn(function()
		wait(time or 5);
		pcall(notify_outer.TweenSize, notify_outer, UDim2.new(0, 0, 0, y_size), 'Out', 'Quart', 0.3, true);
		wait(0.3);
		notify_outer:Destroy();
	end);
end;

function library:create_window(...)
	local arguments = { ... };
	local config = { anchor_point = Vector2.zero };

	if type(...) == 'table' then
		config = ...;
	else
		config.title = arguments[1];
		config.auto_show = arguments[2] or false;
	end;

	if type(config.title) ~= 'string' then config.title = 'No title' end;
	if type(config.tab_padding) ~= 'number' then config.tab_padding = 0 end;
	if type(config.menu_fade_time) ~= 'number' then config.menu_fade_time = 0.18 end;
	if typeof(config.position) ~= 'UDim2' then config.position = UDim2.fromOffset(175, 50) end;
	if typeof(config.size) ~= 'UDim2' then config.size = UDim2.fromOffset(555, 605) end;

	if config.center then
		config.anchor_point = Vector2.new(0.5, 0.5);
		config.position = UDim2.fromScale(0.5, 0.5);
	end;

	local window = { tabs = {} };

	local outer = library:create('Frame', {
		AnchorPoint = config.anchor_point;
		BackgroundColor3 = Color3.new(0, 0, 0);
		BorderSizePixel = 0;
		Position = config.position;
		Size = config.size;
		Visible = false;
		ZIndex = 1;
		Parent = screen_gui;
	});
	make_corner(7).Parent = outer;

	task.defer(function()
		local abs_pos = outer.AbsolutePosition;
		local parent_abs_pos = outer.Parent.AbsolutePosition;
		outer.AnchorPoint = Vector2.new(0, 0);
		outer.Position = UDim2.fromOffset(abs_pos.X - parent_abs_pos.X, abs_pos.Y - parent_abs_pos.Y);
	end);

	library:make_draggable(outer, 28);
	library:make_resizable(outer, Vector2.new(400, 400), Vector2.new(900, 800));

	local inner = library:create('Frame', {
		BackgroundColor3 = library.main_color;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 1, 0, 1);
		Size = UDim2.new(1, -2, 1, -2);
		ZIndex = 1;
		Parent = outer;
	});
	make_corner(6).Parent = inner;
	library:create('UIStroke', {
		Color = library.accent_color;
		Thickness = 1;
		Transparency = 0.6;
		Parent = inner;
	});
	library:add_to_registry(inner, { BackgroundColor3 = 'main_color' });

	local title_bar = library:create('Frame', {
		BackgroundColor3 = library.background_color;
		BorderSizePixel = 0;
		Size = UDim2.new(1, 0, 0, 28);
		ClipsDescendants = false;
		ZIndex = 2;
		Parent = inner;
	});
	make_corner(6).Parent = title_bar;
	library:add_to_registry(title_bar, { BackgroundColor3 = 'background_color' });

	library:create('Frame', {
		BackgroundColor3 = library.background_color;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 0, 1, -4);
		Size = UDim2.new(1, 0, 0, 4);
		ZIndex = 2;
		Parent = title_bar;
	});

	local title_accent = library:create('Frame', {
		BackgroundColor3 = library.accent_color;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 0, 1, -1);
		Size = UDim2.new(1, 0, 0, 1);
		ZIndex = 3;
		Parent = title_bar;
	});
	library:create('UIGradient', {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, library.accent_color),
			ColorSequenceKeypoint.new(0.6, library.accent_color_dark),
			ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
		});
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.85, 0),
			NumberSequenceKeypoint.new(1, 1),
		});
		Rotation = 0;
		Parent = title_accent;
	});
	library:add_to_registry(title_accent, { BackgroundColor3 = 'accent_color' });

	local logo_dot = library:create('Frame', {
		BackgroundColor3 = library.accent_color;
		BorderSizePixel = 0;
		AnchorPoint = Vector2.new(0, 0.5);
		Position = UDim2.new(0, 8, 0.5, 0);
		Size = UDim2.new(0, 6, 0, 6);
		ZIndex = 3;
		Parent = title_bar;
	});
	make_corner(3).Parent = logo_dot;
	library:add_to_registry(logo_dot, { BackgroundColor3 = 'accent_color' });

	local window_label = library:create_label({
		Position = UDim2.new(0, 20, 0, 0);
		Size = UDim2.new(1, -24, 1, 0);
		Text = config.title or '';
		TextXAlignment = Enum.TextXAlignment.Left;
		TextSize = 13;
		ZIndex = 3;
		Parent = title_bar;
		RichText = true;
	});

	local main_section_outer = library:create('Frame', {
		BackgroundColor3 = library.background_color;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 8, 0, 28);
		Size = UDim2.new(1, -16, 1, -36);
		ZIndex = 1;
		Parent = inner;
	});
	make_corner(5).Parent = main_section_outer;
	library:add_to_registry(main_section_outer, { BackgroundColor3 = 'background_color' });

	local main_section_inner = library:create('Frame', {
		BackgroundColor3 = library.background_color;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 0, 0, 0);
		Size = UDim2.new(1, 0, 1, 0);
		ZIndex = 1;
		Parent = main_section_outer;
	});
	make_corner(5).Parent = main_section_inner;
	library:add_to_registry(main_section_inner, { BackgroundColor3 = 'background_color' });

	local tab_area = library:create('Frame', {
		BackgroundTransparency = 1;
		Position = UDim2.new(0, 6, 0, 6);
		Size = UDim2.new(1, -12, 0, 22);
		ZIndex = 1;
		Parent = main_section_inner;
	});

	local tab_list_layout = library:create('UIListLayout', {
		Padding = UDim.new(0, config.tab_padding + 2);
		FillDirection = Enum.FillDirection.Horizontal;
		SortOrder = Enum.SortOrder.LayoutOrder;
		Parent = tab_area;
	});

	local tab_container = library:create('Frame', {
		BackgroundColor3 = library.main_color;
		BorderSizePixel = 0;
		Position = UDim2.new(0, 6, 0, 30);
		Size = UDim2.new(1, -12, 1, -38);
		ZIndex = 2;
		Parent = main_section_inner;
	});
	make_corner(4).Parent = tab_container;
	library:add_to_registry(tab_container, { BackgroundColor3 = 'main_color' });

	function window:set_window_title(title)
		window_label.Text = title;
	end;

	function window:add_tab(name)
		local tab = { groupboxes = {}; tabboxes = {} };

		local tab_btn_width = library:get_text_bounds(name, library.font, 13);

		local tab_button = library:create('Frame', {
			BackgroundColor3 = library.background_color;
			BorderSizePixel = 0;
			Size = UDim2.new(0, tab_btn_width + 16, 1, 0);
			ZIndex = 1;
			Parent = tab_area;
		});
		make_corner(4).Parent = tab_button;
		library:add_to_registry(tab_button, { BackgroundColor3 = 'background_color' });

		local blocker = library:create('Frame', {
			BackgroundColor3 = library.main_color;
			BorderSizePixel = 0;
			Position = UDim2.new(0, 2, 1, 0);
			Size = UDim2.new(1, -4, 0, 4);
			BackgroundTransparency = 1;
			ZIndex = 4;
			Parent = tab_button;
		});
		library:add_to_registry(blocker, { BackgroundColor3 = 'main_color' });

		local active_line = library:create('Frame', {
			BackgroundColor3 = library.accent_color;
			BorderSizePixel = 0;
			AnchorPoint = Vector2.new(0.5, 1);
			Position = UDim2.new(0.5, 0, 1, 0);
			Size = UDim2.new(0, 0, 0, 2);
			ZIndex = 5;
			Parent = tab_button;
		});
		make_corner(1).Parent = active_line;
		library:add_to_registry(active_line, { BackgroundColor3 = 'accent_color' });

		local tab_btn_label = library:create_label({
			Position = UDim2.new(0, 0, 0, 0);
			Size = UDim2.new(1, 0, 1, -2);
			Text = name;
			TextSize = 13;
			ZIndex = 2;
			Parent = tab_button;
		});

		local tab_frame = library:create('Frame', {
			Name = 'TabFrame';
			BackgroundTransparency = 1;
			Position = UDim2.new(0, 0, 0, 0);
			Size = UDim2.new(1, 0, 1, 0);
			Visible = false;
			ZIndex = 2;
			Parent = tab_container;
		});

		local left_side = library:create('ScrollingFrame', {
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new(0, 7, 0, 7);
			Size = UDim2.new(0.5, -11, 0, 510);
			CanvasSize = UDim2.new(0, 0, 0, 0);
			BottomImage = ''; TopImage = '';
			ScrollBarThickness = 0;
			ZIndex = 2;
			Parent = tab_frame;
		});

		local right_side = library:create('ScrollingFrame', {
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			Position = UDim2.new(0.5, 4, 0, 7);
			Size = UDim2.new(0.5, -11, 0, 510);
			CanvasSize = UDim2.new(0, 0, 0, 0);
			BottomImage = ''; TopImage = '';
			ScrollBarThickness = 0;
			ZIndex = 2;
			Parent = tab_frame;
		});

		library:create('UIListLayout', {
			Padding = UDim.new(0, 7);
			FillDirection = Enum.FillDirection.Vertical;
			SortOrder = Enum.SortOrder.LayoutOrder;
			HorizontalAlignment = Enum.HorizontalAlignment.Center;
			Parent = left_side;
		});
		library:create('UIListLayout', {
			Padding = UDim.new(0, 7);
			FillDirection = Enum.FillDirection.Vertical;
			SortOrder = Enum.SortOrder.LayoutOrder;
			HorizontalAlignment = Enum.HorizontalAlignment.Center;
			Parent = right_side;
		});

		for _, side in next, { left_side, right_side } do
			side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
				side.CanvasSize = UDim2.fromOffset(0, side.UIListLayout.AbsoluteContentSize.Y);
			end);
		end;

		function tab:show_tab()
			for _, t in next, window.tabs do t:hide_tab() end;
			blocker.BackgroundTransparency = 0;
			tab_button.BackgroundColor3 = library.main_color;
			library.registry_map[tab_button].properties.BackgroundColor3 = 'main_color';
			tab_btn_label.TextColor3 = library.font_color;
			library.registry_map[tab_btn_label].properties.TextColor3 = 'font_color';
			tween(active_line, { Size = UDim2.new(0.7, 0, 0, 2) }, 0.18);
			tab_frame.Visible = true;
		end;

		function tab:hide_tab()
			blocker.BackgroundTransparency = 1;
			tab_button.BackgroundColor3 = library.background_color;
			library.registry_map[tab_button].properties.BackgroundColor3 = 'background_color';
			tab_btn_label.TextColor3 = library.subtle_color;
			library.registry_map[tab_btn_label].properties.TextColor3 = 'subtle_color';
			tween(active_line, { Size = UDim2.new(0, 0, 0, 2) }, 0.12);
			tab_frame.Visible = false;
		end;

		function tab:set_layout_order(position)
			tab_button.LayoutOrder = position;
			tab_list_layout:ApplyLayout();
		end;

		function tab:add_groupbox(info)
			local groupbox = {};

			local box_outer = library:create('Frame', {
				BackgroundColor3 = library.background_color;
				BorderSizePixel = 0;
				Size = UDim2.new(1, 0, 0, 510);
				ZIndex = 2;
				Parent = info.side == 1 and left_side or right_side;
			});
			make_corner(5).Parent = box_outer;
			library:add_to_registry(box_outer, { BackgroundColor3 = 'background_color' });

			library:create('UIStroke', {
				Color = library.outline_color;
				Thickness = 1;
				Transparency = 0.3;
				Parent = box_outer;
			});

			local box_inner = library:create('Frame', {
				BackgroundColor3 = library.background_color;
				BorderSizePixel = 0;
				Size = UDim2.new(1, -2, 1, -2);
				Position = UDim2.new(0, 1, 0, 1);
				ZIndex = 4;
				Parent = box_outer;
			});
			make_corner(4).Parent = box_inner;
			library:add_to_registry(box_inner, { BackgroundColor3 = 'background_color' });

			local highlight = library:create('Frame', {
				BackgroundColor3 = library.accent_color;
				BorderSizePixel = 0;
				Size = UDim2.new(1, 0, 0, 2);
				ZIndex = 5;
				Parent = box_inner;
			});
			make_corner(4).Parent = highlight;
			library:create('UIGradient', {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, library.accent_color),
					ColorSequenceKeypoint.new(0.7, library.accent_color_dark),
					ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
				});
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.9, 0),
					NumberSequenceKeypoint.new(1, 1),
				});
				Rotation = 0;
				Parent = highlight;
			});
			library:add_to_registry(highlight, { BackgroundColor3 = 'accent_color' });

			local groupbox_label = library:create_label({
				Size = UDim2.new(1, 0, 0, 18);
				Position = UDim2.new(0, 6, 0, 3);
				TextSize = 12;
				Text = info.name;
				TextXAlignment = Enum.TextXAlignment.Left;
				ZIndex = 5;
				Parent = box_inner;
			});
			library:add_to_registry(groupbox_label, { TextColor3 = 'subtle_color' });

			local container = library:create('Frame', {
				BackgroundTransparency = 1;
				Position = UDim2.new(0, 4, 0, 21);
				Size = UDim2.new(1, -4, 1, -21);
				ZIndex = 1;
				Parent = box_inner;
			});
			library:create('UIListLayout', {
				FillDirection = Enum.FillDirection.Vertical;
				SortOrder = Enum.SortOrder.LayoutOrder;
				Parent = container;
			});

			function groupbox:resize()
				local size = 0;
				for _, element in next, groupbox.container:GetChildren() do
					if not element:IsA('UIListLayout') and element.Visible then
						size = size + element.Size.Y.Offset;
					end;
				end;
				box_outer.Size = UDim2.new(1, 0, 0, 21 + size + 6);
			end;

			groupbox.container = container;
			setmetatable(groupbox, base_groupbox);
			groupbox:add_blank(3);
			groupbox:resize();
			tab.groupboxes[info.name] = groupbox;
			return groupbox;
		end;

		function tab:add_left_groupbox(name)
			return tab:add_groupbox({ side = 1; name = name });
		end;
		function tab:add_right_groupbox(name)
			return tab:add_groupbox({ side = 2; name = name });
		end;

		function tab:add_tabbox(info)
			local tabbox = { tabs = {} };

			local box_outer = library:create('Frame', {
				BackgroundColor3 = library.background_color;
				BorderSizePixel = 0;
				Size = UDim2.new(1, 0, 0, 0);
				ZIndex = 2;
				Parent = info.side == 1 and left_side or right_side;
			});
			make_corner(5).Parent = box_outer;
			library:create('UIStroke', { Color = library.outline_color; Thickness = 1; Transparency = 0.3; Parent = box_outer });
			library:add_to_registry(box_outer, { BackgroundColor3 = 'background_color' });

			local box_inner = library:create('Frame', {
				BackgroundColor3 = library.background_color;
				BorderSizePixel = 0;
				Size = UDim2.new(1, -2, 1, -2);
				Position = UDim2.new(0, 1, 0, 1);
				ZIndex = 4;
				Parent = box_outer;
			});
			make_corner(4).Parent = box_inner;
			library:add_to_registry(box_inner, { BackgroundColor3 = 'background_color' });

			local highlight = library:create('Frame', {
				BackgroundColor3 = library.accent_color;
				BorderSizePixel = 0;
				Size = UDim2.new(1, 0, 0, 2);
				ZIndex = 10;
				Parent = box_inner;
			});
			make_corner(4).Parent = highlight;
			library:add_to_registry(highlight, { BackgroundColor3 = 'accent_color' });

			local tabbox_buttons = library:create('Frame', {
				BackgroundTransparency = 1;
				Position = UDim2.new(0, 0, 0, 2);
				Size = UDim2.new(1, 0, 0, 19);
				ZIndex = 5;
				Parent = box_inner;
			});
			library:create('UIListLayout', {
				FillDirection = Enum.FillDirection.Horizontal;
				HorizontalAlignment = Enum.HorizontalAlignment.Left;
				SortOrder = Enum.SortOrder.LayoutOrder;
				Parent = tabbox_buttons;
			});

			function tabbox:add_tab(name)
				local t = {};

				local btn = library:create('Frame', {
					BackgroundColor3 = library.main_color;
					BorderSizePixel = 0;
					Size = UDim2.new(0.5, 0, 1, 0);
					ZIndex = 6;
					Parent = tabbox_buttons;
				});
				library:add_to_registry(btn, { BackgroundColor3 = 'main_color' });

				local btn_label = library:create_label({
					Size = UDim2.new(1, 0, 1, 0);
					TextSize = 12;
					Text = name;
					TextXAlignment = Enum.TextXAlignment.Center;
					ZIndex = 7;
					Parent = btn;
				});

				local block = library:create('Frame', {
					BackgroundColor3 = library.background_color;
					BorderSizePixel = 0;
					Position = UDim2.new(0, 0, 1, 0);
					Size = UDim2.new(1, 0, 0, 2);
					Visible = false;
					ZIndex = 9;
					Parent = btn;
				});
				library:add_to_registry(block, { BackgroundColor3 = 'background_color' });
				local container = library:create('Frame', {
					BackgroundTransparency = 1;
					Position = UDim2.new(0, 4, 0, 21);
					Size = UDim2.new(1, -4, 1, -21);
					ZIndex = 1;
					Visible = false;
					Parent = box_inner;
				});
				library:create('UIListLayout', {
					FillDirection = Enum.FillDirection.Vertical;
					SortOrder = Enum.SortOrder.LayoutOrder;
					Parent = container;
				});

				function t:show()
					for _, tab in next, tabbox.tabs do tab:hide() end;
					container.Visible = true;
					block.Visible = true;
					btn.BackgroundColor3 = library.background_color;
					library.registry_map[btn].properties.BackgroundColor3 = 'background_color';
					btn_label.TextColor3 = library.accent_color;
					library.registry_map[btn_label].properties.TextColor3 = 'accent_color';
					t:resize();
				end;

				function t:hide()
					container.Visible = false;
					block.Visible = false;
					btn.BackgroundColor3 = library.main_color;
					library.registry_map[btn].properties.BackgroundColor3 = 'main_color';
					btn_label.TextColor3 = library.subtle_color;
					library.registry_map[btn_label].properties.TextColor3 = 'subtle_color';
				end;

				function t:resize()
					local tab_count = 0;
					for _ in next, tabbox.tabs do tab_count = tab_count + 1 end;
					for _, b in next, tabbox_buttons:GetChildren() do
						if not b:IsA('UIListLayout') then
							b.Size = UDim2.new(1 / tab_count, 0, 1, 0);
						end;
					end;
					if not container.Visible then return end;
					local size = 0;
					for _, element in next, t.container:GetChildren() do
						if not element:IsA('UIListLayout') and element.Visible then
							size = size + element.Size.Y.Offset;
						end;
					end;
					box_outer.Size = UDim2.new(1, 0, 0, 21 + size + 6);
				end;

				btn.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 and not library:mouse_is_over_opened_frame() then
						t:show(); t:resize();
					end;
				end);

				t.container = container;
				tabbox.tabs[name] = t;
				setmetatable(t, base_groupbox);
				t:add_blank(3);
				t:resize();
				if #tabbox_buttons:GetChildren() == 2 then t:show() end;
				return t;
			end;

			tab.tabboxes[info.name or ''] = tabbox;
			return tabbox;
		end;

		function tab:add_left_tabbox(name)
			return tab:add_tabbox({ name = name, side = 1 });
		end;
		function tab:add_right_tabbox(name)
			return tab:add_tabbox({ name = name, side = 2 });
		end;

		tab_button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				tab:show_tab();
			end;
		end);

		if not window._has_shown_tab then
			window._has_shown_tab = true;
			tab:show_tab();
		end;

		window.tabs[name] = tab;
		return tab;
	end;

	local modal_element = library:create('TextButton', {
		BackgroundTransparency = 1;
		Size = UDim2.new(0, 0, 0, 0);
		Visible = true;
		Text = '';
		Modal = false;
		Parent = screen_gui;
	});

	local transparency_cache = {};
	local toggled = false;
	local fading = false;

	function library.toggle()
		if fading then return end;
		local fade_time = config.menu_fade_time or 0;
		fading = true;
		toggled = not toggled;
		modal_element.Modal = toggled;

		if toggled then
			outer.Visible = true;

			task.spawn(function()
				local state = input_service.MouseIconEnabled;
				local cursor = Drawing.new('Triangle');
				cursor.Thickness = 1; cursor.Filled = true; cursor.Visible = true;
				local cursor_outline = Drawing.new('Triangle');
				cursor_outline.Thickness = 1; cursor_outline.Filled = false;
				cursor_outline.Color = Color3.new(0, 0, 0); cursor_outline.Visible = true;

				while toggled and screen_gui.Parent do
					input_service.MouseIconEnabled = false;
					local m_pos = input_service:GetMouseLocation();
					cursor.Color = library.accent_color;
					cursor.PointA = Vector2.new(m_pos.X, m_pos.Y);
					cursor.PointB = Vector2.new(m_pos.X + 15, m_pos.Y + 5);
					cursor.PointC = Vector2.new(m_pos.X + 5, m_pos.Y + 15);
					cursor_outline.PointA = cursor.PointA;
					cursor_outline.PointB = cursor.PointB;
					cursor_outline.PointC = cursor.PointC;
					render_stepped:Wait();
				end;
				input_service.MouseIconEnabled = state;
				cursor:Remove(); cursor_outline:Remove();
			end);
		end;

		for _, desc in next, outer:GetDescendants() do
			local props = {};
			if desc:IsA('ImageLabel') then
				table.insert(props, 'ImageTransparency');
				table.insert(props, 'BackgroundTransparency');
			elseif desc:IsA('TextLabel') or desc:IsA('TextBox') then
				table.insert(props, 'TextTransparency');
			elseif desc:IsA('Frame') or desc:IsA('ScrollingFrame') then
				table.insert(props, 'BackgroundTransparency');
			elseif desc:IsA('UIStroke') then
				table.insert(props, 'Transparency');
			end;

			local cache = transparency_cache[desc];
			if not cache then cache = {}; transparency_cache[desc] = cache end;

			for _, prop in next, props do
				if not cache[prop] then cache[prop] = desc[prop] end;
				if cache[prop] == 1 then continue end;
				if fade_time > 0 then
					tween_service:Create(desc, TweenInfo.new(fade_time, Enum.EasingStyle.Quart), { [prop] = toggled and cache[prop] or 1 }):Play();
				else
					desc[prop] = toggled and cache[prop] or 1;
				end;
			end;
		end;

		if fade_time > 0 then task.wait(fade_time) end;
		outer.Visible = toggled;
		fading = false;
		if toggled then
			for _, toggle in next, toggles do
				toggle:display();
			end;
		end;
	end;

	library:give_signal(input_service.InputBegan:Connect(function(input, processed)
		if type(library.toggle_keybind) == 'table' and library.toggle_keybind.type == 'KeyPicker' then
			if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == library.toggle_keybind.value then
				task.spawn(library.toggle);
			end;
		elseif input.KeyCode == Enum.KeyCode.RightControl
			or (input.KeyCode == Enum.KeyCode.RightShift and not processed) then
			task.spawn(library.toggle);
		end;
	end));

	if config.auto_show then task.spawn(library.toggle) end;

	window.holder = outer;
	return window;
end;

local function on_player_change()
	local player_list = get_players_string();
	for _, value in next, options do
		if value.type == 'Dropdown' and value.special_type == 'Player' then
			value:set_values(player_list);
		end;
	end;
end;
players.PlayerAdded:Connect(on_player_change);
players.PlayerRemoving:Connect(on_player_change);
return library;
