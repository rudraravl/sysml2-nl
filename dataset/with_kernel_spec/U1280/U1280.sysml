package DustbotSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def StartMission;
    attribute def DirtDetected;
    attribute def ObstacleDetected;
    attribute def AreaClean;
    attribute def PathClear;
    attribute def Docked;
    attribute def ChargeComplete;

    action def ScanEnvironment;
    action def NavigateArea;
    action def CleanFloor;
    action def ActivateVacuum;
    action def RotateBrush;
    action def ReplanPath;
    action def NavigateToDock;
    action def RechargeBattery;
    action def EmptyDustBin;

    part def DockingStation {
        port chargingPort;
        port emptyingPort;
    }

    part def Dustbot {
        attribute maxProximityRange : LengthValue = 0.8 [m];
        attribute binCapacity : MassValue = 0.6 [kg];

        part proximitySensors[6];
        part floorSensors[3];
        part vacuumUnit;
        part brushAssembly;
        part dustBin {
            attribute currentFill : MassValue;
        }
        part navigationModule;
        part motorController;
        part wheels[2];
        part battery {
            attribute chargeLevel : Real;
            attribute lowThreshold : Real = 0.2;
        }

        port dockingPort;

        perform action scanEnvironment : ScanEnvironment;
        perform action navigateArea : NavigateArea;
        perform action cleanFloor : CleanFloor;
        perform action activateVacuum : ActivateVacuum;
        perform action rotateBrush : RotateBrush;
        perform action replanPath : ReplanPath;
        perform action navigateToDock : NavigateToDock;
        perform action rechargeBattery : RechargeBattery;
        perform action emptyDustBin : EmptyDustBin;

        exhibit state 'dustbot states' {
            entry; then standby;
            state standby;
            accept StartMission then active;
            state active {
                entry; then scanning;
                do scanEnvironment;
                do navigateArea;
                do cleanFloor;

                state scanning;
                accept DirtDetected then cleaning;
                accept ObstacleDetected then avoiding;

                state cleaning {
                    do activateVacuum;
                    do rotateBrush;
                }
                accept AreaClean then scanning;

                state avoiding {
                    do replanPath;
                }
                accept PathClear then scanning;
            }
            accept when battery.chargeLevel < battery.lowThreshold then returningToDock;
            accept when dustBin.currentFill >= binCapacity then returningToDock;

            state returningToDock {
                do navigateToDock;
            }
            accept Docked then charging;

            state charging {
                do rechargeBattery;
                do emptyDustBin;
            }
            accept ChargeComplete then standby;
        }
    }

    part dustbot : Dustbot {
        part dock : DockingStation;

        connect dockingPort to dock.chargingPort;
        connect dockingPort to dock.emptyingPort;
    }

    requirement def ObstacleAvoidanceRequirement {
        text "Proximity sensors must detect obstacles up to 0.8 meters.";
    }

    requirement def DirtDetectionRequirement {
        text "Floor sensors must assess dirt level to focus cleaning.";
    }

    requirement def BinCapacityRequirement {
        text "Dust bin capacity must be 0.6 kg.";
    }

    requirement def AutonomousOperationRequirement {
        text "System must automatically return to dock for charging or emptying.";
    }

    requirement obstacleAvoidance : ObstacleAvoidanceRequirement;
    requirement dirtDetection : DirtDetectionRequirement;
    requirement binCapacity : BinCapacityRequirement;
    requirement autonomousOperation : AutonomousOperationRequirement;

    satisfy obstacleAvoidance by dustbot.proximitySensors;
    satisfy dirtDetection by dustbot.floorSensors;
    satisfy binCapacity by dustbot.dustBin;
    satisfy autonomousOperation by dustbot;
}
