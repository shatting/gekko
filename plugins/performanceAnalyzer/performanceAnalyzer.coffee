_ = require('lodash')

moment = require('moment')
stats = require('../../core/stats')
util = require('../../core/util')
ENV = util.gekkoEnv()

# Load the proper module that handles the results
if ENV is 'child-process'
  Handler = require './cpRelay'
else
  Handler = require './logger'

class PerformanceAnalyzer

  constructor: ->
    _.bindAll @
    config = util.getConfig()

    @silent = config.performanceAnalyzer.silent
    @riskFreeReturn = config.performanceAnalyzer.riskFreeReturn
    @dates =
      start: false
      end: false

    @startPrice = 0
    @endPrice = 0
    @currency = config.watch.currency
    @asset = config.watch.asset
    @handler = new Handler config.watch
    @trades = 0
    @sharpe = 0
    @wins = 0
    @losses = 0
    @rawTrades = []
    @roundTrips = []
    @roundTrip =
      entry: false
      exit: false
    @totalFees = 0

  # from market
  processCandle: (candle, done) =>
    @price = candle.close
    @dates.end = candle.start
    unless @dates.start
      @dates.start = candle.start
      @startPrice = candle.close
    @endPrice = candle.close
    done()

  # from trader
  processPortfolioUpdate: (portfolio) =>
    @start = portfolio
    @current = _.clone(portfolio)

  # from trader
  processTrade: (trade) =>
    @trades++
    @rawTrades.push trade
    @current = trade.portfolio
    @totalFees += trade.fee
    report = @calculateReportStatistics()
    @handler.handleTrade trade, report
    @_logRoundtripPart trade

  _logRoundtripPart: (trade) =>
    #console.log trade
    # this is not part of a valid roundtrip
    if @trades is 1 and trade.action is 'sell'
      return
    if trade.action is 'buy'
      @roundTrip.entry =
        date: trade.date
        price: trade.price
        balance: trade.portfolio.balance
    else if trade.action is 'sell'
      @roundTrip.exit =
        date: trade.date
        price: trade.price
        balance: trade.portfolio.balance
      @_handleRoundtrip()

  _round: (amount) =>
    amount.toFixed 8

  _handleRoundtrip: =>
    roundtrip =
      entryAt: @roundTrip.entry.date
      entryPrice: @roundTrip.entry.price
      entryBalance: @roundTrip.entry.balance
      exitAt: @roundTrip.exit.date
      exitPrice: @roundTrip.exit.price
      exitBalance: @roundTrip.exit.balance
      duration: @roundTrip.exit.date.diff(@roundTrip.entry.date)

    roundtrip.pnl = roundtrip.exitBalance - roundtrip.entryBalance
    roundtrip.profit = 100 * roundtrip.exitBalance / roundtrip.entryBalance - 100
    if roundtrip.profit > 0
      @wins++
    else
      @losses++

    @roundTrips.push roundtrip
    @handler.handleRoundtrip roundtrip
    # we need a cache for sharpe
    # every time we have a new roundtrip
    # update the cached sharpe ratio
    @sharpe = stats.sharpe(@roundTrips.map((r) ->
      r.profit
    ), @riskFreeReturn)

  calculateReportStatistics: =>
    # the portfolio's balance is measured in {currency}
    @end =
      currency: @current.currency
      asset: @current.asset
      price: @price
      balance: @current.currency + @price * @current.asset

    profit = @end.balance - @start.balance
    market = @endPrice * 100 / @startPrice - 100

    timespan = moment.duration @dates.end.diff(@dates.start)

    relativeProfit = @end.balance / @start.balance * 100 - 100

    report =
      currency: @currency
      asset: @asset
      startTime: @dates.start.utc().format('YYYY-MM-DD HH:mm:ss')
      endTime: @dates.end.utc().format('YYYY-MM-DD HH:mm:ss')
      timespan: timespan.humanize()
      market: market
      balance: @end.balance
      profit: profit
      relativeProfit: relativeProfit
      yearlyProfit: @_round(profit / timespan.asYears())
      relativeYearlyProfit: @_round(relativeProfit / timespan.asYears())
      startPrice: @startPrice
      endPrice: @endPrice
      trades: @trades
      startBalance: @start.balance
      sharpe: @sharpe
      start: @start
      end: @end
      alpha: profit - market
      wins: @wins
      losses: @losses
      totalFees: @totalFees

    report

  finalize: =>
    if @silent
      return
    report = @calculateReportStatistics()
    @handler.finalize report

module.exports = PerformanceAnalyzer
