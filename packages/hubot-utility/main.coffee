mailer = require 'nodemailer'
AbstractAPIAdapter = require('./abstractAPIAdapter.coffee')
AbstractAPIWriter = require('./abstractAPIWriter.coffee')

module.exports =
	createSender: (context) ->
		context.send.bind(context)

	createReplier: (context) ->
		context.reply.bind(context)

	notify: (subject, info, respond = ->) ->
		hubotEmail = encodeURIComponent(process.env.HUBOT_GMAIL_EMAIL)
		hubotPass = encodeURIComponent(process.env.HUBOT_GMAIL_PASSWORD)
		transporter = mailer.createTransport("smtps://#{hubotEmail}:#{hubotPass}@smtp.gmail.com")
		mailData =
			from: '"Hubot" <hubot@resin.io>'
			to: 'andrewl@resin.io'
			subject: subject
			text: """
				Message: #{info.message}
				Full error object: #{info}
			"""
		transporter.sendMail mailData, (err) ->
			if err
				console.log err
			else
				respond("Email sent to #{mailData.to}")

	AbstractAPIAdapter: AbstractAPIAdapter

	AbstractAPIWriter: AbstractAPIWriter

