package AutomatedWindowBlindSystem {
    package Definitions {
        package Units {
            import ScalarValues::*;
            unit lux;
            unit percent;
            unit rpm;
            unit nm;
            unit v;
            unit a;
            unit n;
            unit s;
        }
        
        package ValueTypes {
            import Units::*;
            attribute def LightLevel :> Real { * unit = lux; }
            attribute def Position :> Real { * unit = percent; min = 0; max = 100; }
            attribute def MotorSpeed :> Real { * unit = rpm; }
            attribute def Torque :> Real { * unit = nm; }
            attribute def VoltageAC :> Real { * unit = v; }
            attribute def VoltageDC :> Real { * unit = v; }
            attribute def Current :> Real { * unit = a; }
            attribute def Force :> Real { * unit = n; }
            attribute def Time :> Real { * unit = s; }
        }
        
        package Items {
            import ValueTypes::*;
            item def LightData {
                attribute level : LightLevel;
            }
            item def MotorCommand {
                attribute command : String;
                attribute targetSpeed : MotorSpeed;
            }
            item def UserCommand {
                attribute command : String;
                attribute targetPosition : Position optional;
            }
            item def ObstructionAlert;
            item def PowerDC {
                attribute voltage : VoltageDC;
                attribute current : Current;
            }
            item def PowerAC {
                attribute voltage : VoltageAC;
                attribute current : Current;
            }
            item def SmartHomeCommand {
                attribute command : String;
                attribute targetPosition : Position optional;
            }
        }
        
        package Ports {
            import Items::*;
            port def LightSensorOut {
                out lightData : LightData;
            }
            port def ControllerLightIn {
                in lightData : LightData;
            }
            port def MotorCommandOut {
                out motorCmd : MotorCommand;
            }
            port def MotorCommandIn {
                in motorCmd : MotorCommand;
            }
            port def UserCommandOut {
                out userCmd : UserCommand;
            }
            port def UserCommandIn {
                in userCmd : UserCommand;
            }
            port def PowerACIn {
                in power : PowerAC;
            }
            port def PowerDCOut {
                out power : PowerDC;
            }
            port def PowerDCIn {
                in power : PowerDC;
            }
            port def SmartHomeOut {
                out smartHomeCmd : SmartHomeCommand;
            }
            port def SmartHomeIn {
                in smartHomeCmd : SmartHomeCommand;
            }
            port def RotationalForceOut {
                out torque : Torque;
                out speed : MotorSpeed;
            }
            port def RotationalForceIn {
                in torque : Torque;
                in speed : MotorSpeed;
            }
            port def LinearForceOut {
                out force : Force;
            }
            port def LinearForceIn {
                in force : Force;
            }
        }
    }

    package Requirements {
        import Definitions::ValueTypes::*;
        
        requirement def LightRegulation {
            subject : AutomatedWindowBlindSystem;
            attribute targetLightLevel : LightLevel;
            requirement {
                subject.ambientLightLevel <= targetLightLevel + 10 [lux] and
                subject.ambientLightLevel >= targetLightLevel - 10 [lux]
            }
        }
        
        requirement def ManualOverride {
            subject : AutomatedWindowBlindSystem;
            requirement {
                subject.manualOverrideActive == true implies
                subject.automaticModeActive == false
            }
        }
        
        requirement def SafetyObstruction {
            subject : AutomatedWindowBlindSystem;
            requirement {
                subject.obstructionDetected == true implies
                subject.motorActive == false
            }
        }
        
        requirement def PerformanceSpeed {
            subject : AutomatedWindowBlindSystem;
            attribute maxTransitionTime : Time = 10 [s];
            requirement {
                subject.fullTransitionTime <= maxTransitionTime
            }
        }
        
        requirement def PerformanceAccuracy {
            subject : AutomatedWindowBlindSystem;
            attribute positionTolerance : Position = 2 [percent];
            requirement {
                abs(subject.currentPosition - subject.targetPosition) <= positionTolerance
            }
        }
        
        requirement def SmartHomeIntegration {
            subject : AutomatedWindowBlindSystem;
            requirement {
                subject.smartHomeConnected == true
            }
        }
    }

    package Components {
        import Definitions::*;
        import Ports::*;
        
        part def AmbientLightSensor {
            attribute measuredLight : LightLevel;
            port powerIn : PowerDCIn;
            port dataOut : LightSensorOut;
            action def MeasureLight {
                out lightData : LightData;
            }
            perform MeasureLight;
        }
        
        part def ElectricMotor {
            attribute currentSpeed : MotorSpeed;
            attribute maxTorque : Torque;
            port powerIn : PowerDCIn;
            port commandIn : MotorCommandIn;
            port forceOut : RotationalForceOut;
            action def DriveMotor {
                in cmd : MotorCommand;
                out torque : Torque;
                out speed : MotorSpeed;
            }
        }
        
        part def MechanicalLiftMechanism {
            port forceIn : RotationalForceIn;
            port linearForceOut : LinearForceOut;
            action def ConvertForce {
                in torque : Torque;
                in speed : MotorSpeed;
                out force : Force;
            }
        }
        
        part def SlatAssembly {
            attribute currentPosition : Position;
            port forceIn : LinearForceIn;
            action def MoveSlats {
                in force : Force;
                out position : Position;
            }
        }
        
        part def PowerSupply {
            port acIn : PowerACIn;
            port dcOut : PowerDCOut;
            action def ConvertPower {
                in ac : PowerAC;
                out dc : PowerDC;
            }
        }
        
        part def Controller {
            attribute targetLightLevel : LightLevel;
            attribute targetPosition : Position;
            attribute currentPosition : Position;
            attribute currentLightLevel : LightLevel;
            attribute currentUserCmd : String;
            attribute automaticModeActive : Boolean = true;
            attribute manualOverrideActive : Boolean = false;
            attribute obstructionDetected : Boolean = false;
            
            port powerIn : PowerDCIn;
            port lightIn : ControllerLightIn;
            port userIn : UserCommandIn;
            port smartHomeIn : SmartHomeIn;
            port motorOut : MotorCommandOut;
            
            state def ControllerStates {
                entry; then Idle;
                state Idle;
                state Raising;
                state Lowering;
                state Obstructed;
                transition from Idle to Raising
                    if (currentLightLevel < targetLightLevel and automaticModeActive) or (currentUserCmd == "raise");
                transition from Idle to Lowering
                    if (currentLightLevel > targetLightLevel and automaticModeActive) or (currentUserCmd == "lower");
                transition from Raising to Idle
                    if (currentPosition >= 100 or currentUserCmd == "stop" or currentLightLevel >= targetLightLevel);
                transition from Lowering to Idle
                    if (currentPosition <= 0 or currentUserCmd == "stop" or currentLightLevel <= targetLightLevel);
                transition from Raising to Obstructed if obstructionDetected;
                transition from Lowering to Obstructed if obstructionDetected;
                transition from Obstructed to Idle if !obstructionDetected;
            }
            perform ControllerStates;
        }
    }

    package System {
        import Components::*;
        import Requirements::*;
        
        part AutomatedWindowBlindSystem {
            attribute ambientLightLevel : LightLevel;
            attribute currentPosition : Position;
            attribute targetPosition : Position;
            attribute manualOverrideActive : Boolean;
            attribute automaticModeActive : Boolean;
            attribute obstructionDetected : Boolean;
            attribute motorActive : Boolean;
            attribute smartHomeConnected : Boolean;
            attribute fullTransitionTime : Time;
            
            port acIn : PowerACIn;
            port userIn : UserCommandIn;
            port smartHomeIn : SmartHomeIn;
            
            part powerSupply : PowerSupply {
                port acIn : PowerACIn;
                port dcOut : PowerDCOut;
            }
            
            part controller : Controller {
                port powerIn : PowerDCIn;
                port lightIn : ControllerLightIn;
                port userIn : UserCommandIn;
                port smartHomeIn : SmartHomeIn;
                port motorOut : MotorCommandOut;
            }
            
            part lightSensor : AmbientLightSensor {
                port powerIn : PowerDCIn;
                port dataOut : LightSensorOut;
            }
            
            part motor : ElectricMotor {
                port powerIn : PowerDCIn;
                port commandIn : MotorCommandIn;
                port forceOut : RotationalForceOut;
            }
            
            part liftMechanism : MechanicalLiftMechanism {
                port forceIn : RotationalForceIn;
                port linearForceOut : LinearForceOut;
            }
            
            part slatAssembly : SlatAssembly {
                port forceIn : LinearForceIn;
            }
            
            satisfy LightRegulation by AutomatedWindowBlindSystem;
            satisfy ManualOverride by AutomatedWindowBlindSystem;
            satisfy SafetyObstruction by AutomatedWindowBlindSystem;
            satisfy PerformanceSpeed by AutomatedWindowBlindSystem;
            satisfy PerformanceAccuracy by AutomatedWindowBlindSystem;
            satisfy SmartHomeIntegration by AutomatedWindowBlindSystem;
            
            connection acPowerConn connect acIn to powerSupply.acIn;
            connection dcPowerConn1 connect powerSupply.dcOut to controller.powerIn;
            connection dcPowerConn2 connect powerSupply.dcOut to lightSensor.powerIn;
            connection dcPowerConn3 connect powerSupply.dcOut to motor.powerIn;
            
            connection lightDataConn connect lightSensor.dataOut to controller.lightIn;
            connection userCmdConn connect userIn to controller.userIn;
            connection smartHomeConn connect smartHomeIn to controller.smartHomeIn;
            
            connection motorCmdConn connect controller.motorOut to motor.commandIn;
            connection rotForceConn connect motor.forceOut to liftMechanism.forceIn;
            connection linForceConn connect liftMechanism.linearForceOut to slatAssembly.forceIn;
        }
    }
}
