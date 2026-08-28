package AutomatedLightingControlSystem {
    import ScalarValues::*;

    // ---- Value Types ----
    value type Illuminance > Real {
        unit "lux";
    }

    value type BrightnessLevel > Real {
        unit "percent";
        constraint { 0 <= self and self <= 100 }
    }

    value type ElectricPower > Real {
        unit "W";
    }

    value type Voltage > Real {
        unit "V";
    }

    value type TimeDuration > Real {
        unit "s";
    }

    value type Distance > Real {
        unit "m";
    }

    // ---- Enumerations ----
    enum OccupancyState {
        occupied;
        empty;
    }

    enum SystemMode {
        automatic;
        manual;
    }

    enum PowerCommand {
        on;
        off;
    }

    // ---- Item Types ----
    item OccupancyData {
        attribute state : OccupancyState;
        attribute confidence : Real [0..1] = 1.0;
    }

    item AmbientLightData {
        attribute level : Illuminance;
    }

    item UserCommand {
        attribute mode : SystemMode;
        attribute brightness : BrightnessLevel [0..1];
        attribute power : PowerCommand [0..1];
    }

    item ControlCommand {
        attribute brightness : BrightnessLevel;
        attribute power : PowerCommand;
    }

    item PowerFlow {
        attribute voltage : Voltage;
        attribute power : ElectricPower;
    }

    // ---- Port Definitions ----
    port def OccupancyOut {
        out data : OccupancyData;
    }

    port def LightOut {
        out data : AmbientLightData;
    }

    port def UserPanelOut {
        out command : UserCommand;
    }

    port def ControlOut {
        out command : ControlCommand;
    }

    port def ControlIn {
        in command : ControlCommand;
    }

    port def PowerOut {
        out power : PowerFlow;
    }

    port def PowerIn {
        in power : PowerFlow;
    }

    // ---- Components ----
    part def OccupancySensor {
        port occupancyOut : OccupancyOut;
        attribute detectionRange : Distance = 8 [unit "m"];
        attribute detectionInterval : TimeDuration = 1 [unit "s"];
        attribute currentState : OccupancyState = OccupancyState::empty;

        action detectOccupancy {
            out data : OccupancyData;
            perform {
                if (currentState == OccupancyState::occupied) {
                    send OccupancyData { state = OccupancyState::occupied; confidence = 0.95; } to occupancyOut.data;
                } else {
                    send OccupancyData { state = OccupancyState::empty; confidence = 0.95; } to occupancyOut.data;
                }
            }
        }
        compute detectOccupancy;
    }

    part def LightSensor {
        port lightOut : LightOut;
        attribute maxRange : Illuminance = 2000 [unit "lux"];
        attribute measurementInterval : TimeDuration = 2 [unit "s"];
        attribute currentLevel : Illuminance = 0 [unit "lux"];

        action measureLight {
            out data : AmbientLightData;
            perform {
                send AmbientLightData { level = currentLevel; } to lightOut.data;
            }
        }
        compute measureLight;
    }

    part def UserPanel {
        port panelOut : UserPanelOut;
        attribute currentMode : SystemMode = SystemMode::automatic;
        attribute manualBrightness : BrightnessLevel = 100 [unit "percent"];
        attribute manualPower : PowerCommand = PowerCommand::on;

        action acceptInput {
            out command : UserCommand;
            perform {
                send UserCommand {
                    mode = currentMode;
                    brightness = manualBrightness;
                    power = manualPower;
                } to panelOut.command;
            }
        }
        compute acceptInput;
    }

    part def LightingFixture {
        port controlIn : ControlIn;
        port powerIn : PowerIn;
        attribute maxPower : ElectricPower = 60 [unit "W"];
        attribute currentBrightness : BrightnessLevel = 0 [unit "percent"];
        attribute currentPower : PowerCommand = PowerCommand::off;

        action illuminate {
            in command : ControlCommand;
            in power : PowerFlow;
            perform {
                currentBrightness := command.brightness;
                currentPower := command.power;
            }
        }
        compute illuminate;
    }

    part def PowerSupply {
        port powerOut : PowerOut;
        attribute inputVoltage : Voltage = 120 [unit "V"];
        attribute outputVoltage : Voltage = 24 [unit "V"];
        attribute maxOutput : ElectricPower = 200 [unit "W"];
        attribute efficiency : Real [0..1] = 0.92;

        action convertPower {
            out power : PowerFlow;
            perform {
                send PowerFlow {
                    voltage = outputVoltage;
                    power = maxOutput;
                } to powerOut.power;
            }
        }
        compute convertPower;
    }

    // ---- Lighting Controller ----
    part def LightingController {
        port occupancyIn : OccupancyOut;
        port lightIn : LightOut;
        port panelIn : UserPanelOut;
        port fixtureControl1 : ControlOut;
        port fixtureControl2 : ControlOut;

        attribute mode : SystemMode = SystemMode::automatic;
        attribute timeout : TimeDuration = 300 [unit "s"];
        attribute emptyTimer : TimeDuration = 0 [unit "s"];
        attribute daylightThreshold : Illuminance = 300 [unit "lux"];
        attribute lowBrightness : BrightnessLevel = 20 [unit "percent"];
        attribute fullBrightness : BrightnessLevel = 100 [unit "percent"];
        attribute manualBrightness : BrightnessLevel = 100 [unit "percent"];
        attribute manualPower : PowerCommand = PowerCommand::on;

        action sendOffCommand {
            perform {
                send ControlCommand {
                    power = PowerCommand::off;
                    brightness = 0 [unit "percent"];
                } to fixtureControl1.command;
                send ControlCommand {
                    power = PowerCommand::off;
                    brightness = 0 [unit "percent"];
                } to fixtureControl2.command;
            }
        }

        action sendOnCommand {
            in brightness : BrightnessLevel;
            perform {
                send ControlCommand {
                    power = PowerCommand::on;
                    brightness = brightness;
                } to fixtureControl1.command;
                send ControlCommand {
                    power = PowerCommand::on;
                    brightness = brightness;
                } to fixtureControl2.command;
            }
        }

        action sendManualCommand {
            perform {
                send ControlCommand {
                    power = manualPower;
                    brightness = manualBrightness;
                } to fixtureControl1.command;
                send ControlCommand {
                    power = manualPower;
                    brightness = manualBrightness;
                } to fixtureControl2.command;
            }
        }

        state def ControllerBehavior {
            entry; then Automatic;

            state Automatic {
                entry; then Monitoring;

                state Monitoring {
                    entry / emptyTimer := 0 [unit "s"];
                }

                transition monitoring_to_empty
                    source Monitoring
                    target EmptyTimeout
                    guard occupancyIn.data.state == OccupancyState::empty;

                transition monitoring_to_occupied
                    source Monitoring
                    target Occupied
                    guard occupancyIn.data.state == OccupancyState::occupied;

                state EmptyTimeout {
                    entry / emptyTimer := 0 [unit "s"];
                    do sendOffCommand;
                    transition empty_timeout_complete
                        source EmptyTimeout
                        target EmptyOff
                        guard emptyTimer >= timeout;
                    transition empty_to_occupied
                        source EmptyTimeout
                        target Occupied
                        guard occupancyIn.data.state == OccupancyState::occupied;
                }

                state EmptyOff {
                    do sendOffCommand;
                    transition emptyOff_to_occupied
                        source EmptyOff
                        target Occupied
                        guard occupancyIn.data.state == OccupancyState::occupied;
                }

                state Occupied {
                    transition occupied_dark
                        source Occupied
                        target LightsOn
                        guard lightIn.data.level < daylightThreshold;
                    transition occupied_bright
                        source Occupied
                        target LightsDim
                        guard lightIn.data.level >= daylightThreshold;
                }

                state LightsOn {
                    entry / sendOnCommand(fullBrightness);
                    transition lightsOn_to_monitoring
                        source LightsOn
                        target Monitoring
                        guard occupancyIn.data.state == OccupancyState::empty;
                }

                state LightsDim {
                    entry / sendOnCommand(lowBrightness);
                    transition lightsDim_to_monitoring
                        source LightsDim
                        target Monitoring
                        guard occupancyIn.data.state == OccupancyState::empty;
                }
            }

            state Manual {
                entry / sendManualCommand;
                transition manual_to_automatic
                    source Manual
                    target Automatic
                    guard panelIn.command.mode == SystemMode::automatic;
            }

            transition automatic_to_manual
                source Automatic
                target Manual
                guard panelIn.command.mode == SystemMode::manual;
        }

        compute ControllerBehavior;
    }

    // ---- System Assembly ----
    part def LightingControlSystem {
        part controller : LightingController;
        part occupancySensor : OccupancySensor;
        part lightSensor : LightSensor;
        part userPanel : UserPanel;
        part fixture1 : LightingFixture;
        part fixture2 : LightingFixture;
        part powerSupply : PowerSupply;

        connect occupancySensor.occupancyOut to controller.occupancyIn;
        connect lightSensor.lightOut to controller.lightIn;
        connect userPanel.panelOut to controller.panelIn;
        connect controller.fixtureControl1 to fixture1.controlIn;
        connect controller.fixtureControl2 to fixture2.controlIn;
        connect powerSupply.powerOut to fixture1.powerIn;
        connect powerSupply.powerOut to fixture2.powerIn;
    }

    // ---- Requirements ----
    requirement def EnergyEfficiencyRequirement {
        subject system : LightingControlSystem;
        attribute maxStandbyPower : ElectricPower = 5 [unit "W"];
        constraint {
            system.controller.mode == SystemMode::automatic and
            system.controller.occupancyIn.data.state == OccupancyState::empty implies
            system.fixture1.currentPower == PowerCommand::off and
            system.fixture2.currentPower == PowerCommand::off
        }
        constraint {
            system.controller.mode == SystemMode::automatic and
            system.controller.lightIn.data.level >= system.controller.daylightThreshold implies
            system.fixture1.currentBrightness <= system.controller.lowBrightness and
            system.fixture2.currentBrightness <= system.controller.lowBrightness
        }
    }

    requirement def UserComfortRequirement {
        subject system : LightingControlSystem;
        attribute minIlluminance : Illuminance = 300 [unit "lux"];
        constraint {
            system.controller.mode == SystemMode::automatic and
            system.controller.occupancyIn.data.state == OccupancyState::occupied and
            system.controller.lightIn.data.level < system.controller.daylightThreshold implies
            system.fixture1.currentBrightness == system.controller.fullBrightness and
            system.fixture2.currentBrightness == system.controller.fullBrightness
        }
        constraint {
            system.controller.mode == SystemMode::manual implies
            system.fixture1.currentBrightness == system.controller.manualBrightness and
            system.fixture2.currentBrightness == system.controller.manualBrightness
        }
    }

    requirement def ResponsivenessRequirement {
        subject system : LightingControlSystem;
        attribute maxOccupancyResponseTime : TimeDuration = 2 [unit "s"];
        attribute maxTimeout : TimeDuration = 300 [unit "s"];
        constraint {
            system.controller.timeout <= maxTimeout
        }
        constraint {
            system.occupancySensor.detectionInterval <= maxOccupancyResponseTime
        }
    }

    requirement def SafetyRequirement {
        subject system : LightingControlSystem;
        constraint {
            system.powerSupply.outputVoltage == 24 [unit "V"] and
            system.powerSupply.maxOutput >= system.fixture1.maxPower + system.fixture2.maxPower
        }
    }

    requirement EnergyEfficiency : EnergyEfficiencyRequirement {
        subject : LightingControlSystem;
    }

    requirement UserComfort : UserComfortRequirement {
        subject : LightingControlSystem;
    }

    requirement Responsiveness : ResponsivenessRequirement {
        subject : LightingControlSystem;
    }

    requirement Safety : SafetyRequirement {
        subject : LightingControlSystem;
    }

    // ---- Verification Use Case ----
    action def VerifyAutomaticOffOnEmpty {
        in system : LightingControlSystem;
        perform {
            system.controller.mode := SystemMode::automatic;
            system.occupancySensor.currentState := OccupancyState::empty;
            assert system.fixture1.currentPower == PowerCommand::off;
            assert system.fixture2.currentPower == PowerCommand::off;
        }
    }

    action def VerifyManualOverride {
        in system : LightingControlSystem;
        perform {
            system.userPanel.currentMode := SystemMode::manual;
            system.userPanel.manualBrightness := 50 [unit "percent"];
            assert system.controller.mode == SystemMode::manual;
            assert system.fixture1.currentBrightness == 50 [unit "percent"];
        }
    }
}
