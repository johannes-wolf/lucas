local global = {
  -- Kill recursive calls with no change
  kill_recursive_recall = true,

  -- Limit for iterative algorithms
  kill_iteration_limit = 1000000,

  SYM_KILL = {'sym', 'KILL'}
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
