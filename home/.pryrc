load File.join(File.expand_path("~"), ".irbrc")

# if we're in a project with a log directory, put history there
if File.directory? File.join(Dir.pwd, "log")
  Pry.config.history_file = File.join(Dir.pwd, "log", "pry_history")
end
