# Module options

Every `services.openhop-repeater.*` option, with its type, default and description.
This file is generated from the module by `scripts/update-generated.sh`. Do not edit it by
hand: the `docs-in-sync` check fails if it is out of date.

## services\.openhop-repeater\.enable



Whether to enable the openHop Repeater MeshCore daemon\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```



## services\.openhop-repeater\.package



The openhop-repeater package to run\. The default is built from this repository
with your nixpkgs; set it to ` pkgs.openhop-repeater ` if you use the overlay\.



*Type:*
package



*Default:*

```nix
pkgs.callPackage ./package.nix { }
```



## services\.openhop-repeater\.companions

Virtual companion identities\. Each one exposes the MeshCore companion
protocol over TCP so standard clients can connect to ` bindAddress:port `
(one client at a time)\. The attribute name is the identity’s ` name `\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```



## services\.openhop-repeater\.companions\.\<name>\.bindAddress



Address the TCP server binds to\. Defaults to localhost because the companion
port has no authentication; use ` 0.0.0.0 ` only on a trusted network\.



*Type:*
string



*Default:*

```nix
"127.0.0.1"
```



*Example:*

```nix
"0.0.0.0"
```



## services\.openhop-repeater\.companions\.\<name>\.identityKeyFile



File holding the identity key as hex: 64 characters (32-byte seed) or 128
(MeshCore firmware key)\. Must differ from every other identity on the node\.
Generate a new one with ` openssl rand -hex 32 `\.



*Type:*
absolute path



*Example:*

```nix
"/run/secrets/openhop-companion-key"
```



## services\.openhop-repeater\.companions\.\<name>\.nodeName



Name the companion presents on the mesh (max 31 characters)\.



*Type:*
string matching the pattern \.{1,31}



*Default:*

```nix
"‹name›"
```



## services\.openhop-repeater\.companions\.\<name>\.openFirewall



Whether to enable opening this companion’s TCP port in the firewall\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```



## services\.openhop-repeater\.companions\.\<name>\.port



TCP port\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
5000
```



## services\.openhop-repeater\.companions\.\<name>\.settings



Extra keys for this companion’s ` settings ` block\.



*Type:*
attribute set of anything



*Default:*

```nix
{ }
```



## services\.openhop-repeater\.companions\.\<name>\.tcpTimeout



Client idle timeout in seconds; 0 disables\. Null uses upstream’s default (120)\.



*Type:*
null or (unsigned integer, meaning >=0)



*Default:*

```nix
null
```



## services\.openhop-repeater\.extraGroups



Extra groups for the service user, beyond those the module adds for the
selected radio (` dialout `, ` plugdev `, ` gpio `, ` spi `)\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "i2c"
]
```



## services\.openhop-repeater\.gps\.enable



Whether to enable reading a local GPS receiver (also lets the daemon set the system clock)\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```



## services\.openhop-repeater\.gps\.device



Serial device for the GPS module\.



*Type:*
string



*Default:*

```nix
"/dev/serial0"
```



## services\.openhop-repeater\.group



Service group\.



*Type:*
string



*Default:*

```nix
"openhop-repeater"
```



## services\.openhop-repeater\.http\.enable



Enable the web dashboard and API\.



*Type:*
boolean



*Default:*

```nix
true
```



## services\.openhop-repeater\.http\.host



Listen address\.



*Type:*
string



*Default:*

```nix
"0.0.0.0"
```



## services\.openhop-repeater\.http\.port



Listen port\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
8000
```



## services\.openhop-repeater\.logLevel



Daemon log level\.



*Type:*
one of “TRACE”, “DEBUG”, “INFO”, “WARNING”, “ERROR”



*Default:*

```nix
"INFO"
```



## services\.openhop-repeater\.mesh\.defaultRegion



Default flood scope for locally originated flood adverts\.



*Type:*
null or string



*Default:*

```nix
null
```



## services\.openhop-repeater\.mesh\.loopDetect



Flood loop detection mode\. Null leaves the upstream default\.



*Type:*
null or one of “off”, “minimal”, “moderate”, “strict”



*Default:*

```nix
null
```



## services\.openhop-repeater\.mesh\.pathHashMode



Per-hop path hash size: 0 = 1 byte (legacy), 1 = 2 bytes, 2 = 3 bytes\.
Must match the rest of your mesh\. If null, the value from ` radio.preset ` is used when the
preset defines one, otherwise the upstream default applies\.



*Type:*
null or one of 0, 1, 2



*Default:*

```nix
null
```



## services\.openhop-repeater\.mqtt\.brokers



Broker list, in upstream’s format\. An entry can be a bundled network preset such as
` { preset = "letsmesh"; } ` (bundled: ` chimesh `, ` letsmesh `, ` meshat-se `, ` meshcore-ca `,
` meshmapper `, ` waev `), or a full broker definition\. Do not put a broker password here:
it would end up in the Nix store\.



*Type:*
list of attribute set of anything



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  { preset = "letsmesh"; }
  {
    name = "my-broker";
    enabled = true;
    host = "mqtt.example.org";
    port = 8883;
    transport = "tcp";
    username = "repeater";
    tls.enabled = true;
  }
]

```



## services\.openhop-repeater\.mqtt\.iataCode



IATA airport code identifying your area\. Setting it enables the ` mqtt_brokers ` section\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"ORD"
```



## services\.openhop-repeater\.mqtt\.owner



Public key of your companion device, which links the repeater to it on MQTT analyzers\.
A public key, not a secret\.



*Type:*
null or string



*Default:*

```nix
null
```



## services\.openhop-repeater\.openFirewall



Whether to enable opening the web dashboard port in the firewall\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```



## services\.openhop-repeater\.radio\.bandwidth



Bandwidth in Hz\. Overrides ` radio.preset `\.



*Type:*
null or (positive integer, meaning >0)



*Default:*

```nix
null
```



*Example:*

```nix
62500
```



## services\.openhop-repeater\.radio\.ch341



` ch341 ` section (USB vid/pid, optional bus/address/serial_number)\.



*Type:*
attribute set of anything



*Default:*

```nix
{
  pid = 21778;
  vid = 6790;
}
```



## services\.openhop-repeater\.radio\.codingRate



LoRa coding rate denominator (5-8)\. Overrides ` radio.preset `\.



*Type:*
null or integer between 5 and 8 (both inclusive)



*Default:*

```nix
null
```



*Example:*

```nix
5
```



## services\.openhop-repeater\.radio\.frequency



Frequency in Hz\. Overrides ` radio.preset `\. Without a preset you must set this and the three settings below\.



*Type:*
null or (positive integer, meaning >0)



*Default:*

```nix
null
```



*Example:*

```nix
910525000
```



## services\.openhop-repeater\.radio\.kiss



` kiss ` section, used when ` radio.type = "kiss" `\.



*Type:*
attribute set of anything



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  baud_rate = 9600;
  port = "/dev/ttyUSB0";
}
```



## services\.openhop-repeater\.radio\.modemTcp



` modem_tcp ` section, used when ` radio.type = "modem_tcp" `\.



*Type:*
attribute set of anything



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  host = "openhop-modem.local";
  port = 5055;
}
```



## services\.openhop-repeater\.radio\.modemUsb



` modem_usb ` section, used when ` radio.type = "modem_usb" `\.



*Type:*
attribute set of anything



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  baudrate = 921600;
  port = "/dev/ttyACM0";
}
```



## services\.openhop-repeater\.radio\.preambleLength



Preamble length in symbols\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
32
```



## services\.openhop-repeater\.radio\.preset



A named set of regional radio settings (frequency, bandwidth, spreading factor, coding
rate, and a path hash size where the region defines one)\. Any of those you also set
yourself, such as ` radio.frequency `, replaces the preset’s value\. ` radio.txPower ` is
not part of a preset\. The presets are upstream openHop’s list:

 - ` australia `: Australia, 915\.800MHz / SF10 / BW250 / CR5
 - ` australia-mid `: Australia (Mid), 915\.075MHz / SF9 / BW125 / CR5
 - ` australia-narrow `: Australia (Narrow), 916\.575MHz / SF7 / BW62\.5 / CR8
 - ` australia-qld `: Australia: QLD, 923\.125MHz / SF8 / BW62\.5 / CR5
 - ` australia-sa-wa `: Australia: SA, WA, 923\.125MHz / SF8 / BW62\.5 / CR8
 - ` brazil `: Brazil, 923\.125MHz / SF8 / BW62\.5 / CR8
 - ` costa-rica `: Costa Rica, 910\.525MHz / SF11 / BW125 / CR5
 - ` czech-republic-narrow `: Czech Republic (Narrow), 869\.432MHz / SF7 / BW62\.5 / CR5
 - ` eu-433mhz-long-range `: EU 433MHz (Long Range), 433\.650MHz / SF11 / BW250 / CR5
 - ` eu-433mhz-narrow `: EU 433MHz (Narrow), 433\.650MHz / SF8 / BW62\.5 / CR8
 - ` eu-uk-deprecated `: EU/UK (Deprecated), 869\.525MHz / SF11 / BW250 / CR5
 - ` eu-uk-narrow `: EU/UK (Narrow), 869\.618MHz / SF8 / BW62\.5 / CR8
 - ` hungary `: Hungary, 869\.618MHz / SF7 / BW62\.5 / CR5 / 2B
 - ` netherlands `: Netherlands, 869\.618MHz / SF7 / BW62\.5 / CR5
 - ` new-zealand-gisborne `: New Zealand (Gisborne), 917\.375MHz / SF11 / BW250 / CR5 / 1B
 - ` new-zealand-narrow `: New Zealand (Narrow), 917\.375MHz / SF7 / BW62\.5 / CR5 / 2B
 - ` portugal-433 `: Portugal 433, 433\.375MHz / SF9 / BW62\.5 / CR6
 - ` portugal-868 `: Portugal 868, 869\.618MHz / SF7 / BW62\.5 / CR6
 - ` slovakia `: Slovakia, 869\.618MHz / SF7 / BW62\.5 / CR5 / 2B
 - ` switzerland `: Switzerland, 869\.618MHz / SF8 / BW62\.5 / CR8
 - ` usa-canada-recommended `: USA/Canada (Recommended), 910\.525MHz / SF7 / BW62\.5 / CR5
 - ` vietnam-deprecated `: Vietnam (Deprecated), 920\.250MHz / SF11 / BW250 / CR5
 - ` vietnam-narrow `: Vietnam (Narrow), 920\.250MHz / SF8 / BW62\.5 / CR5



*Type:*
null or one of “australia”, “australia-mid”, “australia-narrow”, “australia-qld”, “australia-sa-wa”, “brazil”, “costa-rica”, “czech-republic-narrow”, “eu-433mhz-long-range”, “eu-433mhz-narrow”, “eu-uk-deprecated”, “eu-uk-narrow”, “hungary”, “netherlands”, “new-zealand-gisborne”, “new-zealand-narrow”, “portugal-433”, “portugal-868”, “slovakia”, “switzerland”, “usa-canada-recommended”, “vietnam-deprecated”, “vietnam-narrow”



*Default:*

```nix
null
```



*Example:*

```nix
"eu-uk-narrow"
```



## services\.openhop-repeater\.radio\.spreadingFactor



LoRa spreading factor\. Overrides ` radio.preset `\.



*Type:*
null or integer between 5 and 12 (both inclusive)



*Default:*

```nix
null
```



*Example:*

```nix
7
```



## services\.openhop-repeater\.radio\.sx1262



Overrides for the ` sx1262 ` hardware section (BCM GPIO numbers for ` sx1262 `,
CH341 GPIO 0-7 for ` sx1262_ch341 `)\. Unset keys use upstream’s defaults\.



*Type:*
attribute set of anything



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  busy_pin = 20;
  cs_pin = 21;
  irq_pin = 16;
  reset_pin = 18;
  use_dio3_tcxo = true;
}
```



## services\.openhop-repeater\.radio\.txPower



TX power in dBm\.



*Type:*
signed integer



*Default:*

```nix
14
```



## services\.openhop-repeater\.radio\.type



Radio backend\. ` sx1262 ` is a Linux SPI/GPIO radio (e\.g\. Raspberry Pi HAT),
` sx1262_ch341 ` is CH341 USB-to-SPI, ` kiss ` a serial KISS modem, and
` modem_tcp ` / ` modem_usb ` an openHop Modem\. ` null ` starts the daemon
without any RF I/O\.



*Type:*
null or one of “sx1262”, “sx1262_ch341”, “kiss”, “modem_tcp”, “modem_usb”



*Default:*

```nix
null
```



## services\.openhop-repeater\.renderedSettings



The final config (minus secrets) written to ` config.yaml `\. Read-only; inspect with
` nix eval .#nixosConfigurations.<host>.config.services.openhop-repeater.renderedSettings `\.



*Type:*
YAML 1\.1 value *(read only)*



*Default:*
the generated configuration



## services\.openhop-repeater\.repeater\.allowDiscovery



Respond to discovery requests from other nodes\.



*Type:*
boolean



*Default:*

```nix
true
```



## services\.openhop-repeater\.repeater\.directAdvertIntervalHours



Additional zero-hop advert interval in hours; 0 disables\.



*Type:*
unsigned integer, meaning >=0



*Default:*

```nix
0
```



## services\.openhop-repeater\.repeater\.identityFile



Path to the node’s identity key\. Created on first start if missing, so the
node keeps the same identity across rebuilds\. Back this file up\.



*Type:*
string



*Default:*

```nix
"/var/lib/openhop_repeater/identity.key"
```



## services\.openhop-repeater\.repeater\.identityKeyFile



File holding the repeater’s identity key, in the format the daemon writes
(an existing ` identity.key `)\. It is copied to ` identityFile ` at every start, so
the node keeps its identity and never generates a new one\. If null, the daemon
creates ` identityFile ` on first start\. Kept out of the Nix store\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



*Example:*

```nix
"/var/lib/openhop-secrets/identity.key"
```



## services\.openhop-repeater\.repeater\.latitude



Latitude in decimal degrees (-90 to 90)\. Strings are accepted and converted\.



*Type:*
floating point number or string convertible to it



*Default:*

```nix
0.0
```



*Example:*

```nix
"41.44663"
```



## services\.openhop-repeater\.repeater\.longitude



Longitude in decimal degrees (-180 to 180)\. Strings are accepted and converted\.



*Type:*
floating point number or string convertible to it



*Default:*

```nix
0.0
```



*Example:*

```nix
"-81.69541"
```



## services\.openhop-repeater\.repeater\.mode



` forward ` repeats packets, ` monitor ` doesn’t repeat, ` no_tx ` disables all transmit\.



*Type:*
one of “forward”, “monitor”, “no_tx”



*Default:*

```nix
"forward"
```



## services\.openhop-repeater\.repeater\.name



Node name advertised on the mesh (` repeater.node_name `)\.



*Type:*
string



*Example:*

```nix
"Hilltop Repeater"
```



## services\.openhop-repeater\.repeater\.ownerInfo



Owner info shown to clients that request it\.



*Type:*
string



*Default:*

```nix
""
```



## services\.openhop-repeater\.repeater\.security\.adminPasswordFile



File containing the admin password\. Kept out of the Nix store\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



*Example:*

```nix
"/run/secrets/openhop-admin-password"
```



## services\.openhop-repeater\.repeater\.security\.allowReadOnly



Allow read-only access without a password\.



*Type:*
boolean



*Default:*

```nix
false
```



## services\.openhop-repeater\.repeater\.security\.guestPasswordFile



File containing the guest password\. Kept out of the Nix store\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



## services\.openhop-repeater\.repeater\.security\.jwtExpiryMinutes



Web login lifetime\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
60
```



## services\.openhop-repeater\.repeater\.security\.jwtSecretFile



File containing the JWT signing secret (e\.g\. ` openssl rand -hex 32 `)\.
If unset the daemon generates one\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



## services\.openhop-repeater\.repeater\.security\.maxClients



Max authenticated clients\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
5
```



## services\.openhop-repeater\.repeater\.sendAdvertIntervalHours



Flood advert interval in hours; 0 disables automatic adverts\.



*Type:*
unsigned integer, meaning >=0



*Default:*

```nix
10
```



## services\.openhop-repeater\.roomServers



Room server identities\. Each acts as a separate logical node on the mesh\.
The attribute name is the identity’s ` name `\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```



## services\.openhop-repeater\.roomServers\.\<name>\.adminPasswordFile



File with the room’s admin password\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



## services\.openhop-repeater\.roomServers\.\<name>\.directAdvertIntervalHours



Zero-hop advert interval in hours\.



*Type:*
null or (unsigned integer, meaning >=0)



*Default:*

```nix
null
```



## services\.openhop-repeater\.roomServers\.\<name>\.floodAdvertIntervalHours



Flood advert interval in hours\.



*Type:*
null or (unsigned integer, meaning >=0)



*Default:*

```nix
null
```



## services\.openhop-repeater\.roomServers\.\<name>\.guestPasswordFile



File with the room’s guest password\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



## services\.openhop-repeater\.roomServers\.\<name>\.identityKeyFile



File holding the room’s identity key as hex (see ` companions.<name>.identityKeyFile `)\.



*Type:*
absolute path



*Example:*

```nix
"/run/secrets/openhop-room-key"
```



## services\.openhop-repeater\.roomServers\.\<name>\.latitude



Room latitude\.



*Type:*
null or (floating point number or string convertible to it)



*Default:*

```nix
null
```



## services\.openhop-repeater\.roomServers\.\<name>\.longitude



Room longitude\.



*Type:*
null or (floating point number or string convertible to it)



*Default:*

```nix
null
```



## services\.openhop-repeater\.roomServers\.\<name>\.nodeName



Name the room presents on the mesh\.



*Type:*
string



*Default:*

```nix
"‹name›"
```



## services\.openhop-repeater\.roomServers\.\<name>\.settings



Extra keys for this room’s ` settings ` block\.



*Type:*
attribute set of anything



*Default:*

```nix
{ }
```



## services\.openhop-repeater\.settings



Free-form settings merged over everything above, using upstream’s
` config.yaml ` keys (see ` config.yaml.example ` in the openhop_repeater repo)\.
Values of ` null ` are dropped\. Do not put secrets here: they end up in the Nix store\.



*Type:*
YAML 1\.1 value



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  mqtt_brokers = {
    iata_code = "CLE";
    brokers = [ { preset = "letsmesh"; } ];
  };
  mesh.loop_detect = "moderate";
}

```



## services\.openhop-repeater\.user



Service user\.



*Type:*
string



*Default:*

```nix
"openhop-repeater"
```


