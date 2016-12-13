# Description:
#   A filter to enable in-app configuration of room monitoring
#
# Commands:
#   monitor off - stop monitoring this room
#   monitor me - monitor the wrangler's input to this room
#   monitor all - monitor everyone's input to this room
#
# Notes:
#   This is deliberately not implemented as a receiveMiddleware & listener pairing.
#   That would give people a route to listeners by including monitor in their message.
#
# Author:
# Andrew Lucas (sqweelygig) <andrewl@resin.io> <sqweelygig@gmail.com>

module.exports = (robot) ->

	rooms = {}

	robot.receiveMiddleware (context, next, done) ->
		roomSet = (text, room) ->
			# The monitor may be set to follow just the bot-wrangler
			if text.match /\b(me|on)\b/
				rooms[room] = 'me'
			# The monitor may be set to follow everyone
			else if text.match /\b(all)\b/
				rooms[room] = 'all'
			# The monitor may be set to off
			else if text.match /\b(off)\b/
				delete rooms[room]

		roomFilter = (context, next, done) ->
			# If we've instructions to monitor this room
			if Object.keys(rooms).includes context.response.message.room
				# If the monitor is set to me and the post is from me, then continue
				if rooms[context.response.message.room] is 'me' \
				   and context.response.message.user.name is context.response.robot.name
					next()
				# If the monitor is set to everyone then continue
				else if rooms[context.response.message.room] is 'all'
					next()
				# If the conditions don't match a situation in which we should continue
				else
					done()
			# If we've no instructions to monitor this room
			else
				done()

		# The bot-wrangler may change the monitor settings of the robot
		message_text = context.response.message.text or context.response.message.message.text
		if context.response.message.user.name is context.response.robot.name \
		   and message_text.match /^(monitor)\b/
			roomSet(message_text, context.response.message.room)
			done()
		# If we're not changing monitor settings, then we're filtering based on them
		else
			roomFilter(context, next, done)
