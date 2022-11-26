# Dotbox

My attempt to rethink my dotfiles in a way that makes them more portable, shareable, and compatible with immutable host operating systems (ie: os-tree distros).

I will strive to take advantage of containers for most of my dev tooling, using tools like distrobox to ease integration with the host OS.

If you are going to use this project, you should probably clone it:

```
git clone https://github.com/carlzulauf/dotbox.git
cd dotbox
```

## `bin/install_dotfiles`

Utility for installing dotfiles to the current user's home directory. Starts with the dotfiles found in `home/` & `home-files/` within this project, and then layers on top any private dotfiles directories.

See `--help` usage hints. Confirms any changes, sosafe to run and see what would be changed.

By default, the following paths are checked and assumed to contain private dotfiles if found. This behavior can be overwritten by specifying directories with `--private-dir`.

* `private/` - Within the dotbox project folder you can create a directory called `private`. It will be ignored by git but picked up by the `install_dotfiles`.
* `../dotbox-private/` - If the parent folder of the `dotbox` project directory contains a folder called `dotbox-private`, it is assumed to contain private dotfiles.

Within each private directory, dotfiles are looked for in directories named `home/` and `home-files/`. Dotfiles should be placed in one of these private "home" directories using the path relative to the user's home directory (`~`) they will reside at once installed. Any file found in a private directory that already existed in the base dotfiles or a previous private directroy will overwrite the previous version of the file.

### What are dotfiles?

Really, any file in the user's home directory.

Usually they start with a dot (`.`) like `~/.gitconfig` or `~/.config/starship.toml`. They usually contain user preferences or configurations for various apps. Keeping your dotfiles organized and source controlled can make your workflow more efficient, and makes it much easier to keep your workflow in sync between machines or setup your workflow on a new machine. Whether you are a developer, a designer, or even a gamer, understanding and organizing your dotfiles can benefit you. This tool is definitely developer focused, though.

### Customizing Configs Example

Say you want to change the config for [starship](https://starship.rs/). Dotbox already has a [starship config](home/.config/starship.toml). You'll need to copy the config to a private directory and make your changes there. Then, just re-run the installer.

```
mkdir -p ../dotbox-private/home/.config
cp home/.config/starship.toml ../dotbox-private/home/.config/starship.toml
# make your changes in ../dotbox-private
bin/install_dotfiles
```

Your private dotfiles are layered on top and will take precedence over any dotfiles in this project.

### Existing dotfiles: Where do they go?

Any existing dotfiles that would be modified or overwritten will be placed into `~/.backup-dotfiles`.

### `home/` vs `home-files/`

Dotbox itself and any private directories can contain `home/` and/or `home-files/`. For files in `home/`, the installer creates a symlink to the file in the user's home directory. For files in `home-files/` the installer creates real files, copying each file found to the user's home directory.

Usually symlinks work fine. Any edits to the symlink will be reflected in the linked file in dotbox or your private dotfiles directory, making it easier to track/commit any changes. Symlinks are also more space efficient, which doesn't *usually* matter for these kinds of files.

I have encountered instances, like the flatpak version of Google Chrome, where symlinks will not work. `home-files/` are for those cases and will copy the file contents instead.

If you make a change to the installed copy of a `home-files/` dotfile you might find those changes erased the next time you run the installer. The installer will see the md5 hash of the file does not match the one in `home-files/` and will move the modified dotfile to `~/.backup-dotfiles` before replacing it. Make any changes in `home-files/` and re-run the installer to apply them.

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

You can also create sessions for projects that are not yet configured supplying more details to the command. If you want a tmux session with 5 windows for `~/project/my_project` it might look like this:

```
tproj mine ~/projects/my_project 5
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
