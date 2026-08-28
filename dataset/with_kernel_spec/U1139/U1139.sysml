package AutonomousDroneSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def SigStartMission;
    attribute def SigCompletePreflight;
    attribute def SigPreflightFailed;
    attribute def SigLowBattery;
    attribute def SigCriticalFailure;
    attribute def SigMissionComplete;
    attribute def SigLand;
    attribute def SigHover;
    attribute def SigCruise;
    attribute def SigManeuver;
    attribute def SigStartSurvey;
    attribute def SigStartDelivery;
    attribute def SigStartPatrol;
    
    attribute def BatteryLevel :> Real;
    attribute def GPSData;
    attribute def TelemetryData;
    attribute def RemoteCommand;
    attribute def ThrustCommand;
    attribute def PackageReleaseCommand;
    attribute def SensorData;
    attribute def PowerValue :> Real;
    
    constraint def BatteryLowConstraint {
        in level : BatteryLevel;
        in threshold : BatteryLevel;
        level < threshold;
    }
    
    requirement def PropulsionRequirement {
        doc /* The drone shall be a quadcopter with four individual motors controlled by a central Flight Control Module. */
    }
    requirement def NavigationRequirement {
        doc /* The Navigation Module shall use GPS and other data to plan routes, follow waypoints, and determine position. */
    }
    requirement def CommunicationRequirement {
        doc /* The Communication Module shall maintain a constant link for telemetry and remote commands. */
    }
    requirement def SensingRequirement {
        doc /* The Sensing Module shall include two sensor units for high-resolution images and environmental data. */
    }
    requirement def PayloadRequirement {
        doc /* The Payload Module shall carry a package and execute a controlled release. */
    }
    requirement def PowerRequirement {
        doc /* The Power Module shall house the battery and manage power distribution to all subsystems. */
    }
    requirement def SafetyRequirement {
        doc /* The system shall automatically return to base or perform emergency landing on low battery or critical failure. */
    }
    
    requirement propulsionRequirement : PropulsionRequirement;
    requirement navigationRequirement : NavigationRequirement;
    requirement communicationRequirement : CommunicationRequirement;
    requirement sensingRequirement : SensingRequirement;
    requirement payloadRequirement : PayloadRequirement;
    requirement powerRequirement : PowerRequirement;
    requirement safetyRequirement : SafetyRequirement;
    
    part def PowerModule {
        attribute batteryLevel : BatteryLevel;
        port powerOut {
            out power : PowerValue;
        }
        port batteryStatusOut {
            out status : BatteryLevel;
        }
        perform action monitorBattery;
        constraint batteryLow : BatteryLowConstraint {
            in level = batteryLevel;
            in threshold = 20.0;
        }
    }
    
    part def FlightControlModule {
        port powerIn {
            in power : PowerValue;
        }
        port batteryStatusIn {
            in status : BatteryLevel;
        }
        port navIn {
            in navData : GPSData;
        }
        port commandIn {
            in command : RemoteCommand;
        }
        port thrustOut1 {
            out thrust : ThrustCommand;
        }
        port thrustOut2 {
            out thrust : ThrustCommand;
        }
        port thrustOut3 {
            out thrust : ThrustCommand;
        }
        port thrustOut4 {
            out thrust : ThrustCommand;
        }
        port payloadCmdOut {
            out releaseCmd : PackageReleaseCommand;
        }
        perform action calculateThrust;
    }
    
    part def NavigationModule {
        port powerIn {
            in power : PowerValue;
        }
        port navOut {
            out navData : GPSData;
        }
        perform action planRoute;
    }
    
    part def CommunicationModule {
        port powerIn {
            in power : PowerValue;
        }
        port sensorDataIn {
            in data : SensorData;
        }
        port telemetryOut {
            out telemetry : TelemetryData;
        }
        port commandOut {
            out command : RemoteCommand;
        }
        perform action sendTelemetry;
        perform action receiveCommand;
    }
    
    part def SensingModule {
        port powerIn {
            in power : PowerValue;
        }
        part sensorUnit1;
        part sensorUnit2;
        port dataOut {
            out data : SensorData;
        }
        perform action captureData;
    }
    
    part def PayloadModule {
        port powerIn {
            in power : PowerValue;
        }
        port releaseCmdIn {
            in releaseCmd : PackageReleaseCommand;
        }
        perform action releasePackage;
    }
    
    part def Motor {
        port thrustIn {
            in thrust : ThrustCommand;
        }
        port powerIn {
            in power : PowerValue;
        }
        perform action generateThrust;
    }
    
    part def PropulsionSystem {
        port powerIn {
            in power : PowerValue;
        }
        part motor1 : Motor;
        part motor2 : Motor;
        part motor3 : Motor;
        part motor4 : Motor;
    }
    
    part def Drone {
        attribute mass :> ISQ::mass;
        attribute maxPayload :> ISQ::mass = 2.0 [kg];
        attribute lowBatteryThreshold : BatteryLevel = 20.0;
        
        part powerModule : PowerModule;
        part flightControlModule : FlightControlModule;
        part navigationModule : NavigationModule;
        part communicationModule : CommunicationModule;
        part sensingModule : SensingModule;
        part payloadModule : PayloadModule;
        part propulsionSystem : PropulsionSystem;
        
        connect powerModule.powerOut to flightControlModule.powerIn;
        connect powerModule.powerOut to navigationModule.powerIn;
        connect powerModule.powerOut to communicationModule.powerIn;
        connect powerModule.powerOut to sensingModule.powerIn;
        connect powerModule.powerOut to payloadModule.powerIn;
        connect powerModule.powerOut to propulsionSystem.powerIn;
        
        connect powerModule.batteryStatusOut to flightControlModule.batteryStatusIn;
        connect navigationModule.navOut to flightControlModule.navIn;
        
        connect flightControlModule.thrustOut1 to propulsionSystem.motor1.thrustIn;
        connect flightControlModule.thrustOut2 to propulsionSystem.motor2.thrustIn;
        connect flightControlModule.thrustOut3 to propulsionSystem.motor3.thrustIn;
        connect flightControlModule.thrustOut4 to propulsionSystem.motor4.thrustIn;
        
        connect sensingModule.dataOut to communicationModule.sensorDataIn;
        connect communicationModule.commandOut to flightControlModule.commandIn;
        connect flightControlModule.payloadCmdOut to payloadModule.releaseCmdIn;
        
        exhibit state droneStates {
            entry; then standby;
            state standby;
            accept SigStartMission then preFlightCheck;
            
            state preFlightCheck {
                entry action performPreflightCheck;
            }
            accept SigCompletePreflight then flying;
            accept SigPreflightFailed then standby;
            
            state flying parallel {
                state flightMode {
                    entry; then cruising;
                    state cruising;
                    accept SigHover then hovering;
                    state hovering;
                    accept SigCruise then cruising;
                    accept SigManeuver then maneuvering;
                    state maneuvering;
                    accept SigCruise then cruising;
                }
                state missionMode {
                    entry; then idle;
                    state idle;
                    accept SigStartSurvey then surveying;
                    accept SigStartDelivery then delivering;
                    accept SigStartPatrol then patrolling;
                    state surveying;
                    accept SigMissionComplete then idle;
                    state delivering;
                    accept SigMissionComplete then idle;
                    state patrolling;
                    accept SigMissionComplete then idle;
                }
            }
            
            transition flying_to_returnToBase
                first flying
                accept SigLowBattery
                then returnToBase;
            transition flying_to_emergencyLanding
                first flying
                accept SigCriticalFailure
                then emergencyLanding;
            
            state returnToBase;
            accept SigLand then standby;
            
            state emergencyLanding;
            accept SigLand then standby;
        }
        
        action performPreflightCheck {
            out passed : Boolean;
            first start;
            then action checkPower;
            then action checkSensors;
            then action checkPayload;
            then action checkNavigation;
            then action checkComms;
            then action evaluateResults {
                out passed : Boolean = true;
            }
            then done;
        }
        
        satisfy propulsionRequirement by propulsionSystem;
        satisfy navigationRequirement by navigationModule;
        satisfy communicationRequirement by communicationModule;
        satisfy sensingRequirement by sensingModule;
        satisfy payloadRequirement by payloadModule;
        satisfy powerRequirement by powerModule;
        satisfy safetyRequirement by droneStates;
    }
    
    part autonomousDrone : Drone;
}
