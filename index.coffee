util = require "./core/util"

module.exports = (config, mode, cb) ->
  if config?
    util.setConfig config
  else
    config = util.getConfig()

  if mode
    util.setGekkoMode mode
  else
    mode = util.gekkoMode()

  dirs = util.dirs()
  pipeline = require dirs.core + 'pipeline'

  pipeline
    config: config
    mode: mode
  , cb


