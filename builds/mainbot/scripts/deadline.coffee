# Description:
#   Create a event deadline that will be posted every day in the flow it was triggered
#
# Dependencies:
#   "chrono-node": "^0.1.10"
#
# Configuration:
#   HUBOT_FIREBASE_URL
#   HUBOT_FIREBASE_SECRET
#
# Commands:
#   hubot deadline (in <number> days)||(on yyyy-mm-dd) for <event> - Creates / Updates a deadline that will post everyday to that specific flow
#   hubot delete deadline for <event> - Makes the <event> deadline inactive
#
# Author:
#   okakosolikos

firebaseUrl = process.env.HUBOT_FIREBASE_URL
firebaseAuth = process.env.HUBOT_FIREBASE_SECRET

module.exports = (robot) ->
  cronJob = require('cron').CronJob
  dateFormat = require 'dateformat'
  chrono = require('chrono-node')

  robot.respond /deadline (.+?) for (.*)/i, (msg) ->
    flowId = msg.message.room
    if not flowId?
      msg.send "This script is not available in 1-1!"
      return

    rawDateTime = msg.match[1]
    parseDateTime = chrono.parseDate(rawDateTime)
    if not parseDateTime?
      msg.send "That's not even a date, dude! Try `deadline in <number> days for <event>` or `deadline on yyyy-mm-dd for <event>`"
      return

    parseDateTime.setHours(9,0,0,0)
    now = new Date()
    if parseDateTime.getTime() < now.getTime() #before or after the cronJob in cron.coffee
      msg.send "I'm not a time traveler man, are you?"
      return
    deadline = new Date(parseDateTime.setHours(0,0,0,0))
    console.log deadline

    event = msg.match[2]

    robot.http("#{firebaseUrl}/data/countdownEvents.json?auth=#{firebaseAuth}")
      .get() (err, res, body) ->
        countdownEvents = JSON.parse(body)
        eventTitles = (countdownEvent.title for countdownEvent in countdownEvents)

        unless event in eventTitles
          data = JSON.stringify({deadlineDate: deadline, title: event, isActive: true, flowId: flowId})
          robot.http("#{firebaseUrl}/data/countdownEvents/#{eventTitles.length}.json?auth=#{firebaseAuth}")
            .put(data) (err, res, body) ->
              if err or res.statusCode isnt 200
                msg.send "Oops, something went wrong. Bad Hubot!"
                return
              else
                msg.send "Countdown created! Deadline on #{dateFormat(deadline, "fullDate")}"
                return
        else
          for countdownEvent, index in countdownEvents
            if countdownEvent.title is event
              data = JSON.stringify({deadlineDate: deadline, isActive: true, flowId: flowId})
              robot.http("#{firebaseUrl}/data/countdownEvents/#{index}/.json?auth=#{firebaseAuth}")
                .patch(data) (err, res, body) ->
                  if err or res.statusCode isnt 200
                    msg.send "Oops, something went wrong. Bad Hubot!"
                    return
                  else
                    msg.send "Countdown updated! Deadline on #{dateFormat(deadline, "fullDate")}"
                    return

  robot.respond /delete deadline for (.*)/i, (msg) ->
    event = msg.match[1]
    robot.http("#{firebaseUrl}/data/countdownEvents.json?auth=#{firebaseAuth}")
      .get() (err, res, body) ->
        countdownEvents = JSON.parse(body)
        eventFound = false
        for countdownEvent, index in countdownEvents
          do (countdownEvent, index) ->
            if countdownEvent.title is event
              eventFound = true
              if countdownEvent.isActive is false
                msg.send "Deadline is already deleted!"
                return
              else
                data = JSON.stringify({isActive: false})
                robot.http("#{firebaseUrl}/data/countdownEvents/#{index}.json?auth=#{firebaseAuth}")
                  .patch(data) (err, res, body) ->
                    if err or res.statusCode isnt 200
                      msg.send "Oops, something went wrong. Bad Hubot!"
                      return
                    else
                      msg.send "Deadline deleted!"
                      return
        if eventFound is false then msg.send "There's no deadline with that name, dawg!"

  robot.on 'deadline', ->
    now = new Date()
    now.setHours(0,0,0,0)
    robot.http("#{firebaseUrl}/data/countdownEvents.json?auth=#{firebaseAuth}")
      .get() (err, res, body) ->
        countdownEvents = JSON.parse(body)
        for countdownEvent, index in countdownEvents when countdownEvent.isActive is true
          deadlineDate = new Date(countdownEvent.deadlineDate)
          dateDiff = Math.round((deadlineDate.getTime() - now.getTime()) / (24*60*60*1000))
          if dateDiff > 0
            dayORdays = if dateDiff is 1 then "day" else "days"
            robot.messageRoom countdownEvent.flowId, "#{dateDiff} #{dayORdays} left for #{countdownEvent.title}!"
          else
            if dateDiff is 0 then robot.messageRoom countdownEvent.flowId, "Deadline for #{countdownEvent.title} is today!"
            data = JSON.stringify({isActive: false})
            robot.http("#{firebaseUrl}/data/countdownEvents/#{index}/.json?auth=#{firebaseAuth}")
              .patch(data) (err, res, body) ->
                if err or res.statusCode isnt 200
                  msg.send "Oops, something went wrong. Bad Hubot!"
                  return
