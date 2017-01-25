# Description:
#   A hubot script to duplicate messages between services
#
# Configuration:
#   HUBOT_DUPLICATE_TO
#   HUBOT_DUPLICATE_FROM
#   HUBOT_DUPLICATE_ROOMS
#
# Commands:
#   hubot duplicate about - Echoes an expanded about message
#
# Author:
#   Andrew Lucas (sqweelygig) <andrewl@resin.io> <sqweelygig@gmail.com>
class Duplicator
	constructor: (robot) ->
		@to = { name: process.env.HUBOT_DUPLICATE_TO }
		@to.adapter = require('hubot-' + @to.name).use(robot)
		@from = { name: process.env.HUBOT_DUPLICATE_FROM }
		@pairs = JSON.parse process.env.HUBOT_DUPLICATE_ROOMS
		@apiKeys = JSON.parse robot.brain.get('ScriptDuplicateAPIKeys')
		@apiKeys ?= {}
		@persists = new Set(Object.keys @apiKeys)
		@robot = robot
		@knownThreads = {}
		@setupActions robot

	setupActions: (robot) ->
		# Core function
		robot.hear /.*/i, (context) =>
			@echo(
				context.message.text
				{
					user: context.message.user.name
					flow: context.message.room
					comment: context.message.id
					thread: context.message.metadata.thread_id
				}
			)
		# My key
		robot.respond /set my key (\w+)/i, (context) => @setAPIKey context.message.user.name, context.match[1], @respond(context)
		robot.respond /check my key (\w+)/i, (context) => @checkAPIKey context.message.user.name, context.match[1], @respond(context)
		# My regex
		robot.respond /set my pattern (\w+)/i, (context) => @setPattern context.message.user.name, context.match[1], @respond(context)
		robot.respond /reveal my pattern/i, (context) => @viewPattern context.message.user.name, @respond(context)
		# My details
		robot.respond /save my config(uration)?/i, (context) => @persistUser context.message.user.name, @respond(context)
		robot.respond /forget my config(uration)?/i, (context) => @forgetUser context.message.user.name, @respond(context)
		# Other's details
		robot.respond /reveal who.*s.? config(ured)?/i, (context) => @listUsers @respond(context)
		robot.respond /forget @(\w+)'?s? config(uration)?/i, (context) => @forgetUser context.match[1], @respond(context)
		# Misc
		robot.respond /duplicator( about| help)?/i, (context) => @viewHelp @respond(context)
		robot.respond /reveal your config(uration)?/i, (context) => @viewEnvVars @respond(context)

	# text, { user: [id], flow: [id], comment: [id], thread: [id] }
	# Duplicate this message to the paired room with the paired identity
	echo: (text, from_ids) ->
		to_ids = {
			flow: null
			user: null
			comment: null
			thread: null
		}
		to_ids.thread = @knownThreads[from_ids.thread]
		for pair in @pairs when pair[@from.name] is from_ids.flow
			to_ids.flow = pair[@to.name]
		for username, object of @apiKeys when from_ids.user.match new RegExp(object.pattern ? username)
			to_ids.user = object.key
		if to_ids.user? and to_ids.flow?
			@to.adapter.postUsing?(
				text
				to_ids
				(error, posted_ids) => if not error then @knownThreads[from_ids.thread] = posted_ids.thread
			)

	# Store an api key in volatile memory
	setAPIKey: (username, value, respond) ->
		@getObject(username).key = value
		@updateBrain()
		respond "@#{username} API key updated"

	# Output in thread the whether the key matches, by hash
	checkAPIKey: (username, hash, respond) ->
		if hash is @hash @getObject(username).key
			respond "@#{username} API key matched"
			true
		else
			respond "@#{username} API key differed"
			false

	# Store your account's regex, for non-default setups
	setPattern: (username, value, respond) ->
		@getObject(username).pattern = value
		respond "@#{username} pattern updated"

	# Output in thread your accounts regex
	viewPattern: (username, respond) ->
		respond "@#{username} " + @getObject(username).pattern

	# Duplicate an api key into persistent memory
	persistUser: (username, respond) ->
		@persists.add username
		@updateBrain()
		respond "@#{username} details saved"

	# Output in thread the accounts that have set up keys
	listUsers: (respond) ->
		respond JSON.stringify Object.keys(@apiKeys).map((val) -> '@' + val)

	# Remove a user's details from both volatile and persistent memory
	forgetUser: (username, respond) ->
		delete @apiKeys[username]
		@persists.delete username
		@updateBrain()
		respond "@#{username} details forgotten"

	# Output in thread the environment variables
	viewEnvVars: (respond) ->
		output = {}
		for own key of process.env
			if key.match /(key|token|password)/i
				output["sha1(#{key})"] = @hash process.env[key]
			else
				output[key] = process.env[key]
		respond JSON.stringify output

	# Output in thread some explanatory notes
	viewHelp: (respond) ->
		respond """
			# Chat duplicator
				This script monitors your messages and duplicates then to paired rooms in a different service using your identity.
				## A few promises
					* Your API key can only ever be compared to a hash, even by your own account.
					* Your API key will, by default, be stored in volatile memory to lock it to codebase/configuration.
					* The codebase and environment is fully scrutinisable.
					* You can stop others within your organisition.  Only use to control runaway bots or colleagues.
					* Your personal details may all be entered via PM.
					* This command will return a good documentation string.
					* Access to your details will ping you, even if it's your account that's doing it.
					* All read operations are done via the reveal and check keywords.
						* Reveal shall give full details and never be used for keys.
						* Check shall compare the stored value to a provided hash.
				## Caveats
					* Until https://github.com/resin-io/hubot-as-webot/issues/15 is resolved the PM history is a vulnerability.
					* If your API key is set to persist then the vulnerabilities also include the redis brain and code changes.
				## Commands
					* #{@robot.name} set my key [string]- store the key value
					* #{@robot.name} check my key [string] - output whether the hash matches the hash of your key
					* #{@robot.name} set my pattern [string]- configure a pattern which the username must match.
						* This is optional, but useful for occasions where one key may sync several accounts (eg the public)
					* #{@robot.name} reveal my pattern - output the pattern associated with this account
					* #{@robot.name} save my config - put your key value into persistent memory
					* #{@robot.name} forget my config - remove your configuration from all memories
					* #{@robot.name} reveal who's config - list the accounts with configured keys.
					* #{@robot.name} forget @[string]'s config - remove the specified configuration from all memories.
					* #{@robot.name} reveal your configuration - output the environment variables for this instance
					* #{@robot.name} duplicator about - show this message
		"""

	# Utility function to create an output method that takes a simple string
	respond: (context) ->
		context.send.bind(context)

	# Utility function to hash a string
	hash: (string) ->
		if string?
			require('crypto').createHash('sha1').update(string).digest('hex')

	# Utility function to return a user's object, creating if required
	getObject: (username) ->
		@apiKeys[username] ?= {}

	# Utility function to store persistent users in the brain
	updateBrain: ->
		store = {}
		for username in @persists
			store[username] = @apiKeys[username]
		@robot.brain.set 'ScriptDuplicateAPIKeys', JSON.stringify(store)

module.exports = (robot) ->
	new Duplicator(robot)
