local global = {
  kill_recursive_recall = true
}

function global.message(s)
  return global.message_fn and global.message_fn(s)
end

function global.warn(s)
  return global.warn_fn and global.warn_fn(s)
end

function global.error(s)
  return global.error_fn and global.error_fn(s)
end

return global
