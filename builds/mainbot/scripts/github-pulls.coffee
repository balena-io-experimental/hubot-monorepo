# Description:
#   Show open pull requests from a Github repository or organization
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
#   hubot show [me] <user/repo> pulls [with <regular expression>] -- Shows open pull requests for that project by filtering pull request's title.
#   hubot show [me] <repo> pulls -- Show open pulls for HUBOT_GITHUB_USER/<repo>, if HUBOT_GITHUB_USER is configured
#   hubot show [me] org-pulls [for <organization>] -- Show open pulls for all repositories of an organization, default is HUBOT_GITHUB_ORG
#
# Notes:
#   HUBOT_GITHUB_API allows you to set a custom URL path (for Github enterprise users)
#
#   You can further filter pull request title by providing a regular expression.
#   For example, `show me hubot pulls with awesome fix`.
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

  pullSupervisor = (pullCreator) ->
    return Promise.resolve(null) if not pullCreator?
    Promise.fromNode (cb) ->
      robot.http("#{firebaseUrl}/users.json?auth=#{firebaseAuth}").get() (err, res, body) ->
        cb(err, body)
    .then (body) ->
      for user in JSON.parse(body)
        if user.github and user.github.id
          if user.github.id is pullCreator.id
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

  robot.respond /show\s+(me\s+)?org\-pulls(\s+for\s+)?(.*)?/i, (msg) ->
    org_name = msg.match[3] || process.env.HUBOT_GITHUB_ORG
    org_name_url = org_name.replace /,/g, "+user:"

    today = new Date
    twoWeeksAgo = today.setDate(-13)
    twoWeeksAgo = dateFormat(twoWeeksAgo, 'yyyy-mm-dd')

    unless (org_name)
      msg.send "No organization specified, please provide one or set HUBOT_GITHUB_ORG accordingly."
      return

    url = "#{url_api_base}/search/issues?q=type:pr+is:open+updated:<#{twoWeeksAgo}+sort:updated-asc+user:#{org_name_url}&per_page=100"
    github.get url, (issues) ->
      if issues.total_count is 0
        msg.send "Achievement unlocked: zero inactive open pull requests on Github!"
      else
        if issues.total_count is 1
          msg.send "There's only one inactive open pull request on Github for #{org_name}:"
        else
          msg.send "I found #{issues.total_count} inactive open pull requests on Github for #{org_name}:"

        Promise.all(issues.items.map (item) ->
          Promise.all([
            pullSupervisor(item.user)
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
          msg.send "[:github: **PR ##{item.number}: #{item.title}** by #{item.user.login} *in #{repoLocation}*](#{item.html_url}) *Created on: **#{creationDate}**, Updated on: **#{updateDate}** - Repo Maintainer~>**#{supervisor}***"
