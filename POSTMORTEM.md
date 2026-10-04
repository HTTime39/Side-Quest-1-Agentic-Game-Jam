---
# ---- Fill every field. Use `unavailable` (with a reason in tokens_source) rather than guessing. ----
game_title: "The Deep"
twist_one_liner: "The stage is dark illuminated by your angler fish light with upgrades to help light up your way to victory." # "ARENA, but ..."
twist_category: "Three new enemies (two regular + boss fight), rule-bender (dark stages + different attack), player progression (upgrades)" # rule-bender | enemies | player-progression | world | other
twist_from_ideas_list: "Yes (darkness, level up cards), adapted (whale shark boss is similar to charger enemy type)" # yes | adapted | no
how_far_from_arena: "Some small twists, and some medium twists" # small-twist | substantial | barely-recognizable

# Tools and models (lists; exact names as the tool shows them)
tools: [GitHub Copilot]         # e.g. [claude-code, chatgpt-web]
models: [gpt-6-luna]            # e.g. [claude-sonnet-5, gpt-5-mini]
primary_model: "gpt-6-luna"     # the one that did most of the work
plan: "student"                 # free | student | paid-personal | api | none
agent_instructions_file: no     # yes | no  (CLAUDE.md, AGENTS.md, .cursorrules, ...)

# Totals (must match jam-log.csv)
sessions: 7
total_minutes: 429
total_prompts: 69
total_tokens_in: Unavailable    # or unavailable
total_tokens_out: Unavailable   # or unavailable
tokens_source: Unavailable, GitHub Copilot through VSCode didn't report token usage  # ccusage | cost-command | dashboard | cli-summary | estimated | unavailable (+ why)

# Your estimate of who wrote the code in the final build (should add to 100)
code_share_llm_pct: 99          # accepted from an LLM with little or no change
code_share_mixed_pct: 0         # LLM-generated then substantially edited by you
code_share_hand_pct: 1          # written by you

# Before this jam
odin_experience_before: "none"  # none | under-10h | 10-50h | over-50h
llm_coding_before: "Extremely occasional"   # never | occasional | weekly | daily
gamedev_experience_before: "A few small games"    # none | a-tutorial | a-few-small-games | shipped-something

transcripts_shared: no         # yes | no  (optional, ungraded)
---

# Postmortem — The Deep

> Your own words. Grammar and spelling help from a tool is fine; the argument
> and the evidence are yours. Aim for 1-2 pages plus the table.

## 1. The game

One paragraph: what your game is and how to play it. Then what you **kept**,
**changed**, **removed** and **added** compared with ARENA.

**Where is the depth?** Answer the three questions from the README: the new
**decision** the twist creates, the **trade-off** behind it, and what an
**expert** does differently from a beginner. Use what you saw players do at
the Monday showcase as evidence.

In my game, you play as an anglerfish that shoots light beams from its lure light to attack the other hostile fish around you. Enemies approach from the edges of the screen like the base ARENA game. The whole stage is dark with the only visible areas being directly around the player and around the light beams you shoot. The different enemy types approach according to different movement rules. The red octopus approaches the player directly. The blue crabs can only approach by moving directly up, down, left, and right to approach the player at a faster speed. The yellow squids can only approach the player moving on diagonals at an even faster speed than the blue crab. I also added stages that end after the player kills set numbers of hostile fish. After the fifth stage, a giant whale shark spawns in as the final boss. The game ends after the whale shark is defeated. 

The darkness and light beams change the player's attacks into a scouting/probing tool as well. Player's need to decide for each of their shots whether they will try to kill enemies or scout ahead into the dark. The different movement patterns of the added enemies also change the movement patterns that the player can use effectively as they can't just herd enemies in a circle like you could when there were only enemies directly towards the player. 

The trade off of this is that it can be challenging to learn the differences between the enemy types quickly since the player can't see them most of the time. This can become frustrating to newer players as they may get damaged by something they don't see or notice. 

Since a few play throughs are required to determine the patterns of the enemies, a pro would have devised movement and shooting strategies that work around the movement patterns of the different enemies. In contrast, a beginner may move around randomly and shoot in random directions where they see the hostile blinking lights. 

## 2. Your setup

Which tools and models, and **why** those (cost, familiarity, a friend's
advice...). Did you give the agent a project instruction file, the Raylib
binding, docs, example code? Paste the instruction file, or its key lines, if
you used one.

I used GitHub Copilot for the project. I chose this because I was able to get access to it within VSCode for free through GitHub's student pack. I didn't give Copilot any instruction files. I only interacted it with it through the chat window where I gave it instructions on what I wanted it to do. I didn't give it the Raylib bindings but I gave it permission whenever it had a knowledge gap to scout through the local framework files/SDK on my computer to learn whatever it needed. 

## 3. Feature by feature

One row per feature you built. The first rows are ARENA's parts; drop the ones
you removed, and add a row for each feature of your own.
`who` = `llm`, `mixed` or `me`. `first try` = did the first LLM answer work
without changes? `help` = 1 (got in the way) - 5 (did it well).

| feature | who | prompts | first try? | minutes | help 1-5 | note |
|---|---|--:|---|--:|:--:|---|
| window, loop, game states, restart | Copilot | 1 | yes | 2 | 5 | |
| player movement | Copilot | 1 | yes | 2 | 5 | |
| shooting | Copilot | 3 | no | 20 | 5 | |
| enemies and spawning | Copilot | 12 | no | 180 | 5 | Copilot had a hard time with drawing enemies and needed multiple tries to get them to appear right. It also need multiple tries to change how they move to be distinct/tuned |
| health, damage, hit feedback | Copilot | 1 | yes | 2 | 5 | |
| difficulty over time | Copilot | 1 | yes | 2 | 5 | |
| HUD | Copilot | 3 | yes | 20 | 5 | I used multiple prompts to iterate what appears as a part of the HUD |
| (optional) sprites / sound | Copilot | 10 | no | 120 | 5 | Copilot struggled with triangle winding orders and positioning |
| Background | Me | n/a | n/a | 30 | 1 | I drew the background using Paint3D |
| Darkness | Copilot | 2 | yes | 5 | 5 | I had to describe the darkness effect a few times for Copilot to get it right |
| Level up cards | Copilot | 10 | no | 60 | 5 | I iterated on the effects of the upgrades and had to describe some of them multiple times to get the right effects |

## 4. Where the LLM sped you up

The easy parts. Name the features, the session number from `jam-log.csv` or
the commit, and estimate how long it would have taken you without it.

Copilot did all of the coding. It got the base ARENA game completed in a single prompt with everything working. After that it was able to complete most features in one or two prompts. It wrote basically all of the code and I only tweaked a few values here and there when tuning the difficulty. Without Copilot, I probably would have taken over 20 hours to complete this since I'd have to learn Odin syntax from scratch as well as the typical architecture of games using Raylib.

## 5. Where it did not help

The hard parts. What was the problem, what did you try (prompts, other models,
docs, a classmate, doing it by hand), and what finally worked? Was the
difficulty Odin, Raylib, game design, tuning the feel, or the tool itself?

The only technical feature it had a hard time implementing was the movement of the rear laser upgrade. I remedied this by reiterating and trying to explain in more detail what I wanted it to do. Additionally, Copilot had a hard time with drawing the various fish in the game. The red octopus and the blue crab it got right on the first try. When it tried drawing the yellow squid, the triangle making its head wasn't appearing. I asked it to check its triangle vertex wind order since I remembered that being important for drawing triangles in computer graphics and that solved the issue. It kept having the same issue when I was specifying what to draw for the whale shark. I had to get really specific when describing what shapes to use and how to colour them in before finally getting a whale shark I was satisfied with. I think this came from a limitation of Copilot's knowledge of Raylib as well as its inability to actually see what it's drawing.

## 6. One LLM-introduced bug: found, fixed, verified

- **The bug**: what it did wrong, and the code (a short excerpt or a commit link).
- **How you noticed**.
- **The fix**: the code after.
- **How you know it is fixed**: the evidence (debug draw, printed values, a
  test, a before/after clip or screenshot in the repo).

Copilot specified triangle vertices for parts of the yellow squid in the wrong order so its head wasn't appearing due to back face culling. I noticed this because freaky eyes with tentacles were all that were appearing. After asking it to draw the triangle explicitely and it not appearing, I asked it to check if the vertex wind order was causing it to not to appear. It realized that this was the issue and was able to correct it after that with the triangular head bit now appearing. 

## 7. Pitch vs. delivered

Paste your Wednesday pitch. What survived, what was cut, what was added, and why.
What did you change after the Monday showcase, based on how people played it?

On Wednesday, my game only had the three enemy types that were just shapes, darkness, and the end game condition was based on a time limit. Since then, I've implemented the recommended advice of adding a theme (fish sprites and background), a progression system (upgrade cards), the levels, and the final boss. 

## 8. Improving the pipeline

If you did another jam next week with the same tools, what would you change?
Be concrete: setup, instruction files, prompting habits, when to use the LLM
and when not, commit rhythm, how you verify, which model for which job.
What would you want **from the tools** that they do not do today?

I think I'd be satisfied sticking with the same tools again. However I'd be interested to try out Claude code since I hear a lot of good things about it. I'm hesitant to try it though since it's kind of pricey. I think instruction files might be something useful to try out but I'm not entirely sure what I'd put in them to make Copilot more effective than it already has been. I think to try and be more clear to Copilot, I'd shorten my prompts and try to be as descript as possible about a single addition at a time so I don't have to spend as much time fighting with it over my intention. I think my commit rhythm was pretty good by grouping related features/additions together into commits but it might have been a good idea to try and separate features into their own commits more to act as smaller checkpoints of progress. If I were to improve the tools from what I had today, I think I'd like to have the responses from Copilot be a little more verbose in its replies when explaining what it's doing and why. I also think it would be cool/useful to be able to talk back and forth with my voice to Copilot within my VSCode chat window. 

## 9. Anything else

Optional: what surprised you, what you learned about Odin, Raylib or game
development, what you would tell next year's class.

I was suprised at how effective Copilot was at knowing what I wanted and how quickly it was able to implement it. I had never used an LLM like this before so it was an interesting experience and I think I'll probably try to make use of Copilot like this more in future projects. 