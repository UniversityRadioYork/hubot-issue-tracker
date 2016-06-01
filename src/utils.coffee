request = require "request"
q = require "q"
tomlify = require "tomlify-j0.4"
toml = require "toml"

api_url = "https://api.github.com"
base_url = "#{api_url}/repos/#{process.env.HUBOT_ISSUE_TRACKER_GITHUB_OWNER}/#{process.env.HUBOT_ISSUE_TRACKER_GITHUB_REPO}/issues"

headers =
	"User-Agent": "UniversityRadioYork/hubot-issue-tracker"
	"Content-Type": "application/json"
	"Authorization": "token #{process.env.HUBOT_ISSUE_TRACKER_GITHUB_TOKEN}"

module.exports = class Utils

	@addTask: (user, task) ->
		deferred = q.defer()
		try
			if user["slack"]?
				delete  user["slack"]
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
						"user": user
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

	@listTasks: ->
		deferred = q.defer()
		try
			request.get
				"url": "#{base_url}?state=open&sort=created&direction=asc&labels=#{encodeURIComponent process.env.HUBOT_ISSUE_TRACKER_GITHUB_LABEL }"
				"headers": headers
			,
				(error, response, body) ->
					try
						if not error and response.statusCode == 200
							data = JSON.parse body
							string = "Current tasks:\n\n"
							for issue in data
								string += " - ##{issue.number} - #{issue.title}\n"
							deferred.resolve string
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
			request.get
				"url": "#{base_url}/#{encodeURIComponent id}"
				"headers": headers
			,
				(error, response, body) ->
					try
						if not error and response.statusCode == 200
							data = JSON.parse body
							string = """
								Task ##{id} details:

								Description: #{data["title"]}
								"""
							if data["body"]?
								try
									info = toml.parse data["body"]
									string += "\nReported By: #{info["user"]["name"]}"
								catch error
#									do nothing, break nothing
							string += """

								Status: #{data["state"]}
								Opened: #{data["created_at"]}
								Last Updated: #{data["updated_at"]}
								"""
							if data["state"] is "closed"
								string += """

								Closed: #{data["closed_at"]}
								Closed By: #{data["closed_by"]["login"]}
								""" # @TODO: Check to see if it was us that closed it
							deferred.resolve string
						else
						deferred.reject if error then error else body
					catch ex
						deferred.reject ex
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
					q.all [
						Utils.addCommentToIssue user, id
						Utils.closeIssue id
					]
					.then () ->
						deferred.resolve "Task #{id} closed!"
					.catch (error) ->
						deferred.reject error
					.done()
				return
			.catch (error) ->
				deferred.reject error
			.done()
		catch ex
			deferred.reject ex
		return deferred.promise

	@getStatusAndOwnerOfTask: (id) ->
		deferred = q.defer()
		try
			request.get
				"url": "#{base_url}/#{encodeURIComponent id}"
				"headers": headers
			,
				(error, response, body) ->
					try
						if not error and response.statusCode == 200
							data = JSON.parse body
							owner = null
							if data["body"]?
								info = toml.parse data["body"]
								if info["user"]? and info["user"]["name"]?
									owner = info["user"]["name"]
							deferred.resolve [data["state"], owner]
						else
						deferred.reject if error then error else body
					catch ex
						deferred.reject ex
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
						"user": user
					, null, 2}
					"""
			,
				(error, response) ->
					try
						if not error and response.statusCode == 201
							deferred.resolve true
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
						deferred.resolve true
					else
						deferred.reject if error then error else body
					return
		catch ex
			deferred.reject ex
		return deferred.promise
