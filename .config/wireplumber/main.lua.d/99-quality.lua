rule = {
  matches = {
    {
      -- Matches all sinks.
      { "node.name", "matches", "alsa_output.*" },
    },
  },
  apply_properties = {
      ["resample.quality"]       = 10,
      ["resample.disable"]       = true,
      ["session.suspend-timeout-seconds"] = 0,
    --["audio.channels"]         = 2,
    --["audio.format"]           = "S32LE",
    --["audio.rate"]             = 44100,
      ["audio.allowed-rates"]    = "44100,48000,88200,96000,192000,352800,384000,768000",
  },
}

table.insert(alsa_monitor.rules, rule)
