analytics = require "forex.analytics"

config = require('../core/util.js').getConfig();

forexUtils = require "./forex_utils"

strategy =

  init: ->
    @requiredHistory = config.forex.history
    @history = []
    @strategy = config.forex.strategy

  update: (candle) ->
    @history.push forexUtils.gekko2forexCandle candle
    if @history.length > @requiredHistory
      @history = @history[@history.length-@requiredHistory..]

  log: (candle) ->
    #console.log "log", candle

  check: (candle) ->
    #console.log "check", candle

    result = analytics.getMarketStatus @history,
      strategy: @strategy

    #console.log "check #{@history.length}/#{@requiredHistory}"
    #console.log result
    if (result.shouldSell)
      @advice "short"
    else if (result.shouldBuy)
      @advice "long"

module.exports = strategy;
