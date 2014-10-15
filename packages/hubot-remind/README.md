# Hubot Remember To

Just a simple remember to module for Hubot

This hubot script is based on `hubot-cron`

## Install

```
npm install hubot-rememberto --save
```

## How to use it

```
hubot remember to me in 1h to send an email to someone...
```

You can use

 * `s` -> seconds
 * `m` -> minutes
 * `h` -> hours
 * `d` -> days

You can check existing jobs

```
hubot what do you remember?
```

And drop things out

```
hubot forget <job id>
```

