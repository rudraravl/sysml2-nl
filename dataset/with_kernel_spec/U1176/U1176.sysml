package ROV_System {
    import ISQ::**;
    import ScalarValues::**;
    
    package ROV_System_Types {
        item def PowerSignal;
        item def ControlCommand;
        item def TelemetryData;
        item def VideoFeed;
        
        attribute def DepthValue :> ScalarValues::Real;
        attribute def HeadingValue :> ScalarValues::Real;
        attribute def BatteryLevelValue :> ScalarValues::Real;
        
        attribute def SigDeploy;
        attribute def SigDescent;
        attribute def SigOperational;
        attribute def SigComplete;
        attribute def SigRecover;
        attribute def SigReset;
        attribute def SigEmergency;
        attribute def SigRecovered;
        attribute def SigInspect;
        attribute def SigManipulate;
        attribute def SigNavigate;
    }

    part def ROVFrame;
    part def PressureHousing;
    part def Thruster;
    part def DepthSensor;
    part def Compass;
    part def Gyroscope;
    part def SonarSystem;
    part def Camera;
    part def LightingSystem;
    part def Gripper;
    part def ManipulatorArm;
    part def BatteryPack;
    part def Display;
    part def OperatorConsole;
    part def PowerGenerator;
    part def CommunicationsEquipment;

    part def ROV {
        part rovFrame : ROVFrame;
        part pressureHousing : PressureHousing;
        part thrusters[6] : Thruster;
        part navigationSystem {
            part depthSensor : DepthSensor;
            part compass : Compass;
            part gyroscope : Gyroscope;
        }
        part sonarSystem : SonarSystem;
        part cameras[2] : Camera;
        part lightingSystem : LightingSystem;
        part manipulatorArm : ManipulatorArm {
            part gripper : Gripper;
        }
        part batteryPack : BatteryPack;
        
        port tetherPort {
            in item power : ROV_System_Types::PowerSignal;
            in item commands : ROV_System_Types::ControlCommand;
            out item telemetry : ROV_System_Types::TelemetryData;
            out item video : ROV_System_Types::VideoFeed;
        }
        
        perform action updateTelemetry {
            out item telemetry : ROV_System_Types::TelemetryData;
            first start;
            then action gatherData;
            then action transmitData;
            then done;
        }
    }

    part def SurfaceControlStation {
        part operatorConsole : OperatorConsole {
            part displays[2..*] : Display;
        }
        part powerGenerator : PowerGenerator;
        part communicationsEquipment : CommunicationsEquipment;
        
        port tetherPort {
            out item power : ROV_System_Types::PowerSignal;
            out item commands : ROV_System_Types::ControlCommand;
            in item telemetry : ROV_System_Types::TelemetryData;
            in item video : ROV_System_Types::VideoFeed;
        }
    }

    part def UmbilicalTether {
        port surfacePort {
            in item power : ROV_System_Types::PowerSignal;
            in item commands : ROV_System_Types::ControlCommand;
            out item telemetry : ROV_System_Types::TelemetryData;
            out item video : ROV_System_Types::VideoFeed;
        }
        port rovPort {
            out item power : ROV_System_Types::PowerSignal;
            out item commands : ROV_System_Types::ControlCommand;
            in item telemetry : ROV_System_Types::TelemetryData;
            in item video : ROV_System_Types::VideoFeed;
        }
        flow surfacePort.power to rovPort.power;
        flow surfacePort.commands to rovPort.commands;
        flow rovPort.telemetry to surfacePort.telemetry;
        flow rovPort.video to surfacePort.video;
    }

    part rovSystem {
        part rov : ROV;
        part controlStation : SurfaceControlStation;
        part tether : UmbilicalTether;
        
        connect controlStation.tetherPort to tether.surfacePort;
        connect tether.rovPort to rov.tetherPort;
        
        state missionLifecycle {
            entry; then standby;
            state standby {
                entry action preDiveChecks {
                    first start;
                    then action checkSystems;
                    then done;
                }
            }
            accept ROV_System_Types::SigDeploy then deployment;
            state deployment;
            accept ROV_System_Types::SigDescent then descent;
            state descent;
            accept ROV_System_Types::SigOperational then operational;
            state operational {
                entry; then navigating;
                state navigating;
                accept ROV_System_Types::SigInspect then inspecting;
                state inspecting;
                accept ROV_System_Types::SigManipulate then manipulating;
                state manipulating;
                accept ROV_System_Types::SigNavigate then navigating;
            }
            accept ROV_System_Types::SigComplete then ascent;
            state ascent;
            accept ROV_System_Types::SigRecover then recovery;
            state recovery;
            accept ROV_System_Types::SigReset then standby;
            
            state emergency {
                entry action autoAscent {
                    first start;
                    then action ascend;
                    then done;
                }
            }
            accept ROV_System_Types::SigEmergency then emergency;
            accept ROV_System_Types::SigRecovered then standby;
        }
        
        requirement def DepthRequirement {
            doc /* The ROV shall operate at depths up to 3000 meters. */
        }
        requirement def TetherRequirement {
            doc /* The umbilical tether shall transmit high-voltage power and high-bandwidth data simultaneously. */
        }
        requirement def EmergencyRequirement {
            doc /* The system shall automatically initiate emergency ascent upon detection of critical failure or low battery. */
        }
        requirement def ManipulatorRequirement {
            doc /* The manipulator arm shall provide at least 6 degrees of freedom for intervention tasks. */
        }
        requirement def DisplayRequirement {
            doc /* The surface control station shall display real-time video feeds and telemetry data including depth, heading, and battery level. */
        }
        
        requirement depthReq : DepthRequirement;
        requirement tetherReq : TetherRequirement;
        requirement emergencyReq : EmergencyRequirement;
        requirement manipulatorReq : ManipulatorRequirement;
        requirement displayReq : DisplayRequirement;
    }
}
