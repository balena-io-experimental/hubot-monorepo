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

	robot.receiveMiddleware (context, next, done) ->
		if process.env.HUBOT_IGNORE_PREFIX? \
		   and context.response.message.text.slice(0, process.env.HUBOT_IGNORE_PREFIX.length) is process.env.HUBOT_IGNORE_PREFIX
			done()
		else
			next()
