# hubot-ignore

A hubot script that selectively ignores indicated messages

See [`src/ignore-by-prefix.coffee`](src/ignore-by-prefix.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install hubot-ignore-by-prefix --save`

Then add **hubot-ignore-by-prefix** to your `external-scripts.json`:

```json
[
  "hubot-ignore-by-prefix"
]
```

## Environment variables

```
HUBOT_IGNORE_PREFIX
```

## Sample Interaction

```
user1>> badger
hubot>> We don't need no stinking badgers!
user1>> :badger
```

## NPM Module

https://www.npmjs.com/package/hubot-ignore-by-prefix
