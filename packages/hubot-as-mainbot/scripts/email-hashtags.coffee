# Description:
#   Sends an email when a new incident in Flowdock appears
#
# Dependencies:
#   "dateformat": "~1.0.12"
#   "nodemailer": "2.4.2"
#
# Configuration:
#   HUBOT_GMAIL_EMAIL
#   HUBOT_GMAIL_PASSWORD
#   HUBOT_FLOWDOCK_API_KEY
#   HUBOT_FIREBASE_URL
#   HUBOT_FIREBASE_SECRET
#
# Commands:
#   #<inbox> <subject> sends an email to the specified inbox, with a link back to the thread
#
# Author:
#   okakosolikos, sqweelygig

emails = {
	architecture: 'architecture@resin.io'
	blog: 'blog@resin.io', writeup: 'blog@resin.io', toblogfor: 'blog@resin.io'
	design: 'design@resin.io'
	devices: 'devices@resin.io'
	devops: 'devops@resin.io', deploy: 'devops@resin.io'
	docs: 'docs@resin.io'
	incident: 'reliability@resin.io', reliability: 'reliability@resin.io'
	newsletter: 'newsletter@resin.io'
	processfail: 'process@resin.io', processincident: 'process@resin.io', process: 'process@resin.io'
	product: 'product@resin.io'
	meeting: 'team@resin.io', 'meeting-notes': 'team@resin.io', meetingnotes: 'team@resin.io', minutes: 'team@resin.io'
	order: 'operations@resin.io', orders: 'operations@resin.io', stuff: 'operations@resin.io'
	gimme: 'operations@resin.io', buy: 'operations@resin.io', plz: 'operations@resin.io'
	botmeister: 'andrewl@resin.io', botmeister2: 'andrewl+2@resin.io'
}

nodemailer = require 'nodemailer'
dateFormat = require 'dateformat'
_ = require 'lodash'

hubotEmail = encodeURIComponent(process.env.HUBOT_GMAIL_EMAIL)
hubotPass = process.env.HUBOT_GMAIL_PASSWORD
API_URL = "https://#{process.env.HUBOT_FLOWDOCK_API_TOKEN}@api.flowdock.com"
firebaseUrl = process.env.HUBOT_FIREBASE_URL
firebaseAuth = process.env.HUBOT_FIREBASE_SECRET

incident = {}

transporter = nodemailer.createTransport("smtps://#{hubotEmail}:#{hubotPass}@smtp.gmail.com")

module.exports = (robot) ->

	decodeHtmlEntity = (str) ->
		str.replace /&#(\d+);/g, (match, dec) ->
			String.fromCharCode dec

	getFlowInfo = (msg) ->
		threadId = msg.message.metadata.thread_id
		incident.reporterNickname = msg.message.user.name
		robot.http("#{API_URL}/flows/find?id=#{msg.message.metadata.room}")
			.get() (err, res, body) ->
				flowInfo = JSON.parse(body)
				orgName = flowInfo.organization.parameterized_name
				incident.threadUrl = "#{flowInfo.web_url}/threads/#{threadId}"
				incident.flowParamName = flowInfo.parameterized_name
				incident.flowName = flowInfo.name
				getThreadInfo orgName, threadId, msg

	getThreadInfo = (organization, threadId, msg) ->
		robot.http("#{API_URL}/flows/#{organization}/#{incident.flowParamName}/threads/#{threadId}")
			.get() (err, res, body) ->
				threadInfo = JSON.parse(body)
				incident.threadTitle = decodeHtmlEntity threadInfo.title
				getMessageInfo organization, msg

	getMessageInfo = (organization, msg) ->
		robot.http("#{API_URL}/flows/#{organization}/#{incident.flowParamName}/messages/#{msg.message.id}")
			.get() (err, res, body) ->
				messageInfo = JSON.parse(body)
				incident.message = messageInfo.content
				incident.creationDate = dateFormat(messageInfo.created_at, 'mmmm dS, yyyy')
				sendEmail msg

	sendEmail = (msg) ->
		for fullHashtag in msg.match
			mailData =
				from: '"Hubot" <hubot@resin.io>'
				to: ''
				subject: ''
				text: ''
			hashtag = fullHashtag.match(/\w+/)[0]
			if hashtag is 'incident'
				mailData.subject = "Flowdock Incident ##{incident.id} : #{incident.threadTitle}"
				hashORincident1 = 'incident was created' #
				hashORincident2 = "incident's "          # will be used in mailData.text
			else
				mailData.subject = "##{incident.id} : #{incident.threadTitle}"
				hashORincident1 = 'hashtag appeared'    #
				hashORincident2 = ''                    # will be used in mailData.text

			mailData.text = """
				A new #{hashORincident1} in Flowdock's flow, #{incident.flowName}, on #{incident.creationDate} from #{incident.reporterNickname}


				Click on the link to view thread ->
				#{incident.threadUrl}


				Sneak peek of the #{hashORincident2} message:
				#{incident.message}
			"""

			mailData.to = emails[hashtag]

			transporter.sendMail mailData, (err, res) ->
				if err
					msg.send 'There was an error: ' + err
				else
					msg.send "Email sent to #{res.accepted.join(', ')} (id: ##{incident.id})"

	# This regex has been tested with the following strings:
	# Matches recognisedInboxWithHashtag:
	#  `#process`, `email #process`, `email #process plz`, `#process plz`
	#  `to #process's inbox`
	# Does not match:
	#  `process`, `email process`, `email process plz`, `process plz`
	#  `to process's inbox`, `unprocess`, `#processaurus`, `test#process`

	# \B ensure that the gap between words from # extends this far
	# # match the literal character # to detect hashtag presence
	# (...) capture any of the list of possible targets
	# \b makes sure the target is the complete word
	recognisedInboxWithHashtag = new RegExp("\\B#(#{Object.keys(emails).join('|')})\\b", 'gi')
	robot.hear recognisedInboxWithHashtag, (msg) ->
		robot.http("#{firebaseUrl}/data/incidentId.json?auth=#{firebaseAuth}")
			.get() (err, res, body) ->
				incident.id = JSON.parse(body)
				newIncidentId = incident.id + 1
				data = JSON.stringify({ incidentId: newIncidentId })
				robot.http("#{firebaseUrl}/data/.json?auth=#{firebaseAuth}")
					.patch(data) (err, res, body) ->
						if err or res.statusCode isnt 200
							msg.send "Couldn't update the increment number of the email"
							return
						else
							getFlowInfo msg
