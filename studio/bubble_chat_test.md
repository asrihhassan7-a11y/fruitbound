# FruitBound — Bubble Chat live test

Run after `studio/bubble_chat_fix.lua` printed `DONE - all steps OK/SKIP`.
Studio: Test > Clients and Servers > **2 players** (Local Server). Keep the server Output open.

Mark each line PASS / FAIL and write what you saw on FAIL.

## Setup check (server Output or command bar in the server window)
- [ ] `print(game:GetService("TextChatService").ChatVersion)` → `Enum.ChatVersion.TextChatService`
- [ ] No `Infinite yield possible on 'ServerScriptService:WaitForChild("ChatServiceRunner")'`

## 2-player test
| # | Test | Expected | Result |
|---|------|----------|--------|
| 1 | Player1 says `hello` | Bubble above Player1's head, readable, rounded, seen by both players; chat-window line shows `[title] Name: hello` | |
| 2 | Player1 sends 5 messages fast | Max 3 bubbles stacked, oldest drop off, no duplicate bubble per message | |
| 3 | Wait ~15 s | Bubbles fade out, none stuck | |
| 4 | Player1 resets (Esc > Reset), then chats | New character gets bubbles, no Output errors | |
| 5 | Player1 uses Travel (My Farm ↔ Village), then chats | Bubble on Player1 at new location, not left at the old spot | |
| 6 | Player2 leaves and rejoins (stop that client, start a new one), then chats | Bubbles work for the rejoined player | |
| 7 | Both players stand together and chat back and forth | Each bubble on the correct character, no overlap with names | |
| 8 | Stand ~90 studs away from the speaker | Bubble hidden (MaxDistance 80); at ~40–80 studs bubble is minimized | |
| 9 | Talk to Fisher Finn / Seed Shop NPC | NPC dialogue window unchanged, no chat bubbles from NPCs | |
| 10 | Hatch an Egg (good enough rarity to announce) | Hatch announcement appears in the chat window as a system message | |

## Phone viewport
Device emulator (top bar > Test > Device) → a small phone, landscape.
- [ ] Bubbles readable, not giant
- [ ] 3 stacked bubbles do not hide the Fishing HOLD button or the Guide card
- [ ] Chat window / input bar does not cover the left menu buttons

## Output
- [ ] No red errors from TextChatService, ChatTitles, HatchAnnounce or server-main
- [ ] Copy any warnings here:

## Result
PASS only if every row above is PASS. Otherwise: FAIL — <row number + what happened>.
