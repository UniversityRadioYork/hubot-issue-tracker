# hubot-issue-tracker

A hubot script that helps to keep track of issues reported in Slack.

See [`src/issue-tracker.coffee`](src/issue-tracker.coffee) for full documentation.

Based on [hubot-slack-github-issues](https://github.com/18F/hubot-slack-github-issues), but uses commands instead of emoji.

## Installation

In hubot project repo, run:

`npm install hubot-issue-tracker --save`

Then add **hubot-issue-tracker** to your `external-scripts.json`:

```json
["hubot-issue-tracker"]
```

## Sample Interaction

```
user1>> hubot add task fix that annoying thing that's broken
hubot>> Task 1 added!
user1>> hubot list tasks
hubot>> Current tasks:
        
- #1 - fix that annoying thing that's broken
user1>> hubot close task 1
hubot>> Task 1 closed!
```
