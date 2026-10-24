#!/bin/bash
set -e

PSQL="psql --username=freecodecamp --dbname=number_guess -q -t --no-align -v ON_ERROR_STOP=1"

printf 'Enter your username:\n'
IFS= read -r USERNAME

USER_ID=$(printf '%s\n' "SELECT user_id FROM users WHERE username = :'username';" |
  $PSQL -v username="$USERNAME")

if [[ -z $USER_ID ]]; then
  USER_ID=$(printf '%s\n' "INSERT INTO users (username) VALUES (:'username') RETURNING user_id;" |
    $PSQL -v username="$USERNAME")
  printf 'Welcome, %s! It looks like this is your first time here.\n' "$USERNAME"
else
  STATS=$(printf '%s\n' "SELECT COUNT(*), COALESCE(MIN(number_of_guesses), 0) FROM games WHERE user_id = :user_id;" |
    $PSQL -v user_id="$USER_ID")
  GAMES_PLAYED=${STATS%%|*}
  BEST_GAME=${STATS#*|}
  printf 'Welcome back, %s! You have played %s games, and your best game took %s guesses.\n' \
    "$USERNAME" "$GAMES_PLAYED" "$BEST_GAME"
fi

SECRET_NUMBER=$((RANDOM % 1000 + 1))
NUMBER_OF_GUESSES=0

printf 'Guess the secret number between 1 and 1000:\n'
while IFS= read -r GUESS
do
  if [[ ! $GUESS =~ ^[0-9]+$ ]]; then
    printf 'That is not an integer, guess again:\n'
    continue
  fi

  GUESS_NUMBER=$((10#$GUESS))
  NUMBER_OF_GUESSES=$((NUMBER_OF_GUESSES + 1))
  if (( GUESS_NUMBER < SECRET_NUMBER )); then
    printf "It's higher than that, guess again:\n"
  elif (( GUESS_NUMBER > SECRET_NUMBER )); then
    printf "It's lower than that, guess again:\n"
  else
    printf 'You guessed it in %s tries. The secret number was %s. Nice job!\n' \
      "$NUMBER_OF_GUESSES" "$SECRET_NUMBER"
    printf '%s\n' "INSERT INTO games (user_id, number_of_guesses) VALUES (:user_id, :number_of_guesses);" |
      $PSQL -v user_id="$USER_ID" -v number_of_guesses="$NUMBER_OF_GUESSES"
    break
  fi
done
