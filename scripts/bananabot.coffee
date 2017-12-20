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
#

schedule = require 'node-schedule'

module.exports = (robot) ->

  # How many bananas does a user have to give away each day.
  INITIAL_BANANAS_PER_USER = 5


  # Pull the valid recipients out of a message
  valid_recipients = (message) ->
    mentioned_user_names = message.match(/@(\w+)/g)

    recipients = []
    for recipient in mentioned_user_names
      recipient = recipient.slice(1)
      recipient_user = robot.brain.userForName recipient
      if recipient_user
        recipients.push recipient_user

    return recipients


  # Create an empty leaderboard
  init_banana_leaderboard = () ->
    console.log "Creating a new leaderboard."
    robot.brain.set("leaderboard", {})
    return {}


  # Reset the counters for tracking the bananas users have to hand out.
  init_recognition_bananas_counters = () ->
    console.log "Init the bananas per user tracker."
    robot.brain.set("recognition_bananas", {})
    return {}


  # Fetch and update the users remaining bananas to give out as recognition.
  remaining_bananas = (user_id) ->
    recognition_bananas = robot.brain.get("recognition_bananas") || init_recognition_bananas_counters()

    user = robot.brain.userForId user_id
    console.log "Looking up remaining bananas for #{user.name}"

    # this whole construct seems dumb, can we write this nicer?
    if user_id of recognition_bananas
      recognition_bananas[user_id] = recognition_bananas[user_id] - 1
    else
      recognition_bananas[user_id] = INITIAL_BANANAS_PER_USER - 1

    return recognition_bananas[user_id]


  # Assign the given user N bananas
  update_leaderboard = (user_id, bananas) ->
    leaderboard = robot.brain.get("leaderboard") || init_banana_leaderboard()
    if user_id of leaderboard
      leaderboard[user_id] += bananas
    else
      leaderboard[user_id] = bananas


  # When you hear a banana message update the banana leaderboard
  robot.hear /🍌|(:banana:)/i, (msg) ->
    console.log "It's Banana Time!"

    user = msg.message.user
    bananas = remaining_bananas user.id
    if bananas < 0
      msg.send "Sorry, you've given away all your bananas!"
      return

    recipients = valid_recipients msg.message.text
    for recipient in recipients
      console.log "Giving a banana to #{recipient.name}."
      update_leaderboard recipient.id, 1

    recipient_names = ["@#{recipient.name}" for recipient in recipients].join(', ')

    msg.send "Great job #{recipient_names}. #{user.name} you have #{bananas} left to give!"


  # Returns the list of users and their recognition stats
  robot.respond /leaderboard/i, (msg) ->
    console.log "These people got some love from their coworkers."

    leaderboard = robot.brain.get("leaderboard") || init_banana_leaderboard()

    keys = Object.keys(leaderboard).sort (a, b) -> leaderboard[b] - leaderboard[a]
    keys = keys.filter (a) -> leaderboard[a] > 0
    response = "Who has received the most bananas?!\n"
    for user_id in keys
      response += "#{robot.brain.userForId(user_id).name}: #{leaderboard[user_id]}\n"

    msg.send response


  # reset the recognition state (for debuging)
  # robot.respond /reset leaderboard/i, (msg) ->
  #  robot.brain.set("leaderboard", {})
  #  msg.send "Done"


  # When the bot hears discussion of banana sharing / splitting, it will
  # help find a partner to share with.
  split_a_banana = (res) ->
    user = res.message.user.name
    splitter = robot.brain.get('splitter')

    if splitter and user != splitter
      res.send "Hey \@#{user} and \@#{splitter} go share a banana!"
      splitter = robot.brain.remove('splitter')
    else
      res.send "@all anyone want to split a banana with #{user}?"
      robot.brain.set('splitter', user)

  robot.hear /(split a banana)|(share a banana)/i, (res) -> split_a_banana res
  robot.respond /(me)|(yes)|(sure)|(ok)|(i do)/i, (res) -> split_a_banana res

  # When banabot hears that there is half a banana in the kitchen it'll let
  # let the team know.
  robot.hear /banana bandit(.*)struck/i, (res) ->
    splitter = robot.brain.get('splitter')
    if splitter
      res.send "Hey \@#{splitter} there is half a banana in the kitchen."
    else
      res.send "There is half a banana in the kitchen!"


  # Positive Feedback!
  robot.hear /(add)(.*)(test)/i, (res) ->
    user = res.message.user.name
    res.send "Nice job \@#{user} on that new test."


  # Return the version of the bot.
  robot.respond /rules/i, (res) ->
    version = 0.5
    res.send "Rule 1: Don't leave half a banana in the kitchen. (v{version})"


  # Reset the banana counters at the start of each day
  schedule.scheduleJob '* * * 0 0 0', init_recognition_bananas_counters()

