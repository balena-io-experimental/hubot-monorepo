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

module.exports = AbstractAPIAdapter
