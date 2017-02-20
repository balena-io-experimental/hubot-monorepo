# Description:
#   Stores and responds on who is on support
#
# Configuration:
#   HUBOT_FIREBASE_URL
#   HUBOT_FIREBASE_SECRET
#
# Commands:
#   who's on support - Responds with the person in support at this specific time
#
# Author:
#   okakosolikos, dfunckt

#firebaseUrl = process.env.HUBOT_FIREBASE_URL
#firebaseAuth = process.env.HUBOT_FIREBASE_SECRET

module.exports = (robot) ->
	support_link = (msg) ->
		supportLink = process.env.HUBOT_SUPPORT_LINK
		msg.send 'The schedule is here:' + '\n' + supportLink

	robot.hear /on support @[\w\-]+\s*@[\w\-]+\s*@[\w\-]+\s*@[\w\-]+/i, support_link #(msg) ->
#    regex = /@([\w\-]+)[,\s]?/g
#    matchedNames = []
#    while true
#      match = regex.exec(msg.match.input)
#      break if not match
#      matchedNames.push(match[1])
#    data = JSON.stringify({onSupport: matchedNames})
#    console.log matchedNames
#    console.log msg.match
#    robot.http("#{firebaseUrl}/data/.json?auth=#{firebaseAuth}")
#      .patch(data) (err, res, body) ->
#        if err or res.statusCode isnt 200
#          msg.send "Oops, something went wrong. Bad Hubot!"
#          return
#        else
#          msg.send "Go #{matchedNames}!"

	robot.hear /(who's|who is|whos|who’s) on support/i, support_link #(msg) ->
#    robot.http("#{firebaseUrl}/data/onSupport.json?auth=#{firebaseAuth}")
#      .get() (err, res, body) ->
#        supportSlot = JSON.parse(body)
#        time = new Date().getHours()
#        supportGuy = switch
#          when time < 7 then "No one"
#          when time < 11 then supportSlot[0]
#          when time < 15 then supportSlot[1]
#          when time < 19 then supportSlot[2]
#          when time < 23 then supportSlot[3]
#        msg.send "#{supportGuy}\nhttps://github.com/resin-io/hq/wiki/Support"

	robot.hear /\B#support\b/i, support_link #(msg) ->
#    messageText = msg.message.text
#    robot.http("#{firebaseUrl}/data/onSupport.json?auth=#{firebaseAuth}")
#      .get() (err, res, body) ->
#        supportSlot = JSON.parse(body)
#        time = new Date().getHours()
#        supportGuy = switch
#          when time < 7 then "No one"
#          when time < 11 then supportSlot[0]
#          when time < 15 then supportSlot[1]
#          when time < 19 then supportSlot[2]
#          when time < 23 then supportSlot[3]
#        unless supportGuy is "No one"
#          messageText = "**#{msg.message.user.name}** said: " + messageText.replace /#support\b/gi, "@#{supportGuy}"
#          msg.send messageText
#        else
#          messageText = "**#{msg.message.user.name}** said: " + messageText.replace /#support\b/gi, "@#{supportSlot[0]}"
#          msg.reply "No one is on support at the moment.\n#{supportSlot[0]} will have to check when his shift starts.\n#{messageText}"
