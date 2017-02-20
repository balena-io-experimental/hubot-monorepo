# Description:
#   Useful commands for Resin team
#
# Commands:
#   hubot commands - Useful commands for Resin team
#
# Author:
#   okakosolikos

commands = [
	'Hubot help - Displays all of the help commands that Hubot knows about.',
	'Hubot status? - Display an overall status of all StatusPage components',
	'Hubot meeting - Shows the standard Zoom weekly meeting URL',
	"get a room - Hubot hears when someone says 'get a room' and responds with the first available Zoom room URL",
	'Hubot remind me (on <date>|in <time>) to <action> - Set a reminder in <time> to do an <action>; <time> is in the ' +
		'format 1 day, 2 hours, 5 minutes etc.',
	"Hubot open office - Opens the lock of London's office",
	"Hubot who's off today - Responds with the names of the people that are on leave and the date of their return",
	"Hubot who's off over the coming <number> days - Responds with the names of the people that are on leave over the coming x days",
	'hubot deadline (in <number> days)||(on yyyy-mm-dd) for <event> - Creates / Updates a deadline that will post everyday to that specific flow',
	'#<inbox> <subject> sends an email to the specified inbox, with a link back to the thread',
]

module.exports = (robot) ->
	robot.respond /commands/i, (msg) ->
		msg.send commands.join('\n')
