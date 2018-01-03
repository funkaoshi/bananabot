# Description:
#   Bananabot helps you find someone to split a banana with.
#
# Commands:
#   bananabot split a banana - let people know you are interested in sharing a banana.
#   bananabot me - reply to bananabot's search for banana loving people that aren't that hungry.
#   bananabot rules - print the robot rules
#   bananabot balance - how many bananas do you have left to give out
#   message with a :banana: in it along with a @username - give @username a banana
#
# Author:
#   funkaoshi
#

schedule = require 'node-schedule'

module.exports = (robot) ->

  # How many bananas does a user have to give away each day.
  INITIAL_BANANAS_PER_USER = 5

  # The URL of the server banana bot is connecting to
  BASE_URL = process.env.HUBOT_LCB_PROTOCOL + "://" +
             process.env.HUBOT_LCB_HOSTNAME + ":" +
             process.env.HUBOT_LCB_PORT

  try
    # These users can not give or receive recognition
    BLACKLIST = process.env.BANANA_BOT_BLACKLIST.split(",")
  catch
    BLACKLIST = []


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


  # Valid recognition messages shouldn't just be a list of names and a banana.
  valid_recognition = (message) ->
    console.log "Validate the recognition."
    strip_mentions = message.replace(/@(\w+)/ig, '')
    strip_bananas = strip_mentions.replace(/🍌|(:banana:)/ig, '')
    strip_whitespace = strip_bananas.replace(/\s/, '').trim()

    console.log "Strip mentions: '#{strip_mentions}'"
    console.log "Strip bananas: '#{strip_bananas}'"
    console.log "Strip whitespace: '#{strip_whitespace}'"

    return !! strip_whitespace


  # Pull the valid recipients out of a message. The user who is giving away
  # bananas can't give a banana to themselves
  valid_recipients = (username, message) ->
    console.log("#{username} is giving bananas to people mentioned in #{message}")

    mentioned_user_names = message.match(/@(\w+)/g)
    if not mentioned_user_names.length
      return {}

    recipients = {}
    for recipient in mentioned_user_names
      console.log "Looking for #{recipient}"
      recipient = recipient.slice(1)
      recipient_user = user_for_name recipient
      if (recipient_user and
          recipient != username and
          recipient != robot.name and
          recipient not in BLACKLIST)
        console.log "And we found #{recipient}!"
        recipients[recipient] = recipient_user.id

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
  get_bananas_for_users = (user_id, bananas_desired) ->
    console.log "Find bananas for #{user_id}"

    user = user_for_id user_id
    if user == undefined
      return

    recognition_bananas = robot.brain.get("recognition_bananas") || init_recognition_bananas_counters()

    if user_id of recognition_bananas
      remaining_bananas = recognition_bananas[user_id]
    else
      remaining_bananas = INITIAL_BANANAS_PER_USER

    console.log "#{user.username} has #{remaining_bananas} in their cache of bananas and want #{bananas_desired}."

    if remaining_bananas - bananas_desired < 0
      return -1

    recognition_bananas[user_id] = remaining_bananas - bananas_desired

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
    if user.name in BLACKLIST
      msg.send "Sorry, you aren't allowed to give recognition."
      return

    if not valid_recognition msg.message.text
      msg.send "Hey @#{user.name}, put a bit more effort into that recognition."
      return

    recipients = valid_recipients user.name, msg.message.text
    number_of_recipients = Object.keys(recipients).length
    if number_of_recipients == 0
      return

    bananas = get_bananas_for_users(user.id, number_of_recipients)
    if bananas < 0
      msg.send "Sorry, you don't have enough bananas to give away!"
      return

    for recipient, recipient_id of recipients
      console.log "Giving a banana to #{recipient}."
      update_leaderboard recipient_id, 1

    recipient_names = ["@#{recipient}" for recipient, recipient_id of recipients].join(', ')

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


  # How many bananas does a user have to give out?
  robot.respond /balance/i, (msg) ->
    console.log "How many bananas do you have left?"

    user = msg.message.user
    bananas = get_bananas_for_users(user.id, 0)

    response = "Hey @#{user.name} you have #{bananas} bananas left."

    console.log response
    msg.send response


  # reset the recognition state (for debugging)
  robot.respond /reset/i, (msg) ->
    if msg.message.user.name != process.env.BANANA_BOT_SUPERUSER
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
  robot.hear /banana bandit(.*)struck/i, (msg) ->
    splitter = robot.brain.get('splitter')
    if splitter
      msg.send "Hey \@#{splitter} there is half a banana in the kitchen."
    else
      msg.send "There is half a banana in the kitchen!"


  # Positive Feedback!
  robot.hear /(add)(.*)(test)/i, (msg) ->
    user = res.message.user.name
    msg.send "Nice job \@#{user} on that new test."

  robot.hear /(bananatime)/i, (msg) ->
    msg.send "https://media.giphy.com/media/IB9foBA4PVkKA/giphy.gif"


  # Return the version of the bot.
  robot.respond /rules/i, (msg) ->
    version = 0.6
    msg.send "Rule 1: Don't leave half a banana in the kitchen. (v{version})"


  # Reset the banana counters at the start of each day
  schedule.scheduleJob '* * * 0 0 0', init_recognition_bananas_counters()
  schedule.scheduleJob '* * * 0 0 0', fetch_valid_users()

