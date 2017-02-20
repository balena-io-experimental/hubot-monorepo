# Lerna lessons

## How-I-did
* A `lerna init`, clone your repos down
* Do a load of cleaning up and `lerna import`
* `lerna exec npm install` and `lerna bootstrap`
* Tweak the package.json file to envvar the install and start
* Push it to heroku, with envvar
* Rejoice and have a beer

## Heroku FAQ
* my current understanding is that your code must work as if a node module at
  the root level
* However: package.json is just like any other package.json
  * In particular note that I have added a scripts section

## Lerna FAQ
* What is it?
  * It's great, look here https://github.com/lerna/lerna
* tl;dr: lerna?
  * It automates a lot of the chores of managing a single repo containing 
    several modules
* I used to have forked repos to improve upstream branches
  * Not any more?
  * Keep them separate?
* I get these weird messages (note to self: put proper message output here) 
  on lerna import
  * git rebase --root is your friend
* I used to have a bundle of history in github, issues, etc.
  * Migrate it.
* Independent mode
  * Seriously, use it.  You don't want one semver across all your modules do 
    you?
