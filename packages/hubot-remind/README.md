# Hubot Remember To

Just a simple remember to module for Hubot

This hubot script is based on `hubot-cron`

## Install

```
npm install hubot-rememberto --save
```

## How to use it

```
hubot remind <user or me> in <time with unit> to <message to remember>
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

