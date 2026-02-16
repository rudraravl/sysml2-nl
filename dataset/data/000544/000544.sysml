package BaranyChairSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def RotationSpeed :> ISQ::angularVelocity;
    attribute def RotationAngle :> ISQ::angle;
    attribute def TestDuration :> ISQ::duration;
    attribute def TorqueValue :> ISQ::torque;
    attribute def PowerValue :> ISQ::power;
    
    enum def RotationDirection {
        clockwise;
        counterclockwise;
    }
    
    enum def ChairState {
        idle;
        accelerating;
        constantRotation;
        decelerating;
        stopped;
        emergency;
    }
    
    enum def TestType {
        caloric;
        rotational;
        postRotational;
    }
    
    item def RotationCommand {
        attribute targetSpeed : RotationSpeed;
        attribute direction : RotationDirection;
        attribute duration : TestDuration;
    }
    
    item def VestibularResponse {
        attribute nystagmusDetected : Boolean;
        attribute nystagmusIntensity : Real;
        attribute dizzinessLevel : Real;
        attribute balanceScore : Real;
    }
    
    item def SafetyStatus {
        attribute restraintEngaged : Boolean;
        attribute emergencyStopActive : Boolean;
        attribute speedWithinLimits : Boolean;
    }
    
    port def ControlPort {
        in command : RotationCommand;
        out status : ChairState;
    }
    
    port def SensorPort {
        out response : VestibularResponse;
    }
    
    port def PowerPort {
        in power : PowerValue;
    }
    
    port def MechanicalPort {
        in torque : TorqueValue;
        out speed : RotationSpeed;
    }
    
    part def Patient {
        attribute bodyMass : ISQ::mass;
        attribute vestibularSensitivity : Real;
        attribute currentOrientation : RotationAngle;
    }
    
    part def RotatingPlatform {
        attribute currentSpeed : RotationSpeed;
        attribute currentAngle : RotationAngle;
        attribute platformMass : ISQ::mass;
        attribute platformDiameter : ISQ::length;
        
        port mechanicalInterface : MechanicalPort;
    }
    
    part def DriveMotor {
        attribute motorSpeed : RotationSpeed;
        attribute outputTorque : TorqueValue;
        attribute maxSpeed : RotationSpeed = 360.0 [SI::rad/SI::s];
        attribute maxTorque : TorqueValue = 100.0 [SI::'N·m'];
        
        port powerInput : PowerPort;
        port driveOutput : MechanicalPort;
        port controlInterface : ControlPort;
    }
    
    part def ControlSystem {
        attribute targetSpeed : RotationSpeed;
        attribute testDuration : TestDuration;
        attribute selectedDirection : RotationDirection;
        attribute currentState : ChairState;
        
        port operatorInterface : ControlPort;
        port motorControl : ControlPort;
        port sensorInput : SensorPort;
    }
    
    part def SeatAssembly {
        attribute seatHeight : ISQ::length = 0.6 [SI::m];
        attribute hasHeadrest : Boolean = true;
        attribute hasSafetyHarness : Boolean = true;
        attribute seatMass : ISQ::mass = 15.0 [SI::kg];
        
        port mountingInterface;
    }
    
    part def SafetySystem {
        attribute restraintEngaged : Boolean;
        attribute emergencyStopPressed : Boolean;
        attribute speedLimitExceeded : Boolean;
        
        port safetyMonitor;
    }
    
    part def ObservationSystem {
        attribute nystagmusDetected : Boolean;
        attribute responseRecorded : Boolean;
        
        port observationPort : SensorPort;
    }
    
    action def InitializeTest {
        in patient : Patient;
        in testSpeed : RotationSpeed;
        in testDuration : TestDuration;
        in testDirection : RotationDirection;
        out testReady : Boolean;
    }
    
    action def AccelerateChair {
        in targetSpeed : RotationSpeed;
        in accelerationRate : Real;
        out speedAchieved : Boolean;
    }
    
    action def RotateAtConstantSpeed {
        in speed : RotationSpeed;
        in direction : RotationDirection;
        in duration : TestDuration;
        out rotationComplete : Boolean;
    }
    
    action def MonitorVestibularResponse {
        in patient : Patient;
        out response : VestibularResponse;
    }
    
    action def DecelerateChair {
        in decelerationRate : Real;
        out stopped : Boolean;
    }
    
    action def EmergencyStop {
        out stopped : Boolean;
    }
    
    action def PerformVestibularTest {
        first start;
        
        then action initialize : InitializeTest {
            in patient : Patient;
            in testSpeed : RotationSpeed;
            in testDuration : TestDuration;
            in testDirection : RotationDirection;
            out testReady : Boolean;
        }
        
        then action checkSafety {
            assert constraint { safetySystem.restraintEngaged == true }
            in safetySystem : SafetySystem;
        }
        
        then action accelerate : AccelerateChair {
            in targetSpeed = initialize.testSpeed;
            in accelerationRate = 10.0;
            out speedAchieved : Boolean;
        }
        
        then fork monitoringPhase;
        
        parallel action rotate : RotateAtConstantSpeed {
            in speed = initialize.testSpeed;
            in direction = initialize.testDirection;
            in duration = initialize.testDuration;
            out rotationComplete : Boolean;
        }
        
        parallel action monitor : MonitorVestibularResponse {
            in patient = initialize.patient;
            out response : VestibularResponse;
        }
        
        join then decelerate;
        
        action decelerate : DecelerateChair {
            in decelerationRate = 15.0;
            out stopped : Boolean;
        }
        
        then done;
    }
    
    part def BaranyChair {
        attribute maxRotationSpeed : RotationSpeed = 180.0 [SI::rad/SI::s];
        attribute minRotationSpeed : RotationSpeed = 5.0 [SI::rad/SI::s];
        attribute totalMass : ISQ::mass;
        attribute operatingVoltage : Real = 220.0;
        attribute powerRating : PowerValue = 750.0 [SI::W];
        
        part platform : RotatingPlatform {
            attribute :>> currentSpeed : RotationSpeed;
            attribute :>> currentAngle : RotationAngle;
            attribute :>> platformMass = 40.0 [SI::kg];
            attribute :>> platformDiameter = 1.2 [SI::m];
        }
        
        part motor : DriveMotor {
            attribute :>> motorSpeed : RotationSpeed;
            attribute :>> outputTorque : TorqueValue;
            attribute :>> maxSpeed = 360.0 [SI::rad/SI::s];
            attribute :>> maxTorque = 100.0 [SI::'N·m'];
        }
        
        part controller : ControlSystem {
            attribute :>> targetSpeed : RotationSpeed;
            attribute :>> testDuration : TestDuration;
            attribute :>> currentState : ChairState;
        }
        
        part seat : SeatAssembly {
            attribute :>> seatHeight = 0.6 [SI::m];
            attribute :>> hasHeadrest = true;
            attribute :>> hasSafetyHarness = true;
            attribute :>> seatMass = 15.0 [SI::kg];
        }
        
        part safety : SafetySystem {
            attribute :>> restraintEngaged : Boolean;
            attribute :>> emergencyStopPressed : Boolean;
            attribute :>> speedLimitExceeded : Boolean;
        }
        
        part observation : ObservationSystem {
            attribute :>> nystagmusDetected : Boolean;
            attribute :>> responseRecorded : Boolean;
        }
        
        connection motorToPlatform connect motor.driveOutput to platform.mechanicalInterface;
        connection controlToMotor connect controller.motorControl to motor.controlInterface;
        connection observationToController connect observation.observationPort to controller.sensorInput;
        connection seatToPlatform connect seat.mountingInterface to platform.mechanicalInterface;
        
        assert constraint massConstraint {
            totalMass == platform.platformMass + seat.seatMass + 40.0 [SI::kg]
        }
        
        perform action vestibularTest : PerformVestibularTest;
    }
    
    requirement def VestibularTestingCapability {
        doc /* The Bárány chair system shall provide controlled rotational 
             * stimulation to assess vestibular function by inducing nystagmus 
             * and evaluating balance responses in patients.
             */
        subject chair : BaranyChair;
        
        require speedControl;
        require safetyFeatures;
        require responseMonitoring;
    }
    
    requirement <'REQ-BC-001'> speedControl {
        doc /* The chair shall provide adjustable rotation speed between 
             * 5 and 180 degrees per second with bidirectional control.
             */
        subject chair : BaranyChair;
        
        assert constraint {
            chair.platform.currentSpeed >= chair.minRotationSpeed and
            chair.platform.currentSpeed <= chair.maxRotationSpeed
        }
    }
    
    requirement <'REQ-BC-002'> safetyFeatures {
        doc /* The chair shall include safety harness, headrest, and 
             * emergency stop capability for patient protection.
             */
        subject seat : BaranyChair::seat;
        
        assert constraint {
            seat.hasSafetyHarness and seat.hasHeadrest
        }
    }
    
    requirement <'REQ-BC-003'> responseMonitoring {
        doc /* The system shall enable continuous observation and recording 
             * of vestibular responses including nystagmus during rotation.
             */
        subject observation : BaranyChair::observation;
    }
    
    requirement <'REQ-BC-004'> emergencyStop {
        doc /* The system shall stop rotation within 2 seconds upon 
             * activation of emergency stop control.
             */
        subject safety : BaranyChair::safety;
        
        attribute maxStopTime : TestDuration = 2.0 [SI::s];
    }
    
    requirement <'REQ-BC-005'> smoothAcceleration {
        doc /* The chair shall accelerate and decelerate smoothly to 
             * minimize patient discomfort and ensure accurate testing.
             */
        subject motor : BaranyChair::motor;
    }
    
    part baranyChairSystem : BaranyChair {
        attribute :>> maxRotationSpeed = 180.0 [SI::rad/SI::s];
        attribute :>> minRotationSpeed = 5.0 [SI::rad/SI::s];
        attribute :>> totalMass = 95.0 [SI::kg];
        attribute :>> operatingVoltage = 220.0;
        attribute :>> powerRating = 750.0 [SI::W];
        
        part :>> platform {
            attribute :>> currentSpeed = 0.0 [SI::rad/SI::s];
            attribute :>> currentAngle = 0.0 [SI::rad];
            attribute :>> platformMass = 40.0 [SI::kg];
            attribute :>> platformDiameter = 1.2 [SI::m];
        }
        
        part :>> motor {
            attribute :>> motorSpeed = 0.0 [SI::rad/SI::s];
            attribute :>> outputTorque = 75.0 [SI::'N·m'];
            attribute :>> maxSpeed = 360.0 [SI::rad/SI::s];
            attribute :>> maxTorque = 100.0 [SI::'N·m'];
        }
        
        part :>> controller {
            attribute :>> targetSpeed = 90.0 [SI::rad/SI::s];
            attribute :>> testDuration = 30.0 [SI::s];
            attribute :>> selectedDirection = RotationDirection::clockwise;
            attribute :>> currentState = ChairState::idle;
        }
        
        part :>> seat {
            attribute :>> seatHeight = 0.6 [SI::m];
            attribute :>> hasHeadrest = true;
            attribute :>> hasSafetyHarness = true;
            attribute :>> seatMass = 15.0 [SI::kg];
        }
        
        part :>> safety {
            attribute :>> restraintEngaged = false;
            attribute :>> emergencyStopPressed = false;
            attribute :>> speedLimitExceeded = false;
        }
        
        part :>> observation {
            attribute :>> nystagmusDetected = false;
            attribute :>> responseRecorded = false;
        }
    }
    
    satisfy VestibularTestingCapability by baranyChairSystem;
    satisfy speedControl by baranyChairSystem.controller;
    satisfy safetyFeatures by baranyChairSystem.seat;
    satisfy responseMonitoring by baranyChairSystem.observation;
    satisfy emergencyStop by baranyChairSystem.safety;
    satisfy smoothAcceleration by baranyChairSystem.motor;
}
