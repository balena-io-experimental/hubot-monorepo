# Description:
#   A hubot script to prevent responses if they repeat a recent response
#
# Author:
#   Andrew Lucas (sqweelygig) <andrewl@resin.io> <sqweelygig@gmail.com>
moment = require 'moment'
_ = require 'lodash'

scopes = {}
timeout = parseInt(process.env.HUBOT_PREVENT_REPEAT_TIMEOUT ? '30')

# Remove old comments up every 10 percent of the way through the timeout
maybeTidy = _.throttle(
	->
		horizon = moment().subtract(timeout, 'minutes')
		for scope, comments of scopes
			for comment, timestamp of comments when timestamp.isBefore horizon
				delete scopes[scope][comment]
	timeout * 6000 # (minutes->milliseconds * 10%)
)

module.exports = (robot) ->
	robot.responseMiddleware (context, next, done) ->
		# Extract and initialise the data we need
		now = moment()
		horizon = moment(now).subtract(timeout, 'minutes')
		comment = JSON.stringify(context.strings)
		scope = context.response.message.metadata?.thread_id ? context.response.message.room
		scopes[scope] ?= {}

		# If the comment isn't in our memory or is old
		if (not scopes[scope][comment]?) or scopes[scope][comment].isBefore(horizon)
			scopes[scope][comment] = now
			next()
		else
			done()

		# Trigger garbage collection
		maybeTidy()
