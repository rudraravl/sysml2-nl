package LutronLightingControl {
    import ScalarValues::*;

    public value def Illuminance :> Real { unit "lux"; }
    public value def PowerValue :> Real { unit "W"; }
    public value def DimLevel :> Real { unit "%"; min 0; max 100; }
    public value def Duration :> Real { unit "s"; }
    public value def Probability :> Real { min 0; max 1; }

    public enum def OccupancyState { occupied; unoccupied; }
    public enum def SystemMode { off; monitoring; adjusting; }

    public item def OccupancyReading {
        attribute status : OccupancyState;
        attribute timestamp : Duration;
    }

    public item def AmbientLightReading {
        attribute illuminance : Illuminance;
        attribute timestamp : Duration;
    }

    public item def DimmingCommand {
        attribute targetLevel : DimLevel;
        attribute circuitId : Integer;
    }

    public item def SceneSelection {
        attribute sceneId : Integer;
        attribute override : Boolean;
    }

    public port def OccupancySensorPort {
        out reading : OccupancyReading;
    }

    public port def AmbientLightSensorPort {
        out reading : AmbientLightReading;
    }

    public port def LoadCommandPort {
        in command : DimmingCommand;
    }

    public port def FixtureDrivePort {
        out driveLevel : DimLevel;
    }

    public port def UIPort {
        out selection : SceneSelection;
    }

    public part def OccupancySensor {
        attribute detectionRange : Duration = 8.0;
        attribute detectionInterval : Duration = 0.1;
        port sensorOut : OccupancySensorPort;

        action def detectOccupancy {
            in area : Duration;
            out result : OccupancyReading;
        }

        action detect : detectOccupancy {
            in area := detectionRange;
            out result := sensorOut.reading;
        }
    }

    public part def AmbientLightSensor {
        attribute maxRange : Illuminance = 10000;
        attribute samplingInterval : Duration = 0.2;
        port sensorOut : AmbientLightSensorPort;

        action def measureIlluminance {
            out result : AmbientLightReading;
        }

        action measure : measureIlluminance {
            out result := sensorOut.reading;
        }
    }

    public part def LoadController {
        attribute maxLoad : PowerValue;
        attribute circuitId : Integer;
        attribute currentLevel : DimLevel = 0;
        port loadIn : LoadCommandPort;
        port fixtureOut : FixtureDrivePort;

        action def applyCommand {
            in cmd : DimmingCommand;
            out level : DimLevel;
        }

        action apply : applyCommand {
            in cmd := loadIn.command;
            out level := fixtureOut.driveLevel;
        }
    }

    public part def LightFixture {
        attribute maxPower : PowerValue;
        attribute currentLevel : DimLevel = 0;
        port driveIn : ~FixtureDrivePort;

        action def emitLight {
            in level : DimLevel;
        }

        action emit : emitLight {
            in level := driveIn.driveLevel;
        }
    }

    public part def WallUI {
        attribute buttonCount : Integer = 6;
        attribute sceneCount : Integer = 4;
        port uiOut : UIPort;

        action def buttonPress {
            in buttonId : Integer;
            out selection : SceneSelection;
        }

        action press : buttonPress {
            in buttonId : Integer;
            out selection := uiOut.selection;
        }
    }

    public part def CentralProcessor {
        attribute responseTimeTarget : Duration = 0.5;
        attribute occupiedThreshold : Illuminance = 100;
        attribute dimThreshold : Illuminance = 300;
        attribute offDelay : Duration = 15.0;
        port occIn : ~OccupancySensorPort;
        port lightIn : ~AmbientLightSensorPort;
        port uiIn : ~UIPort;
        port cmdOut : ~LoadCommandPort;

        attribute currentMode : SystemMode = SystemMode::off;
        attribute occupancyDetected : Boolean = false;
        attribute ambientLevel : Illuminance = 0;
        attribute manualOverride : Boolean = false;
        attribute targetLevel : DimLevel = 0;
        attribute activeSceneId : Integer = 0;

        action def computeTargetLevel {
            in measured : Illuminance;
            in occupied : Boolean;
            out level : DimLevel;
        }

        action compute : computeTargetLevel {
            in measured := ambientLevel;
            in occupied := occupancyDetected;
            out level := targetLevel;
        }

        state def ProcessorStateMachine {
            state off {
                entry { currentMode := SystemMode::off; }
                exit { occupancyDetected := true; }
            }

            state monitoring {
                entry { currentMode := SystemMode::monitoring; }
            }

            state adjusting {
                entry { currentMode := SystemMode::adjusting; }
            }

            transition off to monitoring
                when occIn.reading.status == OccupancyState::occupied
                do {
                    occupancyDetected := true;
                    ambientLevel := lightIn.reading.illuminance;
                };

            transition monitoring to adjusting
                when occIn.reading.status == OccupancyState::occupied
                    and lightIn.reading.illuminance < occupiedThreshold
                do {
                    ambientLevel := lightIn.reading.illuminance;
                    targetLevel := 100 - (ambientLevel / dimThreshold) * 100;
                    if targetLevel < 10 { targetLevel := 10; }
                    cmdOut.command := DimmingCommand { targetLevel := targetLevel, circuitId := 1; };
                };

            transition monitoring to adjusting
                when occIn.reading.status == OccupancyState::occupied
                    and lightIn.reading.illuminance >= occupiedThreshold
                    and lightIn.reading.illuminance < dimThreshold
                do {
                    ambientLevel := lightIn.reading.illuminance;
                    targetLevel := 100 - (ambientLevel / dimThreshold) * 100;
                    cmdOut.command := DimmingCommand { targetLevel := targetLevel, circuitId := 1; };
                };

            transition monitoring to off
                when occIn.reading.status == OccupancyState::unoccupied
                    and not manualOverride
                do {
                    occupancyDetected := false;
                    targetLevel := 0;
                    cmdOut.command := DimmingCommand { targetLevel := 0, circuitId := 1; };
                    cmdOut.command := DimmingCommand { targetLevel := 0, circuitId := 2; };
                };

            transition monitoring to adjusting
                when uiIn.selection.override == true
                do {
                    manualOverride := true;
                    activeSceneId := uiIn.selection.sceneId;
                    targetLevel := sceneToLevel(activeSceneId);
                    cmdOut.command := DimmingCommand { targetLevel := targetLevel, circuitId := 1; };
                };

            transition adjusting to monitoring
                when true
                do {
                    currentMode := SystemMode::monitoring;
                };
        }

        exhibit ProcessorStateMachine;

        private action def sceneToLevel {
            in sceneId : Integer;
            out level : DimLevel;
        }
    }

    public part def LightingControlSystem {
        part processor : CentralProcessor;
        part occSensor : OccupancySensor;
        part lightSensor : AmbientLightSensor;
        part loadController600 : LoadController {
            attribute maxLoad := 600;
            attribute circuitId := 1;
        }
        part loadController1000 : LoadController {
            attribute maxLoad := 1000;
            attribute circuitId := 2;
        }
        part fixture1 : LightFixture {
            attribute maxPower := 600;
        }
        part fixture2 : LightFixture {
            attribute maxPower := 1000;
        }
        part wallUI : WallUI {
            attribute buttonCount := 6;
        }

        connection occSensor.sensorOut to processor.occIn;
        connection lightSensor.sensorOut to processor.lightIn;
        connection wallUI.uiOut to processor.uiIn;
        connection processor.cmdOut to loadController600.loadIn;
        connection processor.cmdOut to loadController1000.loadIn;
        connection loadController600.fixtureOut to fixture1.driveIn;
        connection loadController1000.fixtureOut to fixture2.driveIn;
    }

    public requirement def EnergyEfficiencyRequirement {
        attribute maxStandbyPower : PowerValue = 5;
        attribute minReductionPercent : DimLevel = 30;
        subject : system :> LightingControlSystem;
        objective {
            doc "The system shall reduce lighting energy consumption by at least minReductionPercent compared to always-on baseline, and standby power shall not exceed maxStandbyPower.";
        }
    }

    public requirement def ResponsivenessRequirement {
        attribute maxResponseTime : Duration = 0.5;
        subject : system :> LightingControlSystem;
        objective {
            doc "The system shall react to changes in occupancy within maxResponseTime.";
        }
    }

    public requirement def ReliabilityRequirement {
        attribute minMTBF : Duration = 50000;
        attribute maxFailureProb : Probability = 0.001;
        subject : system :> LightingControlSystem;
        objective {
            doc "The system mean time between failures shall be at least minMTBF hours and failure probability shall not exceed maxFailureProb.";
        }
    }

    public requirement def OccupancyBasedControlRequirement {
        subject : system :> LightingControlSystem;
        objective {
            doc "The system shall turn lights on to an appropriate level when a room becomes occupied and ambient light is insufficient.";
        }
    }

    public requirement def DaylightHarvestingRequirement {
        subject : system :> LightingControlSystem;
        objective {
            doc "The system shall dim or turn off artificial lights when sufficient natural daylight is available, even if the room is occupied.";
        }
    }

    public requirement def VacancyOffRequirement {
        subject : system :> LightingControlSystem;
        objective {
            doc "The system shall turn lights off when all occupants have left the room, subject to manual override.";
        }
    }

    public requirement def ManualOverrideRequirement {
        subject : system :> LightingControlSystem;
        objective {
            doc "The system shall allow users to manually override automatic settings and select pre-programmed lighting scenes via the wall-mounted user interface.";
        }
    }

    public requirement def MultiCircuitSupportRequirement {
        subject : system :> LightingControlSystem;
        objective {
            doc "The system shall manage multiple lighting circuits with different power requirements, including a 600W circuit and a 1000W circuit.";
        }
    }

    public requirement def SystemModeRequirement {
        subject : system :> LightingControlSystem;
        objective {
            doc "The system shall operate in off, monitoring, and adjusting modes, transitioning between them based on sensor inputs and user commands.";
        }
    }

    public satisfaction satisfyResponsiveness : ResponsivenessRequirement satisfy processor.responseTimeTarget;
    public satisfaction satisfyMultiCircuit : MultiCircuitSupportRequirement satisfy loadController600.maxLoad + loadController1000.maxLoad;
}
}
