# Description:
#   List incidents
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   hubot list incidents since <date> - List messages in flowdock containing incident tag
#
# Author:
#   codec

Promise = require 'bluebird'
dateParse = require 'dehumanize-date'
dateFormat = require 'dateformat'

API_URL = "https://#{process.env.HUBOT_FLOWDOCK_API_KEY}@api.flowdock.com"

listFlowIncidents = (msg, flow, sinceDate) ->
	orgName = flow.organization.parameterized_name
	flowName = flow.parameterized_name
	Promise.fromNode (cb) ->
		msg.robot.http("#{API_URL}/flows/#{orgName}/#{flowName}/messages?tags=incident").get() (err, res, body) ->
			cb(err, body ? [])
	.then (body) ->
		JSON.parse(body)
	.filter (message) ->
		message.thread_id?
	.filter (message) ->
		console.log(message.thread_id, message.sent, sinceDate)
		new Date(message.sent) > sinceDate
	.map (incident) ->
		rawTitle = "#{incident.thread.title}"
		title = rawTitle.replace /@/g ,"[at]"
		link = "#{flow.web_url}/threads/#{incident.thread_id}"
		date = new Date(incident.sent)
		prettyDate = dateFormat(date, 'yyyy-mm-dd')
		response = "[:flowdock: **#{title}** on #{prettyDate}](#{link})"
		return { response, date }
	.catch (err) ->
		console.error('Error', err, err.stack)
		throw new Error("Sorry, I wasn't able to list messages from flow #{flow.name}.")

listFlows = (msg) ->
	Promise.fromNode (cb) ->
		msg.robot.http("#{API_URL}/flows").get() (err, res, body) ->
			cb(err, body ? [])
	.then (body) ->
		JSON.parse(body)
	.catch (err) ->
		console.error('Error', err, err.stack)
		throw new Error("Sorry, I wasn't able to get the list of flows.")

module.exports = (robot) ->
	robot.respond /(list )?incidents since (.+)/i, (msg) ->
		console.log msg.message.text, msg.message.room, msg.message.metadata.room, msg.message.metadata.thread_id
		Promise.try ->
			dateText = msg.match[2]
			date = dateParse(dateText)
			if not date?
				throw new Error("Sorry, I couldn't understand date #{dateText}.")
			return [new Date(date), dateText]
		.spread (date, dateText) ->
			listFlows(msg)
			.map (flow) ->
				listFlowIncidents(msg, flow, date)
			.then (incidentsPerFlow) ->
				[].concat(incidentsPerFlow...) # flatten
			.then (incidents) ->
				incidents.sort (a, b) ->
					return a.date > b.date
			.map (incident) ->
				incident.response
			.then (incidentLinks) ->
				prettyDate = dateFormat(date, 'dddd, mmmm dS, yyyy')
				if incidentLinks.length == 0
					msg.send("There were no incidents since #{prettyDate}.")
				else
					msg.send("Incidents since #{prettyDate}\n\n#{incidentLinks.join('\n')}")
		.catch (err) ->
			console.error('Error', err, err.stack)
			msg.send(err)
