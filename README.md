# Garbage: Road to Ace

A single-player portrait card game built with Godot 4.7. This repository contains the Godot project, card artwork, tutorial video, music, and sound effects.

## Open it
1. Extract the project folder.
2. Open Godot 4.7.
3. Import `project.godot`.
4. Run the project.

The prototype targets a 720 × 1280 portrait viewport.

## Current flow
- Main menu with Easy, Normal, and Hard CPU difficulty.
- `Learn by Playing` launches a controlled interactive tutorial.
- `Watch Tutorial` plays the supplied real tabletop gameplay video inside the app.
- Normal match progression is shown as the **Road to Ace** for both the player and CPU.
- Round-win screens show each player's current stage.
- The final Ace win uses a dedicated `ROAD TO ACE COMPLETE` result.

## Rules implemented
- There are only two table piles: the main draw deck and one discard pile.
- At the start of a turn, the player chooses either the top discard card (when playable) or draws from the main deck.
- There is no separate “In Play” pile; the currently resolving card is shown over the discard area only while it is being played.
- Each player begins at 10 face-down positions representing Ace through 10.
- A matching card replaces the face-down card in that numbered position.
- The displaced hidden card becomes the next active card, allowing chains.
- Jacks, Queens, and Kings are dead cards.
- Jokers are wild.
- Once a Joker is assigned to a position, it is permanently locked to that position for the remainder of the round.
- If the natural card for a Joker-filled position is later drawn, that natural card is dead.
- The first player to reveal all current positions wins the round.
- Only the round winner moves down one stage: 10 → 9 → 8 → 7 → 6 → 5 → 4 → 3 → 2 → Ace.
- The first player to complete the single-Ace stage wins the full match.

## Interactive tutorial sequence
The practice round deliberately teaches:
1. Draw a 4 and place it in position 4.
2. Continue the chain with the revealed 8.
3. Discard a revealed King as a dead face card.
4. Draw a Joker and lock it into the Ace position.
5. Discard the Queen revealed underneath it.
6. Draw the natural Ace and see that it is now dead because the Joker is permanently occupying Ace.
7. Finish with an explanation of the complete 10-to-Ace match structure.

During the tutorial, face-down positions are labeled A through 10 for new players.

## Video tutorial
`tutorial/tutorial.ogv` is a mobile-sized Godot-compatible conversion of the supplied gameplay recording, including its audio. The in-app tutorial screen provides Play/Pause, Restart, and Back controls.

For a final App Store build, this file can be replaced with a professionally edited version using the same filename without changing the game code.

## Main files
- `scripts/game.gd` — rules, AI, match progression, menus, interactive tutorial, video tutorial UI.
- `scripts/card_view.gd` — card rendering, highlighting, tutorial position badges, interaction.
- `assets/wood.gdshader` — warm tabletop background treatment.
- `tutorial/tutorial.ogv` — watchable gameplay tutorial.

