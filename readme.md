# Lerna Monorepo <-> Heroku Deploy using Hubot as example

This repo is intended to serve as a monorepo for the rather spammy and unmanageable set of repos that sqweelygig has
accumulated in the first few months at resin.  Since Resin are exploring Lerna as a management tool for this, I thought
it a sensible moment to consolidate using that.
However, since this has to be deployed into a reasonably standard node environment there were lessons to learn and 
questions to ask. Some of these are below.

## Lerna <-> Heroku
* package.json is just like any other package.json
  * In particular note that I have added a scripts section
  * Heroku (Node) picks up on this, building and running the module from envvar

## Lerna FAQ
* What is it?
  * It's great, look here https://github.com/lerna/lerna
* tl;dr: lerna?
  * It automates a lot of the chores of managing a single repo containing several modules
* I used to have forked repos to improve upstream branches
  * Not any more?
  * Keep them separate?
* I get these weird messages (note to self: put proper message output here) on lerna import
  * git rebase --root is your friend
* I used to have a bundle of history in github, issues, etc.
  * Migrate it.
* Independent mode
  * Seriously, use it.  You don't want one semver across all your modules do you?
