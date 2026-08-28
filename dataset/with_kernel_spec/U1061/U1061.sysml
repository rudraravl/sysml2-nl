package TALON_System {
    import ISQ::*;
    import ScalarValues::*;
    
    attribute def BatteryCapacity :> Real;
    attribute def SpeedValue :> Real;
    attribute def DistanceValue :> LengthValue;
    attribute def AngleValue :> Real;
    attribute def VoltageValue :> ElectricPotentialValue;
    attribute def TorqueValue :> Real;
    
    attribute def Sig;
    attribute def SigActivate :> Sig;
    attribute def SigDeactivate :> Sig;
    attribute def SigEmergencyStop :> Sig;
    attribute def SigReset :> Sig;
    attribute def SigDrive :> Sig;
    attribute def SigManipulate :> Sig;
    attribute def SigSurveil :> Sig;
    
    attribute def Coordinate {
        attribute x : DistanceValue;
        attribute y : DistanceValue;
    }
    enum def ArmStatus { idle; moving; grasping; lifting; }
    enum def GripCommand { open; close; hold; }
    enum def GripStatus { open; closed; moving; }
    attribute def JointAngles {
        attribute base : AngleValue;
        attribute elbow : AngleValue;
        attribute wrist : AngleValue;
    }
    item def VideoFrame;
    attribute def TelemetryPacket {
        attribute position : Coordinate;
        attribute armStatus : ArmStatus;
        attribute batteryLevel : BatteryCapacity;
    }
    attribute def CommandPacket {
        attribute signal : Sig;
        attribute payload : ScalarValues::String;
    }
    
    port def PowerPort {
        out attribute voltage : VoltageValue;
    }
    port def MotorControlPort {
        in attribute desiredSpeed : SpeedValue;
        out attribute actualSpeed : SpeedValue;
        out attribute torque : TorqueValue;
    }
    port def ArmControlPort {
        in attribute jointAngles : JointAngles;
        in attribute gripCommand : GripCommand;
        out attribute currentAngles : JointAngles;
        out attribute gripStatus : GripStatus;
    }
    port def SensorDataPort {
        out attribute obstacleDetected : ScalarValues::Boolean;
        out attribute distance : DistanceValue;
    }
    port def VideoPort {
        out attribute video : VideoFrame;
    }
    port def RadioPort {
        in attribute command : CommandPacket;
        in attribute emergencyStop : SigEmergencyStop;
        out attribute video : VideoFrame;
        out attribute telemetry : TelemetryPacket;
    }
    port def BatteryStatusPort {
        out attribute chargeLevel : BatteryCapacity;
    }
    
    part def Battery {
        attribute capacity : BatteryCapacity;
        attribute currentCharge : BatteryCapacity;
        port powerOut : PowerPort;
        port statusOut : BatteryStatusPort;
    }
    
    part def DriveMotor {
        attribute maxSpeed : SpeedValue;
        port powerIn : PowerPort;
        port controlIn : MotorControlPort;
    }
    
    part def ManipulatorArm {
        part joint1;
        part joint2;
        part joint3;
        part gripper;
        port powerIn : PowerPort;
        port controlIn : ArmControlPort;
    }
    
    part def Camera {
        port powerIn : PowerPort;
        port videoOut : VideoPort;
    }
    
    part def ProximitySensor {
        port powerIn : PowerPort;
        port dataOut : SensorDataPort;
    }
    
    part def MainController {
        port powerIn : PowerPort;
        port commandIn {
            in attribute command : CommandPacket;
            in attribute emergencyStop : SigEmergencyStop;
        }
        port leftMotorControl : MotorControlPort;
        port rightMotorControl : MotorControlPort;
        port armControl : ArmControlPort;
        port frontSensorIn : SensorDataPort;
        port rearSensorIn : SensorDataPort;
        port primaryCameraIn : VideoPort;
        port armCameraIn : VideoPort;
        port batteryStatusIn : BatteryStatusPort;
        port telemetryOut {
            out attribute telemetry : TelemetryPacket;
        }
        port videoOut {
            out attribute video : VideoFrame;
        }
    }
    
    part def TALONRobot {
        attribute mass : MassValue;
        
        port radioIn : RadioPort;
        
        part battery : Battery;
        part leftDriveMotor : DriveMotor;
        part rightDriveMotor : DriveMotor;
        part leftTrack;
        part rightTrack;
        part manipulatorArm : ManipulatorArm;
        part primaryCamera : Camera;
        part armCamera : Camera;
        part frontProximitySensor : ProximitySensor;
        part rearProximitySensor : ProximitySensor;
        part mainController : MainController;
        part radio {
            port powerIn : PowerPort;
            port antenna : RadioPort;
            port toController {
                out attribute command : CommandPacket;
                out attribute emergencyStop : SigEmergencyStop;
                in attribute video : VideoFrame;
                in attribute telemetry : TelemetryPacket;
            }
        }
        
        connect battery.powerOut to leftDriveMotor.powerIn;
        connect battery.powerOut to rightDriveMotor.powerIn;
        connect battery.powerOut to manipulatorArm.powerIn;
        connect battery.powerOut to primaryCamera.powerIn;
        connect battery.powerOut to armCamera.powerIn;
        connect battery.powerOut to frontProximitySensor.powerIn;
        connect battery.powerOut to rearProximitySensor.powerIn;
        connect battery.powerOut to mainController.powerIn;
        connect battery.powerOut to radio.powerIn;
        connect battery.statusOut to mainController.batteryStatusIn;
        
        connect mainController.leftMotorControl to leftDriveMotor.controlIn;
        connect mainController.rightMotorControl to rightDriveMotor.controlIn;
        connect mainController.armControl to manipulatorArm.controlIn;
        connect frontProximitySensor.dataOut to mainController.frontSensorIn;
        connect rearProximitySensor.dataOut to mainController.rearSensorIn;
        connect primaryCamera.videoOut to mainController.primaryCameraIn;
        connect armCamera.videoOut to mainController.armCameraIn;
        
        connect radio.antenna to radioIn;
        connect radio.toController to mainController.commandIn;
        connect mainController.telemetryOut to radio.toController;
        connect mainController.videoOut to radio.toController;
        
        state talonStates {
            entry; then standby;
            state standby;
            accept SigActivate then operational;
            state operational {
                entry; then driving;
                state driving;
                accept SigManipulate then manipulating;
                accept SigSurveil then surveillance;
                state manipulating;
                accept SigDrive then driving;
                accept SigSurveil then surveillance;
                state surveillance;
                accept SigDrive then driving;
                accept SigManipulate then manipulating;
            }
            accept SigDeactivate then standby;
            accept SigEmergencyStop then emergencyStop;
            state emergencyStop;
            accept SigReset then standby;
        }
    }
    
    part def VideoDisplay {
        port videoIn : VideoPort;
        port telemetryIn {
            in attribute telemetry : TelemetryPacket;
        }
    }
    
    part def Joystick {
        port commandOut {
            out attribute command : CommandPacket;
        }
    }
    
    part def CommandInterface {
        port commandOut {
            out attribute command : CommandPacket;
            out attribute emergencyStop : SigEmergencyStop;
        }
    }
    
    part def OperatorConsole {
        port radioOut : RadioPort;
        port radioIn : RadioPort;
        
        part videoDisplay : VideoDisplay;
        part joystick : Joystick;
        part commandInterface : CommandInterface;
        part consoleRadio {
            port antenna : RadioPort;
            port toConsole {
                in attribute command : CommandPacket;
                in attribute emergencyStop : SigEmergencyStop;
                out attribute video : VideoFrame;
                out attribute telemetry : TelemetryPacket;
            }
        }
        
        connect joystick.commandOut to consoleRadio.toConsole;
        connect commandInterface.commandOut to consoleRadio.toConsole;
        connect consoleRadio.toConsole to videoDisplay.videoIn;
        connect consoleRadio.toConsole to videoDisplay.telemetryIn;
        connect consoleRadio.antenna to radioOut;
        connect consoleRadio.antenna to radioIn;
    }
    
    part def TALONSystem {
        part robot : TALONRobot;
        part console : OperatorConsole;
        
        connect console.radioOut to robot.radioIn;
        connect robot.radioIn to console.radioIn;
    }
    
    requirement def TALONRequirements {
        requirement RemoteOperation {
            doc /* The TALON system shall allow an operator to remotely control the robot from a safe distance via a wireless link. */
            subject talonSystem : TALONSystem;
        }
        requirement HazardousEnvironmentOperation {
            doc /* The robot shall be capable of operating in hazardous environments including EOD, reconnaissance, and hazmat handling. */
            subject robot : TALONRobot;
        }
        requirement EmergencyStopCapability {
            doc /* The system shall provide an emergency stop function that immediately halts all robot movement when triggered. */
            subject robot : TALONRobot;
        }
        requirement DualVideoFeed {
            doc /* The robot shall stream live video from at least two cameras: a primary navigation camera and an arm-mounted close-up camera. */
            subject robot : TALONRobot;
        }
        requirement TrackedMobility {
            doc /* The robot shall use left and right drive motors powering caterpillar-style tracks to navigate difficult terrain including stairs and debris. */
            subject robot : TALONRobot;
        }
        requirement ManipulatorArmCapability {
            doc /* The robot shall be equipped with a multi-jointed manipulator arm capable of grasping, lifting, and precisely manipulating objects. */
            subject robot : TALONRobot;
        }
        requirement ObstacleAvoidance {
            doc /* The robot shall use front and rear proximity sensors to detect and avoid obstacles during operation. */
            subject robot : TALONRobot;
        }
        requirement TelemetryFeedback {
            doc /* The robot shall stream telemetry data including position and arm status to the operator console in real time. */
            subject robot : TALONRobot;
        }
    }
}
