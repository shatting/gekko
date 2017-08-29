Readable = require('stream').Readable

_ = require 'lodash'
async = require "async"

log = require "../../core/log"

class MemoryMarket extends Readable

  constructor: (config) ->
    @ended = false
    @closed = false
    @reading = false

    @candles = config.candles

    super objectMode: true

  _read: =>
    if @reading
      return
    @reading = true

    pushed = 0
    async.eachSeries @candles, (candle, cb) =>
      pushed++
      #console.log "memoryMarket pushing #{pushed}/#{@candles.length}"
      @push candle
      setImmediate cb
    , =>
      @closed = true
      #console.log "memoryMarket ending #{pushed}/#{@candles.length}"
      @emit 'end'

module.exports = MemoryMarket
