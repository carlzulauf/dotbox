# functions to help using distrobox

function is_container
  if test -n "$CONTAINER_ID"
    return 0
  else
    return 1
  end
end

function is_asdf_container
  if string match -q "asdf" "$CONTAINER_ID"
    return 0
  else
    return 1
  end
end

function is_local_or_asdf_container
  if is_container
    return (is_asdf_container)
  else
    return 0
  end
end
