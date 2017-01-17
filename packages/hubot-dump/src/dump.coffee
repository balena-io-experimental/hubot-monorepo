console.log 'dump loaded'

module.exports = (robot) ->
	robot.hear /.*/i, (context) ->
		console.log 'here'
		thislineisduff
		robot.logger.info context.message.text
