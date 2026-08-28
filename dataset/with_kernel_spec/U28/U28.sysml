package VaimosAutonomousVehicle {
    private import ISQ::*;
    private import ScalarValues::*;

    package Definitions {
        item def Waypoint {
            attribute latitude : AngleValue;
            attribute longitude : AngleValue;
            attribute altitude : LengthValue;
        }

        item def NavigationData {
            attribute positionX : LengthValue;
            attribute positionY : LengthValue;
            attribute positionZ : LengthValue;
            attribute velocityX : SpeedValue;
            attribute velocityY : SpeedValue;
            attribute velocityZ : SpeedValue;
            attribute roll : AngleValue;
            attribute pitch : AngleValue;
            attribute yaw : AngleValue;
        }

        item def EnvironmentalData {
            attribute temperature : TemperatureValue;
            attribute humidity : Real;
            attribute pressure : PressureValue;
            attribute salinity : Real;
        }

        item def PropulsionCommand {
            attribute thrust : ForceValue;
        }

        item def StabilizationCommand {
            attribute rollAdjust : AngleValue;
            attribute pitchAdjust : AngleValue;
            attribute yawAdjust : AngleValue;
        }

        item def VehicleHealthStatus {
            attribute batteryLevel : Real;
            attribute systemIntegrity : Real;
            attribute errorCodes : Integer[*];
        }

        item def DataPacket {
            attribute timestamp : TimeValue;
            attribute healthStatus : VehicleHealthStatus;
            attribute environmentalData : EnvironmentalData[*];
        }

        item def MissionPlan {
            attribute waypoints : Waypoint[1..*];
        }

        attribute def SigPowerOn;
        attribute def SigInitComplete;
        attribute def SigStartMission;
        attribute def SigWaypointReached;
        attribute def SigMissionComplete;
        attribute def SigDataTransmitted;
        attribute def SigPowerDown;

        action def RunSelfTest;
        action def LoadWaypoints {
            in missionPlan : MissionPlan;
        }

        action def SenseNavigation {
            out navData : NavigationData;
        }

        action def SenseEnvironment {
            out envData : EnvironmentalData;
        }

        action def ComputeTrajectory {
            in navData : NavigationData;
            in envData : EnvironmentalData;
            in nextWaypoint : Waypoint;
            out propCmd : PropulsionCommand;
            out stabCmd : StabilizationCommand;
        }

        action def ActuatePropulsion {
            in propCmd : PropulsionCommand;
        }

        action def ActuateStabilization {
            in stabCmd : StabilizationCommand;
        }

        action def NavigationCycle {
            first start;
            then action senseNav : SenseNavigation;
            then action senseEnv : SenseEnvironment;
            then action compute : ComputeTrajectory;
            then action actuateProp : ActuatePropulsion;
            then action actuateStab : ActuateStabilization;
            then done;
        }

        action def TransmitFinalData {
            in dataPkg : DataPacket;
        }

        action def ShutdownSystems;
        action def DistributePower;

        part def GuidanceComputer {
            port navDataIn { in navData : NavigationData; }
            port sensorDataIn { in envData : EnvironmentalData; }
            port missionPlanIn { in missionPlan : MissionPlan; }
            port propCmdOut { out propCmd : PropulsionCommand; }
            port stabCmdOut { out stabCmd : StabilizationCommand; }
            port telemetryOut { out dataPkg : DataPacket; }
            port powerIn { in power : PowerValue; }
            port batteryStatusIn { in batteryLevel : Real; }
            perform action computeTrajectory : ComputeTrajectory;
        }

        part def NavigationSystem {
            port navDataOut { out navData : NavigationData; }
            port powerIn { in power : PowerValue; }
            perform action senseNavigation : SenseNavigation;
        }

        part def SensorArray {
            port sensorDataOut { out envData : EnvironmentalData; }
            port powerIn { in power : PowerValue; }
            perform action senseEnvironment : SenseEnvironment;
        }

        part def PropulsionSystem {
            port propCmdIn { in propCmd : PropulsionCommand; }
            port powerIn { in power : PowerValue; }
            perform action actuatePropulsion : ActuatePropulsion;
        }

        part def StabilizationSystem {
            port stabCmdIn { in stabCmd : StabilizationCommand; }
            port powerIn { in power : PowerValue; }
            perform action actuateStabilization : ActuateStabilization;
        }

        part def HighCapacityBattery {
            attribute capacity : EnergyValue;
            port batteryLevelOut { out batteryLevel : Real; }
            port powerOut { out power : PowerValue; }
        }

        part def PowerManagement {
            port batteryLevelIn { in batteryLevel : Real; }
            port batteryLevelOut { out batteryLevel : Real; }
            port powerIn { in power : PowerValue; }
            port powerOut { out power : PowerValue; }
            perform action distributePower : DistributePower;
        }

        part def CommunicationModule {
            port dataIn { in dataPkg : DataPacket; }
            port txOut { out dataPkg : DataPacket; }
            port powerIn { in power : PowerValue; }
            attribute maxRange : LengthValue;
            perform action transmitData : TransmitFinalData;
        }

        part def GroundStation {
            port rxIn { in dataPkg : DataPacket; }
        }

        requirement def EnduranceRequirement {
            doc /* The system shall operate continuously for up to 24 hours on a single charge. */
            attribute maxDuration : TimeValue;
        }

        requirement def CommunicationRangeRequirement {
            doc /* The communication module shall transmit data to a ground station up to 50 kilometers away. */
            attribute maxRange : LengthValue;
        }

        requirement def PrecisionNavigationRequirement {
            doc /* The vehicle shall autonomously navigate to predefined waypoints with precision. */
            attribute waypointAccuracy : LengthValue;
        }

        part def Vaimos {
            attribute missionPlan : MissionPlan;
            attribute currentWaypointIndex : Integer = 0;

            part guidanceComputer : GuidanceComputer;
            part navigationSystem : NavigationSystem;
            part sensorArray : SensorArray;
            part propulsionSystem : PropulsionSystem;
            part stabilizationSystem : StabilizationSystem;
            part battery : HighCapacityBattery;
            part powerManagement : PowerManagement;
            part communicationModule : CommunicationModule;

            perform action runSelfTest : RunSelfTest;
            perform action loadWaypoints : LoadWaypoints;
            perform action navigationCycle : NavigationCycle;
            perform action transmitFinalData : TransmitFinalData;

            connect navigationSystem.navDataOut to guidanceComputer.navDataIn;
            connect sensorArray.sensorDataOut to guidanceComputer.sensorDataIn;
            connect guidanceComputer.propCmdOut to propulsionSystem.propCmdIn;
            connect guidanceComputer.stabCmdOut to stabilizationSystem.stabCmdIn;
            connect guidanceComputer.telemetryOut to communicationModule.dataIn;
            connect battery.powerOut to powerManagement.powerIn;
            connect battery.batteryLevelOut to powerManagement.batteryLevelIn;
            connect powerManagement.batteryLevelOut to guidanceComputer.batteryStatusIn;
            connect powerManagement.powerOut to guidanceComputer.powerIn;
            connect powerManagement.powerOut to navigationSystem.powerIn;
            connect powerManagement.powerOut to sensorArray.powerIn;
            connect powerManagement.powerOut to propulsionSystem.powerIn;
            connect powerManagement.powerOut to stabilizationSystem.powerIn;
            connect powerManagement.powerOut to communicationModule.powerIn;

            exhibit state missionStates {
                entry; then poweredOff;
                state poweredOff;
                accept SigPowerOn then initializing;
                state initializing {
                    entry runSelfTest;
                }
                accept SigInitComplete then ready;
                state ready;
                accept SigStartMission then navigating;
                state navigating {
                    entry loadWaypoints;
                    do navigationCycle;
                    accept SigWaypointReached then navigating;
                    accept SigMissionComplete then transmitting;
                }
                state transmitting {
                    entry transmitFinalData;
                }
                accept SigDataTransmitted then poweredDown;
                state poweredDown;
                accept SigPowerDown then poweredOff;
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part vaimosVehicle : Vaimos {
            requirement enduranceReq : EnduranceRequirement;
            requirement commsReq : CommunicationRangeRequirement;
            requirement precisionNavReq : PrecisionNavigationRequirement;
        }

        part groundStation : GroundStation;

        interface vaimosToGroundStation connect vaimosVehicle.communicationModule.txOut to groundStation.rxIn {
            flow dataFlow of DataPacket
                from vaimosVehicle.communicationModule.txOut.dataPkg to groundStation.rxIn.dataPkg;
        }

        satisfy vaimosVehicle.enduranceReq by vaimosVehicle.battery;
        satisfy vaimosVehicle.commsReq by vaimosVehicle.communicationModule;
        satisfy vaimosVehicle.precisionNavReq by vaimosVehicle.guidanceComputer;
    }
}
