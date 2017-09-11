# Small writable stream wrapper that
# passes data to all `candleConsumers`.
Writable = require('stream').Writable
_     = require('lodash')
async = require('async')

util  = require('./util')
env   = util.gekkoEnv()

class GekkoStream extends Writable
  constructor: (candleConsumers) ->
    @candleConsumers = candleConsumers
    #console.log candleConsumers
    super objectMode: true

  _write: (chunk, encoding, cb) =>
    #console.log "gekko received"
    async.each @candleConsumers, (c, cb) =>
      c.processCandle chunk, cb
    , (err) =>
      #console.log "gekko consumed"
      @emit 'consumed', chunk
      cb err

  getConsumerBySlug: (name) ->
    _.find @candleConsumers, (c) ->
      c.meta.slug is name

  finalize: =>
    #console.log "gekkoStream finalize"
    tradingMethod = _.find @candleConsumers, (c) ->
      c.meta.name is 'Trading Advisor'

    if tradingMethod
      return @shutdown()

    tradingMethod.finish @shutdown

  shutdown: =>
    #console.log "gekkoStream shutdown"
    _.each @candleConsumers, (c) ->
      c.finalize?()

    @emit "shutdown"
    if env == 'child-process'
      process.exit 0

module.exports = GekkoStream
