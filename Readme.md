# ExtendedVehicle

A Farming Simulator 25 mod that provides extended vehicle functionality, focusing on advanced lighting and sound controls, particularly useful for emergency services and utility vehicles.

## Features

- **Beacon Light Groups**: Group multiple beacon lights and control them via dedicated input bindings. Supports both toggle and button modes.
- **Sound Groups**: Manage multiple sound effects (e.g., sirens, air horns) with easy switching and toggling.
- **Pre-defined Actions**: Includes several default action bindings for common tasks like Rear Warning Systems (RWS), Stop flashes, and Sirens.

## Usage

### ModDesc

To use this mod, add the following to your `modDesc.xml`:

* Add a dependency to FS25_extendedVehicle
* Add the `extendedVehicle` specialization to your `vehicleType`.

#### Example ModDesc
````xml
<dependencies>
    <dependency>FS25_extendedVehicle</dependency>
</dependencies>

<vehicleTypes>
    <type name="someSpecialCar" parent="baseDrivable" className="Vehicle" filename="$dataS/scripts/vehicles/Vehicle.lua">
        <specialization name="FS25_extendedVehicle.extendedVehicle" />
    </type>
    <type name="someSpecialTrailer" parent="trailer" className="Vehicle" filename="$dataS/scripts/vehicles/Vehicle.lua">
        <specialization name="FS25_extendedVehicle.extendedVehicle" />
    </type>
</vehicleTypes>
````

### XML Configuration

To use this specialization in your vehicle, add the `extendedVehicle` specialization to your `vehicleType` and configure the `<extendedVehicle>` section in your vehicle XML.

#### Example Configuration

```xml
<extendedVehicle>
    <beaconLightGroups>
        <!-- name: identifier for the group -->
        <!-- toggleInputButton: the action name to trigger this group -->
        <beaconLightGroup name="HWS" toggleInputButton="VD_EV_TOGGLE_RWS">
            <!-- optional animation to play when the group is triggered -->
            <animation name="HWS_Button" speedScale="1.0" />
            <!-- beaconLight: BeacnLight definition is the same as in the vanilla vehicle XML -->
            <beaconLight realLight="0>1|5|0|2|1">
                <staticLight node="0>1|5|0|2|0" intensity="100" multiBlink="true"
                    multiBlinkParameters="10 5 40 10" />
            </beaconLight>
            <beaconLight>
                <staticLight node="0>1|4|0|1|1|1" intensity="100" multiBlink="true"
                    multiBlinkParameters="10 5 40 10" />
            </beaconLight>
        </beaconLightGroup>

        <beaconLightGroup name="STOP" toggleInputButton="VD_EV_TOGGLE_STOPFLASH">
            <beaconLight>
                <staticLight node="0>1|4|5|0" intensity="100" multiBlink="true"
                    multiBlinkParameters="7 5 40 100" />
            </beaconLight>
            <beaconLight>
                <staticLight node="0>1|4|5|2" intensity="100" multiBlink="true"
                    multiBlinkParameters="7 5 40 -100" />
            </beaconLight>
        </beaconLightGroup>
    </beaconLightGroups>

    <soundGroups>
        <!-- toggleInputButton: switches the sound on/off -->
        <!-- switchInputButton: cycles through sounds within the group -->
        <soundGroup name="SIREN" toggleInputButton="VD_EV_TOGGLE_SIREN"
            switchInputButton="VD_EV_SWITCH_SIREN">
            <!-- optional animation to play when the group is triggered -->
            <animation name="Siren_Button" speedScale="1.0" />
            <extendedSound>
                <!-- sound: sound definition is the same as in the vanilla vehicle XML -->
                <sound file="sounds/e_horn.ogg" pitchScale="1" volumeScale="2.5"
                    indoorVolume="0.035" outdoorVolume="0.1" range="30" innerRange="1"
                    pitchMin="0.8" pitchMax="1.5"
                    indoorLowpassGain="1" outdoorLowpassGain="1"
                    indoorLowpassCutoffFrequencyGain="5000.0"
                    indoorLowpassCutoffFrequencyResonance="2.0"
                    outdoorLowpassCutoffFrequencyGain="5000.0"
                    outdoorLowpassCutoffFrequencyResonance="2.0" />
            </extendedSound>
            <extendedSound>
                <sound file="sounds/pressluft.ogg" pitchScale="1.0"
                    volumeScale="14"
                    indoorVolume="0.035" outdoorVolume="1" range="75" innerRange="1"
                    pitchMin="0.8" pitchMax="1.5"
                    indoorLowpassGain="1" outdoorLowpassGain="1"
                    indoorLowpassCutoffFrequencyGain="5000.0"
                    indoorLowpassCutoffFrequencyResonance="2.0"
                    outdoorLowpassCutoffFrequencyGain="5000.0"
                    outdoorLowpassCutoffFrequencyResonance="2.0" />
            </extendedSound>
        </soundGroup>
        <soundGroup name="Bullhorn" toggleInputButton="VD_EV_AIR_HORN" inputMode="BUTTON">
            <extendedSound>
                <sound file="sounds/bullhorn.ogg" pitchScale="1" volumeScale="2.5"
                       indoorVolume="0.035" outdoorVolume="0.1" range="30" innerRange="1"
                       pitchMin="0.8" pitchMax="1.5"
                       indoorLowpassGain="1" outdoorLowpassGain="1"
                       indoorLowpassCutoffFrequencyGain="5000.0"
                       indoorLowpassCutoffFrequencyResonance="2.0"
                       outdoorLowpassCutoffFrequencyGain="5000.0"
                       outdoorLowpassCutoffFrequencyResonance="2.0" />
            </extendedSound>
        </soundGroup>
    </soundGroups>
</extendedVehicle>
```

### Attributes

#### Beacon Light Groups
- `name`: (String) Name of the group.
- `inputMode`: (String) `SWITCH` (default) or `BUTTON`.
- `toggleInputButton`: (String) The action binding to toggle/trigger the group.

#### Sound Groups
- `name`: (String) Name of the group.
- `inputMode`: (String) `SWITCH` (default) or `BUTTON`.
- `toggleInputButton`: (String) The action binding to toggle/trigger the sound.
- `switchInputButton`: (String) Optional. The action binding to switch between multiple sounds in the group.

## Default Keybindings

| Action | Keybinding | Description |
| :--- | :--- | :--- |
| `VD_EV_TOGGLE_RWS` | `LCtrl + Numpad 1` | Toggle Rear Warning System |
| `VD_EV_TOGGLE_STOPFLASH` | `LCtrl + Numpad 2` | Toggle Stop Flash |
| `VD_EV_TOGGLE_SIREN` | `LAlt + Numpad 1` | Toggle Siren |
| `VD_EV_SWITCH_SIREN` | `LAlt + Numpad 2` | Switch Siren Tone |
| `VD_EV_AIR_HORN` | `LAlt + Numpad 3` | Air Horn / Bullhorn |

## Credits
- **Author**: VertexDezign
- **Development Assistant**: [Junie](https://www.jetbrains.com/ai/) (JetBrains AI)

### Idea / Inspiration
- EmergencyPack by Creative Mesh