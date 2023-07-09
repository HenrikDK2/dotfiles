rule = {
  matches = {
    {
      -- Matches all sinks (outputs).
      { "node.name", "matches", "alsa_output.*" },
    },
  },
  apply_properties = {
    ["resample.quality"] = 10,
    ["session.suspend-timeout-seconds"] = 0,
    ["audio.allowed-rates"] = "44100,48000",
  },
}

table.insert(alsa_monitor.rules, rule)
