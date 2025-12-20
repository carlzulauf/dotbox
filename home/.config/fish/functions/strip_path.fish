# strips an environment variable of entries that match a sub string

function strip_path # 1: sub_str
  set -l replacement_path

  for path_entry in (string split ':' $PATH)
    if not string match -qe "$argv[1]" $path_entry
      if test -z "$replacement_path"
        set replacement_path $path_entry
      else
        set replacement_path $replacement_path:$path_entry
      end
    end
  end

  set -gx PATH $replacement_path

  return 0
end
