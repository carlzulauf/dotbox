# Dotbox

My attempt to rethink my dotfiles in a way that makes them more portable, shareable, and compatible with immutable host operating systems (ie: os-tree distros).

I will strive to take advantage of containers for most of my dev tooling, using tools like distrobox to ease integration with the host OS.

If you are going to use this project, you should probably clone it:

```
git clone https://github.com/carlzulauf/dotbox.git
cd dotbox
```

## `bin/install_dotfiles`

Utility for installing dotfiles to your home directory. Starts with the dotfiles in this project, then layers on top any private dotfiles directories. The file structures of each of the following directories are merged into the current user's home directory. For example, `home/.local/bin/console_saver` would be installed to `~/.local/bin/console_saver`.

`home/` - Files are symlinked to user's home, with any existing files backed up and replaced.
`home-files/` - Files are copied to home, with any existing files backed up and replaced. Subsequent installs will compare the source file with what's in the home directory, replacing the file in the home directory if a difference is detected.
`optional/` - Files are symlinked to home, unless the destination folder doesn't exist, or a real file already exists at the destination.
`optional-files/` - Files are copied to home, unless the destination folder doesn't exist. Compares with existing on install, replacing when different.
`private/` - Like `home/`, but git ignored and higher priority.
`private-files/` - Like `home-files/`, but git ignored and higher priority.
`../dotbox-private/home/` - Like `home/`, but higher priority.
`../dotbox-private/home-files/` - Like `home-files/`, but higher priority.
`../dotbox-private/optional/` - Like `optional/`, but higher priority.
`../dotbox-private/optional-files/` - Like `optional-files/`, but higher priority.

See `--help` usage hints. Confirms any changes, thus safe to run and see what would be changed.

## Installed Executables

These are executable scripts installed into `~/.local/bin` when you run `bin/install_dotfiles`. They are a collection of small workflow helpers that haven't yet grown large enough to be projects unto themselves.

All scripts require `ruby` unless otherwise noted.

### `tproj`

Project setup script for tmux.

Allows you to define per project configuration (in `~/.config/tproj.yml`). When started with a pre-configured project name a tmux session will be created in the project directory with the specified windows, labels, and commands.

See the [included config](home/.config/tproj.yml) for some examples. Once configured a project can be launched by referring to it's abbreviation or any of the listed names. Launching a tmux session for the dotbox project might look like this:

```
tproj dotbox
```

You can also create sessions for projects that are not yet configured by supplying more details to the command. If you want a tmux session with 5 windows for `~/project/my_project` it might look like this:

```
tproj mine ~/projects/my_project --windows=5
```

### `console_saver`

**Requires**: `pry` gem for ruby. Install `ruby-pry` with your package manager or `gem install pry` to run.

Creates a pry session with a `db` hash and a `save` method. When you call `save` the `db` hash is serialized into the console script itself (using ruby's `__END__` and `DATA` features). Next time you run the console the serialized data will be parsed and restored into the `db` object.

Useful if you are exploring data or something and need a quick place to store data. Especially useful to copy this executable to a new name based on the topic you are researching. Then you've got a portable single file db with interface.

Example:

```
# create new executable and run it
cp home/.local/bin/console_saver private/home/.local/bin/nyc_building_search
nyc_building_search
# build and save your database
[1] pry(#<Console>)> # <import your database into `db`>
[2] pry(#<Console>)> save
[4] pry(#<Console>)> exit
# next run your data will be there
nyc_building_search
[1] pry(#<Console>)> db
# => { ... your data ... }
```

### `git-clean-local`

Utility for clearing out local stale git branches. Provides a basic console UI with confirmation process, so safe to run and see what it will do.

See `git-clean-local --help` for command line options.

Can be treated as a git sub-command: `git clean-local`

### `git-pullf`

Shortcut to force pull from the current tracking branch.

Similar to running this, but less verbose:

```
git pull --force upstream_remote upstream_branch:current_branch
```

Can be treated as a git sub-command: `git pullf`

### `git-pushu`

Behaves like `git push` unless there is no remote tracking branch, in which case it tries to set that up.

Assumes you want your local branch to track a branch of the same name on the default remote repository.

Can be treated as a git sub-command: `git pushu`

### `pjson`

Pretty-print JSON

Takes json, supplied via STDIN or from file names passed to the script, parses it, and spits it back out nicely formatted.

### `prepend_command`

Not sure what arguments are being sent to a command? Just prepend the command name with `prepend_command` and the full command will be printed to the console before being executed.

### `untilfail`

Bash script that runs the supplied command, repeatedly, until a non-zero exit code is received.
