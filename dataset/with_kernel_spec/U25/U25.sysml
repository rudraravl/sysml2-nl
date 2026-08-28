package TaurobInspector {
    private import ISQ::*;
    private import ScalarValues::*;

    package Definitions {
        item def TelemetryData;
        item def VideoStream;
        item def SensorData;
        item def CommandData;
        item def Sample;
        
        attribute def StartCharging;
        attribute def StopCharging;
        attribute def StartMission;
        attribute def ReachInspectionPoint;
        attribute def RequireManipulation;
        attribute def FinishInspectionPoint;
        attribute def FinishManipulation;
        attribute def CompleteMission;
        attribute def EmergencyTrigger;
        attribute def ResetEmergency;
        
        port def PowerOutPort {
            out attribute voltage :> ISQ::electricPotential;
            out attribute current :> ISQ::electricCurrent;
        }
        port def PowerInPort {
            in attribute voltage :> ISQ::electricPotential;
            in attribute current :> ISQ::electricCurrent;
        }
        port def DataOutPort {
            out item data : SensorData;
        }
        port def DataInPort {
            in item data : SensorData;
        }
        port def VideoOutPort {
            out item video : VideoStream;
        }
        port def VideoInPort {
            in item video : VideoStream;
        }
        port def CmdOutPort {
            out item cmd : CommandData;
        }
        port def CmdInPort {
            in item cmd : CommandData;
        }
        port def DriveControlPort {
            in attribute speed :> ISQ::speed;
            in attribute direction : String;
        }
        port def ArmControlPort {
            in attribute jointAngles : Real[6];
            in attribute gripperCommand : Boolean;
        }
        
        part def TrackedChassis {
            attribute maxIncline :> ISQ::planeAngle;
            part leftTrack;
            part rightTrack;
            part suspensionSystem;
            part leftDriveMotor {
                port pwrIn : PowerInPort;
                port ctrlIn : DriveControlPort;
            }
            part rightDriveMotor {
                port pwrIn : PowerInPort;
                port ctrlIn : DriveControlPort;
            }
        }
        
        part def MultiSensorArray {
            part visualCameras[4] {
                port videoOut : VideoOutPort;
            }
            part thermalImager {
                port dataOut : DataOutPort;
            }
            part gasDetectors[3] {
                port dataOut : DataOutPort;
            }
            part lidarUnit {
                port dataOut : DataOutPort;
            }
            part imu {
                port dataOut : DataOutPort;
            }
        }
        
        part def ArticulatedManipulator {
            part joints[6];
            part gripper;
            port ctrlIn : ArmControlPort;
            perform action collectSample {
                out item sample : Sample;
            }
        }
        
        part def OnboardComputer {
            part processor;
            part safetySystem {
                attribute hazardDetected : Boolean;
                perform action monitorHazards;
            }
            port sensorDataIn : DataInPort;
            port videoIn : VideoInPort;
            port cmdIn : CmdInPort;
            port commDataOut : DataOutPort;
            port commVideoOut : VideoOutPort;
            port leftChassisCtrlOut : DriveControlPort;
            port rightChassisCtrlOut : DriveControlPort;
            port armCtrlOut : ArmControlPort;
            port pwrIn : PowerInPort;
            perform action planPath;
            perform action avoidObstacles;
            perform action manageMission;
        }
        
        part def BatteryPack {
            attribute capacity :> ISQ::energy;
            part cells;
            part batteryManagementSystem;
            port pwrOut : PowerOutPort;
            port statusOut {
                out attribute chargeLevel : Real;
            }
        }
        
        part def CommunicationSystem {
            attribute range :> ISQ::length;
            part transmitter;
            part receiver;
            part antenna;
            port dataIn : DataInPort;
            port videoIn : VideoInPort;
            port cmdOut : CmdOutPort;
            attribute encryptionEnabled : Boolean = true;
        }
        
        part def TaurobInspectorRobot {
            attribute mass :> ISQ::mass;
            part chassis : TrackedChassis;
            part sensors : MultiSensorArray;
            part arm : ArticulatedManipulator;
            part computer : OnboardComputer;
            part battery : BatteryPack;
            part comm : CommunicationSystem;
            
            connect battery.pwrOut to chassis.leftDriveMotor.pwrIn;
            connect battery.pwrOut to chassis.rightDriveMotor.pwrIn;
            connect battery.pwrOut to computer.pwrIn;
            
            connect sensors.visualCameras.videoOut to computer.videoIn;
            connect sensors.thermalImager.dataOut to computer.sensorDataIn;
            connect sensors.gasDetectors.dataOut to computer.sensorDataIn;
            connect sensors.lidarUnit.dataOut to computer.sensorDataIn;
            connect sensors.imu.dataOut to computer.sensorDataIn;
            
            connect computer.leftChassisCtrlOut to chassis.leftDriveMotor.ctrlIn;
            connect computer.rightChassisCtrlOut to chassis.rightDriveMotor.ctrlIn;
            connect computer.armCtrlOut to arm.ctrlIn;
            
            connect computer.commDataOut to comm.dataIn;
            connect computer.commVideoOut to comm.videoIn;
            connect comm.cmdOut to computer.cmdIn;
            
            exhibit state operationalModes {
                entry; then standby;
                state standby;
                accept StartCharging then charging;
                state charging;
                accept StopCharging then standby;
                accept StartMission then active;
                state active {
                    entry; then navigating;
                    state navigating;
                    accept ReachInspectionPoint then inspecting;
                    state inspecting;
                    accept RequireManipulation then manipulating;
                    accept FinishInspectionPoint then navigating;
                    state manipulating;
                    accept FinishManipulation then inspecting;
                    accept CompleteMission then operationalModes.standby;
                }
                accept EmergencyTrigger then emergency;
                state emergency;
                accept ResetEmergency then standby;
            }
        }
    }
    
    public import Definitions::*;
    
    action def ExecuteInspectionMission {
        in robot : Definitions::TaurobInspectorRobot;
        perform action navigateRoute;
        perform action inspectPoints;
        perform action transmitResults;
        first start;
        then navigateRoute;
        then inspectPoints;
        then transmitResults;
        then done;
    }
    
    package Requirements {
        private import Definitions::*;
        
        requirement def InspectionMissionRequirement {
            subject robot : TaurobInspectorRobot;
            doc /* The robot shall autonomously inspect hazardous environments. */
        }
    }
}
