

### Per-player cooldown (blade heat)

In addition to plate cooldown and owned/blacklist checks, there is a **per-player** cooldown:

```lua
Config.PlayerCooldownSeconds = 60 -- time after a successful cut before player can cut again
```

- After a successful converter cut, the player is put on cooldown.
- If they try to use the saw again before that time, the server returns:
  > "Your blade is too hot to cut right now. Let it cool down."
- This is enforced twice:
  - Via a server callback before starting the progress bar.
  - Again when the server processes the actual strip event (in case of exploits).
