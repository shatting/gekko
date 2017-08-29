Readable  = require('stream').Readable

_         = require 'lodash'
moment    = require 'moment'

util = require '../util'

log = require "../log"

class BacktestMarket extends Readable

  constructor: (config, reader)->
    @pushing = false
    @ended = false
    @closed = false
    @reader = reader
    @batchSize = config.batchSize

    daterange = config.daterange
    @to = moment.utc daterange.to
    @from = moment.utc daterange.from
    if @to <= @from
      util.die 'This daterange does not make sense.'
    if not @from.isValid()
      util.die 'invalid `from`'
    if not @to.isValid()
      util.die 'invalid `to`'

    @iterator =
      from: @from.clone()
      to: @from.clone().add(@batchSize, 'm').subtract(1, 's')

    super objectMode: true

  _read: =>
    if @reading
      return
    @reading = true
    @get()

  get: =>
    if @iterator.to >= @to
      @iterator.to = @to
      @ended = true
    @reader.get @iterator.from.unix(), @iterator.to.unix(), 'full', @processCandles

  processCandles: (err, candles) =>
    if err
      util.die err.message

    @pushing = true
    amount = candles.length
    if amount is 0
      if @ended
        @closed = true
        @reader.close()
        @emit 'end'
      else
        util.die 'Query returned no candles (do you have local data for the specified range?)'

    if not @ended and amount < @batchSize

      d = (ts) ->
        moment.unix(ts).utc().format 'YYYY-MM-DD HH:mm:ss'

      from = d(_.first(candles).start)
      to = d(_.last(candles).start)
      log.warn "Simulation based on incomplete market data (#{@batchSize - amount} missing between #{from} and #{to})."

    for candle in candles
      candle.start = moment.unix candle.start
      @push candle

    @pushing = false
    @iterator =
      from: @iterator.from.clone().add(@batchSize, 'm')
      to: @iterator.from.clone().add(@batchSize * 2, 'm').subtract(1, 's')
    if !@closed
      @get()



module.exports = BacktestMarket
