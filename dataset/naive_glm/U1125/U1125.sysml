package RoboticSurgicalSystem {

    import ScalarValues::*;

    package Units {
        unit mm;
        unit N;
        unit mmHg;
        unit degC;
        unit bpm;
        unit percent;
        unit mm_per_s;
        unit deg;
        unit A;
        unit V;
        unit W;
    }

    package ValueTypes {
        import ScalarValues::*;
        import Units::*;

        valueType Length :> Real {
            unit mm;
        }
        valueType Position :> Real {
            unit mm;
        }
        valueType Force :> Real {
            unit N;
        }
        valueType Pressure :> Real {
            unit mmHg;
        }
        valueType Temperature :> Real {
            unit degC;
        }
        valueType HeartRate :> Real {
            unit bpm;
        }
        valueType OxygenSaturation :> Real {
            unit percent;
        }
        valueType Velocity :> Real {
            unit mm_per_s;
        }
        valueType Angle :> Real {
            unit deg;
        }
        valueType Current :> Real {
            unit A;
        }
        valueType Voltage :> Real {
            unit V;
        }
        valueType Power :> Real {
            unit W;
        }
    }

    package Enums {
        import ScalarValues::*;

        enumeration def SafetyLevel {
            SAFE;
            WARNING;
            EMERGENCY_STOP;
        }

        enumeration def SystemState {
            IDLE;
            INITIALIZING;
            CALIBRATION;
            READY;
            OPERATING;
            SHUTDOWN;
            ERROR;
        }

        enumeration def ProcedurePhase {
            PREPARATION;
            INCISION;
            MAIN_PROCEDURE;
            CLOSURE;
        }
    }

    package Items {
        import ScalarValues::*;
        import ValueTypes::*;
        import Enums::*;

        item def Position3D {
            attribute x : Position;
            attribute y : Position;
            attribute z : Position;
        }

        item def Command {
            attribute id : String;
            attribute targetPosition : Position3D;
            attribute targetForce : Force;
        }

        item def StatusUpdate {
            attribute systemState : SystemState;
            attribute safetyLevel : SafetyLevel;
            attribute currentPhase : ProcedurePhase;
            attribute timestamp : Real;
        }

        item def ForceReading {
            attribute value : Force;
            attribute timestamp : Real;
        }

        item def PositionReading {
            attribute position : Position3D;
            attribute timestamp : Real;
        }

        item def TemperatureReading {
            attribute value : Temperature;
            attribute timestamp : Real;
        }

        item def ImageData {
            attribute frameId : Integer;
            attribute width : Integer;
            attribute height : Integer;
            attribute timestamp : Real;
        }

        item def VitalSigns {
            attribute heartRate : HeartRate;
            attribute bloodPressure : Pressure;
            attribute oxygenSaturation : OxygenSaturation;
            attribute timestamp : Real;
        }

        item def PowerFlow {
            attribute voltage : Voltage;
            attribute current : Current;
        }

        item def EndEffectorCommand {
            attribute gripForce : Force;
            attribute toolId : String;
        }
    }

    package Ports {
        import Items::*;
        import ValueTypes::*;

        port def CommandPort {
            in command : Command;
            out status : StatusUpdate;
        }

        port def SensorDataPort {
            out forceReading : ForceReading;
            out positionReading : PositionReading;
            out temperatureReading : TemperatureReading;
        }

        port def VisionDataPort {
            out image : ImageData;
        }

        port def VitalSignsPort {
            out vitals : VitalSigns;
        }

        port def HeartRatePort {
            out rate : HeartRate;
        }

        port def BloodPressurePort {
            out systolic : Pressure;
            out diastolic : Pressure;
        }

        port def OxygenPort {
            out saturation : OxygenSaturation;
        }

        port def PowerPort {
            in power : PowerFlow;
        }

        port def ActuatorCommandPort {
            in targetAngle : Angle;
            in targetVelocity : Velocity;
        }

        port def ActuatorFeedbackPort {
            out currentAngle : Angle;
            out current : Current;
        }

        port def EndEffectorControlPort {
            in gripCommand : EndEffectorCommand;
            out appliedForce : Force;
        }
    }

    package PartDefs {
        import ScalarValues::*;
        import Ports::*;
        import Items::*;
        import ValueTypes::*;
        import Enums::*;

        part def PowerSupply {
            attribute outputVoltage : Voltage = 48.0;
            attribute maxCurrent : Current = 50.0;
            attribute powerCapacity : Power = 2400.0;
            attribute isOn : Boolean = false;

            port powerOut : ~PowerPort;

            action def generatePower {
                out power : PowerFlow;
            }
            action def powerOn;
            action def powerOff;
        }

        part def Actuator {
            attribute id : Integer;
            attribute maxAngle : Angle = 180.0;
            attribute maxVelocity : Velocity = 100.0;
            attribute maxTorque : Real = 5.0;
            attribute currentAngle : Angle = 0.0;
            attribute operatingTemp : Temperature = 25.0;

            port commandIn : ActuatorCommandPort;
            port feedbackOut : ActuatorFeedbackPort;
            port powerIn : PowerPort;

            action def actuate {
                in targetAngle : Angle;
                in targetVelocity : Velocity;
                out achievedAngle : Angle;
            }
            action def reportFeedback {
                out angle : Angle;
                out current : Current;
            }
        }

        part def EndEffector {
            attribute maxGripForce : Force = 10.0;
            attribute attachedToolId : String = "none";
            attribute currentGripForce : Force = 0.0;

            port controlPort : EndEffectorControlPort;
            port powerIn : PowerPort;

            state gripState {
                state OPEN;
                state GRIPPING;
                state CLOSED;
                transition openToGripping first OPEN then GRIPPING;
                transition grippingToClosed first GRIPPING then CLOSED;
                transition closedToOpen first CLOSED then OPEN;
                transition grippingToOpen first GRIPPING then OPEN;
            }

            action def grip {
                in gripCmd : EndEffectorCommand;
                out appliedForce : Force;
            }
            action def release {
                out released : Boolean;
            }
            action def changeTool {
                in toolId : String;
                out success : Boolean;
            }
        }

        part def RoboticArm {
            attribute armLength : Length = 800.0;
            attribute positionAccuracy : Length = 0.5;
            attribute joint1 : Angle;
            attribute joint2 : Angle;
            attribute joint3 : Angle;
            attribute joint4 : Angle;
            attribute joint5 : Angle;
            attribute joint6 : Angle;

            part actuator1 : Actuator {
                :>> id = 1;
            }
            part actuator2 : Actuator {
                :>> id = 2;
            }
            part actuator3 : Actuator {
                :>> id = 3;
            }
            part actuator4 : Actuator {
                :>> id = 4;
            }
            part actuator5 : Actuator {
                :>> id = 5;
            }
            part actuator6 : Actuator {
                :>> id = 6;
            }
            part endEffector : EndEffector;

            port controlPort : CommandPort;
            port sensorFeedback : SensorDataPort;
            port powerIn : PowerPort;

            connection act1Power from powerIn to actuator1.powerIn;
            connection act2Power from powerIn to actuator2.powerIn;
            connection act3Power from powerIn to actuator3.powerIn;
            connection act4Power from powerIn to actuator4.powerIn;
            connection act5Power from powerIn to actuator5.powerIn;
            connection act6Power from powerIn to actuator6.powerIn;
            connection eePower from powerIn to endEffector.powerIn;

            action def moveTo {
                in targetPosition : Position3D;
                out achievedPosition : Position3D;
            }
            action def calibrateJoints;
        }

        part def ForceController {
            attribute maxSafeForce : Force = 20.0;
            attribute minSafeForce : Force = 0.0;
            attribute currentForce : Force = 0.0;
            attribute forceTolerance : Force = 2.0;

            port commandIn : CommandPort;
            port commandOut : ~CommandPort;
            port sensorInput : ~SensorDataPort;
            port powerIn : PowerPort;

            action def controlForce {
                in reading : ForceReading;
                out adjustedForce : Force;
            }
            action def checkForceLimits {
                in force : Force;
                out isSafe : Boolean;
            }
            action def adjustForce {
                in targetForce : Force;
                in measuredForce : Force;
                out correctedForce : Force;
            }
        }

        part def MedicalRobot {
            attribute name : String = "SurgicalRobot1";
            attribute serialNumber : String;
            attribute firmwareVersion : String = "1.0.0";
            attribute positionAccuracy : Length = 0.5;

            part roboticArm : RoboticArm;
            part forceController : ForceController;

            port controlPort : CommandPort;
            port sensorPort : SensorDataPort;
            port powerIn : PowerPort;

            connection ctrlToForce from controlPort to forceController.commandIn;
            connection forceToArm from forceController.commandOut to roboticArm.controlPort;
            connection armSensorToForce from roboticArm.sensorFeedback to forceController.sensorInput;
            connection armSensorToPort from roboticArm.sensorFeedback to sensorPort;
            connection powerToArm from powerIn to roboticArm.powerIn;
            connection powerToForce from powerIn to forceController.powerIn;

            state robotLifecycle {
                state idle;
                state initializing;
                state calibration;
                state ready;
                state operating;
                state shutdown;
                state error;
                transition startInit first idle then initializing;
                transition startCal first initializing then calibration;
                transition finishCal first calibration then ready;
                transition startOp first ready then operating;
                transition pauseOp first operating then ready;
                transition startShutdown first ready then shutdown;
                transition opToShutdown first operating then shutdown;
                transition enterError first * then error;
                transition resetError first error then idle;
            }

            action def initialize;
            action def calibrate;
            action def performOperation {
                in targetPosition : Position3D;
                in targetForce : Force;
            }
            action def emergencyStop;
        }

        part def Camera {
            attribute resolution : Integer = 1920;
            attribute frameRate : Real = 60.0;
            attribute fieldOfView : Angle = 90.0;
            attribute isCalibrated : Boolean = false;

            port imageOut : VisionDataPort;
            port powerIn : PowerPort;

            action def capture {
                out image : ImageData;
            }
            action def calibrateCamera;
        }

        part def ImageProcessor {
            attribute processingLatency : Real = 0.02;
            attribute trackingEnabled : Boolean = true;

            port imageIn : ~VisionDataPort;
            port processedOut : VisionDataPort;

            action def processImage {
                in rawImage : ImageData;
                out processedImage : ImageData;
            }
            action def trackFeatures {
                in image : ImageData;
                out trackedPosition : Position3D;
            }
            action def enhanceImage {
                in rawImage : ImageData;
                out enhancedImage : ImageData;
            }
        }

        part def VisionSystem {
            part camera1 : Camera {
                :>> resolution = 1920;
                :>> frameRate = 60.0;
                :>> fieldOfView = 90.0;
            }
            part camera2 : Camera {
                :>> resolution = 1920;
                :>> frameRate = 60.0;
                :>> fieldOfView = 90.0;
            }
            part imageProcessor : ImageProcessor;

            port visionOut : VisionDataPort;
            port powerIn : PowerPort;

            connection cam1ToProc from camera1.imageOut to imageProcessor.imageIn;
            connection cam2ToProc from camera2.imageOut to imageProcessor.imageIn;
            connection procToOut from imageProcessor.processedOut to visionOut;
            connection powerToCam1 from powerIn to camera1.powerIn;
            connection powerToCam2 from powerIn to camera2.powerIn;

            action def captureStereo {
                out leftImage : ImageData;
                out rightImage : ImageData;
            }
            action def provideVisualFeedback {
                out processedImage : ImageData;
                out trackedPosition : Position3D;
            }
        }

        part def ProcedureController {
            attribute currentPhase : ProcedurePhase = ProcedurePhase::PREPARATION;
            attribute procedureProgress : Real = 0.0;
            attribute procedureName : String;

            port operatorPort : CommandPort;
            port robotPort : ~CommandPort;
            port sensorInput : ~SensorDataPort;
            port visionInput : ~VisionDataPort;

            state procedureState {
                state preparation;
                state incision;
                state mainProcedure;
                state closure;
                transition prepToIncision first preparation then incision;
                transition incisionToMain first incision then mainProcedure;
                transition mainToClosure first mainProcedure then closure;
                transition closureToPrep first closure then preparation;
            }

            action def managePhase {
                in currentPhase : ProcedurePhase;
                out nextPhase : ProcedurePhase;
            }
            action def executePreparation;
            action def executeIncision;
            action def executeMainProcedure;
            action def executeClosure;
        }

        part def SafetyMonitor {
            attribute safetyLevel : SafetyLevel = SafetyLevel::SAFE;
            attribute maxForce : Force = 20.0;
            attribute maxTemperature : Temperature = 60.0;
            attribute positionTolerance : Length = 0.5;
            attribute emergencyStopTriggered : Boolean = false;

            port sensorInput : ~SensorDataPort;
            port emergencyOut : ~CommandPort;

            state safetyState {
                state safe;
                state warning;
                state emergencyStop;
                transition safeToWarning first safe then warning;
                transition warningToSafe first warning then safe;
                transition warningToEmergency first warning then emergencyStop;
                transition safeToEmergency first safe then emergencyStop;
            }

            action def analyzeSafety {
                in force : ForceReading;
                in position : PositionReading;
                in temperature : TemperatureReading;
                out level : SafetyLevel;
            }
            action def triggerEmergencyStop;
            action def resetSafety {
                out success : Boolean;
            }
        }

        part def ControlUnit {
            part procedureController : ProcedureController;
            part safetyMonitor : SafetyMonitor;

            port operatorPort : CommandPort;
            port robotPort : ~CommandPort;
            port sensorPort : ~SensorDataPort;
            port visionPort : ~VisionDataPort;
            port vitalSignsPort : ~VitalSignsPort;
            port powerIn : PowerPort;

            connection opToProc from operatorPort to procedureController.operatorPort;
            connection procToRobot from procedureController.robotPort to robotPort;
            connection sensorToSafety from sensorPort to safetyMonitor.sensorInput;
            connection sensorToProc from sensorPort to procedureController.sensorInput;
            connection visionToProc from visionPort to procedureController.visionInput;
            connection safetyToRobot from safetyMonitor.emergencyOut to robotPort;
        }

        part def OperatorConsole {
            attribute operatorId : String;
            attribute displayEnabled : Boolean = true;
            attribute controlMode : String = "manual";

            port systemPort : ~CommandPort;
            port powerIn : PowerPort;

            action def sendCommand {
                in command : Command;
            }
            action def receiveStatus {
                in status : StatusUpdate;
            }
            action def displayStatus {
                in status : StatusUpdate;
                in vitals : VitalSigns;
            }
            action def setTargetPosition {
                in position : Position3D;
                out command : Command;
            }
            action def setTargetForce {
                in force : Force;
                out command : Command;
            }
        }

        part def HeartRateSensor {
            attribute range : HeartRate = 250.0;
            attribute accuracy : HeartRate = 1.0;

            port vitalOut : HeartRatePort;
            port powerIn : PowerPort;

            action def measureHeartRate {
                out rate : HeartRate;
            }
        }

        part def BloodPressureSensor {
            attribute maxPressure : Pressure = 300.0;
            attribute accuracy : Pressure = 2.0;

            port vitalOut : BloodPressurePort;
            port powerIn : PowerPort;

            action def measureBloodPressure {
                out systolic : Pressure;
                out diastolic : Pressure;
            }
        }

        part def OxygenSensor {
            attribute maxSaturation : OxygenSaturation = 100.0;
            attribute accuracy : OxygenSaturation = 1.0;

            port vitalOut : OxygenPort;
            port powerIn : PowerPort;

            action def measureOxygen {
                out saturation : OxygenSaturation;
            }
        }

        part def PatientMonitoringSystem {
            attribute samplingRate : Real = 100.0;
            attribute alarmThreshold_HR : HeartRate = 40.0;
            attribute alarmThreshold_BP : Pressure = 50.0;
            attribute alarmThreshold_O2 : OxygenSaturation = 90.0;

            part heartRateSensor : HeartRateSensor;
            part bloodPressureSensor : BloodPressureSensor;
            part oxygenSensor : OxygenSensor;

            port vitalSignsOut : VitalSignsPort;
            port powerIn : PowerPort;

            connection powerToHR from powerIn to heartRateSensor.powerIn;
            connection powerToBP from powerIn to bloodPressureSensor.powerIn;
            connection powerToOxy from powerIn to oxygenSensor.powerIn;

            action def monitorVitals {
                out vitals : VitalSigns;
            }
            action def checkVitals {
                in vitals : VitalSigns;
                out alert : Boolean;
            }
            action def alertOperator {
                in alertType : String;
            }
        }
    }

    package Requirements {
        import ScalarValues::*;
        import ValueTypes::*;
        import Enums::*;

        requirement def PrecisionRequirement {
            doc "The system shall achieve positioning accuracy of less than 0.5 mm.";
            attribute maxPositionError : Length = 0.5;
        }

        requirement def ForceSafetyRequirement {
            doc "The system shall apply force within safe, predefined limits during all surgical procedures.";
            attribute maxSafeForce : Force = 20.0;
        }

        requirement def VisionRequirement {
            doc "The system shall provide real-time visual feedback using at least 2 cameras.";
            attribute minCameras : Integer = 2;
            attribute realTimeLatency : Real = 0.05;
        }

        requirement def EmergencyStopRequirement {
            doc "The Safety Monitor shall trigger an emergency stop when unsafe conditions are detected.";
            attribute maxResponseTime : Real = 0.1;
        }

        requirement def VitalsMonitoringRequirement {
            doc "The system shall continuously monitor heart rate, blood pressure, and oxygen saturation throughout the operation.";
            attribute samplingRate : Real = 100.0;
        }

        requirement def LifecycleRequirement {
            doc "The system shall follow the lifecycle states: idle, initializing, calibration, ready, operating, shutdown, with an error state triggered by safety breaches.";
        }

        requirement def PowerSupplyRequirement {
            doc "The system shall be powered by a dedicated, high-capacity power supply.";
            attribute minPower : Power = 2000.0;
        }

        requirement def ActuatorCountRequirement {
            doc "The robotic arm shall be equipped with six actuators for a wide range of motion.";
            attribute actuatorCount : Integer = 6;
        }

        requirement def ProcedureControlRequirement {
            doc "The procedure controller shall manage phases: preparation, incision, main procedure, and closure.";
        }
    }

    package System {
        import ScalarValues::*;
        import Ports::*;
        import Items::*;
        import ValueTypes::*;
        import Enums::*;
        import PartDefs::*;
        import Requirements::*;

        part SurgicalSystem {
            part operatorConsole : OperatorConsole;
            part controlUnit : ControlUnit;
            part medicalRobot : MedicalRobot;
            part visionSystem : VisionSystem;
            part patientMonitoring : PatientMonitoringSystem;
            part powerSupply : PowerSupply;

            connection powerToConsole from powerSupply.powerOut to operatorConsole.powerIn;
            connection powerToControl from powerSupply.powerOut to controlUnit.powerIn;
            connection powerToRobot from powerSupply.powerOut to medicalRobot.powerIn;
            connection powerToVision from powerSupply.powerOut to visionSystem.powerIn;
            connection powerToPatient from powerSupply.powerOut to patientMonitoring.powerIn;

            connection opToControl from operatorConsole.systemPort to controlUnit.operatorPort;
            connection controlToRobot from controlUnit.robotPort to medicalRobot.controlPort;
            connection robotSensorsToControl from medicalRobot.sensorPort to controlUnit.sensorPort;
            connection visionToControl from visionSystem.visionOut to controlUnit.visionPort;
            connection patientToControl from patientMonitoring.vitalSignsOut to controlUnit.vitalSignsPort;

            satisfy PrecisionRequirement;
            satisfy ForceSafetyRequirement;
            satisfy VisionRequirement;
            satisfy EmergencyStopRequirement;
            satisfy VitalsMonitoringRequirement;
            satisfy LifecycleRequirement;
            satisfy PowerSupplyRequirement;
            satisfy ActuatorCountRequirement;
            satisfy ProcedureControlRequirement;
        }
    }
}
