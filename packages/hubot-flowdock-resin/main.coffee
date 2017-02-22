Promise = require 'bluebird'
flowdock = Promise.promisifyAll(require 'flowdock')
try
	{ Adapter, TextMessage } = require 'hubot'
catch
	prequire = require 'parent-require'
	{ Adapter, TextMessage } = prequire 'hubot'

class Flowdock extends Adapter

	constructor: ->
		super
		@ignores = []
		# Make sure hubot does not see commands posted using only a flow token (eg. no authenticated user)
		if process.env.HUBOT_FLOWDOCK_ALLOW_ANONYMOUS_COMMANDS != '1'
			@ignores.push('0')
		# Make it possible to ignore users
		if process.env.HUBOT_FLOWDOCK_IGNORED_USERS?
			@ignores.push(id) for id in process.env.HUBOT_FLOWDOCK_IGNORED_USERS.split(',')
		@robot.logger.info "Ignoring all messages from user ids #{@ignores.join(', ')}" if @ignores.length > 0

	send: (envelope, strings...) ->
		return if strings.length == 0
		str = strings.shift()
		if str.length > 8096
			str = '** End of Message Truncated **\n' + str
			str = str[0...8096]
		metadata = envelope.metadata || envelope.message?.metadata || {}
		flow = metadata.room || envelope.room
		thread_id = metadata.thread_id
		message_id = metadata.message_id
		user = envelope.user
		forceNewMessage = envelope.newMessage == true
		sendRest = =>
			@send(envelope, strings...)
		if user?
			if flow?
				if thread_id and not forceNewMessage
					# respond to a thread
					@bot.threadMessage flow, thread_id, str, [], sendRest
				else if message_id and not forceNewMessage
					# respond via comment if we have a parent message
					@bot.comment flow, message_id, str, [], sendRest
				else
					@bot.message flow, str, [], sendRest
			else if user.id
				# If replying as private message, strip the preceding user tag
				str = str.replace(new RegExp("^@#{user.name}: ", 'i'), '')
				@bot.privateMessage user.id, str, [], sendRest
		else if flow
			# support wider range of flow identifiers than just id for robot.messageRoom
			flow = @findFlow(flow)
			@bot.message flow, str, [], sendRest

	reply: (envelope, strings...) ->
		user = @userFromParams(envelope)
		@send envelope, strings.map((str) -> "@#{user.name}: #{str}")...

	userFromParams: (params) ->
		# hubot < 2.4.2: params = user
		# hubot >= 2.4.2: params = {user: user, ...}
		if params.user then params.user else params

	findFlow: (identifier) ->
		return flow.id for flow in @flows when identifier == flow.id
		return flow.id for flow in @flows when identifier == @flowPath(flow)
		return flow.id for flow in @flows when identifier.toLowerCase() == flow.name.toLowerCase()
		identifier

	flowPath: (flow) ->
		flow.organization.parameterized_name + '/' + flow.parameterized_name

	joinedFlows: ->
		@flows.filter (f) -> f.joined && f.open

	userFromId: (id, data) ->
		# hubot < 2.5.0: @userForId
		# hubot >=2.5.0: @robot.brain.userForId
		@robot.brain?.userForId?(id, data) || @userForId(id, data)

	changeUserNick: (id, newNick) ->
		if id of @robot.brain.data.users
			@robot.brain.data.users[id].name = newNick

	needsReconnect: (message) ->
		(@myId(message.content) && message.event == 'backend.user.block') ||
			(@myId(message.user) && message.event in ['backend.user.join', 'flow-add', 'flow-remove'])

	myId: (id) ->
		String(id) == String(@bot.userId)

	reconnect: (reason) ->
		@robot.logger.info("Reconnecting: #{reason}")
		@stream.end()
		@stream.removeAllListeners()
		@fetchFlowsAndConnect()

	connect: ->
		ids = (flow.id for flow in @joinedFlows())
		@robot.logger.info('Flowdock: connecting')
		@stream = @bot.stream(ids, active: 'idle', user: 1)
		@stream.on 'connected', =>
			@robot.logger.info('Flowdock: connected and streaming')
			@robot.logger.info('Flowdock: listening to flows:', (flow.name for flow in @joinedFlows()).join(', '))
		@stream.on 'clientError', (error) => @robot.logger.error('Flowdock: client error:', error)
		@stream.on 'disconnected', => @robot.logger.info('Flowdock: disconnected')
		@stream.on 'reconnecting', => @robot.logger.info('Flowdock: reconnecting')
		@stream.on 'message', (message) =>
			return if !message.content? || !message.event? || !message.id?
			if message.event == 'user-edit' || message.event == 'backend.user.join'
				@changeUserNick(message.content.user.id, message.content.user.nick)
			if @needsReconnect(message)
				@reconnect('Reloading flow list')
			return unless message.event in ['message', 'comment']
			return if @myId(message.user) and process.env.HUBOT_FLOWDOCK_LISTEN_TO_SELF != '1'
			return if String(message.user) in @ignores

			@robot.logger.debug 'Received message', message

			author = @userFromId(message.user)

			thread_id = message.thread_id
			messageId = if thread_id?
				undefined
			else if message.event == 'message'
				message.id
			else
				# For comments the parent message id is embedded in an 'influx' tag
				if message.tags
					influxTag = do ->
						for tag in message.tags
							return tag if /^influx:/.test tag
					(influxTag.split ':', 2)[1] if influxTag

			msg = if message.event == 'comment' then message.content.text else message.content

			# Reformat leading @mention name to be like "name: message" which is
			# what hubot expects. Add bot name with private messages if not already given.
			botPrefix = "#{@robot.name}: "
			regex = new RegExp("^@#{@bot.userName}(,|\\b)", 'i')
			hubotMsg = msg.replace(regex, botPrefix)
			if !message.flow && !hubotMsg.match(new RegExp("^#{@robot.name}", 'i'))
				hubotMsg = botPrefix + hubotMsg

			author.room = message.flow # Many scripts expect author.room to be available
			author.flow = message.flow # For backward compatibility

			metadata =
				room: message.flow
			metadata['thread_id'] = thread_id if thread_id?
			metadata['message_id'] = messageId if messageId?

			messageObj = new TextMessage(author, hubotMsg, message.id, metadata)
			# Support metadata even if hubot does not currently do that
			messageObj.metadata = metadata if !messageObj.metadata?

			@receive messageObj

	run: ->
		@apiToken      = process.env.HUBOT_FLOWDOCK_API_TOKEN
		@loginEmail    = process.env.HUBOT_FLOWDOCK_LOGIN_EMAIL
		@loginPassword = process.env.HUBOT_FLOWDOCK_LOGIN_PASSWORD
		if @apiToken?
			@bot = new flowdock.Session(@apiToken)
		else if @loginEmail? && @loginPassword?
			@bot = new flowdock.Session(@loginEmail, @loginPassword)
		else
			throw new Error('ERROR: No credentials given: Supply either environment variable HUBOT_FLOWDOCK_API_TOKEN or both HUBOT_FLOWDOCK_LOGIN_EMAIL and HUBOT_FLOWDOCK_LOGIN_PASSWORD')

		@bot.on 'error', (e) =>
			@robot.logger.error("Unexpected error in Flowdock client: #{e}")
			@emit e

		@fetchFlowsAndConnect()

		@emit 'connected'

	fetchFlowsAndConnect: ->
		@bot.flows (err, flows, res) =>
			return if err?
			@bot.userId = res.headers['flowdock-user']
			@flows = flows
			@robot.logger.info("Found #{@flows.length} flows, and I have joined #{@joinedFlows().length} of them.")
			for flow in flows
				for user in flow.users
					if user.in_flow
						data =
							id: user.id
							name: user.nick
							email: user.email
						savedUser = @userFromId user.id, data
						if savedUser.name != data.name
							@changeUserNick(savedUser.id, data.name)
						if String(user.id) == String(@bot.userId)
							@bot.userName = user.nick
			@robot.logger.info("Connecting to Flowdock as user #{@bot.userName} (id #{@bot.userId}).")
			if @flows.length == 0 || !@flows.some((flow) -> flow.open)
				@robot.logger.warning(
					"Your bot is not part of any flows and probably won't do much. " +
						'Join some flows manually or add the bot to some flows and reconnect.')
			if @bot.userName? && @robot.name.toLowerCase() != @bot.userName.toLowerCase()
				@robot.logger.warning(
					"You have configured this bot to use the wrong name (#{@robot.name}). Flowdock API says " +
						"my name is #{@bot.userName}. You will run into problems if you don't fix this!")

			@connect()

	# Pass to the callback function everyone who has been pinged in a conversation
	fetchThreadPinged: (envelope, callback) ->
		@fetchThreadMessages envelope, (comments) ->
			# Create a set of everything that appears after an @
			people = new Set()
			for comment in comments
				for person in comment.content.match(/@(\w*)/gi) ? []
					people.add person
			# Put the set of people to the callback
			callback Array.from(people)

	# Pass to the callback function everyone who has contributed to a conversation
	fetchThreadCommenters: (envelope, callback) ->
		@fetchThreadMessages envelope, (comments) =>
			# Create a set of everyone who appears as an author
			people = new Set()
			for comment in comments
				people.add comment.user
			# Put the set of people to the callback
			callback Array.from(people).map((value) => '@' + @userFromId(value).name)

	# Pass to the callback function every message in a thread
	fetchThreadMessages: (envelope, callback) ->
		# Fetch the flow parameterised_name from id
		@bot.get '/flows/find', { id: envelope.message.room }, (err, obj, res) =>
			endpoint = obj.url.split('/').splice(3)
			# Fetch all the messages in the thread
			endpoint.push 'threads'
			endpoint.push envelope.message.metadata.thread_id
			endpoint.push 'messages'
			@bot.get '/' + endpoint.join('/'), {}, (err, obj, res) ->
				callback obj

	sessions = {}

	# Post a message with an externally generated context
	postUsing: (text, { user, flow, thread } ) ->
		if not sessions[user]?
			sessions[user] = new flowdock.Session(user)
			sessions[user].on('error', -> console.log('Error occurred in the flowdock session.'))
		promise =
			if thread?
				sessions[user].threadMessageAsync(flow, thread, text, [])
			else
				sessions[user].messageAsync(flow, text, [])
		promise.then (response) ->
			flow: response?.flow
			user: response?.user
			thread: response?.thread_id
			comment: response?.id

exports.use = (robot) ->
	new Flowdock robot
