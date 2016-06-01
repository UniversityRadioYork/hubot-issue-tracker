# Description
#   A hubot script that helps to keep track of issues reported in Slack.
#
# Configuration:
#   HUBOT_ISSUE_TRACKER_GITHUB_TOKEN - Access token for the Github user
#		HUBOT_ISSUE_TRACKER_GITHUB_OWNER - Owner of the repo to add issues to
#		HUBOT_ISSUE_TRACKER_GITHUB_REPO - Repo to add issues to
#		HUBOT_ISSUE_TRACKER_GITHUB_LABEL - Label to add to the issue
#		HUBOT_ISSUE_TRACKER_CONTACT - The contact to report issues to
#
# Commands:
#   hubot add task <task> - Adds a task as an issue on Github with a specific label
#   hubot list tasks - Lists all the open issues on Github with the label
#   hubot task <id> details - Displays the details about an issue
#   hubot close task <id> - Marks the issue as closed on Github
#
# Author:
#   ChrisTheBaron

Utils = require "./utils"

flags = [
	"HUBOT_ISSUE_TRACKER_GITHUB_TOKEN"
	"HUBOT_ISSUE_TRACKER_GITHUB_OWNER"
	"HUBOT_ISSUE_TRACKER_GITHUB_REPO"
	"HUBOT_ISSUE_TRACKER_GITHUB_LABEL"
	"HUBOT_ISSUE_TRACKER_CONTACT"
]

for flag in flags
	unless process.env[flag]?
		console.log "Missing #{flag} in environment: please set and try again"
		process.exit(1)

error_message = "Oops, I couldn't do that. Please contact #{process.env.HUBOT_ISSUE_TRACKER_CONTACT}"

module.exports = (robot) ->
	robot.respond /add task (.*)/, (msg) ->
		Utils.addTask msg.message.user, msg.match[1]
		.then (data) ->
			msg.reply data
		.catch () ->
			msg.reply error_message
		.done()

	robot.respond /list tasks/, (msg) ->
		Utils.listTasks()
		.then (data) ->
			msg.reply data
		.catch () ->
			msg.reply error_message
		.done()

	robot.respond /task (\d*) details/, (msg) ->
		Utils.taskDetails msg.match[1]
		.then (data) ->
			msg.reply data
		.catch () ->
			msg.reply error_message
		.done()

	robot.respond /close task (\d*)/, (msg) ->
		Utils.closeTask msg.message.user, msg.match[1]
		.then (data) ->
			msg.reply data
		.catch () ->
			msg.reply error_message
		.done()
