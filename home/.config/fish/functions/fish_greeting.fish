function fish_greeting
  if type -q fastfetch
    # if it's not set up, setup the global with a value that will show MOTD
    if test -z "$MOTD_LAST_SHOWN_AT"
      set --universal MOTD_LAST_SHOWN_AT 1
    end

    # show fastfetch if we haven't shown it for 2hrs
    if test (date +%s) -gt (math $MOTD_LAST_SHOWN_AT + 7200)
      set --universal MOTD_LAST_SHOWN_AT (date +%s)
      fastfetch
    else
      date
    end
  else if type -q neofetch
    # if it's not set up, setup the global with a value that will show MOTD
    if test -z "$MOTD_LAST_SHOWN_AT"
      set --universal MOTD_LAST_SHOWN_AT 1
    end

    # show neofetch if we haven't shown it for 2hrs
    if test (date +%s) -gt (math $MOTD_LAST_SHOWN_AT + 7200)
      set --universal MOTD_LAST_SHOWN_AT (date +%s)
      neofetch_greeting
    else
      date
    end
  else if test -n "$fish_greeting"
    echo $fish_greeting
  else
    date
  end
end

function neofetch_greeting
  if test -f ~/.config/neofetch_$hostname.conf
    neofetch --config ~/.config/neofetch_$hostname.conf
  else
    neofetch --disable theme wm_theme icons
  end
end
