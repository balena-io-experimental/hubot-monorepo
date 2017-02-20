# Description:
#   Defines periodic executions
#
# Dependencies
#   "cron": "^1.0.6"
#
# Configuration:
#   None
#
# Commands:
#   None
#
# Author:
#   okakosolikos

_ = require 'lodash'
fortunes = require 'fortune-cookie'

module.exports = (robot) ->
	cronJob = require('cron').CronJob
	tz = 'UTC'
	pub = 'rulemotion:rulemotion'

	promoteHubotScripts = ->
		robot.messageRoom pub, "Hey humans and petrosagg, have you checked what can I do for you? Type '@Hubot commands' to find out!"
	new cronJob('0 0 11 * * 2,5', promoteHubotScripts, null, true, tz)

	deadline = ->
		robot.emit 'deadline'
	new cronJob('0 0 9 * * *', deadline, null, true, tz)  #if time changes, please update comparison in deadline.coffee, too

	weeklyUpdate = ->
		robot.messageRoom pub, '@hubot leave 8 days'
	new cronJob('0 0 14 * * 2', weeklyUpdate, null, null, tz)

	fortuneCookie = -> robot.messageRoom pub, _.sample(fortunes)
	new cronJob('0 0 11 * * 1,4', fortuneCookie, null, null, tz)

	### inactive

	remindShaunForSupport = ->
		robot.messageRoom pub, "@shaunmulligan, announce the names support!\n*Hint: 'on support [at]jean [at]claude [at]van [at]damme'*"
	new cronJob('0 30 16 * * 1', remindShaunForSupport, null, true, tz)

	JQLsearch = jqlfilter: 'status=testing'
	devops = 'blah'
	cardsReminderWaitingForTest = ->
		robot.emit 'cards in waiting for test', JQLsearch, devops
	new cronJob('0 0 9,17 * * 1,4', cardsReminderWaitingForTest, null, true, tz)

	devops = 'blah'
	githubOpenPullRequests = ->
		robot.emit 'Github open pull requests', devops
	new cronJob('0 1 9 * * 1,4', githubOpenPullRequests, null, true, tz)

	###
