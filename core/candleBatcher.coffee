# internally we only use 1m
# candles, this can easily
# convert them to any desired
# size.
# Acts as ~fake~ stream: takes
# 1m candles as input and emits
# bigger candles.
#
# input are transported candles.

EventEmitter = require("events").EventEmitter
_ = require('lodash')

class CandleBatcher extends EventEmitter
  constructor: (candleSize) ->
    if not _.isNumber(candleSize)
      throw 'candleSize is not a number'
    @candleSize = candleSize
    @smallCandles = []


  write: (candles) =>
    if !_.isArray(candles)
      throw 'candles is not an array'

    _.each candles, (candle) =>
      @smallCandles.push candle
      @check()

  check: =>
    if _.size(@smallCandles) % @candleSize isnt 0
      return
    @emit 'candle', @calculate()
    @smallCandles = []

  calculate: =>
    first = @smallCandles.shift()
    first.vwp = first.vwp * first.volume

    candle = _.reduce @smallCandles, (candle, m) ->
      candle.high = Math.max candle.high, m.high
      candle.low = Math.min candle.low, m.low
      candle.close = m.close
      candle.volume += m.volume
      candle.vwp += m.vwp * m.volume
      candle.trades += m.trades
      candle
    , first

    if candle.volume
      candle.vwp /= candle.volume
    else
      candle.vwp = candle.open

    candle.start = first.start
    candle

module.exports = CandleBatcher

