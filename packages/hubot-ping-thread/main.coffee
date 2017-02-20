# Description:
#   A couple of mass-ping functions
#
# Commands:
#   @thread respond with a ping to every contributor in the thread
#   @reping respond with a ping to every ping target in the thread

_ = require 'lodash'

module.exports = (robot) ->
	robot.hear /@(thread|t)\b/i, (context) ->
		if context.robot.adapter.fetchThreadCommenters?
			context.robot.adapter.fetchThreadCommenters context, (list) ->
				list = _.difference(list, ['@thread', '@t', '@reping'])
				reply = list.join ' '
				context.send context.message.text + ' (' + reply + ')'

	robot.hear /@reping\b/i, (context) ->
		if context.robot.adapter.fetchThreadPinged?
			context.robot.adapter.fetchThreadPinged context, (list) ->
				list = _.difference(list, ['@thread', '@t', '@reping'])
				reply = list.join ' '
				context.send context.message.text + ' (' + reply + ')'
