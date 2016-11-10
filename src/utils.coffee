request = require "request"
q = require "q"
tomlify = require "tomlify-j0.4"
toml = require "toml"
moment = require "moment"

api_url = "https://api.github.com"
base_url = "#{api_url}/repos/#{process.env.HUBOT_ISSUE_TRACKER_GITHUB_OWNER}/#{process.env.HUBOT_ISSUE_TRACKER_GITHUB_REPO}/issues"

headers =
	"User-Agent": "UniversityRadioYork/hubot-issue-tracker"
	"Content-Type": "application/json"
	"Authorization": "token #{process.env.HUBOT_ISSUE_TRACKER_GITHUB_TOKEN}"

TASK_LIMIT = 5

module.exports = class Utils

	@addTask: (user, task) ->
		deferred = q.defer()
		try
			request.post
				"url": base_url
				"headers": headers
				"body": JSON.stringify
					"title": task
					"labels": [process.env.HUBOT_ISSUE_TRACKER_GITHUB_LABEL]
					"body": """
					###### Please do not alter the description of this issue.
					###### Below is the user that submitted the issue and the original message.
					#{tomlify
						"user":
							"name": user["name"]
							"real_name": user["real_name"]
						"message": task
					, null, 2}
					"""
			,
				(error, response, body) ->
					try
						if not error and response.statusCode == 201
							data = JSON.parse body
							deferred.resolve "Task ##{data["number"]} added!"
						else
							deferred.reject if error then error else body
					catch ex
						deferred.reject ex
		catch ex
			deferred.reject ex
		return deferred.promise

	@listTasks: (full) ->
		deferred = q.defer()
		promises = q.all [
			Utils.getOpenTasks()
			Utils.getRecentlyClosedTasks()
		]
		promises.then (data) ->
			string = "Current tasks:\n\n"
			for issue in (if full then data[0] else data[0].slice(0, TASK_LIMIT))
				string += " - ##{issue.number} - #{issue.title}\n"
			string += "\nRecently Closed Tasks:\n\n"
			for issue in (if full then data[1] else data[1].slice(0, TASK_LIMIT))
				string += " - ##{issue.number} - #{issue.title}\n"
			if not full and (data[0].length > TASK_LIMIT or data[1].length > TASK_LIMIT)
				string += "\nList is truncated, use 'list all tasks' to see complete list"
			deferred.resolve string
		.catch (ex) ->
			deferred.reject ex
		.done()
		return deferred.promise

	@getRecentlyClosedTasks: ->
		deferred = q.defer()
		try
			stamp = moment().subtract(7, 'days').toISOString()
			request.get
				"url": "#{base_url}?state=closed&since=#{encodeURIComponent stamp}&labels=#{encodeURIComponent process.env.HUBOT_ISSUE_TRACKER_GITHUB_LABEL}"
				"headers": headers
			,
				(error, response, body) ->
					try
						if not error and response.statusCode == 200
							data = JSON.parse body
							deferred.resolve data
						else
						deferred.reject if error then error else body
					catch ex
						deferred.reject ex
		catch ex
			deferred.reject ex
		return deferred.promise

	@getOpenTasks: ->
		deferred = q.defer()
		try
			request.get
				"url": "#{base_url}?state=open&labels=#{encodeURIComponent process.env.HUBOT_ISSUE_TRACKER_GITHUB_LABEL}"
				"headers": headers
			,
				(error, response, body) ->
					try
						if not error and response.statusCode == 200
							data = JSON.parse body
							deferred.resolve data
						else
						deferred.reject if error then error else body
					catch ex
						deferred.reject ex
		catch ex
			deferred.reject ex
		return deferred.promise

	@taskDetails: (id) ->
		deferred = q.defer()
		try
			Utils.getTask(id)
			.then (issue) ->
				try
					string = """
					Task ##{id} details:

					Description: #{issue["title"]}
					"""
					if issue["body"]?
						try
							info = toml.parse issue["body"]
							if info["user"]["real_name"]?
								string += "\nReported By: #{info["user"]["real_name"]} (#{info["user"]["name"]})\n"
							else
								string += "\nReported By: #{info["user"]["name"]}\n"
						catch error
#							do nothing, break nothing
					string += """
					Status: #{issue["state"]}
					Opened: #{issue["created_at"]}
					Last Updated: #{issue["updated_at"]}
					"""
					if issue["state"] is "closed"
						string += """
						\nClosed: #{issue["closed_at"]}
						Closed By: #{issue["closed_by"]["login"]}
						""" # @TODO: Check to see if it was us that closed it
					deferred.resolve string
				catch ex
					deferred.reject ex
			.catch (ex) ->
				deferred.reject ex
			.done()
		catch ex
			deferred.reject ex
		return deferred.promise

	@closeTask: (user, id) ->
		deferred = q.defer()
		try
			Utils.getStatusAndOwnerOfTask(id)
			.then ([status, owner]) ->
				if status is "closed"
					deferred.resolve "This task has already been closed. If this is an error please contact #{process.env.HUBOT_ISSUE_TRACKER_CONTACT}"
				else if not owner?
					deferred.resolve "Cannot determine the owner of this task, please contact #{process.env.HUBOT_ISSUE_TRACKER_CONTACT}"
				else if user.name isnt owner
					deferred.resolve "Sorry, only the original owner of this task can close it. If this is an error please contact #{process.env.HUBOT_ISSUE_TRACKER_CONTACT}"
				else
					promises = q.allSettled [
						Utils.addCommentToIssue user, id
						Utils.closeIssue id
					]
					promises.then () ->
						deferred.resolve "Task #{id} closed!"
					.catch (error) ->
						deferred.reject error
					.done()
			.catch (error) ->
				deferred.reject error
			.done()
		catch ex
			deferred.reject ex
		return deferred.promise

	@getStatusAndOwnerOfTask: (id) ->
		deferred = q.defer()
		try
			Utils.getTask(id)
			.then (task) ->
				try
					owner = null
					if task["body"]?
						info = toml.parse task["body"]
						if info["user"]? and info["user"]["name"]?
							owner = info["user"]["name"]
					deferred.resolve [task["state"], owner]
				catch ex
					deferred.reject ex
			.catch (ex) ->
				deferred.reject ex
			.done()
		catch ex
			deferred.reject ex
		return deferred.promise

	@addCommentToIssue: (user, id) ->
		deferred = q.defer()
		try
			if user["slack"]?
				delete  user["slack"]
			request.post
				"url": "#{base_url}/#{encodeURIComponent id}/comments"
				"headers": headers
				"body": JSON.stringify
					"body": """
					###### Please do not change the contents of this comment.
					###### Below is the user that closed this issue.
					#{tomlify
						"user":
							"name": user["name"]
							"real_name": user["real_name"]
					, null, 2}
					"""
			,
				(error, response) ->
					try
						if not error and response.statusCode == 201
							deferred.resolve()
						else
							deferred.reject if error then error else body
					catch ex
						deferred.reject ex
		catch ex
			deferred.reject ex
		return deferred.promise

	@closeIssue: (id) ->
		deferred = q.defer()
		try
			request.patch
				"url": "#{base_url}/#{encodeURIComponent id}"
				"headers": headers
				"body": JSON.stringify
					"state": "closed"
			,
				(error, response) ->
					if not error and response.statusCode == 200
						deferred.resolve()
					else
						deferred.reject if error then error else body
		catch ex
			deferred.reject ex
		return deferred.promise

	@getTask: (id) ->
		deferred = q.defer()
		try
			request.get
				"url": "#{base_url}/#{encodeURIComponent id}"
				"headers": headers
			,
				(error, response, body) ->
					try
						if not error and response.statusCode == 200
							task = JSON.parse body
							if Utils.hasLabel task
								deferred.resolve task
							else
								deferred.reject new Error "Task doesn't have correct label, we don't have permission to see it :)"
						else
						deferred.reject if error then error else body
					catch ex
						deferred.reject ex
		catch ex
			deferred.reject ex
		return deferred.promise

	@hasLabel: (task) ->
		unless task["labels"]?
			return false
		for label in task["labels"]
			if label["name"] is process.env.HUBOT_ISSUE_TRACKER_GITHUB_LABEL
				return true
		return false
