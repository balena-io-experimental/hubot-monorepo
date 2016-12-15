# Description
#   A hubot script that selectively ignores indicated messages
#
# Configuration:
#   LIST_OF_ENV_VARS_TO_SET
#
# Commands:
#   hubot hello - <what the respond trigger does>
#   orly - <what the hear trigger does>
#
# Notes:
#   <optional notes required for the script>
#
# Author:
#   Andrew Lucas <andrewl@resin.io>

module.exports = (robot) ->
  robot.respond /hello/, (res) ->
    res.reply "hello!"

  robot.hear /orly/, (res) ->
    res.send "yarly"
