# Description:
#   A hubot script to repeat all output to gitter
#
# Author:
#   Andrew Lucas (sqweelygig) <andrewl@resin.io> <sqweelygig@gmail.com>
#noinspection JSUnresolvedVariable
module.exports = (robot) ->

  room_id = null
  headers = {
    'Content-Type': 'application/json'
    'Accept': 'application/json'
    'Authorization': 'Bearer ' + process.env.HUBOT_GITTER_API_TOKEN
  }
  post_text = (text) ->
    if room_id?
      (require 'request').post {
        url: 'https://api.gitter.im/v1/rooms/' + room_id + '/chatMessages'
        headers: headers
        body: JSON.stringify { 'text': text }
      }
  robot.hear /(.*)/i, (responder) ->
    if room_id?
      post_text responder.message.text
    else
      (require 'request').post {
        url: 'https://api.gitter.im/v1/rooms'
        headers: headers
        body: JSON.stringify { 'uri': process.env.HUBOT_GITTER_ROOM }
      }, (error, response, body) ->
        room_id = (JSON.parse body).id
        post_text responder.message.text

