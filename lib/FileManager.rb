require 'yaml'

module FileManager

	DIR = "saves"
	EXT = ".yml"

	def save_game(game,filename=nil)
		yaml = YAML::dump(game)
		Dir.mkdir(DIR) unless Dir.exists? DIR

		if !filename
			recent = get_saves_by_date[0]
			if !recent
				filename = "game#{Time.now.strftime("%Y%m%d")}"
			else
				filename = File.basename(recent,EXT)
			end
		end

		file_path = "#{DIR}/#{filename}#{EXT}"
		is_new = !File.exists?(file_path)

		File.open(file_path,"w") { |file| file.puts yaml }
		puts is_new ? "New save '#{filename}' created!" : "#{filename} saved!"
	end

	def load_game(filename)
		file_path = "#{DIR}/#{filename}#{EXT}"
		if File.exists?(file_path)
			save = YAML.load_file(file_path)
		else
			puts "Saved game '#{filename}' does not exist"
		end
	end

	def get_saves_by_date
		files = Dir.entries(DIR).select {|f| File.extname(f) == EXT}
		files.sort_by! {|f| File.mtime("#{DIR}/"+f)}.reverse!
	end

	def list_saves
		saves = get_saves_by_date
		if saves == []
			puts "No saves found."
		else
			saves.each { |f| puts File.basename(f,EXT) + " " +File.mtime("#{DIR}/"+f).strftime("(%Y-%m-%d %H:%M:%S)") }
		end
	end

end