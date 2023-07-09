rule = {
  matches = {
    {
      { "node.name", "equals", "alsa_output.usb-aune_X1S_USB_DAC-00.analog-stereo" },
    },
  },
  apply_properties = {
    ["resample.disable"] = true,
    ["api.alsa.use-chmap"] = true,
    ["api.alsa.disable-batch"] = true,
    ["audio.allowed-rates"] = "44100,48000,88200,96000,176400,192000,352800,384000",
  },
}

table.insert(alsa_monitor.rules, rule)
