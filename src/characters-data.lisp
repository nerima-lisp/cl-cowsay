;;;; src/characters-data.lisp
;;;;
;;;; DATA only: every built-in character, as a DEFCHARACTER form (src/
;;;; macros.lisp). Each is original ASCII art written for this project --
;;;; none of it is copied from, or a rendering of, upstream cowsay's .cow
;;;; files. Character storage and the CHARACTER-TEMPLATE structure live in
;;;; src/characters-definitions.lisp; registry operations live in
;;;; src/characters.lisp.

(in-package #:cl-cowsay)

;; The default. Ears, a two-character ${eyes} slot, a body that carries
;; ${tongue} (empty by default), and two hoof legs.
(defcharacter cow
  "        ${thoughts}   ^__^"
  "         ${thoughts}  (${eyes})"
  "            (__${tongue})"
  "             u  u")

;; Whiskers, a ${eyes} slot between them, and a ${tongue} slot at the mouth.
(defcharacter cat
  "       ${thoughts}   /\\_/\\"
  "        ${thoughts}  (${eyes} )"
  "              >${tongue}<"
  "             /     \\")

;; A boxy head with an ${eyes}/${tongue} display panel and an antenna.
(defcharacter robot
  "          ${thoughts}    (_)"
  "         ${thoughts}  .-----."
  "          ${thoughts} |${eyes} ${tongue}|"
  "            '--|-|--'"
  "               |_|")

;; A wavy-bottomed sheet with a face; ${tongue} shows as a small mouth mark.
(defcharacter ghost
  "        ${thoughts}   .-\"\"-."
  "         ${thoughts}  (${eyes}${tongue})"
  "             )      ("
  "            ^  ^  ^  ^")

;; A long-necked, horned reptile; ${tongue} flickers at the jaw.
(defcharacter dragon
  "        ${thoughts}    ^..^"
  "         ${thoughts}  <${eyes}>"
  "             (__${tongue})~"
  "             ^^  ^^")

;; A round-bellied bird with stubby flippers; ${tongue} is the beak's edge.
(defcharacter penguin
  "        ${thoughts}    .--."
  "         ${thoughts}  (${eyes})"
  "             /|${tongue}|\\"
  "             '  '")

;; Pointed ears and a trailing tail flourish distinguish it from "cat".
(defcharacter fox
  "        ${thoughts}   /\\   /\\"
  "         ${thoughts}  (${eyes} )"
  "              >${tongue}<   ,"
  "            /      \\--<")

;; A round-headed bird with big eyes and a tucked beak.
(defcharacter owl
  "        ${thoughts}    ,^,"
  "         ${thoughts}  (${eyes})"
  "              (${tongue})"
  "             ^     ^")

;; Small rounded ears and a stocky build.
(defcharacter bear
  "        ${thoughts}   ,-.-,"
  "         ${thoughts}  (${eyes} )"
  "             (__${tongue})"
  "             u    u")

;; Long upright ears; ${tongue} shows as the nose mark.
(defcharacter rabbit
  "        ${thoughts}   (\\_/)"
  "         ${thoughts}  (${eyes} )"
  "             (\")${tongue}(\")"
  "             ^    ^")

;; Small round ears and a curling tail flourish.
(defcharacter mouse
  "        ${thoughts}   ,.  ,."
  "         ${thoughts}  (${eyes})~"
  "             (__${tongue})"
  "              u  u")

;; No limbs, just a long curved body and a forked-tongue flick.
(defcharacter snake
  "        ${thoughts}   ~~^~~"
  "         ${thoughts}  <${eyes}>${tongue}"
  "           \\_________/")

;; A featureless dome head with a small oval mouth.
(defcharacter alien
  "        ${thoughts}    .-."
  "         ${thoughts}  ( ${eyes} )"
  "             ( ${tongue} )"
  "             '-...-'")

;; Round fluffy ears set wide apart.
(defcharacter koala
  "        ${thoughts}  (=)  (=)"
  "         ${thoughts}  (${eyes})"
  "             (__${tongue})"
  "             u    u")

;; Same silhouette as ${cat}, marked out by a row of stripe flourishes below.
(defcharacter tiger
  "        ${thoughts}   /\\_/\\"
  "         ${thoughts}  (${eyes} )~"
  "              >${tongue}<"
  "            =^=^=^=^=")

;; A shaggy mane framing the face on both sides.
(defcharacter lion
  "        ${thoughts}  (\\_._/)"
  "         ${thoughts}  (${eyes} )"
  "              >${tongue}<"
  "            (\\(   )/)")

;; Squared-off ears and black-and-white patches.
(defcharacter panda
  "        ${thoughts}   .-. .-."
  "         ${thoughts}  (${eyes})"
  "             (__${tongue})"
  "             u    u")

;; Floppy ears and a wagging-tongue mouth.
(defcharacter dog
  "        ${thoughts}   /'-'\\"
  "         ${thoughts}  (${eyes} )"
  "              >${tongue}<"
  "             u ~ u")

;; Pointed ears and a howling, open-mouthed jaw.
(defcharacter wolf
  "        ${thoughts}   /\\___/\\"
  "         ${thoughts}  (${eyes}   )"
  "              \\ ${tongue} /"
  "               ---")

;; A domed shell over a small peeking head.
(defcharacter turtle
  "        ${thoughts}    ___"
  "         ${thoughts}  /(${eyes})\\"
  "             ${tongue}(     )"
  "              ^^  ^^")

;; Eyes bulge above the waterline; ${tongue} sits in a wide, flat mouth.
(defcharacter frog
  "        ${thoughts}    @${eyes}@"
  "         ${thoughts}   (  ${tongue}  )"
  "              /      \\"
  "             ^        ^")

;; A row of back spikes in place of fur.
(defcharacter hedgehog
  "        ${thoughts}   ^^^^^^^"
  "         ${thoughts}  (${eyes} )>"
  "              >${tongue}<"
  "             ^ ^ ^ ^")

;; Small ears and a bushy tail curled up beside the body.
(defcharacter squirrel
  "        ${thoughts}   /\\/\\"
  "         ${thoughts}  (${eyes} )"
  "              >${tongue}<  @"
  "             ^    ^ \\_/")

;; Folded wings frame the face instead of ears.
(defcharacter bat
  "        ${thoughts}  /\\ ${eyes} /\\"
  "         ${thoughts} ((  ${tongue}  ))"
  "             \\/    \\/")

;; A single spiraled horn above the face.
(defcharacter unicorn
  "        ${thoughts}    /\\"
  "         ${thoughts}  (${eyes} )^"
  "             (__${tongue})"
  "             u    u")

;; A round head over a fan of trailing tentacles.
(defcharacter octopus
  "        ${thoughts}   .-----."
  "         ${thoughts} ( ${eyes} ${tongue} )"
  "           '-.-.-.-.-'"
  "            ) ) ) ) )")

;; Two raised claws over a low, wide body.
(defcharacter crab
  "        ${thoughts}  \\_${eyes}_/"
  "         ${thoughts} <     >"
  "             /  ${tongue}  \\"
  "            ^^     ^^")

;; Rounded double-loop wings above a striped body.
(defcharacter bee
  "        ${thoughts}    ,--."
  "         ${thoughts}  ((${eyes}))~"
  "            \\=${tongue}=/"
  "             ^^^^")

;; Empty eye sockets and a bared row of teeth.
(defcharacter skull
  "        ${thoughts}    .---."
  "         ${thoughts}   |${eyes}|"
  "              |${tongue}|"
  "              '-\"-'")
