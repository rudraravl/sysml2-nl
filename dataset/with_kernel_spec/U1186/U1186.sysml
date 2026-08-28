package BiomimeticRoboticFish {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def SigStartMission;
    attribute def SigObstacleDetected;
    attribute def SigClearPath;
    attribute def SigStationKeepCommand;
    attribute def SigResumeCruise;
    attribute def SigLowBattery;
    attribute def SigCriticalFault;
    attribute def SigAtSurface;

    item def OrientationData {
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }

    item def EnvironmentalData {
        attribute waterTemperature : TemperatureValue;
        attribute waterSalinity : Real;
    }

    item def TelemetryData {
        attribute depth : LengthValue;
        attribute waterTemperature : TemperatureValue;
        attribute waterSalinity : Real;
        attribute batteryLevel : Real;
        attribute systemStatus : String;
    }

    port def PowerPort;

    action def MaintainHeading;
    action def AvoidObstacle;
    action def HoldPosition;
    action def AscendToSurface;
    action def ReadCellVoltage;
    action def ComputePercent;

    part def BatteryPack {
        attribute safeThreshold : Real = 20.0;
        attribute chargeLevel : Real;
        port powerOut : PowerPort;
        port statusPort {
            out attribute chargeLevel : Real;
        }
        perform action monitorCharge {
            out attribute level : Real;
            first start;
            then action readCellVoltage : ReadCellVoltage;
            then action computePercent : ComputePercent;
            then done;
        }
    }

    part def NavigationController {
        port powerIn : PowerPort;
        port batteryPort {
            in attribute chargeLevel : Real;
        }
        port proximityPort {
            in attribute distance : LengthValue;
            in attribute obstacleDetected : Boolean;
        }
        port depthPort {
            in attribute depth : LengthValue;
        }
        port imuPort {
            in attribute orientation : OrientationData;
        }
        port envPort {
            in attribute envData : EnvironmentalData;
        }
        port tailControlPort {
            out attribute oscillationRate : Real;
        }
        port leftFinControlPort {
            out attribute finAngle : Real;
        }
        port rightFinControlPort {
            out attribute finAngle : Real;
        }
        port telemetryPort {
            out attribute telemetry : TelemetryData;
        }
        port commandPort {
            in attribute command : String;
        }
    }

    part def TailActuator {
        port powerIn : PowerPort;
        port controlPort {
            in attribute oscillationRate : Real;
        }
    }

    part def PectoralFin {
        port powerIn : PowerPort;
        port controlPort {
            in attribute finAngle : Real;
        }
    }

    part def ProximitySensor {
        port powerIn : PowerPort;
        attribute obstacleDetected : Boolean;
        port dataPort {
            out attribute distance : LengthValue;
            out attribute obstacleDetected : Boolean;
        }
    }

    part def DepthSensor {
        port powerIn : PowerPort;
        port dataPort {
            out attribute depth : LengthValue;
        }
    }

    part def InertialMeasurementUnit {
        port powerIn : PowerPort;
        port dataPort {
            out attribute orientation : OrientationData;
        }
    }

    part def EnvironmentalSensorPackage {
        port powerIn : PowerPort;
        port dataPort {
            out attribute envData : EnvironmentalData;
        }
    }

    part def CommunicationModule {
        port powerIn : PowerPort;
        port telemetryPort {
            in attribute telemetry : TelemetryData;
        }
        port commandPort {
            out attribute command : String;
        }
        port radioPort {
            in attribute command : String;
            out attribute telemetry : TelemetryData;
        }
    }

    part def BaseStation {
        port commsPort {
            in attribute telemetry : TelemetryData;
            out attribute command : String;
        }
    }

    requirement def MaxSpeedRequirement {
        /* The robotic fish shall achieve a maximum speed of 1.5 m/s. */
    }

    requirement def MaxDepthRequirement {
        /* The robotic fish shall be rated for depths up to 50 m. */
    }

    requirement def MissionDurationRequirement {
        /* The robotic fish shall operate for up to 4 hours on a single charge. */
    }

    requirement def LowBatterySurfaceRequirement {
        /* The robotic fish shall automatically initiate surfacing when battery charge falls below 20%. */
    }

    part def RoboticFish {
        attribute length : LengthValue = 0.5 [m];
        attribute mass : MassValue = 3.5 [kg];
        attribute maxSpeed : SpeedValue = 1.5 [m/s];
        attribute maxDepth : LengthValue = 50 [m];
        attribute maxMissionDuration : DurationValue = 4 [h];
        attribute lowBatteryThreshold : Real = 20.0;

        part batteryPack : BatteryPack;
        part navigationController : NavigationController;
        part tailActuator : TailActuator;
        part pectoralFinLeft : PectoralFin;
        part pectoralFinRight : PectoralFin;
        part proximitySensor : ProximitySensor;
        part depthSensor : DepthSensor;
        part inertialMeasurementUnit : InertialMeasurementUnit;
        part environmentalSensorPackage : EnvironmentalSensorPackage;
        part communicationModule : CommunicationModule;

        connect batteryPack.powerOut to navigationController.powerIn;
        connect batteryPack.powerOut to tailActuator.powerIn;
        connect batteryPack.powerOut to pectoralFinLeft.powerIn;
        connect batteryPack.powerOut to pectoralFinRight.powerIn;
        connect batteryPack.powerOut to proximitySensor.powerIn;
        connect batteryPack.powerOut to depthSensor.powerIn;
        connect batteryPack.powerOut to inertialMeasurementUnit.powerIn;
        connect batteryPack.powerOut to environmentalSensorPackage.powerIn;
        connect batteryPack.powerOut to communicationModule.powerIn;

        connect batteryPack.statusPort to navigationController.batteryPort;
        connect proximitySensor.dataPort to navigationController.proximityPort;
        connect depthSensor.dataPort to navigationController.depthPort;
        connect inertialMeasurementUnit.dataPort to navigationController.imuPort;
        connect environmentalSensorPackage.dataPort to navigationController.envPort;

        connect navigationController.tailControlPort to tailActuator.controlPort;
        connect navigationController.leftFinControlPort to pectoralFinLeft.controlPort;
        connect navigationController.rightFinControlPort to pectoralFinRight.controlPort;

        connect navigationController.telemetryPort to communicationModule.telemetryPort;
        connect communicationModule.commandPort to navigationController.commandPort;

        action maintainHeading : MaintainHeading;
        action avoidObstacle : AvoidObstacle;
        action holdPosition : HoldPosition;
        action ascend : AscendToSurface;

        action checkBattery {
            out level : Real;
        }

        exhibit state fishStates parallel {
            state operationalModes {
                entry; then cruise;

                state cruise {
                    do maintainHeading;
                }
                accept SigObstacleDetected then maneuver;
                accept SigStationKeepCommand then stationKeeping;
                accept SigLowBattery then surface;
                accept SigCriticalFault then surface;

                state maneuver {
                    do avoidObstacle;
                }
                accept SigClearPath then cruise;
                accept SigStationKeepCommand then stationKeeping;
                accept SigLowBattery then surface;
                accept SigCriticalFault then surface;

                state stationKeeping {
                    do holdPosition;
                }
                accept SigResumeCruise then cruise;
                accept SigObstacleDetected then maneuver;
                accept SigLowBattery then surface;
                accept SigCriticalFault then surface;

                state surface {
                    entry ascend;
                }
                accept SigAtSurface then cruise;
            }

            state batteryHealth {
                entry; then normal;
                do checkBattery;

                state normal;
                accept when checkBattery.level < lowBatteryThreshold
                    do send new SigLowBattery() to this
                    then critical;

                state critical;
                accept SigAtSurface then normal;
            }
        }

        satisfy MaxSpeedRequirement;
        satisfy MaxDepthRequirement;
        satisfy MissionDurationRequirement;
        satisfy LowBatterySurfaceRequirement by batteryHealth;
    }
}
