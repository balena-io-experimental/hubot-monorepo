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
