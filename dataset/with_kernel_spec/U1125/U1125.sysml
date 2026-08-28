package RoboticMedicalSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def ForceValue :> Real;
        attribute def PositionValue :> Real;
        attribute def TemperatureValue :> Real;
        attribute def HeartRateValue :> Integer;
        attribute def PressureValue :> Real;
        attribute def OxygenLevelValue :> Real;
        attribute def AccuracyValue :> Real;
        
        item def TargetPosition {
            attribute x : PositionValue;
            attribute y : PositionValue;
            attribute z : PositionValue;
        }
        item def TargetForce {
            attribute force : ForceValue;
        }
        item def StatusUpdate {
            attribute msg : String;
        }
        item def SensorData {
            attribute force : ForceValue;
            attribute position : PositionValue;
            attribute temperature : TemperatureValue;
        }
        item def VitalSigns {
            attribute heartRate : HeartRateValue;
            attribute bloodPressure : PressureValue;
            attribute oxygenLevel : OxygenLevelValue;
        }
        item def ImageData;
        item def ProcessedImageData;
        item def EmergencyStopSignal;
        item def WarningSignal;
        item def SafeSignal;
        
        attribute def StartInitialization;
        attribute def InitializationComplete;
        attribute def CalibrationComplete;
        attribute def StartProcedure;
        attribute def EndProcedure;
        attribute def ShutdownCommand;
        attribute def ResetCommand;
        attribute def BeginIncision;
        attribute def IncisionComplete;
        attribute def BeginClosure;
        attribute def ClosureComplete;
        attribute def UnsafeCondition;
        attribute def CriticalCondition;
        attribute def ReturnToSafe;
        
        port def CommandPort {
            in targetPosition : TargetPosition;
            in targetForce : TargetForce;
            out status : StatusUpdate;
        }
        port def SensorPort {
            out sensorData : SensorData;
        }
        port def VisionPort {
            out imageData : ImageData;
        }
        port def ProcessedVisionPort {
            out processedData : ProcessedImageData;
        }
        port def VitalPort {
            out vitals : VitalSigns;
        }
        port def PowerPort {
            out voltage : Real;
        }
        port def SafetyPort {
            out emergencyStop : EmergencyStopSignal;
            out warning : WarningSignal;
            out safe : SafeSignal;
        }
        
        action def InitializeSystem;
        action def CalibrateArm;
        action def ShutdownSystem;
        action def MoveArm {
            in target : TargetPosition;
        }
        action def ApplyForce {
            in targetForce : TargetForce;
            out actualForce : ForceValue;
        }
        action def GripTool {
            in toolId : String;
        }
        action def ReleaseTool {
            in toolId : String;
        }
        action def CaptureImage {
            out imageData : ImageData;
        }
        action def ProcessImage {
            in imageData : ImageData;
            out processedData : ProcessedImageData;
        }
        action def TrackMovement {
            in processedData : ProcessedImageData;
            out deltaPosition : PositionValue;
        }
        action def AnalyzeSafety {
            in sensorData : SensorData;
            out safetyLevel : String;
        }
        action def MonitorVitals {
            out vitals : VitalSigns;
        }
        action def PerformIncision;
        action def PerformClosure;
        action def TriggerEmergencyStop;
        
        part def Actuator;
        
        part def EndEffector {
            port powerPort : PowerPort;
            perform action gripTool : GripTool;
            perform action releaseTool : ReleaseTool;
        }
        
        part def RoboticArm {
            part actuators[6] : Actuator;
            part endEffector : EndEffector;
            port commandPort : CommandPort;
            port sensorPort : SensorPort;
            port powerPort : PowerPort;
            attribute maxForce : ForceValue = 10.0;
            attribute accuracy : AccuracyValue = 0.5;
            perform action moveArm : MoveArm;
            perform action applyForce : ApplyForce;
            connect powerPort to endEffector.powerPort;
        }
        
        part def Camera {
            port visionPort : VisionPort;
            port powerPort : PowerPort;
            perform action captureImage : CaptureImage;
        }
        
        part def ImageProcessor {
            port inVisionPort : ~VisionPort;
            port outVisionPort : ProcessedVisionPort;
            port powerPort : PowerPort;
            perform action processImage : ProcessImage;
            perform action trackMovement : TrackMovement;
        }
        
        part def VisionSystem {
            part cameras[2] : Camera;
            part imageProcessor : ImageProcessor;
            port visionPort : ProcessedVisionPort;
            port powerPort : PowerPort;
            connect cameras.visionPort to imageProcessor.inVisionPort;
            connect imageProcessor.outVisionPort to visionPort;
            connect powerPort to cameras.powerPort;
            connect powerPort to imageProcessor.powerPort;
        }
        
        part def ForceController {
            port sensorPort : ~SensorPort;
            port commandPort : ~CommandPort;
            attribute maxSafeForce : ForceValue = 10.0;
            attribute criticalForce : ForceValue = 15.0;
            perform action enforceForceLimit : ApplyForce;
        }
        
        part def ProcedureController {
            port commandPort : ~CommandPort;
            port visionPort : ~ProcessedVisionPort;
            exhibit state procedureStates : ProcedureStates;
        }
        
        part def SafetyMonitor {
            port sensorPort : ~SensorPort;
            port safetyPort : SafetyPort;
            attribute maxTemp : TemperatureValue = 40.0;
            attribute criticalTemp : TemperatureValue = 50.0;
            attribute maxSafeForce : ForceValue = 10.0;
            attribute criticalForce : ForceValue = 15.0;
            perform action analyzeSafety : AnalyzeSafety;
            exhibit state safetyStates : SafetyStates;
        }
        
        part def ControlUnit {
            part procedureController : ProcedureController;
            part safetyMonitor : SafetyMonitor;
            port commandPort : ~CommandPort;
            port sensorPort : ~SensorPort;
            port visionPort : ~ProcessedVisionPort;
            port vitalPort : ~VitalPort;
            port powerPort : PowerPort;
            port safetyPort : ~SafetyPort;
            connect commandPort to procedureController.commandPort;
            connect visionPort to procedureController.visionPort;
            connect sensorPort to safetyMonitor.sensorPort;
            connect safetyMonitor.safetyPort to safetyPort;
        }
        
        part def OperatorConsole {
            port commandPort : CommandPort;
            port powerPort : ~PowerPort;
        }
        
        part def PatientMonitoringSystem {
            port vitalPort : VitalPort;
            port powerPort : ~PowerPort;
            perform action monitorVitals : MonitorVitals;
        }
        
        part def PowerSupply {
            port powerPort : PowerPort;
            attribute capacity : Real = 1000.0;
            attribute currentLevel : Real = 1000.0;
        }
        
        part def MedicalRobot {
            part roboticArm : RoboticArm;
            part forceController : ForceController;
            part visionSystem : VisionSystem;
            part controlUnit : ControlUnit;
            port commandPort : ~CommandPort;
            port vitalPort : ~VitalPort;
            port powerPort : ~PowerPort;
            port safetyPort : SafetyPort;
            exhibit state robotLifecycle : RobotLifecycle;
            connect commandPort to controlUnit.commandPort;
            connect controlUnit.commandPort to roboticArm.commandPort;
            connect roboticArm.sensorPort to forceController.sensorPort;
            connect forceController.commandPort to roboticArm.commandPort;
            connect roboticArm.sensorPort to controlUnit.sensorPort;
            connect visionSystem.visionPort to controlUnit.visionPort;
            connect vitalPort to controlUnit.vitalPort;
            connect controlUnit.safetyPort to safetyPort;
            connect powerPort to roboticArm.powerPort;
            connect powerPort to visionSystem.powerPort;
            connect powerPort to controlUnit.powerPort;
        }
        
        state def RobotLifecycle;
        state def SafetyStates;
        state def ProcedureStates;
        
        requirement def AccuracyRequirement {
            doc /* The robotic arm must operate with an accuracy of less than 0.5 mm. */
        }
        requirement def ForceSafetyRequirement {
            doc /* The force applied by the end effector must remain within safe predefined limits. */
        }
        requirement def SafetyMonitoringRequirement {
            doc /* The safety monitor must continuously analyze sensor data and escalate safety level if unsafe conditions are detected. */
        }
        requirement def PatientMonitoringRequirement {
            doc /* The patient monitoring system must continuously track heart rate, blood pressure, and oxygen levels. */
        }
        requirement def PowerRequirement {
            doc /* The power supply must provide sufficient capacity for the entire surgical procedure. */
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        action initializeSystem : InitializeSystem;
        action calibrateArm : CalibrateArm;
        action shutdownSystem : ShutdownSystem;
        action moveArm : MoveArm;
        action applyForce : ApplyForce;
        action gripTool : GripTool;
        action releaseTool : ReleaseTool;
        action captureImage : CaptureImage;
        action processImage : ProcessImage;
        action trackMovement : TrackMovement;
        action analyzeSafety : AnalyzeSafety;
        action monitorVitals : MonitorVitals;
        action performIncision : PerformIncision;
        action performClosure : PerformClosure;
        action triggerEmergencyStop : TriggerEmergencyStop;
        
        part roboticMedicalSystem {
            part medicalRobot : MedicalRobot {
                part roboticArm : RoboticArm;
                part forceController : ForceController;
                part visionSystem : VisionSystem;
                part controlUnit : ControlUnit {
                    part procedureController : ProcedureController;
                    part safetyMonitor : SafetyMonitor;
                }
            }
            
            part operatorConsole : OperatorConsole;
            part patientMonitor : PatientMonitoringSystem;
            part powerSupply : PowerSupply;
            
            connect operatorConsole.commandPort to medicalRobot.commandPort;
            connect patientMonitor.vitalPort to medicalRobot.vitalPort;
            connect powerSupply.powerPort to medicalRobot.powerPort;
            connect powerSupply.powerPort to operatorConsole.powerPort;
            connect powerSupply.powerPort to patientMonitor.powerPort;
            
            requirement accReq : AccuracyRequirement;
            requirement forceReq : ForceSafetyRequirement;
            requirement safetyReq : SafetyMonitoringRequirement;
            requirement patientReq : PatientMonitoringRequirement;
            requirement powerReq : PowerRequirement;
            
            satisfy accReq by medicalRobot.roboticArm;
            satisfy forceReq by medicalRobot.forceController;
            satisfy safetyReq by medicalRobot.controlUnit.safetyMonitor;
            satisfy patientReq by patientMonitor;
            satisfy powerReq by powerSupply;
            
            state robotLifecycle : RobotLifecycle {
                entry; then idle;
                state idle;
                accept StartInitialization
                    then initializing;
                state initializing {
                    do initializeSystem;
                }
                accept InitializationComplete
                    then calibration;
                state calibration {
                    do calibrateArm;
                }
                accept CalibrationComplete
                    then ready;
                state ready;
                accept StartProcedure
                    then operating;
                accept ShutdownCommand
                    then shutdown;
                state operating {
                    do moveArm;
                    do applyForce;
                }
                accept EndProcedure
                    then ready;
                accept EmergencyStopSignal
                    then error;
                state error;
                accept ResetCommand
                    then idle;
                state shutdown {
                    do shutdownSystem;
                }
                accept ResetCommand
                    then idle;
            }
            
            state procedureStates : ProcedureStates {
                entry; then preparation;
                state preparation;
                accept BeginIncision
                    then incision;
                state incision {
                    do performIncision;
                }
                accept IncisionComplete
                    then mainProcedure;
                state mainProcedure {
                    do moveArm;
                    do applyForce;
                }
                accept BeginClosure
                    then closure;
                state closure {
                    do performClosure;
                }
                accept ClosureComplete
                    then preparation;
            }
            
            state safetyStates : SafetyStates {
                entry; then safe;
                state safe {
                    do analyzeSafety;
                }
                accept UnsafeCondition
                    do send new WarningSignal() to medicalRobot.controlUnit.safetyMonitor
                    then warning;
                state warning {
                    do analyzeSafety;
                }
                accept CriticalCondition
                    do send new EmergencyStopSignal() to medicalRobot.controlUnit.safetyMonitor
                    then emergency;
                accept ReturnToSafe
                    then safe;
                state emergency {
                    do triggerEmergencyStop;
                }
                accept ResetCommand
                    then safe;
            }
        }
    }
}
