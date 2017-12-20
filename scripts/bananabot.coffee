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
  BASE_URL = process.env.HUBOT_LCB_PROTOCOL + "://" +
             process.env.HUBOT_LCB_HOSTNAME + ":" +
             process.env.HUBOT_LCB_PORT


  # Retrieve the user list from the server and store it locally
  fetch_valid_users = () ->
    robot.http(BASE_URL + "/users")
      .header('Authorization', 'Bearer ' + process.env.HUBOT_LCB_TOKEN)
      .get() (err, res, body) ->
        # todo: some error checking

        valid_user_ids = {}
        valid_usernames = {}
        for user in JSON.parse(body)
          console.log("#{user.id} -> #{user.username}")
          valid_user_ids[user.id] = user
          valid_usernames[user.username] = user

        valid_users = {
          'usernames': valid_usernames,
          'ids': valid_user_ids
        }
        robot.brain.set("valid_users", valid_users)

        return valid_users


  # For a given user name look up the user
  user_for_name = (username) ->
    valid_users = robot.brain.get("valid_users") || fetch_valid_users()
    return valid_users['usernames'][username]


  # For a given user ID look up the user
  user_for_id = (user_id) ->
    valid_users = robot.brain.get("valid_users") || fetch_valid_users()
    return valid_users['ids'][user_id]


  # Pull the valid recipients out of a message. The user who is giving away
  # bananas can't give a banana to themselves
  valid_recipients = (username, message) ->
    console.log("#{username} is giving bananas to people mentioned in #{message}")

    mentioned_user_names = message.match(/@(\w+)/g)

    recipients = []
    for recipient in mentioned_user_names
      recipient = recipient.slice(1)
      recipient_user = user_for_name recipient
      if recipient_user and recipient != username
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

    user = user_for_id user_id
    if user == undefined
      return

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

    recipients = valid_recipients user.name, msg.message.text
    if recipients
      for recipient in recipients
        console.log "Giving a banana to #{recipient.username}."
        update_leaderboard recipient.id, 1

      recipient_names = ["@#{recipient.username}" for recipient in recipients].join(', ')

      msg.send "Great job #{recipient_names}. #{user.name} you have #{bananas} left to give!"


  # Returns the list of users and their recognition stats
  robot.respond /leaderboard/i, (msg) ->
    console.log "These people got some love from their coworkers."

    leaderboard = robot.brain.get("leaderboard") || init_banana_leaderboard()

    keys = Object.keys(leaderboard).sort (a, b) -> leaderboard[b] - leaderboard[a]
    keys = keys.filter (a) -> leaderboard[a] > 0
    response = "Who has received the most bananas?!\n"
    for user_id in keys
      response += "#{user_for_id(user_id).username}: #{leaderboard[user_id]}\n"

    msg.send response


  # reset the recognition state (for debugging)
  robot.respond /reset/i, (msg) ->
    if msg.message.user.name != 'ramanan'
      return

    init_banana_leaderboard()
    init_recognition_bananas_counters()
    fetch_valid_users()
    msg.send "Done"


  # users in the system (for debugging)
  robot.respond /users/i, (msg) ->
    valid_users = robot.brain.get("valid_users") || fetch_valid_users()
    response = ""
    for user_id, user of valid_users['ids']
      response += "#{user.id} -> #{user.username}\n"
    msg.send response



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

