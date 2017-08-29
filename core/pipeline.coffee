###

  A pipeline implements a full Gekko Flow based on a config and
  a mode. The mode is an abstraction that tells Gekko what market
  to load (realtime, backtesting or importing) while making sure
  all enabled plugins are actually supported by that market.

  Read more here:
  @link https://github.com/askmike/gekko/blob/stable/docs/internals/architecture.md

###

_ = require('lodash')
async = require 'async'

util = require('./util')

log = require './log'

GekkoStream = require './gekkoStream'


pipeline = (settings, cb = _.noop) ->
  console.log 'creating coffee pipeline'
  mode = settings.mode
  config = settings.config
  # prepare a GekkoStream
  # all plugins
  plugins = []
  # all emitting plugins
  emitters = {}
  # all plugins interested in candles
  candleConsumers = []
  # utility to check and load plugins.
  pluginHelper = require './pluginUtil'
  # meta information about every plugin that tells Gekko
  # something about every available plugin
  pluginParameters = require '../plugins'
  # meta information about the events plugins can broadcast
  # and how they should hooked up to consumers.
  subscriptions = require '../subscriptions'
  # Instantiate each enabled plugin

  loadPlugins = (next) ->
    # load all plugins
    async.mapSeries pluginParameters, pluginHelper.load, (error, _plugins) ->
      if error
        return util.die error, true
      plugins = _.compact _plugins
      next()

  # Some plugins emit their own events, store
  # a reference to those plugins.
  referenceEmitters = (next) ->
    _.each plugins, (plugin) ->
      if plugin.meta.emits
        emitters[plugin.meta.slug] = plugin
    next()

  # Subscribe all plugins to other emitting plugins
  subscribePlugins = (next) ->
    # events broadcasted by plugins
    pluginSubscriptions = _.filter subscriptions, (sub) ->
      sub.emitter != 'market'

    # some events can be broadcasted by different
    # plugins, however the pipeline only allows a single
    # emitting plugin for each event to be enabled.
    for subscription in pluginSubscriptions
      unless _.isArray subscription.emitter
        continue

      singleEventEmitters = subscription.emitter.filter (s) ->
        _.size plugins.filter (p) ->
          p.meta.slug == s

      if _.size(singleEventEmitters) > 1
        error = 'Multiple plugins are broadcasting'
        error += " the event '#{subscription.event}' (#{singleEventEmitters.join(',')})."
        error += 'This is unsupported.'
        util.die error
      else
        subscription.emitter = _.first singleEventEmitters

    # subscribe interested plugins to
    # emitting plugins
    for plugin in plugins
      for sub in pluginSubscriptions
        if _.has plugin, sub.handler
          # if a plugin wants to listen
          # to something disabled
          if not emitters[sub.emitter]
            log.warn([
              plugin.meta.name
              'wanted to listen to the'
              sub.emitter + ','
              'however the'
              sub.emitter
              'is disabled.'
            ].join(' '))
            continue
          # attach handler
          emitters[sub.emitter].on sub.event, plugin[sub.handler]

    # events broadcasted by the market
    marketSubscriptions = _.filter subscriptions, emitter: 'market'
    # subscribe plugins to the market
    for plugin in plugins
      for sub in marketSubscriptions
        # for now, only subscribe to candles
        if sub.event != 'candle'
          continue
        if _.has plugin, sub.handler
          candleConsumers.push plugin

    next()

  # TODO: move this somewhere where it makes more sense
  prepareMarket = (next) ->
    if mode == 'backtest' and config.backtest.daterange is 'scan' and not config.market.type is "memory"
      require("./prepareDateRange")(config) next
    else
      next()

  log.info 'Setting up Gekko in', mode, 'mode'
  log.info ''

  Reader = require "../#{config[config.adapter].path}/reader"
  reader = new Reader

  async.series [
    loadPlugins
    referenceEmitters
    subscribePlugins
    prepareMarket
  ], ->
    # load a market based on the config (or fallback to mode)
    if config.market
      marketType = config.market.type
    else
      marketType = mode

    Market = require "./markets/#{marketType}"

    market = new Market config[marketType], reader

    gekko = new GekkoStream candleConsumers

    market.pipe gekko
    # convert JS objects to JSON string
    #.pipe(new require('stringify-stream')())
    # output to standard out
    #.pipe(process.stdout);
    market.on 'end', gekko.finalize
    if cb
      cb null,
        market: market
        gekko: gekko

module.exports = pipeline
