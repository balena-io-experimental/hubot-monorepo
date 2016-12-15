# hubot-gitter-echo

A hubot script that echos all output to a gitter room

See [`src/gitter-echo.coffee`](src/gitter-echo.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install hubot-gitter-echo --save`

Then add **hubot-gitter-echo** to your `external-scripts.json`:

```json
[
  "hubot-gitter-echo"
]
```

## Environment Variables

```
HUBOT_GITTER_ROOM
HUBOT_GITTER_API_TOKEN
```

## Sample Interaction

```
user1>> hubot hello
hubot>> hello!
```

## NPM Module

https://www.npmjs.com/package/hubot-gitter-echo
