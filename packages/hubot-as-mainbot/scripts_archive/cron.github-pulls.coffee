# Description:
#   Cron version - Show open pull requests from a Github repository or organization
#
# Dependencies:
#   "githubot": "0.4.x"
#
# Configuration:
#   HUBOT_GITHUB_TOKEN
#   HUBOT_GITHUB_USER
#   HUBOT_GITHUB_API
#   HUBOT_GITHUB_ORG
#   HUBOT_FIREBASE_URL
#   HUBOT_FIREBASE_SECRET
#
# Commands:
#   Receives a command automatically from cron.coffee
#
# Notes:
#   HUBOT_GITHUB_API allows you to set a custom URL path (for Github enterprise users)
#
# Author:
#   jingweno, okakosolikos

github = require 'githubot'
Promise = require 'bluebird'
dateFormat = require 'dateformat'

firebaseUrl = process.env.HUBOT_FIREBASE_URL
firebaseAuth = process.env.HUBOT_FIREBASE_SECRET

unless (url_api_base = process.env.HUBOT_GITHUB_API)?
  url_api_base = "https://api.github.com"

module.exports = (robot) ->

  pullSupervisor = (pullAssignee) ->
    return Promise.resolve(null) if not pullAssignee?
    Promise.fromNode (cb) ->
      robot.http("#{firebaseUrl}/users.json?auth=#{firebaseAuth}").get() (err, res, body) ->
        cb(err, body)
    .then (body) ->
      for user in JSON.parse(body)
        if user.github and user.github.id
          if user.github.id is pullAssignee.id
            return user.flowdock.nick

  repoSupervisor = (repoUrl) ->
    Promise.fromNode (cb) ->
      github.get repoUrl, (repo) ->
        robot.http("#{firebaseUrl}/users.json?auth=#{firebaseAuth}").get() (err, res, body) ->
          cb(err, [ body, repo ])
    .then ([ body, repo ]) ->
      body = JSON.parse(body)
      for user in body
        if user.github and user.github.reposMaintainer
          if repo.full_name in user.github.reposMaintainer
            return user.flowdock.nick

  orgSupervisor = (repoUrl) ->
    Promise.fromNode (cb) ->
      github.get repoUrl, (repo) ->
        robot.http("#{firebaseUrl}/users.json?auth=#{firebaseAuth}").get() (err, res, body)->
          cb(err, [ body, repo ])
    .then ([ body, repo ]) ->
      for user in JSON.parse(body)
        if user.github and user.github.orgsMaintainer
          if repo.organization.login in user.github.orgsMaintainer
            return user.flowdock.nick

  robot.on 'Github open pull requests', (flow) ->
    org_name = process.env.HUBOT_GITHUB_ORG
    org_name_url = org_name.replace /,/g, "+user:"

    today = new Date
    twoWeeksAgo = today.setDate(-13)
    twoWeeksAgo = dateFormat(twoWeeksAgo, 'yyyy-mm-dd')

    unless (org_name)
      robot.messageRoom flow, "No organization specified, please provide one or set HUBOT_GITHUB_ORG accordingly."
      return

    url = "#{url_api_base}/search/issues?q=type:pr+is:open+updated:<#{twoWeeksAgo}+sort:updated-asc+user:#{org_name_url}&per_page=100"
    github.get url, (issues) ->
      if issues.total_count is 0
        robot.messageRoom flow, "Achievement unlocked: zero inactive open pull requests on Github!"
      else
        if issues.total_count is 1
          robot.messageRoom flow, "There's only one inactive open pull request on Github for #{org_name}:"
        else
          robot.messageRoom flow, "I found #{issues.total_count} inactive open pull requests on Github for #{org_name}:"

        Promise.all(issues.items.map (item) ->
          Promise.all([
            pullSupervisor(item.assignee)
            repoSupervisor(item.repository_url)
            orgSupervisor(item.repository_url)
            Promise.resolve(item)
          ])
        )
        .map ([ nickFromPull, nickFromRepo, nickFromOrg, item ]) ->
          supervisor = nickFromPull ? nickFromRepo ? nickFromOrg ? "shaunmulligan"
          creationDate = dateFormat(item.created_at, 'yyyy-mm-dd')
          updateDate = dateFormat(item.updated_at, 'yyyy-mm-dd')
          repoLocation = item.repository_url.slice(29)
          robot.messageRoom flow, "@#{supervisor} [:github: **PR ##{item.number}: #{item.title}** by #{item.user.login} *in #{repoLocation}*](#{item.html_url}) *Created on: **#{creationDate}**, Updated on: **#{updateDate}***"
