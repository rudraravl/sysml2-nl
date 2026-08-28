package RoboticVacuumSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    item def FloorType;
    item def Hardwood :> FloorType;
    item def Carpet :> FloorType;

    attribute def BatteryLevel :> Real;
    attribute def DustLevel :> Real;
    attribute def SensorData;
    attribute def DriveCommands;
    attribute def CleaningCommands;
    attribute def BatteryStatus;
    attribute def DustStatus;
    attribute def BeaconSignal;
    attribute def Power;

    attribute def StartCommand;
    attribute def StopCommand;
    attribute def DockedSignal;
    attribute def ChargeCompleteSignal;
    attribute def StuckSignal;
    attribute def FaultSignal;
    attribute def ResetSignal;
    attribute def LowBatterySignal;
    attribute def DustbinFullSignal;
    attribute def MissionCompleteSignal;
    attribute def DirtDetected;
    attribute def DirtCleared;
    attribute def EdgeDetected;
    attribute def EdgeCleared;

    part def ChargingStation {
        port irBeaconPort {
            out beaconSignal : BeaconSignal;
        }
        port chargingPort {
            out power : Power;
        }
        perform action emitBeacon;
        perform action supplyPower;
    }

    part def RobotVacuum {
        part controlProcessor {
            port sensorDataPort {
                in sensorData : SensorData;
            }
            port driveCmdPort {
                out driveCommands : DriveCommands;
            }
            port cleaningCmdPort {
                out cleaningCommands : CleaningCommands;
            }
            port batteryStatusPort {
                in batteryStatus : BatteryStatus;
            }
            port dustStatusPort {
                in dustStatus : DustStatus;
            }
            port beaconPort {
                in beaconSignal : BeaconSignal;
            }

            exhibit state robotStates {
                entry; then standby;
                state standby;
                accept StartCommand then activeCleaning;

                state activeCleaning {
                    entry; then normal;
                    state normal;
                    accept DirtDetected then intensive;
                    state intensive;
                    accept DirtCleared then normal;
                    accept EdgeDetected then edge;
                    state edge;
                    accept EdgeCleared then normal;
                }
                accept LowBatterySignal then returningToBase;
                accept DustbinFullSignal then returningToBase;
                accept MissionCompleteSignal then returningToBase;
                accept StuckSignal then error;
                accept FaultSignal then error;

                state returningToBase {
                    do action seekBeacon;
                    do action navigateToDock;
                }
                accept DockedSignal then docked;

                state docked {
                    do action chargeBattery;
                }
                accept ChargeCompleteSignal then standby;

                state error {
                    do action haltMotors;
                    do action alertUser;
                }
                accept ResetSignal then standby;
            }
        }

        part navigationSystem {
            port sensorOutPort {
                out sensorData : SensorData;
            }
            part irSensors[4];
            part bumpSensors[2];
            part cliffSensors[4];
            perform action processSensorData {
                out obstacleDetected : Boolean;
                out cliffDetected : Boolean;
                out contactDetected : Boolean;
            }
            perform action navigateToDock {
                in beaconSignal : BeaconSignal;
            }
        }

        part driveSystem {
            port driveInPort {
                in driveCommands : DriveCommands;
            }
            part leftWheel;
            part rightWheel;
            part casterWheel;
            perform action maneuver {
                in leftSpeed : Real;
                in rightSpeed : Real;
            }
        }

        part cleaningMechanism {
            port cleaningInPort {
                in cleaningCommands : CleaningCommands;
            }
            part mainBrush;
            part sideBrushes[2];
            part vacuumMotor;
            attribute currentFloorType : FloorType;
            perform action clean {
                in floorType : FloorType;
                in intensity : Real;
            }
        }

        part dustContainer {
            port dustOutPort {
                out dustStatus : DustStatus;
            }
            attribute dustLevel : DustLevel;
            attribute capacity : DustLevel = 100.0;
            perform action checkFillLevel {
                out level : DustLevel;
            }
        }

        part batteryModule {
            port batteryOutPort {
                out batteryStatus : BatteryStatus;
            }
            port chargeInPort {
                in power : Power;
            }
            attribute chargeLevel : BatteryLevel;
            attribute lowThreshold : BatteryLevel = 20.0;
            attribute fullThreshold : BatteryLevel = 90.0;
            perform action monitorCharge {
                out level : BatteryLevel;
            }
        }

        connect navigationSystem.sensorOutPort to controlProcessor.sensorDataPort;
        connect controlProcessor.driveCmdPort to driveSystem.driveInPort;
        connect controlProcessor.cleaningCmdPort to cleaningMechanism.cleaningInPort;
        connect batteryModule.batteryOutPort to controlProcessor.batteryStatusPort;
        connect dustContainer.dustOutPort to controlProcessor.dustStatusPort;
    }

    part vacuumSystem : RobotVacuum {
        part chargingStation : ChargingStation;

        connect chargingStation.irBeaconPort to controlProcessor.beaconPort;
        connect chargingStation.chargingPort to batteryModule.chargeInPort;
    }

    requirement def VacuumSystemRequirement {
        doc /* The autonomous robotic vacuum cleaning system shall automatically navigate and clean floor surfaces within a home or office environment, operating independently and returning to its charging station when the battery is low or the cleaning task is complete. */
        
        requirement NavigationRequirement {
            doc /* The robot shall use infrared, bump, and cliff sensors to navigate and avoid obstacles. */
        }
        requirement CleaningRequirement {
            doc /* The cleaning mechanism shall adapt intensity based on floor type and utilize main brush, side brushes, and vacuum motor components. */
        }
        requirement PowerRequirement {
            doc /* The system shall monitor battery level and return to dock when low, recharging until ready for the next mission. */
        }
        requirement DockingRequirement {
            doc /* The charging station shall emit an infrared beacon signal to enable the robot to locate and autonomously dock for recharging. */
        }
    }
}
