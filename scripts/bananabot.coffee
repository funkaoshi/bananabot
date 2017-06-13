# Description:
#   Bananabot helps you find someone to split a banana with.
#
# Commands:
#   bananabot split a banana - let people know you are interested in sharing a banana.
#   bananabot me - reply to bananabot's search for banana loving people that aren't that hungry.
#   bananabot rules - print the robot rules
#
# Author:
#   funkaoshi

module.exports = (robot) ->

  split_a_banana = (res) ->
    user = res.message.user.name
    splitter = robot.brain.get('splitter')

    if splitter and user != splitter
      res.send "Hey \@#{user} and \@#{splitter} go share a banana!"
      splitter = robot.brain.remove('splitter')
    else
      res.send "@all anyone want to split a banana with #{user}?"
      robot.brain.set('splitter', user)

  robot.hear /(split a banana)|(share a banana)/i, (res) ->
    split_a_banana res

  robot.respond /(me)|(yes)|(sure)|(ok)|(i do)/i, (res) ->
    split_a_banana res

  robot.hear /(banana bandit struck)|(banana bandit has struck)/ ->
    splitter = robot.brain.get('splitter')
    if splitter
      res.send "Hey \@#{splitter} there is half a banana in the kitchen."
    else
      res.send "There is half a banana in the kitchen!"

  robot.hear /(add)(.*)(test)/ ->
    user = res.message.user.name
    res.send "Nice job \@{user} on that new test."

  robot.respond /rules/i, (res) ->
    version = 0.4
    res.send "Rule 1: Don't leave half of a banana. (v{version})"
