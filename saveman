local http_service = game:GetService('HttpService');

local save_manager = {};
do
	save_manager.folder = 'LinoriaLibSettings';
	save_manager.ignore = {};
	save_manager.parser = {
		Toggle = {
			save = function(idx, object)
				return { type = 'Toggle', idx = idx, value = object.value };
			end;
			load = function(idx, data)
				if Toggles[idx] then
					Toggles[idx]:set_value(data.value);
				end;
			end;
		};
		Slider = {
			save = function(idx, object)
				return { type = 'Slider', idx = idx, value = tostring(object.value) };
			end;
			load = function(idx, data)
				if Options[idx] then
					Options[idx]:set_value(data.value);
				end;
			end;
		};
		Dropdown = {
			save = function(idx, object)
				return { type = 'Dropdown', idx = idx, value = object.value, multi = object.multi };
			end;
			load = function(idx, data)
				if Options[idx] then
					Options[idx]:set_value(data.value);
				end;
			end;
		};
		ColorPicker = {
			save = function(idx, object)
				return { type = 'ColorPicker', idx = idx, value = object.value:ToHex(), transparency = object.transparency };
			end;
			load = function(idx, data)
				if Options[idx] then
					Options[idx]:set_value_rgb(Color3.fromHex(data.value), data.transparency);
				end;
			end;
		};
		KeyPicker = {
			save = function(idx, object)
				return { type = 'KeyPicker', idx = idx, mode = object.mode, key = object.value };
			end;
			load = function(idx, data)
				if Options[idx] then
					Options[idx]:set_value({ data.key, data.mode });
				end;
			end;
		};
		Input = {
			save = function(idx, object)
				return { type = 'Input', idx = idx, text = object.value };
			end;
			load = function(idx, data)
				if Options[idx] and type(data.text) == 'string' then
					Options[idx]:set_value(data.text);
				end;
			end;
		};
	};

	function save_manager:set_ignore_indexes(list)
		for _, key in next, list do
			self.ignore[key] = true;
		end;
	end;

	function save_manager:set_folder(folder)
		self.folder = folder;
		self:build_folder_tree();
	end;

	function save_manager:save(name)
		if not name then
			return false, 'no config file is selected';
		end;

		local full_path = self.folder .. '/settings/' .. name .. '.json';
		local data = { objects = {} };

		for idx, toggle in next, Toggles do
			if self.ignore[idx] then continue end;
			table.insert(data.objects, self.parser.Toggle.save(idx, toggle));
		end;

		for idx, option in next, Options do
			if not self.parser[option.type] then continue end;
			if self.ignore[idx] then continue end;
			table.insert(data.objects, self.parser[option.type].save(idx, option));
		end;

		local success, encoded = pcall(http_service.JSONEncode, http_service, data);
		if not success then
			return false, 'failed to encode data';
		end;

		writefile(full_path, encoded);
		return true;
	end;

	function save_manager:load(name)
		if not name then
			return false, 'no config file is selected';
		end;

		local file = self.folder .. '/settings/' .. name .. '.json';
		if not isfile(file) then return false, 'invalid file' end;

		local success, decoded = pcall(http_service.JSONDecode, http_service, readfile(file));
		if not success then return false, 'decode error' end;

		for _, option in next, decoded.objects do
			if self.parser[option.type] then
				task.spawn(function() self.parser[option.type].load(option.idx, option) end);
			end;
		end;

		return true;
	end;

	function save_manager:ignore_theme_settings()
		self:set_ignore_indexes({
			'background_color', 'main_color', 'accent_color', 'outline_color', 'font_color';
			'theme_manager_theme_list', 'theme_manager_custom_theme_list', 'theme_manager_custom_theme_name';
		});
	end;

	function save_manager:build_folder_tree()
		local paths = {
			self.folder;
			self.folder .. '/themes';
			self.folder .. '/settings';
		};
		for i = 1, #paths do
			local str = paths[i];
			if not isfolder(str) then makefolder(str) end;
		end;
	end;

	function save_manager:refresh_config_list()
		local list = listfiles(self.folder .. '/settings');
		local out = {};
		for i = 1, #list do
			local file = list[i];
			if file:sub(-5) == '.json' then
				local pos = file:find('.json', 1, true);
				local start = pos;
				local char = file:sub(pos, pos);
				while char ~= '/' and char ~= '\\' and char ~= '' do
					pos = pos - 1;
					char = file:sub(pos, pos);
				end;
				if char == '/' or char == '\\' then
					table.insert(out, file:sub(pos + 1, start - 1));
				end;
			end;
		end;
		return out;
	end;

	function save_manager:set_library(lib)
		self.library = lib;
	end;

	function save_manager:load_autoload_config()
		if isfile(self.folder .. '/settings/autoload.txt') then
			local name = readfile(self.folder .. '/settings/autoload.txt');
			local success, err = self:load(name);
			if not success then
				return self.library:notify('failed to load autoload config: ' .. err);
			end;
			self.library:notify(string.format('auto loaded config %q', name));
		end;
	end;

	function save_manager:build_config_section(tab)
		assert(self.library, 'must set save_manager.library');

		local section = tab:add_right_groupbox('configuration');

		section:add_input('save_manager_config_name', { text = 'config name' });
		section:add_dropdown('save_manager_config_list', { text = 'config list', values = self:refresh_config_list(), allow_null = true });
		section:add_button({ Text = 'create config', Func = function()
			local name = Options.save_manager_config_name.value;
			if name:gsub(' ', '') == '' then
				return self.library:notify('invalid config name (empty)', 2);
			end;
			local success, err = self:save(name);
			if not success then
				return self.library:notify('failed to save config: ' .. err);
			end;
			self.library:notify(string.format('created config %q', name));
			Options.save_manager_config_list:set_values(self:refresh_config_list());
			Options.save_manager_config_list:set_value(nil);
		end }):add_button({ Text = 'load config', Func = function()
			local name = Options.save_manager_config_list.value;
			local success, err = self:load(name);
			if not success then
				return self.library:notify('failed to load config: ' .. err);
			end;
			self.library:notify(string.format('loaded config %q', name));
		end });

		section:add_button({ Text = 'overwrite config', Func = function()
			local name = Options.save_manager_config_list.value;
			local success, err = self:save(name);
			if not success then
				return self.library:notify('failed to overwrite config: ' .. err);
			end;
			self.library:notify(string.format('overwrote config %q', name));
		end });

		section:add_button({ Text = 'refresh list', Func = function()
			Options.save_manager_config_list:set_values(self:refresh_config_list());
			Options.save_manager_config_list:set_value(nil);
		end });

		section:add_button({ Text = 'set autoload', Func = function()
			local name = Options.save_manager_config_list.value;
			writefile(self.folder .. '/settings/autoload.txt', name);
			save_manager.autoload_label:set_text('current autoload config: ' .. name);
			self.library:notify(string.format('set %q to auto load', name));
		end }):add_button({ Text = 'remove autoload', Func = function()
			local name = Options.save_manager_config_list.value;
			delfile(self.folder .. '/settings/autoload.txt', name);
			save_manager.autoload_label:set_text('current autoload config: none');
			self.library:notify(string.format('removed %q from auto load', name));
		end });

		save_manager.autoload_label = section:add_label('current autoload config: none', true);

		if isfile(self.folder .. '/settings/autoload.txt') then
			local name = readfile(self.folder .. '/settings/autoload.txt');
			save_manager.autoload_label:set_text('current autoload config: ' .. name);
		end;

		save_manager:set_ignore_indexes({ 'save_manager_config_list', 'save_manager_config_name' });
	end;

	save_manager:build_folder_tree();
end;

return save_manager;
