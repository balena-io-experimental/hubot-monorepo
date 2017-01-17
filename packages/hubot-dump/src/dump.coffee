console.log 'dump loaded'

module.exports = (robot) ->
	robot.hear /.*/i, (context) ->
		console.log 'here'
		robot.logger.info context.message.text
