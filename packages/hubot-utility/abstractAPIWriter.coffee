request = require 'request'
try
	AbstractAPIAdapter = require('./abstractAPIAdapter.coffee')
catch
	prequire = require 'parent-require'
	AbstractAPIAdapter = prequire('./abstractAPIAdapter.coffee')

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
			request.post(details, (error, headers, body) =>
				if not error and headers.statusCode >= 200 and headers.statusCode < 300
					try
						console.log(body)
						resolve(@parseResponse(JSON.parse(body)))
					catch error
						reject(error)
				else
					reject(error ? new Error("StatusCode: #{headers.statusCode}, Body: #{body}"))
			)

module.exports = AbstractAPIWriter
