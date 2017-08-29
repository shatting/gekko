BATCH_SIZE = 60
# minutes
MISSING_CANDLES_ALLOWED = 3
# minutes, per batch
_ = require('lodash')
async = require('async')

log = require '../log'

# todo: rewrite with generators or async/await..

scan = (reader, done) ->
  log.info 'Scanning local history for backtestable dateranges.'

  reader.tableExists 'candles', (err, exists) ->
    if err
      return done err, null

    if not exists
      return done null, []

    async.parallel
      boundry: reader.getBoundry
      available: reader.countTotal
    , (err, res) ->
      first = res.boundry.first
      last = res.boundry.last
      optimal = (last - first) / 60
      log.debug 'Available', res.available
      log.debug 'Optimal', optimal
      # There is a candle for every minute
      if res.available == optimal + 1
        log.info 'Gekko is able to fully use the local history.'
        return done(false, [ {
          from: first
          to: last
        } ], reader)
      # figure out where the gaps are..
      missing = optimal - (res.available) + 1
      log.info "The database has #{missing} candles missing, Figuring out which ones..."
      iterator =
        from: last - (BATCH_SIZE * 60)
        to: last
      batches = []
      # loop through all candles we have
      # in batches and track whether they
      # are complete
      async.whilst ->
        iterator.from > first
      , (next) ->
        from = iterator.from
        to = iterator.to
        reader.count from, iterator.to, (err, count) ->
          complete = count + MISSING_CANDLES_ALLOWED > BATCH_SIZE
          if complete
            batches.push
              to: to
              from: from
          next()
        iterator.from -= BATCH_SIZE * 60
        iterator.to -= BATCH_SIZE * 60
      , ->
        unless batches.length
          return done new Error 'Not enough data to work with (please manually set a valid `backtest.daterange`)..'

        # batches is now a list like
        # [ {from: unix, to: unix } ]

        ranges = [ batches.shift() ]

        for batch in batches
          curRange = _.last(ranges)
          if batch.to == curRange.from
            curRange.from = batch.from
          else
            ranges.push batch

        # we have been counting chronologically reversed
        # (backwards, from now into the past), flip definitions
        ranges = ranges.reverse()

        _.map ranges, (r) ->
            from: r.to
            to: r.from

        # ranges is now a list like
        # [ {from: unix, to: unix } ]
        #
        # it contains all valid dataranges available for the
        # end user.
        done false, ranges

module.exports = scan
