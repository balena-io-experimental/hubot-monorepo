# Description:
#   A hubot script to repeat all output to gitter
#
# Author:
#   Andrew Lucas (sqweelygig) <andrewl@resin.io> <sqweelygig@gmail.com>
#noinspection JSUnresolvedVariable
module.exports = (robot) ->

	# Keep track of which room to post to
	room_id = null

	# A generic set of headers
	headers = {
		'Content-Type': 'application/json'
		'Accept': 'application/json'
		'Authorization': 'Bearer ' + process.env.HUBOT_GITTER_API_TOKEN
	}

	# Put the text specified to the room
	post_text = (text) ->
		if room_id?
			# Build and fire an untracked post
			(require 'request').post {
				url: 'https://api.gitter.im/v1/rooms/' + room_id + '/chatMessages'
				headers: headers
				body: JSON.stringify { 'text': text }
			}

	# Listen to all traffic that get's this far
	robot.hear /(.*)/i, (responder) ->
		if room_id?
			# Post straight away if we've a room id
			post_text responder.message.text
		else
			# Gather the room id
			(require 'request').post {
				url: 'https://api.gitter.im/v1/rooms'
				headers: headers
				# match on provided room name
				body: JSON.stringify { 'uri': process.env.HUBOT_GITTER_ROOM }
			},
			# then store id & post the message
			(error, response, body) ->
				room_id = (JSON.parse body).id
				post_text responder.message.text

