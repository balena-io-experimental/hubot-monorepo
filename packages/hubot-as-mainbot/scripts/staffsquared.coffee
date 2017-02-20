# Description:
#   Interacts with the Staffsquared API
#
# Configuration:
#   HUBOT_STAFFSQUARED_EMAIL
#   HUBOT_STAFFSQUARED_PASSWORD
#   HUBOT_FIREBASE_URL
#   HUBOT_FIREBASE_SECRET
#
# Commands:
#   hubot who's off today - Responds with the names of the people that are on leave and the date of their return
#   hubot who's off over the coming <number> days | hubot leave <number> - Responds with the names of the people that are on leave over the coming x days
#
# Author:
#   sqweelygig, okakosolikos

email = process.env.HUBOT_STAFFSQUARED_EMAIL
password = process.env.HUBOT_STAFFSQUARED_PASSWORD
expiryHours = process.env.HUBOT_STAFFSQUARED_EXPIRY ? 2

firebaseUrl = process.env.HUBOT_FIREBASE_URL
firebaseAuth = process.env.HUBOT_FIREBASE_SECRET

dataForToken = "grant_type=password&username=#{email}&password=#{password}"

moment = require('moment')
require('moment-range').extendMoment(moment)
memoize = require('memoizee')
_ = require('lodash')
dateFormat = 'ddd Do MMM'

module.exports = (robot) ->
	# Get the results from a url, with basic cache layer
	cachedRequest = do ->
		_request = (url, headers, method, payload, callback) ->
			request = robot.http(url)
			request.header('Content-Type', 'application/json')
			request.header('accept', 'application/json')
			if headers?
				for own key, value of headers
					request.header(key, value)
			# Syntax taken from https://github.com/github/hubot/blob/master/docs/scripting.md#making-http-calls
			request[method](payload) (err, res, body) ->
				if res.statusCode is 200 and not err
					callback(null, JSON.parse(body))
				else
					callback(err, res)
		return memoize(_request, { async: true, maxAge: expiryHours * 1000 * 60 * 60 })

	# Get a basic object representing the employee from either id or handle
	getEmployeeObject = (key, value, callback) ->
		# Request and loop all users
		employeesUrl = "#{firebaseUrl}/users.json?auth=#{firebaseAuth}"
		cachedRequest employeesUrl, null, 'get', null, (err, employees) ->
			if not err
				testPropertyByKey = _.matches(
					switch key
						when 'name' then { flowdock: { nick: value } }
						when 'id' then { staffsquared: { Id: value } }
				)
				for user in employees when testPropertyByKey(user)
					mentionedUser =
						staffId: user.staffsquared?.Id
						flowdockNick: user.flowdock.nick
					callback(null, mentionedUser)
					return
			callback(err)

	# Enrich and post a reply to the context
	replyWithNickname = (context, staffId, text) ->
		getEmployeeObject 'id', staffId, (err, employee) ->
			if not err
				context.reply "#{employee.flowdockNick} #{text}"

	# Report the vacations according to optional filters
	reportVacations = (context, staffId, lookAhead) ->
		# Request a token
		tokenUrl = 'https://api.staffsquared.com/api/Token'
		cachedRequest tokenUrl, null, 'post', dataForToken, (err, token) ->
			if not err then requestVacations(context, staffId, lookAhead, token.access_token)

	# Request the vacations from the API
	requestVacations = (context, staffId, lookAhead, accessToken) ->
		# Tweaked the endpoint according to lookAhead
		absenceUrl =
			'https://api.staffsquared.com/api/Absence/' +
			(if lookAhead? then 'Future' else 'Today')
		absenceHeaders = Authorization: 'Bearer ' + accessToken
		cachedRequest absenceUrl, absenceHeaders, 'get', null, (err, vacations) ->
			if not err then filterVacationsByStaff(context, staffId, lookAhead, vacations)

	filterVacationsByStaff = (context, staffId, lookAhead, vacations) ->
		for vacation in vacations
			if (not staffId?) or (vacation.EmployeeId is staffId)
				if lookAhead
					postVacationsInRange(context, vacation, lookAhead)
				else
					postVacationsToday(context, vacation)

	postVacationsToday = (context, vacation) ->
		today = moment().format(dateFormat)
		lastDayOff = moment(vacation.EventEnd).format(dateFormat)
		texts = ['is out today']
		if today isnt lastDayOff then texts.push("through #{lastDayOff}")
		replyWithNickname(context, vacation.EmployeeId, texts.join(' '))

	postVacationsInRange = (context, vacation, lookAhead) ->
		now = moment()
		firstDayOff = moment(vacation.EventStart).format(dateFormat)
		texts = ['is out']
		perspective = moment.range(now, moment(now).add(lookAhead, 'days'))
		vacationRange = moment.range(moment(vacation.EventStart), moment(vacation.EventEnd))
		if perspective.overlaps(vacationRange)
			# Output details of the vacation
			if vacation.EventDuration is 1
				texts.push("on #{firstDayOff}")
			else
				lastDayOff = moment(vacation.EventEnd).format(dateFormat)
				texts.push("from #{firstDayOff}")
				texts.push("through #{lastDayOff}")
			replyWithNickname(context, vacation.EmployeeId, texts.join(' '))

	# who.*se? to catch whos, who is, who's and whose
	# \w+ to catch off, out, vacationing, etc
	# \?? to make a final question mark optional
	# eg who's off today?
	robot.respond /who.*se? \w+ today\??/i, (context) ->
		# context, everyone, today
		reportVacations(context)

	# who.*se? to catch whos, who is, who's and whose
	# \w+ to catch off, out, vacationing, etc
	# \w+ to catch next, coming, upcoming, etc
	# (blah|leave) to make leave a more command, less natural, option
	# \d+ to catch a whole number
	# ( days?)? to catch day, days or nothing
	# \?? to make a final question mark optional
	# eg who's off over the next 6 days?
	# eg leave 6
	onLeaveSoon = /(who.*se? \w+ over the \w+|leave) (\d+)( days?)?\??/i
	robot.respond onLeaveSoon, (context) ->
		# context, everyone, today
		reportVacations(context)
		# context, everyone, lookAhead
		reportVacations(context, null, context.match[2])

	robot.hear /@[\w\-]+/gi, (context) ->
		cleanedNames = context.match.map (item) -> item[1...]
		for name in cleanedNames
			getEmployeeObject 'name', name, (err, employee) ->
				if (not err) and employee? and employee.staffId?
					# context, specific, today
					reportVacations(context, employee.staffId, null)

	robot.respond /([\w\-]+) phone/i, (context) ->
		username = context.match[1]
		getEmployeeObject 'name', username, (err, userObj) ->
			if not err
				tokenUrl = 'https://api.staffsquared.com/api/Token'
				cachedRequest tokenUrl, null, 'post', dataForToken, (err, token) ->
					if not err
						url = "https://api.staffsquared.com/api/Staff/#{userObj.staffId}"
						headers = { Authorization: 'Bearer ' + token.access_token }
						cachedRequest url, headers, request, 'get', null, (err, response) ->
							if not err
								context.send("""
									Work telephone: #{response.WorkTelephone}
									Work mobile: #{response.WorkMobile}
								""")
