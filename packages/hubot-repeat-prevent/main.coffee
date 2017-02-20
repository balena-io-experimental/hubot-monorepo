# Description:
#   A hubot script to prevent responses if they repeat a recent response
#
# Author:
#   Andrew Lucas (sqweelygig) <andrewl@resin.io> <sqweelygig@gmail.com>
moment = require 'moment'
_ = require 'lodash'

messageTimeByScope = {}

module.exports = (robot) ->
	robot.responseMiddleware (context, next, done) ->
		# Extract and initialise the data we need
		now = moment()
		timeout = parseInt(process.env.HUBOT_PREVENT_REPEAT_TIMEOUT ? '30')
		horizon = moment(now).subtract(timeout, 'minutes')
		response = JSON.stringify(context.strings)
		scopeId = context.response.message.metadata?.thread_id ? context.response.message.room
		messageTimeByScope[scopeId] ?= {}
		scopeConsidered = messageTimeByScope[scopeId]
		# Tidy the old comments
		for comment, timestamp of scopeConsidered when timestamp.isBefore(horizon)
			delete scopeConsidered[comment]
		# Allow the response if it's not in our memory
		if (not scopeConsidered[response]?)
			scopeConsidered[response] = now
			next()
		else
			done()
