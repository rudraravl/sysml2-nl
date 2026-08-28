package DynaliteLightingControl {

    import ScalarValues::*;
    import ISQ::Time;

    value def BrightnessLevel :> Real {
        doc /* Percentage brightness from 0 to 100. */
        unit '%';
        constraint { 0 <= self and self <= 100; }
    }

    value def FadeTime :> Time {
        doc /* Fade duration in seconds. */
        unit 's';
        constraint { 0 <= self; }
    }

    value def Illuminance :> Real {
        doc /* Natural light illuminance in lux. */
        unit 'lux';
        constraint { 0 <= self; }
    }

    value def PowerLevel :> Real {
        doc /* Electrical power modulation level delivered to fixtures. */
        unit '%';
        constraint { 0 <= self and self <= 100; }
    }

    value def OccupancyTimeout :> Time {
        unit 's';
    }

    item def MotionData {
        attribute occupied : Boolean;
        attribute detectedAt : Time;
    }

    item def PhotocellData {
        attribute illuminance : Illuminance;
        attribute sampledAt : Time;
    }

    item def ChannelCommand {
        attribute channel : Integer;
        attribute brightness : BrightnessLevel;
        attribute fade : FadeTime;
    }

    item def Scene {
        attribute name : String;
        attribute brightness : BrightnessLevel[4];
        attribute fade : FadeTime;
    }

    enum def OccupancyState {
        OCCUPIED;
        UNOCCUPIED;
    }

    enum def ControllerMode {
        MANUAL;
        AUTOMATIC;
        EMERGENCY;
    }

    port def MotionSensorPort {
        out motion : MotionData;
    }

    port def PhotocellSensorPort {
        out light : PhotocellData;
    }

    port def ControlBusPort {
        out command : ChannelCommand;
        in ack : Boolean;
    }

    port def FixturePowerPort {
        out power : PowerLevel;
    }

    part def MotionSensor {
        attribute occupied : Boolean := false;
        port sensorOut : MotionSensorPort;

        action def DetectMotion {
            out data : MotionData;
        }

        state def MotionDetectionBehavior {
            state Unoccupied {
                entry { occupied = false; }
            }
            state Occupied {
                entry { occupied = true; }
            }
            transition unoccupied_to_occupied
                from Unoccupied to Occupied
                when occupied == true;
            transition occupied_to_unoccupied
                from Occupied to Unoccupied
                when occupied == false;
        }

        private behavior detection : MotionDetectionBehavior;

        action emitMotion {
            out data : MotionData;
            perform {
                data.occupied = occupied;
                data.detectedAt = now;
                sensorOut.motion = data;
            }
        }
    }

    part def PhotocellSensor {
        attribute measuredIlluminance : Illuminance := 0;
        port sensorOut : PhotocellSensorPort;

        action def SampleLight {
            out data : PhotocellData;
        }

        action sample {
            out data : PhotocellData;
            perform {
                data.illuminance = measuredIlluminance;
                data.sampledAt = now;
                sensorOut.light = data;
            }
        }
    }

    part def NetworkController {
        attribute mode : ControllerMode := ControllerMode::AUTOMATIC;
        attribute occupancyTimeout : OccupancyTimeout := 300;
        attribute daylightTarget : Illuminance := 500;
        attribute lastOccupiedAt : Time;
        attribute currentOccupancy : OccupancyState := OccupancyState::UNOCCUPIED;
        attribute currentIlluminance : Illuminance := 0;

        attribute scenes : Scene[*] := [
            Scene{ name = "Off"; brightness = [0, 0, 0, 0]; fade = 2; },
            Scene{ name = "On"; brightness = [100, 100, 100, 100]; fade = 3; },
            Scene{ name = "Presentation"; brightness = [30, 0, 50, 20]; fade = 5; },
            Scene{ name = "DaylightHarvest"; brightness = [60, 60, 60, 60]; fade = 4; }
        ];

        port motionIn : MotionSensorPort;
        port photocellIn : PhotocellSensorPort;
        port busOut : ControlBusPort;

        action def ProcessSensorData {
            in motion : MotionData;
            in light : PhotocellData;
            out commands : ChannelCommand[*];
        }

        action def DaylightHarvesting {
            in illuminance : Illuminance;
            out brightness : BrightnessLevel;
            perform {
                if illuminance >= daylightTarget then
                    brightness = 0;
                else
                    brightness = 100 * (1 - illuminance / daylightTarget);
                end if;
            }
        }

        action def EvaluateOccupancy {
            in motion : MotionData;
            out state : OccupancyState;
            perform {
                if motion.occupied == true then
                    lastOccupiedAt = motion.detectedAt;
                    state = OccupancyState::OCCUPIED;
                else
                    if (now - lastOccupiedAt) >= occupancyTimeout then
                        state = OccupancyState::UNOCCUPIED;
                    else
                        state = currentOccupancy;
                    end if;
                end if;
            }
        }

        action def GenerateCommands {
            in occ : OccupancyState;
            in lux : Illuminance;
            out cmds : ChannelCommand[*];
            perform {
                if occ == OccupancyState::OCCUPIED then
                    var harvested : BrightnessLevel;
                    call DaylightHarvesting(illuminance = lux, brightness = harvested);
                    for i in 1..4 loop
                        cmds = cmds.append(ChannelCommand{
                            channel = i;
                            brightness = harvested;
                            fade = 3;
                        });
                    end loop;
                else
                    for i in 1..4 loop
                        cmds = cmds.append(ChannelCommand{
                            channel = i;
                            brightness = 0;
                            fade = 5;
                        });
                    end loop;
                end if;
            }
        }

        state def ControllerStateMachine {
            state Idle {
                entry { mode = ControllerMode::AUTOMATIC; }
            }
            state Processing {
                entry {
                    var motion : MotionData := motionIn.motion;
                    var light : PhotocellData := photocellIn.light;
                    var occ : OccupancyState;
                    var cmds : ChannelCommand[*];
                    call EvaluateOccupancy(motion = motion, state = occ);
                    currentOccupancy = occ;
                    currentIlluminance = light.illuminance;
                    call GenerateCommands(occ = occ, lux = light.illuminance, cmds = cmds);
                    for c in cmds loop
                        busOut.command = c;
                    end loop;
                }
            }
            state Emergency {
                entry {
                    for i in 1..4 loop
                        busOut.command = ChannelCommand{
                            channel = i;
                            brightness = 100;
                            fade = 0;
                        };
                    end loop;
                }
            }
            transition idle_to_processing
                from Idle to Processing
                when motionIn.motion != null or photocellIn.light != null;
            transition processing_to_idle
                from Processing to Idle
                when busOut.ack == true;
            transition any_to_emergency
                from Idle, Processing to Emergency
                when mode == ControllerMode::EMERGENCY;
        }

        private behavior control : ControllerStateMachine;
    }

    part def ChannelRelay {
        attribute channel : Integer;
        attribute currentBrightness : BrightnessLevel := 0;
        attribute targetBrightness : BrightnessLevel := 0;
        attribute fadeDuration : FadeTime := 0;
        attribute powerOutput : PowerLevel := 0;

        port busIn : ControlBusPort;
        port fixtureOut : FixturePowerPort;

        action def ApplyCommand {
            in cmd : ChannelCommand;
            perform {
                if cmd.channel == channel then
                    targetBrightness = cmd.brightness;
                    fadeDuration = cmd.fade;
                end if;
            }
        }

        action def ModulatePower {
            perform {
                if fadeDuration > 0 then
                    var step : BrightnessLevel := (targetBrightness - currentBrightness) / (fadeDuration * 10);
                    currentBrightness = currentBrightness + step;
                else
                    currentBrightness = targetBrightness;
                end if;
                powerOutput = currentBrightness;
                fixtureOut.power = powerOutput;
            }
        }

        state def RelayOperation {
            state Idle;
            state Receiving {
                entry {
                    call ApplyCommand(cmd = busIn.command);
                    busIn.ack = true;
                }
            }
            state Fading {
                do call ModulatePower();
            }
            transition idle_to_receiving
                from Idle to Receiving
                when busIn.command != null and busIn.command.channel == channel;
            transition receiving_to_fading
                from Receiving to Fading
                when targetBrightness != currentBrightness;
            transition fading_to_idle
                from Fading to Idle
                when currentBrightness == targetBrightness;
        }

        private behavior operation : RelayOperation;
    }

    part def LightingFixture {
        attribute fixtureId : String;
        attribute maxPower : PowerLevel := 100;
        attribute emittedLight : BrightnessLevel := 0;
        port powerIn : FixturePowerPort;

        action def EmitLight {
            perform {
                emittedLight = powerIn.power;
            }
        }

        state def FixtureState {
            state Off {
                entry { emittedLight = 0; }
            }
            state On {
                do call EmitLight();
            }
            transition off_to_on
                from Off to On
                when powerIn.power > 0;
            transition on_to_off
                from On to Off
                when powerIn.power == 0;
        }

        private behavior lighting : FixtureState;
    }

    part def LightingControlSystem {
        attribute systemName : String := "DynaliteBuildingLighting";

        part controller : NetworkController {
            occupancyTimeout = 300;
            daylightTarget = 500;
        }

        part motionSensor : MotionSensor;
        part photocellSensor : PhotocellSensor;

        part relays : ChannelRelay[4] {
            part relay1 : ChannelRelay { channel = 1; }
            part relay2 : ChannelRelay { channel = 2; }
            part relay3 : ChannelRelay { channel = 3; }
            part relay4 : ChannelRelay { channel = 4; }
        }

        part fixtures : LightingFixture[4] {
            part fixture1 : LightingFixture { fixtureId = "F1"; }
            part fixture2 : LightingFixture { fixtureId = "F2"; }
            part fixture3 : LightingFixture { fixtureId = "F3"; }
            part fixture4 : LightingFixture { fixtureId = "F4"; }
        }

        connection motionSensor.sensorOut to controller.motionIn;
        connection photocellSensor.sensorOut to controller.photocellIn;

        connection controller.busOut to relays.relay1.busIn;
        connection controller.busOut to relays.relay2.busIn;
        connection controller.busOut to relays.relay3.busIn;
        connection controller.busOut to relays.relay4.busIn;

        connection relays.relay1.fixtureOut to fixtures.fixture1.powerIn;
        connection relays.relay2.fixtureOut to fixtures.fixture2.powerIn;
        connection relays.relay3.fixtureOut to fixtures.fixture3.powerIn;
        connection relays.relay4.fixtureOut to fixtures.fixture4.powerIn;
    }

    requirement def OccupancyAutomationRequirement {
        subject : LightingControlSystem;
        objective {
            doc /* The system shall turn lights on when occupancy is detected and off after the occupancy timeout elapses. */
            constraint { 
                subject.controller.currentOccupancy == OccupancyState::OCCUPIED implies
                subject.fixtures.fixture1.emittedLight > 0;
            }
        }
    }

    requirement def DaylightHarvestingRequirement {
        subject : LightingControlSystem;
        objective {
            doc /* The system shall dim artificial lighting in proportion to available natural daylight to maintain the target illuminance. */
            constraint {
                subject.controller.currentIlluminance >= subject.controller.daylightTarget implies
                subject.fixtures.fixture1.emittedLight == 0;
            }
        }
    }

    requirement def ChannelControlRequirement {
        subject : LightingControlSystem;
        objective {
            doc /* The controller shall independently command four lighting channels via channel relays. */
            constraint { subject.relays.size == 4; }
        }
    }

    requirement def FadeControlRequirement {
        subject : LightingControlSystem;
        objective {
            doc /* Each relay shall modulate power smoothly over the commanded fade time. */
            constraint {
                subject.relays.relay1.fadeDuration >= 0 and
                subject.relays.relay2.fadeDuration >= 0 and
                subject.relays.relay3.fadeDuration >= 0 and
                subject.relays.relay4.fadeDuration >= 0;
            }
        }
    }

    requirement def EnergyEfficiencyRequirement {
        subject : LightingControlSystem;
        objective {
            doc /* The system shall minimize artificial lighting energy consumption through automation and daylight harvesting. */
            constraint {
                subject.controller.mode == ControllerMode::AUTOMATIC implies
                subject.controller.currentIlluminance > 0 implies
                subject.fixtures.fixture1.emittedLight < 100;
            }
        }
    }

    requirement occupancyAutomation : OccupancyAutomationRequirement {
        subject = LightingControlSystem::systemName;
    }

    requirement daylightHarvesting : DaylightHarvestingRequirement {
        subject = LightingControlSystem::systemName;
    }

    requirement channelControl : ChannelControlRequirement {
        subject = LightingControlSystem::systemName;
    }

    requirement fadeControl : FadeControlRequirement {
        subject = LightingControlSystem::systemName;
    }

    requirement energyEfficiency : EnergyEfficiencyRequirement {
        subject = LightingControlSystem::systemName;
    }

}
