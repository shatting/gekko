_ = require 'lodash'
prompt = require 'prompt-lite'
moment = require 'moment'

log = require "./log"
scan = require "./tools/dateRangeScanner"
# helper to store the evenutally detected
# daterange.

module.exports = (reader) ->
  (done) ->
    cb = (err, range) ->
      if err
        done err
      else
        done null,
          from: moment.unix(range.from).utc().format()
          to: moment.unix(range.to).utc().format()

    scan reader, (err, ranges) ->
      unless ranges?.length
        return cb new Error 'No history found for this market'

      if _.size(ranges) == 1
        r = _.first ranges
        log.info 'Gekko was able to find a single daterange in the locally stored history:'
        log.info '\u0009', 'from:', moment.unix(r.from).utc().format('YYYY-MM-DD HH:mm:ss')
        log.info '\u0009', 'to:', moment.unix(r.to).utc().format('YYYY-MM-DD HH:mm:ss')
        return cb null, r

      log.info 'Gekko detected multiple dateranges in the locally stored history.', 'Please pick the daterange you are interested in testing:'

      _.each ranges, (range, i) ->
        log.info('\t\t', "OPTION #{i + 1}:");
        log.info '\u0009', 'from:', moment.unix(range.from).utc().format('YYYY-MM-DD HH:mm:ss')
        log.info '\u0009', 'to:', moment.unix(range.to).utc().format('YYYY-MM-DD HH:mm:ss')

      prompt.get { name: 'option' }, (err, result) ->
        option = parseInt result.option
        if option == NaN
          return cb new Error  'Not an option..'

        range = ranges[option - 1]

        if not range
          return cb new Error 'Not an option..'

        cb null, range
