module.exports = (robot) ->
	robot.hear /.*/i, (context) ->
		robot.logger.info context.message.text
