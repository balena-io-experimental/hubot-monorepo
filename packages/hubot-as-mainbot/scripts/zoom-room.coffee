# Description:
#   Opens an available room for meeting in zoom app
#
# Configuration:
#   HUBOT_STAFFSQUARED_EMAIL
#   HUBOT_STAFFSQUARED_PASSWORD
#   HUBOT_ZOOM_API_KEY
#   HUBOT_ZOOM_API_SECRET
#   HUBOT_GMAIL_EMAIL
#   HUBOT_GMAIL_PASSWORD
#   HUBOT_MEETING_BOOKABLE
#
# Commands:
#   get a room - responds with the least recently used available room
#   hubot meeting - responds with the url of the weekly meeting
#   hubot reload (rooms/all) - reloads the list of meeting ids
#   book a room - responds with the way to manage room pre-booking
#
# Author:
#   sqweelygig, okakosolikos
utils = require 'hubot-utility'
_ = require 'lodash'

class NoRoomsError extends Error
	constructor: (payload) ->
		super('Sorry, no rooms available')
		@payload = payload

class MeetingPoolManager
	zoomKey = process.env.HUBOT_ZOOM_API_KEY
	zoomSecret = process.env.HUBOT_ZOOM_API_SECRET
	zoomUrl = 'https://api.zoom.us/v1/meeting/live'
	firebaseUrl = process.env.HUBOT_FIREBASE_URL
	firebaseAuth = process.env.HUBOT_FIREBASE_SECRET

	constructor: (robot) ->
		@robot = robot
		@meetingPoolIds = []
		@refreshMeetingPool()

	refreshMeetingPool: ->
		console.log('Loading meeting ids')
		@requestMeetingPool()
		.then (result) =>
			console.log('Reloaded meeting ids')
			@meetingPoolIds = result
		.catch (error) ->
			console.log('VVV Problem loading meeting ids VVV')
			console.log(error)
			console.log('^^^ Problem loading meeting ids ^^^')
			throw error

	requestMeetingPool: -> new Promise (resolve, reject) =>
		@robot.http("#{firebaseUrl}/data/zoomIds.json?auth=#{firebaseAuth}")
			.get() (err, res, body) ->
				if (not err?) and (res.statusCode is 200)
					resolve(JSON.parse(body))
				else
					reject(err ? new Error("StatusCode: #{res.statusCode}"))

	advertise: (meetingId, respond) ->
		# Move the advertised meeting to the end of the queue
		indexUsed = @meetingPoolIds.indexOf(meetingId)
		if indexUsed >= 0 then @meetingPoolIds.splice(indexUsed, 1)
		@meetingPoolIds.push(meetingId)

		respond "https://zoom.us/j/#{meetingId}"

	requestLiveMeetings: -> new Promise (resolve, reject) =>
		@robot.http("#{zoomUrl}?api_key=#{zoomKey}&api_secret=#{zoomSecret}")
			.post() (err, res, body) ->
				if not err? and res.statusCode is 200
					liveMeetingsIds = (liveMeeting.id for liveMeeting in JSON.parse(body).meetings)
					resolve(liveMeetingsIds)
				else
					reject(err ? new Error("StatusCode: #{res.statusCode}"))

	getAvailableRoom: (pool, live) ->
		available = _.difference(pool, live)
		if available.length is 0
			throw new NoRoomsError
				roomPool: pool
				roomsUsed: live
				roomsFree: available
		else
			return available[0]

	advertiseAvailableRoom: (pool, live, respond) ->
		room = @getAvailableRoom(pool, live)
		@advertise(room, respond)

	notify: (error, respond) ->
		respond(error.message)
		utils.notify(error.message, error, respond)

	findRoom: (respond, attempts = 0) ->
		messages = [
			'Finding a meeting room'
			'Probably no meeting rooms available, trying again'
			'Giving it another shot' # https://github.com/resin-io/hubot-as-mainbot/pull/107#pullrequestreview-21066615
			'Going to try once more for you'
		]
		respond(messages[attempts])
		@requestLiveMeetings()
		.then (liveMeetings) =>
			@advertiseAvailableRoom(@meetingPoolIds, liveMeetings, respond)
		.catch (error) =>
			attempts++
			if attempts >= messages.length
				@notify(error, respond)
			else if error.payload?.roomsFree is 0
				@refreshMeetingPool()
				.then(@findRoom(respond, attempts))
			else
				@notify(error, respond)
				@findRoom(respond, attempts)

module.exports = (robot) ->
	model = new MeetingPoolManager(robot)

	robot.respond /meeting/i, (context) ->
		context.send 'https://zoom.us/j/9676151801'

	robot.respond /reload (rooms|all)/i, (context) ->
		model.refreshMeetingPool()
			.then(-> context.send('Loaded meeting ids'))
			.catch(-> context.send('Problem loading meeting ids'))

	robot.hear /book a room/i, (context) ->
		for key, value of JSON.parse(process.env.HUBOT_MEETING_BOOKABLE)
			context.send "#{key} managed by #{value}"

	robot.hear /get a room/i, (context) ->
		model.findRoom(utils.createSender(context))
