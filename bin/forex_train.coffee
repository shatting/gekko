fs = require 'fs'
path = require "path"

_           = require "lodash"
moment      = require 'moment'
ProgressBar = require 'progress'
commander   = require "commander"
async       = require "async"
colors      = require "colors"

analytics   = require 'forex.analytics'

forex_utils = require "../strategies/forex_utils"
gekko = require "../index.coffee"
selectorLib = require "../core/selector"

fa_defaultIndicators = [
  #'CCI',
  'MACD',
  #'MACD_Signal',
  'MACD_Histogram',
  'Momentum',
  'RSI',
  #'BOP',
  #'ATR',
  #'SAR',
  #'SMA15_SMA50',
  #'Stochastic'
]

getTrainingOptions = (command) ->
  populationCount: command.populationCount
  generationCount: command.generationCount
  selectionAmount: command.selectionAmount
  leafValueMutationProbability: command.leafValueMutationProbability
  leafSignMutationProbability: command.leafSignMutationProbability
  logicalNodeMutationProbability: command.logicalNodeMutationProbability
  leafIndicatorMutationProbability: command.leafIndicatorMutationProbability
  crossoverProbability: command.crossoverProbability
  indicators: command.indicators.split(",")
  concurrency: command.concurrency

getTraningOptionsV2 = (command) ->
  populationCount: command.populationCount
  generationCount: command.generationCount
  selectionAmount: command.selectionAmount
  leafValueMutationProbability: command.leafValueMutationProbability
  leafSignMutationProbability: command.leafSignMutationProbability
  logicalNodeMutationProbability: command.logicalNodeMutationProbability
  leafIndicatorMutationProbability: command.leafIndicatorMutationProbability
  crossoverProbability: command.crossoverProbability
  pipInDecimals: 0.0025
  spread: 1
  concurrency: command.concurrency
  treeHeight: 1
#  strategy: {
#    "buy": {
#        "operator": "Or",
#        "left": {
#            "indicator": "MACD",
#            "sign": ">",
#            "value": 0.0014203584385885553
#        },
#        "right": {
#            "indicator": "RSI14",
#            "sign": ">",
#            "value": 60.77270840729591
#        }
#    },
#    "sell": {
#        "operator": "Or",
#        "left": {
#            "indicator": "RSI14",
#            "sign": "<",
#            "value": 20.770567435576766
#        },
#        "right": {
#            "indicator": "MACD",
#            "sign": "<",
#            "value": -0.0006005087633471459
#        }
#    }
#  }
  indicators:
#    EMA10:
#      type: "EMA"
#      settings: 10
#      value: "result"
#      talib: false
#    EMA21:
#      type: "EMA"
#      settings: 21
#      value: "result"
#      talib: false
#    EMA60:
#      type: "EMA"
#      settings: 60
#      value: "result"
#      talib: false
#    RSI240:
#      type: "RSI"
#      settings:
#        interval: 240
#      value: "rsi"
#      talib: false
#    RSI240:
#      type: "RSI"
#      settings:
#        interval: 240
#      value: "rsi"
#      talib: false
#    RSI120:
#      type: "RSI"
#      settings:
#        interval: 120
#      value: "rsi"
#      talib: false
#    PPO:
#      type: "PPO"
#      settings:
#        short: 60
#        long: 120
#        signal: 20
#      value: "ppo"
#      talib: false
#    DEMA:
#      type: "DEMA"
#      settings:
#        short: 60
#        long: 120
#      value: "result"
#      talib: false
    MACD6012020:
      type: "MACD"
      settings:
        short: 60
        long: 120
        signal: 20
      value: "result"
      talib: false
    MACD306010:
      type: "MACD"
      settings:
        short: 30
        long: 60
        signal: 10
      value: "result"
      talib: false

commander
.option '--testPct <value>', 'test set percentage (default: 10)', Number, 10
.option '--days-back <days>', 'how many days back should we start', Number
.option '--evaluate-training', 'evaluate performance on training set', false
.option '--selector <selector>', 'selector', false
.option '--version <version>', "forex lib version, either 1 or 2", 2

.command 'train'
.description 'Train the binary buy/sell decision tree for the forex.analytics strategy'
#.option('--conf <path>', 'path to optional conf overrides file')
#.option('--period <value>', 'period length of a candlestick (default: 30m)', String, '30m')
#.option('--start_training <timestamp>', 'start training at timestamp')
#.option('--end_training <timestamp>', 'end training at timestamp')
#.option('--days_training <days>', 'set duration of training dataset by day count', Number, null)
#.option('--days_test <days>', 'set duration of test dataset to use with simulation, appended AFTER the training dataset (default: 0)', Number)
.option '--populationCount <value>', 'population count within one generation (default: 100)', Number, 100
.option '--generationCount <value>', 'generation count (default: 100)', Number, 100
.option '--selectionAmount <value>', 'how many chromosomes shall be selected from the old generation when constructing a new one (default: 10)', Number, 10
.option '--leafValueMutationProbability <value>', 'leaf value mutation probability (default: 0.5)', Number, 0.5
.option '--leafSignMutationProbability <value>', 'leaf sign mutation probability (default: 0.3)', Number, 0.3
.option '--logicalNodeMutationProbability <value>', 'logical node mutation probability (default 0.3)', Number, 0.3
.option '--leafIndicatorMutationProbability <value>', 'leaf indicator mutation probability (default: 0.2)', Number, 0.2
.option '--crossoverProbability <value>', 'crossover probability (default: 0.03)', Number, 0.03
.option '--indicators <value>', 'comma separated list of TA-lib indicators (default: ' + fa_defaultIndicators.join(",") + ', available: ' + forex_utils.availableIndicators.join(",") + ')', String, fa_defaultIndicators.join(",")
.option '--concurrency <value>', 'number of threads', Number, -1
.action (command) ->

  if commander.version is 2
    trainingOptions = getTraningOptionsV2 command
  else
    trainingOptions = getTrainingOptions command

    unknownIndicators = forex_utils.getUnknownIndicators trainingOptions.indicators

    if unknownIndicators.length
      console.error 'ERROR: The following indicators are not in forex.analytics: '.red + unknownIndicators.toString().yellow
      console.error 'Available indicators: ' + forex_utils.availableIndicators.toString()
      process.exit 1

  dataSet = new DataSet commander.selector, commander.testPct, commander.daysBack, if commander.version is 2 then trainingOptions.indicators else null

  # get candles
  dataSet.populate (err) ->
    if err
      throw err

    console.log dataSet.toJSON()

    trainer = new Trainer dataSet, trainingOptions
    trainer.train (err) ->

      if err
        throw err

      console.log "Found strategy with final fitness of #{_.last(trainer.fitness)}".red
      console.log JSON.stringify trainer.strategy, false, 4

      evaluator = new Evaluator dataSet, trainer.strategy, commander.evaluateTraining, if commander.version is 2 then trainingOptions.indicators else null
      evaluator.run (err) ->
        if err
          throw err

        writeFinalModel trainer, evaluator

class DataSet
  constructor: (@selector, @testPercentage, @daysBack, @indicators) ->

    config = require "../config.js"

    struct = selectorLib.selector2struct @selector
    unless struct?
      throw new Error "invalid selector: #{@selector}"

    config.watch = struct

    util = require "../core/util"

    util.setConfig config
    util.setGekkoMode "backtest"

    @gekkoCandles = []
    @forexCandles = []

  populate: (cb) ->
    console.log 'getting candles...'
    prepareDateRange = require "../core/prepareDateRange"

    #Reader = require "../#{config[config.adapter].path}/reader"
    Reader = require "../plugins/postgresql/reader"
    reader = new Reader

    BacktestMarket = require "../core/markets/backtest"

    prepareDateRange(reader) (err, daterange) =>
      if err
        cb err

      candleGetter = new BacktestMarket {batchSize: 50, daterange}, reader

      toDate = new Date daterange.to
      fromDate = new Date(toDate -  @daysBack*24*60*60*1000)

      candleGetter.on "data", (candle) =>
        #  start: 1495796760000
        #  open: 0.07541,
        #  high: 0.07545108,
        #  low: 0.07541,
        #  close: 0.07545108,
        #  vwp: 0.0754157399286111,
        #  volume: 67.36543082,
        #  trades: 8

        if not @daysBack? or candle.start.toDate() >= fromDate
          @gekkoCandles.push candle
          @forexCandles.push forex_utils.gekko2forexCandle candle

      candleGetter.on "end", =>
        if @testPercentage > 0
          @trainingIndex = Math.round @forexCandles.length*(1-(@testPercentage/100))
        else
          @trainingIndex = @forexCandles.length - 1

        if @indicators?
          @getIndicators (err) =>
            if err
              throw err
            cb()
        else
          cb()

  getIndicators: (cb) ->
    # set config for training set
    console.log "getting indicator values".magenta
    util = require "../core/util"
    config = util.getConfig()
    config.tradingAdvisor.method = "forex"
    config.forex =
      indicators: @indicators
      mode: "getIndicators"
    config.market =
      type: "memory"
    config.memory =
      candles: @getCandles "gekko"

    # test strategy
    gekko config, "backtest", (err, res) =>

      if err
        return cb err

      bar = new ProgressBar "Getting Indicators [:bar] :percent :etas - Candle: :current/:total",
        width: 80
        total: config.memory.candles.length
        incomplete: ' '

      res.gekko.on "consumed", (c) ->
        bar.tick()

      res.gekko.on "shutdown", =>

        @indicatorValues = res.gekko.getConsumerBySlug("tradingAdvisor").method.indicatorValues
        cb()

  getCandles: (dataType, usageType) ->
    if dataType is "forex"
      candles = @forexCandles
    else if dataType is "gekko"
      candles = @gekkoCandles
    else
      throw new Error "unknown dataType #{dataType}"

    if usageType is "training"
      candles[0..@trainingIndex]
    else if usageType is "testing"
      candles[@trainingIndex+1..]
    else
      candles

  getCloses: (usageType) ->
    if usageType is "training"
      _.map @gekkoCandles[0..@trainingIndex], (c) ->
        c.close
    else if usageType is "testing"
      _.map @gekkoCandles[@trainingIndex+1..], (c) ->
        c.close
    else
      _.map @gekkoCandles, (c) ->
        c.close

  getIndicatorValues: (usageType) ->
    # todo: might be shorter than close values
    res = {}
    for key, val of @indicatorValues
      if usageType is "training"
        res[key] = val[0..@trainingIndex]
      else if usageType is "testing"
        res[key] = val[@trainingIndex+1..]
      else
        res[key] = val
    res

  toJSON: ->
    training = @getCandles "gekko", "training"
    testing = @getCandles "gekko", "testing"
    training:
      start:  new Date training[0].start
      end:    new Date _.last(training).start
      count:  training.length
    testing:
      start:  new Date testing[0].start
      end:    new Date _.last(testing).start
      count:  testing.length
    all:
      start:  new Date @gekkoCandles[0].start
      end:    new Date _.last(@gekkoCandles).start
      count:  @gekkoCandles.length

class Trainer
  constructor: (@dataSet, @options) ->
    @fitness = new Array @options.generationCount
    @strategy = null

  train: (cb) ->
    bar = new ProgressBar "Training strategy [:bar] :percent :elapseds, :etas to go - Fitness: :fitness, Generation: :current/:total",
      width: 80
      total: @options.generationCount
      incomplete: ' '

    # find strategy
    if commander.version is 2
      # TODO: indicators might be shorter than close values
      analytics.findStrategy @dataSet.getCloses("training"), @dataSet.getIndicatorValues("training"), @options, (strategy, fitness, generation) =>
        @fitness[generation-1] = fitness
        bar.tick {fitness: fitness.toPrecision(4)}
      , (err, strategy) =>
        unless err?
          @strategy = strategy
        cb err

    else
      analytics.findStrategy @dataSet.getCandles("forex","training"), @options, (strategy, fitness, generation) =>
        @fitness[generation-1] = fitness
        bar.tick {fitness: fitness.toPrecision(4)}
      .then (strategy) =>
        @strategy = strategy
        cb()
      .catch cb

  toJSON: ->
    strategy: @strategy
    fitness: @fitness
    finalFitness: _.last @fitness
    options: @options

class Evaluator
  constructor: (@dataSet, @strategy, @evaluateTraining, @indicators ) ->
    @evaluators =[
      new ForexStrategyEvaluation @dataSet, "testing", @strategy
      new GekkoStrategyEvaluation @dataSet, "testing", @strategy, @indicators
    ]
    if @evaluateTraining
      @evaluators.push new ForexStrategyEvaluation @dataSet, "training", @strategy
      @evaluators.push new GekkoStrategyEvaluation @dataSet, "training", @strategy, @indicators

  run: (cb) ->

    async.eachSeries @evaluators, (evaluator, cb) ->
      evaluator.run cb
    , cb

  toJSON: ->
    res = {}
    for e in @evaluators
      res[e.type] ?= {}
      res[e.type][e.usageType] = e.toJSON()
    res

class GekkoStrategyEvaluation
  constructor: (@dataSet, @usageType, @strategy, @indicators) ->
    @type = "gekko"

  run: (cb) ->
    # set config for training set
    console.log "evaluating #{@type}:#{@usageType}".magenta
    config = require("../core/util").getConfig()
    config.tradingAdvisor.method = "forex"
    config.forex =
      strategy: @strategy
      #history: 50
      indicators: @indicators
    config.market =
      type: "memory"
    config.memory =
      candles: @dataSet.getCandles "gekko", @usageType

    # test strategy
    gekko config, "backtest", (err, res) =>

      if err
        return cb err

      bar = new ProgressBar "Evaluating '#{@usageType}' [:bar] :percent :etas - Candle: :current/:total",
        width: 80
        total: config.memory.candles.length
        incomplete: ' '

      res.gekko.on "consumed", (c) ->
        bar.tick()

      res.gekko.on "shutdown", =>

        performanceAnalyzer = res.gekko.getConsumerBySlug "performanceAnalyzer"
        @report = performanceAnalyzer.calculateReportStatistics()
        @rawTrades = performanceAnalyzer.rawTrades
        @advices = res.gekko.getConsumerBySlug("tradingAdvisor").method.advices
        cb()

  toJSON: ->
    report: @report
    rawTrades: @rawTrades
    advices: @advices

class ForexStrategyEvaluation
  constructor: (@dataSet, @usageType, @strategy)->
    @type = "forex"

  run: (cb) ->

    console.log "evaluating #{@type}:#{@usageType}".magenta

    @trades = analytics.getTrades @dataSet.getCloses(@usageType), @dataSet.getIndicatorValues(@usageType),
      strategy: @strategy
    #{startIndex,startPrice,endIndex,endPrice, revenue}
    @report =
      totalRevenue:  0
      totalNoOfTrades: 0
      numberOfProfitTrades: 0
      numberOfLossTrades: 0

    for trade in @trades

      if trade.revenue > 0
        @report.numberOfProfitTrades++
      else
        @report.numberOfLossTrades++
      @report.totalNoOfTrades++
      @report.totalRevenue += trade.revenue

    console.log 'Total theoretical revenue is: ' + @report.totalRevenue + ' currency'
    console.log 'Total number of Profitable trades is: ' + @report.numberOfProfitTrades
    console.log 'Total number of loss trades is: ' + @report.numberOfLossTrades
    console.log 'Total number of trades is: ' + @report.totalNoOfTrades


#     Buy: false,
#    Revenue: 0.0043300000000000005,
#    MaximumLoss: 0.0006000000000000033,
#    MaximumProfit: 0.0049999999999999906,
#    ProfitBeforeLoss: 0,
#    start:
#     { open: 0.086995,
#       low: 0.08688001,
#       high: 0.087,
#       close: 0.087,
#       time: 1500148620 },
#    end:
#     { open: 0.08289499,
#       low: 0.08267,
#       high: 0.08289499,
#       close: 0.08267,
#       time: 1500181080 } },
#
    # {
#        "action": "sell",
#        "price": 0.08478992,
#        "portfolio": {
#            "asset": 0,
#            "currency": 0.11769627,
#            "balance": 0.11728
#        },
#        "balance": 0.11769627,
#        "date": "2017-07-13T19:57:00.000Z"
#    },
#    {
#        "action": "buy",
#        "price": 0.08618332,
#        "portfolio": {
#            "asset": 1.36291892,
#            "currency": 0,
#            "balance": 0.11728
#        },
#        "balance": 0.11746686063047321,
#        "date": "2017-07-14T08:11:00.000Z"
#    },
    @rawTrades = []
    for trade, index in @trades
      if trade.Buy
        actions = ["buy", "sell"]
      else
        actions = ["sell", "buy"]

      if commander.version is 2
        @rawTrades.push
          action: actions[1]
          price: trade.StartPrice
          date: new Date() # // TODO trade.end.time*1000
      else
        if index is 0
          @rawTrades.push
            action: actions[0]
            price: trade.start.close
            date: new Date trade.start.time*1000
        @rawTrades.push
          action: actions[1]
          price: trade.end.close
          date: new Date trade.end.time*1000

    cb()

  toJSON: ->
    report: @report
    rawTrades: @rawTrades



#    ###*
#    # Returns an object representing buy/sell strategy
#    # @param  {Object} candlesticks Input candlesticks for strategy estimation
#    ###
#
#    createStrategy = (candlesticks, testing30MinuteCandlesticks) ->
#      lastFitness = -1
#      analytics.findStrategy candlesticks, {
#        populationCount: 3000
#        generationCount: 100
#        selectionAmount: 10
#        leafValueMutationProbability: 0.3
#        leafSignMutationProbability: 0.1
#        logicalNodeMutationProbability: 0.05
#        leafIndicatorMutationProbability: 0.2
#        crossoverProbability: 0.03
#        indicators: indicators
#      }, (strategy, fitness, generation) ->
#        console.log '---------------------------------'
#        console.log 'Fitness: ' + fitness + '; Generation: ' + generation
#        if lastFitness == fitness
#          return
#        lastFitness = fitness
#        console.log '-----------Training--------------'
#        calculateTrades candlesticks, strategy
#        console.log '-----------Testing--------------'
#        calculateTrades testing30MinuteCandlesticks, strategy
#        return

commander
.command "evaluate <file>"
.description "asd"
.action (file, command) ->
  data = require "../forexTraining/#{file}"

  dataSet = new DataSet data.selector, commander.testPct, commander.daysBack, if commander.version is 2 then getTraningOptionsV2({}).indicators else null
  dataSet.populate (err, res) ->
    if err
      throw err

    e = new Evaluator dataSet, data.trainer.strategy, commander.evaluateTraining, if commander.version is 2 then getTraningOptionsV2({}).indicators else null
    e.run (err) ->
      if err
        throw err

      writeHTML data, e, "gekko"


writeFinalModel = (trainer, evaluator) ->
  results =
    timestamp: new Date
    selector:   trainer.dataSet.selector
    resolution: "1m"
    evaluation:   evaluator.toJSON()
    trainer:    trainer.toJSON()
    dataSet:    trainer.dataSet.toJSON()

  fname = "#{results2filename(results)}.json"
  fs.writeFileSync fname, JSON.stringify(results, false, 4)
  console.log fname.green
  writeHTML results, evaluator


results2filename = (results) ->
  creationDate = moment(results.timeStamp).utc().format('YYMMDD_HHmmss')
  fromDate = moment(results.dataSet.training.start).utc().format('YYMMDD_HHmmss')
  toDate = moment(results.dataSet.training.end).utc().format('YYMMDD_HHmmss')
  "forexTraining/forex.model_#{results.selector}_#{results.resolution}_#{creationDate}_#{fromDate}_#{toDate}"

#    action,
#    price,
#    portfolio: _.clone(this.portfolio),
#    balance: this.portfolio.currency + this.price * this.portfolio.asset,
#    date: at
writeHTML = (results, evaluator, type = "gekko")->

  e = evaluator.toJSON()
  testTrades = e[type].testing.rawTrades
  trainTrades =e[type].training?.rawTrades or []

  trades = _.map trainTrades, (trade) ->
    price: trade.price
    size: trade.balance # s.balance.asset
    type: trade.action
    time: trade.date
    class: "train"

  trades = trades.concat _.map testTrades, (trade)  ->
    price: trade.price
    size: trade.balance # s.balance.asset
    type: trade.action
    time: trade.date
    class: "test"

  minTrade = new Date(_.min(trades, "time").time - 60*60*1000)
  maxTrade = new Date(_.max(trades, "time").time + 60*60*1000)

  candles = _.chain evaluator.dataSet.gekkoCandles
    .filter (candle) ->
      candle = candle.start.toDate()
      minTrade <= candle <= maxTrade
    .map (candle) ->
      time: candle.start
      open: candle.open
      high: candle.high
      low: candle.low
      close: candle.close
      volume: candle.volume
    .value()

  code = 'var data = ' + JSON.stringify(candles) + ';\n'
  code += 'var trades = ' + JSON.stringify(trades) + ';\n'
  tpl = fs.readFileSync(path.resolve(__dirname, '..', 'forexTraining', 'sim_result.html.tpl'), encoding: 'utf8')

  out = tpl
    .replace('{{code}}', code)
    .replace('{{trend_ema_period}}', 36)
    .replace '{{output}}', JSON.stringify evaluator.toJSON(), false, 4
    .replace(/\{\{symbol\}\}/g, results.selector)

  fname = "#{results2filename(results)}.html"
  fs.writeFileSync fname, out
  console.log "file://" + path.join(process.cwd(), fname).green

commander.parse process.argv
