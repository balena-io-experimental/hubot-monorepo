# Hubot Remind

Just a simple reminder module for Hubot

This hubot script is based on `hubot-cron`

## Install

```
npm install hubot-remind --save
```

## How to use it

```
hubot remind <user or me> in <time with unit> to <message to remind>
```

You can use:

 * `s` -> seconds
 * `m` -> minutes
 * `h` -> hours
 * `d` -> days

You can check existing reminders:

```
hubot what do you remember?
```

And drop things out:

```
hubot forget <reminder id>
```

---

This is a GitHub fork from the original [Hubot RememberTo](https://github.com/wdalmut/hubot-rememberto) by [@wdalmut](https://github.com/wdalmut).
