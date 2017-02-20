# Description:
#   A hubot script to repeat all output to logs
#
# Author:
#   Andrew Lucas (sqweelygig) <andrewl@resin.io> <sqweelygig@gmail.com>
module.exports = (robot) ->
	robot.hear /.*/i, (context) ->
		robot.logger.info context.message.text
