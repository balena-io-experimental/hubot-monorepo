request = require 'request'
try
	{ Adapter } = require 'hubot'
catch
	prequire = require 'parent-require'
	{ Adapter } = prequire 'hubot'

class AbstractAPIAdapter extends Adapter
	constructor: ->
		###*
		* poll
		* Triggers a poll of the API
		* Likely to use getUntil
		###
		if not @poll?
			throw new TypeError('Must implement poll')
		super
		@interval = 1000
		@lastReport = null
		@pollInProgress = false

	###*
	* Set the adapter going, and let hubot know when this is done
	###
	run: ->
		setInterval(@maybePoll, @interval)
		@emit 'connected'

	###*
	* Trigger a poll if there isn't one in progress
	###
	maybePoll: =>
		unless @pollInProgress
			@pollInProgress = true
			@poll().finally(@finishPoll)

	###*
	* Mark a poll as complete and report status updates to the logger
	###
	finishPoll: (report) ->
		@pollInProgress = false
		report = JSON.stringify(report)
		if @lastReport isnt report
			@lastReport = report
			@robot.logger.debug report

	###*
	* Execute a series of paged requests until we run out of pages or a filter rejects
	* @param {object} options - parameters suitable for a request (https://www.npmjs.com/package/request)
	* @param {function} each - function to run on each item in the array
	* @param {function} extractResults - optional, function to get the results array from a parsed response. Defaults to transparent.
	* @param {function} extractNext - optional, function to extract next page url. Defaults to no next page.
	* @param {function} filter - optional, function to decide if an object should be processed. Defaults to everything.
	###
	getUntil: (
		options, each
		extractResults = (obj) -> obj,
		extractNext = -> false
		filter = -> true
	) ->
		new Promise (resolve, reject) =>
			request.get(options, (error, response, body) =>
				if error or response?.statusCode isnt 200
					# Retry if the error code indicates temporary outage
					if response?.statusCode in [429, 503]
						@getUntil(options, each, filter).then(resolve).catch(reject)
					# Terminate the poll request
					else
						reject(error ? new Error("StatusCode: #{response.statusCode}, Body: #{body}"))
				else
					# Calculate and loop round the returned objects
					responseObject = JSON.parse(body)
					results = extractResults(responseObject)
					for result in results
						# Filter each result, and execute the each function against it
						if filter(result)
							each(result)
						else
							# Terminate the poll request
							resolve('Reached filtered object')
							return
					# Find the next page, if available, and recurse
					if extractNext(responseObject)
						options.url = @extractNext(responseObject)
						@getUntil(options, each, filter).then(resolve).catch(reject)
					else
						# Terminate the poll request
						resolve('Reached end of pagination')
			)

class AbstractAPIWriter extends AbstractAPIAdapter
	constructor: ->
		###*
		* parseResponse
		* Given the parsed body from the Rest API, extract new ids object.
		* You can assume, by this stage, that the HTTP request returned error is falsey and statusCode is 200.
		* @param {object} Objectified body from the HTTP request
		* @return {object} New ids
		###
		if not @parseResponse?
			throw new TypeError('Must implement parseResponse')
		###*
		* buildRequest
		* Given suitable details will return request details
		* @param {string} key of the identity to use
		* @param {string} id of the flow to update
		* @param {string} text to post
		* @param {string}? id of the thread to update
		* @return {object} {url, headers, payload}
		###
		if not @buildRequest?
			throw new TypeError('Must implement buildRequest')
		super

	###*
	* Given a set of ids make best effort to publish the text and pass on the published ids
	* @param {string} text to publish
	* @param {object} ids to use.  ids = {user, flow, thread?}
	###
	postUsing: (text, ids) ->
		new Promise (resolve, reject) =>
			details = @buildRequest(ids.user, ids.flow, text, ids.thread)
			request.post(details, (error, headers, body) ->
				if not error and headers.statusCode is 200
					try
						resolve(@parseResponse(JSON.parse(body)))
					catch error
						reject(error)
				else
					reject(error ? new Error("StatusCode: #{headers.statusCode}, Body: #{body}"))
			)

module.exports =
	createSender: (context) ->
		context.send.bind(context)

	createReplier: (context) ->
		context.reply.bind(context)

	notify: (subject, info, respond) ->
		mailer = require 'nodemailer'
		hubotEmail = encodeURIComponent(process.env.HUBOT_GMAIL_EMAIL)
		hubotPass = encodeURIComponent(process.env.HUBOT_GMAIL_PASSWORD)
		transporter = mailer.createTransport("smtps://#{hubotEmail}:#{hubotPass}@smtp.gmail.com")
		mailData =
			from: '"Hubot" <hubot@resin.io>'
			to: 'process@resin.io'
			subject: subject
			text: 'Debug output follows: ' + JSON.stringify(info)
		transporter.sendMail mailData, (err) ->
			if not err then respond?("Email sent to #{mailData.to}")

	AbstractAPIAdapter: AbstractAPIAdapter

	AbstractAPIWriter: AbstractAPIWriter

