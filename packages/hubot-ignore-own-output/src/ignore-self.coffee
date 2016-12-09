# Description:
#   A hubot script to help a hubot ignore it's own output
#
# Author:
#   Andrew Lucas (sqweelygig) <andrewl@resin.io> <sqweelygig@gmail.com>

previous = []

#noinspection CoffeeScriptUnusedLocalSymbols
robot.responseMiddleware (context, next, done) ->
	previous = context.strings
	next()

robot.receiveMiddleware (context, next, done) ->
	if previous.includes context.response.message.text
		previous = []
		done()
	else
		next()
