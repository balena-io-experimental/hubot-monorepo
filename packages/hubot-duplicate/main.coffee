# Description:
#   A hubot script to one-way replicate messages between flows,
#   from the source service to a target service,
#   while persisting the message author and relating threads if possible.
#
# Configuration:
#   HUBOT_DUPLICATE_FROM = string, defines adapter to use as source, eg gitter
#   HUBOT_DUPLICATE_TO = string, defines modded (postUsing function) adapter to use as target, eg flowdock
#   HUBOT_DUPLICATE_ROOMS = JSON encoded array of objects, each containing room ids that should be treated as equivalent,
#     eg [ { "gitter": "...id...", "flowdock": "...id..." }, { ... } ]
#
# Brain:
#   ScriptDuplicateAPIKeys = JSON encoded object of objects, keyed by user id and containing key and optionally a regex,
#     eg { "sqweelygig": { "key": "...key...", "pattern": "...body of regex..." }, "...": { ... } }
#
# Commands:
#   hubot duplicate about - Echoes an expanded about message
#
# Author:
#   Andrew Lucas (sqweelygig) <andrewl@resin.io> <sqweelygig@gmail.com>

utils = require 'hubot-utility'
crypto = require 'crypto'
adapter = require('hubot-' + process.env.HUBOT_DUPLICATE_TO)

class Duplicator
	constructor: (robot) ->
		@to =
			name: process.env.HUBOT_DUPLICATE_TO
			adapter: adapter.use(robot)
		@from = { name: process.env.HUBOT_DUPLICATE_FROM }
		@apiKeys = JSON.parse(robot.brain.get('ScriptDuplicateAPIKeys')) ? {}
		@persists = new Set(Object.keys @apiKeys)
		@robot = robot
		@knownThreads = {}
		@roomMapping = {}
		for pair in JSON.parse(process.env.HUBOT_DUPLICATE_ROOMS) when pair[@from.name]? and pair[@to.name]?
			@roomMapping[pair[@from.name]] = pair[@to.name]
		@setupActions robot

	setupActions: (robot) ->
		# Core function
		robot.hear /.*/i, (context) =>
			@echo context.message.text,
				user: context.message.user.name
				flow: context.message.room
				comment: context.message.id
				thread: context.message.metadata.thread_id
		# My key
		robot.respond /set my key (\S+)/i, (context) => @setAPIKey context.message.user.name, context.match[1], @createResponder(context)
		robot.respond /check my key (\S+)/i, (context) => @checkAPIKey context.message.user.name, context.match[1], @createResponder(context)
		# My regex
		robot.respond /set my pattern (\S+)/i, (context) => @setPattern context.message.user.name, context.match[1], @createResponder(context)
		robot.respond /reveal my pattern/i, (context) => @viewPattern context.message.user.name, @createResponder(context)
		# My details
		robot.respond /save my config(uration)?/i, (context) => @persistUser context.message.user.name, @createResponder(context)
		robot.respond /forget my config(uration)?/i, (context) => @forgetUser context.message.user.name, @createResponder(context)
		# Other's details
		robot.respond /reveal who.*se? config(ured)?/i, (context) => @listUsers @createResponder(context)
		robot.respond /forget @(\S+)'?s? config(uration)?/i, (context) => @forgetUser context.match[1], @createResponder(context)
		# Misc
		robot.respond /duplicator( about| help)?/i, (context) => @viewHelp @createResponder(context)
		robot.respond /reveal your config(uration)?/i, (context) => @viewEnvVars @createResponder(context)

	###*
	* Duplicate this message to the paired room with the paired identity
	* @param {string} text to post
	* @param {Object} { user: [id], flow: [id], comment: [id], thread: [id] }
	###
	echo: (text, from_ids) ->
		to_ids = {
			flow: null
			user: null
			comment: null
			thread: null
		}
		to_ids.thread = @knownThreads[from_ids.thread]
		to_ids.flow = @roomMapping[from_ids.flow]
		for username, { key, pattern } of @apiKeys when from_ids.user.match(new RegExp(pattern ? username))
			to_ids.user = key
		if to_ids.user? and to_ids.flow?
			if @to.adapter.postUsing?
				@to.adapter.postUsing(text, to_ids)
				.then((posted_ids) => @knownThreads[from_ids.thread] = posted_ids.thread)
				.catch((error) -> utils.notify('error from duplicator', error))
			else
				utils.notify('Target has no postUsing function.')

	# Store an api key in volatile memory
	setAPIKey: (username, value, respond) ->
		@getUserConfig(username).key = value
		@updateBrain()
		respond "@#{username} API key updated"

	# Output in thread the whether the key matches, by hash
	checkAPIKey: (username, hash, respond) ->
		if hash is @hash @getUserConfig(username).key
			respond "@#{username} API key matched"
			true
		else
			respond "@#{username} API key differed"
			false

	# Store your account's regex, for non-default setups
	setPattern: (username, value, respond) ->
		@getUserConfig(username).pattern = value
		respond "@#{username} pattern updated"

	# Output in thread your accounts regex
	viewPattern: (username, respond) ->
		respond "@#{username} " + @getUserConfig(username).pattern

	# Duplicate an api key into persistent memory
	persistUser: (username, respond) ->
		@persists.add username
		@updateBrain()
		respond "@#{username} details saved"

	# Output in thread the accounts that have set up keys
	listUsers: (respond) ->
		usernames = Object.keys(@apiKeys).map((val) -> '@' + val)
		respond(JSON.stringify(usernames))

	# Remove a user's details from both volatile and persistent memory
	forgetUser: (username, respond) ->
		delete @apiKeys[username]
		@persists.delete username
		@updateBrain()
		respond "@#{username} details forgotten"

	# Output in thread the environment variables
	viewEnvVars: (respond) ->
		respond(JSON.stringify
			to: @to.name
			from: @from.name
			map: @roomMapping
		)

	# Output in thread some explanatory notes
	viewHelp: (respond) ->
		respond """
			Chat duplicator
			===============
			This script monitors your messages and duplicates then to paired rooms in a different service using your identity.
			A couple of details
			-------------------
			* This bot needs an API key for the target service for each identity it will post as.
			* This bot can be configured for multiple users (for example the public) to share one API key.
			* I'd strongly suggest configuring your API key via 1-1.
			A few promises
			--------------
			* Your API key can only ever be compared to a hash, even by your own account.
			* Your API key will, by default, be stored in volatile memory to lock it to codebase/configuration.
			* The codebase and environment is scrutinisable.
			* You can stop others within your organisition.  Only use to control runaway bots or colleagues.
			* Your personal details may all be entered via PM.
			* This command will return a good documentation string.
			* Access to your details will ping you, even if it's your account that's doing it.
			* All read operations are done via the reveal and check keywords.
				* Reveal shall give full details and never be used for keys.
				* Check shall compare the stored value to a provided hash.
			Caveats
			-------
			* Until https://github.com/resin-io/hubot-as-webot/issues/15 is resolved the PM history is a vulnerability.
			* If your API key is set to persist then the vulnerabilities also include the redis brain and code changes.
			Commands
			--------
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
	createResponder: (context) ->
		context.send.bind(context)

	# Utility function to hash a string
	hash: (string) ->
		crypto.createHash('sha256').update(string).digest('hex') if string?

	# Utility function to return a user's object, creating if required
	getUserConfig: (username) ->
		@apiKeys[username] ?= {}

	# Utility function to store persistent users in the brain
	updateBrain: ->
		store = {}
		for username in @persists
			store[username] = @apiKeys[username]
		@robot.brain.set 'ScriptDuplicateAPIKeys', JSON.stringify(store)

module.exports = (robot) ->
	new Duplicator(robot)
