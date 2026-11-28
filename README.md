# c4-ea-homeassistant

Home Assistant and Music Assistant on Control4 EA-series controllers (EA-1,
EA-3, EA-5), on top of [openHC](https://github.com/The1TrueJoe/openHC). Turn an
EA you no longer use with Control4 into a home automation hub and a music
player:

- **Home Assistant** on the box, with the EA's relays, contact inputs, IR
  outputs, IR receiver and serial ports already in it as entities.
- **Zigbee** on the EA's built-in radio: pair bulbs, sensors and switches from
  any brand straight into Home Assistant.
- **Bluetooth LE** sensors (EA-3) in Home Assistant, with no pairing.
- **Music Assistant** playing to every audio output (analog, coax, HDMI), and
  each output an **AirPlay 2** speaker for your phone.
- **Home Assistant on the TV** from the EA's HDMI output, driven by a USB
  keyboard or from Home Assistant itself.

Or install **Music Assistant only**, for a music player without Home Assistant.

## Install

You need the EA on your network and a Mac, Windows or Linux computer on the
same network. No serial cable, no opening the box.

1. Download **ohc-flasher** for your computer from
   [openHC's releases](https://github.com/The1TrueJoe/openHC/releases).
2. Open it. It finds the Control4 controllers on your network; pick your EA.
3. On **What should this controller run?**, pick **Home Assistant** or
   **Music Assistant only**. The flasher downloads the right image for your
   EA by itself.
4. Press **Install** and leave the box powered until the flasher says it is
   done (a few minutes; the box restarts twice).
5. On its first start the box installs Home Assistant and Music Assistant from
   the internet. On the EA that takes 20–40 minutes. Then open:
   - Home Assistant: `http://<box address>:8123`
   - Music Assistant: `http://<box address>:8095`
   - openHC's own page (audio, display, network): `http://<box address>/`

The **[guide](docs/install.md)** walks through the rest: connecting the box's
IO and Zigbee in Home Assistant, setting up Music Assistant's players,
AirPlay, and the screen.

Installing erases what was on the box's system partition. Control4's factory
recovery stays on the box, and openHC's
[Recovery](https://the1truejoe.github.io/openHC/shared/recovery/) page explains
how to go back to Control4.

Already have Home Assistant on another machine? Install plain **openHC**
instead; the guide's second half shows how your Home Assistant and Music
Assistant use the box over MQTT.

## Logging in

SSH: `ssh root@<box address>`, password `openhc`. Change it with `passwd`.

## Status

Tested on an EA-3:

- [x] Home Assistant and Music Assistant install and run; the box's relays and
      contacts work from Home Assistant.
- [x] Music Assistant plays to the analog output; AirPlay 2 on every output.
- [x] Zigbee network formed, joining from Home Assistant. A paired device: not
      yet.
- [x] Bluetooth LE devices seen on MQTT and in Home Assistant. A decoded
      sensor: not yet.
- [x] Home Assistant on the HDMI output, keys and page driven from Home
      Assistant (tested without a monitor attached).
- [ ] EA-1 and EA-5 on real hardware.
- [ ] Music Assistant only, on real hardware.

## Contributing

How the image is built, and how to work on it:
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT.
