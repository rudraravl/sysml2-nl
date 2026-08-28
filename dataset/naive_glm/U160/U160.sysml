package BaranyChairSystem {
    import ScalarValues::*;

    // ===== Value Types =====
    value type RotationalSpeed :> Real { unit 'rpm'; }
    value type AngularAcceleration :> Real { unit 'rad/s^2'; }
    value type Torque :> Real { unit 'N*m'; }
    value type Duration :> Real { unit 's'; }
    value type Angle :> Real { unit 'deg'; }
    value type Frequency :> Real { unit 'Hz'; }
    value type HeartRateValue :> Real { unit 'bpm'; }
    value type ElectricCurrent :> Real { unit 'A'; }
    value type Voltage :> Real { unit 'V'; }

    // ===== Enumerations =====
    enum RotationDirection { clockwise; counterClockwise; }
    enum ChairOperationalState { idle; accelerating; constantRotation; decelerating; stopped; emergencyStop; }
    enum TestStatus { notStarted; inProgress; completed; aborted; }

    // ===== Item Definitions =====
    item def TestParameters {
        attribute targetSpeed : RotationalSpeed;
        attribute duration : Duration;
        attribute direction : RotationDirection;
        attribute accelerationRate : AngularAcceleration;
        attribute decelerationRate : AngularAcceleration;
    }

    item def MotorCommand {
        attribute targetSpeed : RotationalSpeed;
        attribute direction : RotationDirection;
        attribute acceleration : AngularAcceleration;
    }

    item def MotorFeedback {
        attribute currentSpeed : RotationalSpeed;
        attribute currentTorque : Torque;
        attribute direction : RotationDirection;
    }

    item def NystagmusReading {
        attribute beatFrequency : Frequency;
        attribute amplitude : Angle;
        attribute direction : RotationDirection;
        attribute timestamp : Duration;
    }

    item def PatientVitals {
        attribute heartRate : HeartRateValue;
        attribute dizzinessLevel : Real;
    }

    item def SafetyStatus {
        attribute harnessEngaged : Boolean;
        attribute speedWithinLimit : Boolean;
        attribute emergencyStopActive : Boolean;
        attribute headrestLocked : Boolean;
    }

    // ===== Signal Items =====
    item StartTest;
    item TargetSpeedReached;
    item DurationElapsed;
    item SpeedZero;
    item EmergencyStopSignal;
    item ResetSignal;

    // ===== Port Definitions =====
    port def MotorControlPort {
        in command : MotorCommand;
        out feedback : MotorFeedback;
    }

    port def SafetyControlPort {
        in emergencyStop : Boolean;
        out status : SafetyStatus;
    }

    port def ObservationControlPort {
        out nystagmus : NystagmusReading;
        out vitals : PatientVitals;
    }

    port def OperatorControlPort {
        in parameters : TestParameters;
        in startCommand : Boolean;
        in stopCommand : Boolean;
        in emergencyStop : Boolean;
        out currentState : ChairOperationalState;
        out testStatus : TestStatus;
    }

    // ===== Part Definitions =====
    part def SafetyHarness {
        attribute engaged : Boolean = false;
        attribute tensionLevel : Real = 0.0;
        part buckle;
        part straps[2];
        part shoulderStraps[2];

        action def engage {
            in signal : Boolean;
            assign engaged = signal;
        }
        action def release {
            assign engaged = false;
        }
        action def checkTension {
            out tension : Real;
            assign tension = tensionLevel;
        }
    }

    part def Headrest {
        attribute locked : Boolean = false;
        attribute position : Angle = 0.0 [deg];
        attribute adjustable : Boolean = true;

        action def adjust {
            in newPosition : Angle;
            assign position = newPosition;
        }
        action def lock {
            assign locked = true;
        }
        action def unlock {
            assign locked = false;
        }
    }

    part def SeatAssembly {
        part seat;
        part headrest : Headrest;
        part harness : SafetyHarness;
        part armrests[2];
        part footrest;

        action def securePatient {
            then harness.engage;
            then headrest.lock;
        }
    }

    part def DriveMotor {
        attribute currentSpeed : RotationalSpeed = 0.0 [rpm];
        attribute currentTorque : Torque = 0.0 [N*m];
        attribute direction : RotationDirection = RotationDirection::clockwise;
        attribute maxSpeed : RotationalSpeed = 30.0 [rpm];
        attribute maxTorque : Torque = 200.0 [N*m];
        attribute powerOn : Boolean = false;
        port motorPort : MotorControlPort;

        action def rotate {
            in cmd : MotorCommand;
            assign currentSpeed = cmd.targetSpeed;
            assign direction = cmd.direction;
        }
        action def stop {
            assign currentSpeed = 0.0 [rpm];
            assign currentTorque = 0.0 [N*m];
        }
        action def emergencyBrake {
            assign currentSpeed = 0.0 [rpm];
            assign currentTorque = -150.0 [N*m];
        }
        action def powerOn_ {
            assign powerOn = true;
        }
        action def powerOff {
            assign powerOn = false;
            assign currentSpeed = 0.0 [rpm];
        }
    }

    part def RotatingPlatform {
        attribute currentAngle : Angle = 0.0 [deg];
        attribute loadCapacity : Real = 150.0;
        part motor : DriveMotor;
        part seatAssembly : SeatAssembly;
        part bearing;
        part baseFrame;

        action def rotatePlatform {
            in angle : Angle;
            assign currentAngle = angle;
        }
    }

    part def ObservationSystem {
        attribute recording : Boolean = false;
        attribute cameraActive : Boolean = false;
        port observationPort : ObservationControlPort;
        part eyeTrackingCamera;
        part dataRecorder;
        part vitalsMonitor;

        action def detectNystagmus {
            out reading : NystagmusReading;
        }
        action def recordVitals {
            out vitals : PatientVitals;
        }
        action def startRecording {
            assign recording = true;
            assign cameraActive = true;
        }
        action def stopRecording {
            assign recording = false;
            assign cameraActive = false;
        }
    }

    part def SafetySystem {
        attribute emergencyStopActive : Boolean = false;
        attribute maxSafeSpeed : RotationalSpeed = 30.0 [rpm];
        attribute emergencyStopResponseTime : Duration = 0.5 [s];
        attribute safetyInterlock : Boolean = true;
        port safetyPort : SafetyControlPort;
        part speedSensor;
        part restraintSensor;
        part emergencyButton;

        action def monitorSafety {
            in speed : RotationalSpeed;
            in harnessEngaged : Boolean;
            in headrestLocked : Boolean;
            out status : SafetyStatus;
            assign status.speedWithinLimit = (speed <= maxSafeSpeed);
            assign status.harnessEngaged = harnessEngaged;
            assign status.emergencyStopActive = emergencyStopActive;
            assign status.headrestLocked = headrestLocked;
        }
        action def triggerEmergencyStop {
            assign emergencyStopActive = true;
        }
        action def resetEmergencyStop {
            assign emergencyStopActive = false;
        }
        action def checkInterlocks {
            out interlockOk : Boolean;
            assign interlockOk = safetyInterlock;
        }
    }

    part def ControlSystem {
        attribute targetSpeed : RotationalSpeed = 0.0 [rpm];
        attribute duration : Duration = 0.0 [s];
        attribute direction : RotationDirection = RotationDirection::clockwise;
        attribute accelerationRate : AngularAcceleration = 2.0 [rad/s^2];
        attribute decelerationRate : AngularAcceleration = 2.0 [rad/s^2];
        attribute currentState : ChairOperationalState = ChairOperationalState::idle;
        attribute testStatus : TestStatus = TestStatus::notStarted;
        attribute elapsedTime : Duration = 0.0 [s];

        port motorPort : ~MotorControlPort;
        port safetyPort : ~SafetyControlPort;
        port observationPort : ~ObservationControlPort;
        port operatorPort : ~OperatorControlPort;

        state machine ChairStateMachine {
            state idle;
            state accelerating;
            state constantRotation;
            state decelerating;
            state stopped;
            state emergencyStop;

            transition t_idle_to_accel
                source idle
                target accelerating
                accept StartTest;
            transition t_accel_to_const
                source accelerating
                target constantRotation
                accept TargetSpeedReached;
            transition t_const_to_decel
                source constantRotation
                target decelerating
                accept DurationElapsed;
            transition t_decel_to_stopped
                source decelerating
                target stopped
                accept SpeedZero;
            transition t_accel_to_emerg
                source accelerating
                target emergencyStop
                accept EmergencyStopSignal;
            transition t_const_to_emerg
                source constantRotation
                target emergencyStop
                accept EmergencyStopSignal;
            transition t_decel_to_emerg
                source decelerating
                target emergencyStop
                accept EmergencyStopSignal;
            transition t_idle_to_emerg
                source idle
                target emergencyStop
                accept EmergencyStopSignal;
            transition t_emerg_to_idle
                source emergencyStop
                target idle
                accept ResetSignal;
            transition t_stopped_to_idle
                source stopped
                target idle
                accept ResetSignal;
        }

        action def executeTest {
            in params : TestParameters;
            assign targetSpeed = params.targetSpeed;
            assign duration = params.duration;
            assign direction = params.direction;
            assign accelerationRate = params.accelerationRate;
            assign decelerationRate = params.decelerationRate;
            assign testStatus = TestStatus::inProgress;
            then send StartTest;
        }
        action def abortTest {
            assign testStatus = TestStatus::aborted;
            then send EmergencyStopSignal;
        }
        action def completeTest {
            assign testStatus = TestStatus::completed;
        }
        action def reset {
            assign currentState = ChairOperationalState::idle;
            assign testStatus = TestStatus::notStarted;
            assign targetSpeed = 0.0 [rpm];
            assign elapsedTime = 0.0 [s];
        }
    }

    part def OperatorInterface {
        attribute displayActive : Boolean = true;
        attribute inputEnabled : Boolean = true;
        port operatorPort : OperatorControlPort;
        part display;
        part keypad;
        part emergencyStopButton;
        part speedIndicator;

        action def inputParameters {
            out params : TestParameters;
        }
        action def startTest {
            out command : Boolean;
        }
        action def stopTest {
            out command : Boolean;
        }
        action def pressEmergencyStop {
            out command : Boolean;
        }
        action def displayStatus {
            in state : ChairOperationalState;
            in status : TestStatus;
        }
    }

    // ===== Requirements =====
    requirement def SafetyRequirements {
        subject chair : BaranyChair;
        requirement maxSpeedLimit {
            constraint { chair.rotatingPlatform.motor.currentSpeed <= 30.0 [rpm] }
        }
        requirement harnessMustBeEngaged {
            constraint { chair.rotatingPlatform.seatAssembly.harness.engaged == true }
        }
        requirement emergencyStopResponse {
            constraint { chair.safetySystem.emergencyStopResponseTime <= 0.5 [s] }
        }
        requirement headrestMustBeLocked {
            constraint { chair.rotatingPlatform.seatAssembly.headrest.locked == true }
        }
        requirement safetyInterlockActive {
            constraint { chair.safetySystem.safetyInterlock == true }
        }
    }

    requirement def PerformanceRequirements {
        subject chair : BaranyChair;
        requirement speedAccuracy {
            constraint { chair.rotatingPlatform.motor.currentSpeed - chair.controlSystem.targetSpeed <= 0.5 [rpm] }
        }
        requirement smoothAcceleration {
            constraint { chair.controlSystem.accelerationRate <= 5.0 [rad/s^2] }
        }
        requirement smoothDeceleration {
            constraint { chair.controlSystem.decelerationRate <= 5.0 [rad/s^2] }
        }
        requirement bidirectionalOperation {
            constraint { chair.rotatingPlatform.motor.direction == RotationDirection::clockwise or chair.rotatingPlatform.motor.direction == RotationDirection::counterClockwise }
        }
    }

    requirement def FunctionalRequirements {
        subject chair : BaranyChair;
        requirement nystagmusDetection {
            constraint { chair.observationSystem.recording == true }
        }
        requirement stateCoverage {
            constraint { chair.controlSystem.currentState == ChairOperationalState::idle or chair.controlSystem.currentState == ChairOperationalState::accelerating or chair.controlSystem.currentState == ChairOperationalState::constantRotation or chair.controlSystem.currentState == ChairOperationalState::decelerating or chair.controlSystem.currentState == ChairOperationalState::stopped or chair.controlSystem.currentState == ChairOperationalState::emergencyStop }
        }
        requirement operatorControl {
            constraint { chair.operatorInterface.inputEnabled == true }
        }
    }

    // ===== Top-level System =====
    part def BaranyChair {
        attribute systemId : String;
        attribute operational : Boolean = true;
        attribute manufacturer : String;
        attribute modelNumber : String;

        part controlSystem : ControlSystem;
        part rotatingPlatform : RotatingPlatform;
        part observationSystem : ObservationSystem;
        part safetySystem : SafetySystem;
        part operatorInterface : OperatorInterface;

        connection controlToMotor
            connect controlSystem.motorPort
            to rotatingPlatform.motor.motorPort;
        connection controlToSafety
            connect controlSystem.safetyPort
            to safetySystem.safetyPort;
        connection controlToObservation
            connect controlSystem.observationPort
            to observationSystem.observationPort;
        connection operatorToControl
            connect operatorInterface.operatorPort
            to controlSystem.operatorPort;

        requirement safetyReqs : SafetyRequirements {
            subject self;
        }
        requirement performanceReqs : PerformanceRequirements {
            subject self;
        }
        requirement functionalReqs : FunctionalRequirements {
            subject self;
        }
    }
}
