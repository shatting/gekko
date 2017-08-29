
module.exports =
  selector2struct: (selector) ->
    m = selector?.match /^(\w+)\.(\w+)-(\w+)$/
    if m?
      return {
        exchange: m[1]
        currency: m[3]
        asset: m[2]
      }

  struct2selector: (struct) ->
    for key in ["exchange", "currency", "asset"]
      unless struct[key]
        return ""
    "#{struct.exchange}.#{struct.asset}-#{struct.currency}"
