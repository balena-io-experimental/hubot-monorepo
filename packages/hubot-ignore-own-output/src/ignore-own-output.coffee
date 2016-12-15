# Description:
#   A hubot script to help a hubot ignore it's own output
#
# Author:
#   Andrew Lucas (sqweelygig) <andrewl@resin.io> <sqweelygig@gmail.com>
#noinspection JSUnresolvedVariable
module.exports = (robot) ->

	previous = []

	#noinspection CoffeeScriptUnusedLocalSymbols
	robot.responseMiddleware (context, next, done) ->
		# Record the output that is heading toward the client
		previous = context.strings
		next()

	robot.receiveMiddleware (context, next, done) ->
		# If the input from the client is what we've just output
		if previous.includes context.response.message.text
			# ignore it once by resetting the previous
			previous = []
			done()
		else
			next()
