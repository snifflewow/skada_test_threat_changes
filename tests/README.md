# Threat regression checks

Run from the repository root with Lua 5.1 or LuaJIT:

```sh
luajit tests/threat.lua
```

The harness loads the real threat module with mocked WoW APIs. It checks threat
percentages, pull-aggro scaling, pet visibility, changing raid tokens, stale rows,
focus/target selection, warning cooldowns and module cleanup. It is not a substitute
for testing on a WoW 3.3.5 client.

In game, check a hunter pet tanking with **Ignore Pets** on and off, switching
between enemies with different threat tables, melee/ranged pull thresholds, and
warnings with the threat window hidden. Repeat in both percentage and raw modes.
Also check changing focus and targeting a friendly tank to use `targettarget`.

TPS remains current threat divided by the current segment's duration, not a
rolling threat-generation rate. The legacy negative-threat display adjustment is
preserved; its server-specific behavior still needs in-game verification.
