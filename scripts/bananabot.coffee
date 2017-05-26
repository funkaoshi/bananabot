# Description:
#   Bananabot helps you find someone to split a banana with.
#
# Commands:
#   bananabot split a banana - let people know you are interested in sharing a banana.
#   bananabot me - reply to bananabot's search for banana loving people that aren't that hungry.
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

  robot.respond /me/i, (res) ->
    split_a_banana res
