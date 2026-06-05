local http_service = game:GetService('HttpService');
local theme_manager = {};
do
	theme_manager.folder = 'LinoriaLibSettings';
	theme_manager.library = nil;
	theme_manager.built_in_themes = {
		['Default']     = { 1, http_service:JSONDecode('{"font_color":"ffffff","main_color":"1c1c1c","accent_color":"0055ff","background_color":"141414","outline_color":"323232"}') };
		['BBot']        = { 2, http_service:JSONDecode('{"font_color":"ffffff","main_color":"1e1e1e","accent_color":"7e48a3","background_color":"232323","outline_color":"141414"}') };
		['Fatality']    = { 3, http_service:JSONDecode('{"font_color":"ffffff","main_color":"1e1842","accent_color":"c50754","background_color":"191335","outline_color":"3c355d"}') };
		['Jester']      = { 4, http_service:JSONDecode('{"font_color":"ffffff","main_color":"242424","accent_color":"db4467","background_color":"1c1c1c","outline_color":"373737"}') };
		['Mint']        = { 5, http_service:JSONDecode('{"font_color":"ffffff","main_color":"242424","accent_color":"3db488","background_color":"1c1c1c","outline_color":"373737"}') };
		['Tokyo Night'] = { 6, http_service:JSONDecode('{"font_color":"ffffff","main_color":"191925","accent_color":"6759b3","background_color":"16161f","outline_color":"323232"}') };
		['Ubuntu']      = { 7, http_service:JSONDecode('{"font_color":"ffffff","main_color":"3e3e3e","accent_color":"e2581e","background_color":"323232","outline_color":"191919"}') };
		['Quartz']      = { 8, http_service:JSONDecode('{"font_color":"ffffff","main_color":"232330","accent_color":"426e87","background_color":"1d1b26","outline_color":"27232f"}') };
	};

	function theme_manager:apply_theme(theme)
		local custom_theme_data = self:get_custom_theme(theme);
		local data = custom_theme_data or self.built_in_themes[theme];
		if not data then return end;

		local scheme = data[2];
		for idx, col in next, custom_theme_data or scheme do
			self.library[idx] = Color3.fromHex(col);
			if Options[idx] then
				Options[idx]:set_value_rgb(Color3.fromHex(col));
			end;
		end;

		self:theme_update();
	end;

	function theme_manager:theme_update()
		local fields = { 'font_color', 'main_color', 'accent_color', 'background_color', 'outline_color' };
		for _, field in next, fields do
			if Options and Options[field] then
				self.library[field] = Options[field].value;
			end;
		end;

		self.library.accent_color_dark = self.library:get_darker_color(self.library.accent_color);
		self.library:update_colors_using_registry();
	end;

	function theme_manager:load_default()
		local theme = 'Default';
		local content = isfile(self.folder .. '/themes/default.txt') and readfile(self.folder .. '/themes/default.txt');

		local is_default = true;
		if content then
			if self.built_in_themes[content] then
				theme = content;
			elseif self:get_custom_theme(content) then
				theme = content;
				is_default = false;
			end;
		elseif self.built_in_themes[self.default_theme] then
			theme = self.default_theme;
		end;

		if is_default then
			Options.theme_manager_theme_list:set_value(theme);
		else
			self:apply_theme(theme);
		end;
	end;

	function theme_manager:save_default(theme)
		writefile(self.folder .. '/themes/default.txt', theme);
	end;

	function theme_manager:create_theme_manager(groupbox)
		groupbox:add_label('background color'):add_color_picker('background_color', { default = self.library.background_color });
		groupbox:add_label('main color'):add_color_picker('main_color', { default = self.library.main_color });
		groupbox:add_label('accent color'):add_color_picker('accent_color', { default = self.library.accent_color });
		groupbox:add_label('outline color'):add_color_picker('outline_color', { default = self.library.outline_color });
		groupbox:add_label('font color'):add_color_picker('font_color', { default = self.library.font_color });

		local themes_array = {};
		for name, _ in next, self.built_in_themes do
			table.insert(themes_array, name);
		end;
		table.sort(themes_array, function(a, b) return self.built_in_themes[a][1] < self.built_in_themes[b][1] end);

		groupbox:add_divider();
		groupbox:add_dropdown('theme_manager_theme_list', { text = 'theme list', values = themes_array, default = 1 });

		groupbox:add_button({ Text = 'set as default', Func = function()
			self:save_default(Options.theme_manager_theme_list.value);
			self.library:notify(string.format('set default theme to %q', Options.theme_manager_theme_list.value));
		end });

		Options.theme_manager_theme_list:on_changed(function()
			self:apply_theme(Options.theme_manager_theme_list.value);
		end);

		groupbox:add_divider();
		groupbox:add_input('theme_manager_custom_theme_name', { text = 'custom theme name' });
		groupbox:add_dropdown('theme_manager_custom_theme_list', { text = 'custom themes', values = self:reload_custom_themes(), allow_null = true, default = 1 });
		groupbox:add_divider();

		groupbox:add_button({ Text = 'save theme', Func = function()
			self:save_custom_theme(Options.theme_manager_custom_theme_name.value);
			Options.theme_manager_custom_theme_list:set_values(self:reload_custom_themes());
			Options.theme_manager_custom_theme_list:set_value(nil);
		end }):add_button({ Text = 'load theme', Func = function()
			self:apply_theme(Options.theme_manager_custom_theme_list.value);
		end });

		groupbox:add_button({ Text = 'refresh list', Func = function()
			Options.theme_manager_custom_theme_list:set_values(self:reload_custom_themes());
			Options.theme_manager_custom_theme_list:set_value(nil);
		end });

		groupbox:add_button({ Text = 'set as default', Func = function()
			if Options.theme_manager_custom_theme_list.value ~= nil and Options.theme_manager_custom_theme_list.value ~= '' then
				self:save_default(Options.theme_manager_custom_theme_list.value);
				self.library:notify(string.format('set default theme to %q', Options.theme_manager_custom_theme_list.value));
			end;
		end });

		theme_manager:load_default();

		local function update_theme()
			self:theme_update();
		end;

		Options.background_color:on_changed(update_theme);
		Options.main_color:on_changed(update_theme);
		Options.accent_color:on_changed(update_theme);
		Options.outline_color:on_changed(update_theme);
		Options.font_color:on_changed(update_theme);
	end;

	function theme_manager:get_custom_theme(file)
		local path = self.folder .. '/themes/' .. file;
		if not isfile(path) then return nil end;
		local data = readfile(path);
		local success, decoded = pcall(http_service.JSONDecode, http_service, data);
		if not success then return nil end;
		return decoded;
	end;

	function theme_manager:save_custom_theme(file)
		if file:gsub(' ', '') == '' then
			return self.library:notify('invalid file name for theme (empty)', 3);
		end;
		local theme = {};
		local fields = { 'font_color', 'main_color', 'accent_color', 'background_color', 'outline_color' };
		for _, field in next, fields do
			theme[field] = Options[field].value:ToHex();
		end;
		writefile(self.folder .. '/themes/' .. file .. '.json', http_service:JSONEncode(theme));
	end;

	function theme_manager:reload_custom_themes()
		local list = listfiles(self.folder .. '/themes');
		local out = {};
		for i = 1, #list do
			local file = list[i];
			if file:sub(-5) == '.json' then
				local pos = file:find('.json', 1, true);
				local char = file:sub(pos, pos);
				while char ~= '/' and char ~= '\\' and char ~= '' do
					pos = pos - 1;
					char = file:sub(pos, pos);
				end;
				if char == '/' or char == '\\' then
					table.insert(out, file:sub(pos + 1));
				end;
			end;
		end;
		return out;
	end;

	function theme_manager:set_library(lib)
		self.library = lib;
	end;

	function theme_manager:build_folder_tree()
		local paths = {};
		local parts = self.folder:split('/');
		for idx = 1, #parts do
			paths[#paths + 1] = table.concat(parts, '/', 1, idx);
		end;
		table.insert(paths, self.folder .. '/themes');
		table.insert(paths, self.folder .. '/settings');
		for i = 1, #paths do
			local str = paths[i];
			if not isfolder(str) then makefolder(str) end;
		end;
	end;

	function theme_manager:set_folder(folder)
		self.folder = folder;
		self:build_folder_tree();
	end;

	function theme_manager:create_groupbox(tab)
		assert(self.library, 'must set theme_manager.library first!');
		return tab:add_left_groupbox('themes');
	end;

	function theme_manager:apply_to_tab(tab)
		assert(self.library, 'must set theme_manager.library first!');
		local groupbox = self:create_groupbox(tab);
		self:create_theme_manager(groupbox);
	end;

	function theme_manager:apply_to_groupbox(groupbox)
		assert(self.library, 'must set theme_manager.library first!');
		self:create_theme_manager(groupbox);
	end;

	theme_manager:build_folder_tree();
end;

return theme_manager;
