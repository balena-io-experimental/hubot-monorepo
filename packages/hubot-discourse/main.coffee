try
	{ Adapter, TextMessage } = require 'hubot'
catch
	prequire = require 'parent-require'
	{ Adapter, TextMessage } = prequire 'hubot'

class Discourse extends Adapter
	# This function doesn't /need/ to be extended
	constructor: ->
		super
		@pingCount = 0

	# This function must be implemented.
	# This puts a un-targeted message to the endpoint.
	send: (envelope, strings...) ->
		@robot.logger.info 'Send'

	# This function must be implemented.
	# This puts a targeted message to the endpoint.
	# Often just a trivial tweak then call send
	reply: (envelope, strings...) ->
		@robot.logger.info 'Reply'

	# This function must be implemented.
	# This must set up monitoring of the endpoint.
	# This must then emit connected.
	run: ->
		setInterval @ping, 1000
		@emit 'connected'

	# This function is a jumping-off point and must be reworked
	# This just mimics a received message once a second
	ping: =>
		user = @robot.brain.userForId 1122, name: 'Ping User'
		message = new TextMessage user, 'ping ' + @pingCount, 'MSG-' + @pingCount
		@pingCount++
		@receive message

exports.use = (robot) ->
	new Discourse robot
