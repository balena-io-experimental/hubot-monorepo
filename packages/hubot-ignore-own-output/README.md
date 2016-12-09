# hubot-ignore-self

A hubot script that prevents a hubot from acting on it's own output

See [`src/ignore-self.coffee`](src/ignore-self.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install hubot-ignore-self --save`

Then add **hubot-ignore-self** to your `external-scripts.json`:

```json
[
  "hubot-ignore-self"
]
```

## Sample Interaction

```
user1>> hubot hello
hubot>> hello!
```

## NPM Module

https://www.npmjs.com/package/hubot-ignore-self
