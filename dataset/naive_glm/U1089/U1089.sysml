package CollaborativeRoboticAssemblySystem {

import ScalarValues::*;
import ScalarFunctions::*;

// ===== Value Types with Units =====

value def Length : Real { unit "mm"; }
value def Distance : Real { unit "mm"; }
value def Velocity : Real { unit "mm/s"; }
value def Force : Real { unit "N"; }
value def Mass : Real { unit "kg"; }
value def Angle : Real { unit "deg"; }
value def AngularVelocity : Real { unit "deg/s"; }
value def TimeValue : Real { unit "s"; }
value def Power : Real { unit "W"; }
value def Frequency : Real { unit "Hz"; }
value def VolumeLevel : Real { unit "dB"; }

// ===== Enumerations =====

enum def RobotState {
    literal Idle;
    literal Planning;
    literal Executing;
    literal AwaitingApproval;
    literal Paused;
    literal EmergencyStopped;
}

enum def CommandKind {
    literal Start;
    literal Pause;
    literal Resume;
    literal Approve;
    literal Reject;
    literal Retry;
    literal EmergencyStop;
    literal Reset;
}

enum def LEDColor {
    literal Off;
    literal Green;
    literal Yellow;
    literal Red;
    literal Blue;
}

enum def SafetyStatus {
    literal Safe;
    literal Warning;
    literal Unsafe;
}

enum def GripperState {
    literal Open;
    literal Closed;
}

enum def StepStatus {
    literal Pending;
    literal InProgress;
    literal Completed;
    literal Approved;
    literal Rejected;
}

// ===== Item Definitions =====

item def Position {
    attribute x : Length;
    attribute y : Length;
    attribute z : Length;
    attribute roll : Angle;
    attribute pitch : Angle;
    attribute yaw : Angle;
}

item def JointConfiguration {
    attribute jointAngles : Angle[6];
}

item def AssemblyPart {
    attribute partId : String;
    attribute partName : String;
    attribute mass : Mass;
    attribute length : Length;
    attribute width : Length;
    attribute height : Length;
    attribute position : Position;
}

item def AssemblyStep {
    attribute stepId : Integer;
    attribute description : String;
    attribute isCritical : Boolean;
    attribute partId : String;
    attribute sourcePosition : Position;
    attribute targetPosition : Position;
    attribute status : StepStatus = StepStatus::Pending;
}

item def AssemblyPlan {
    attribute planId : String;
    attribute product : String;
    attribute steps : AssemblyStep[1..*];
    attribute currentStepIndex : Integer = 0;
    attribute totalSteps : Integer;
}

item def AssemblyProduct {
    attribute productId : String;
    attribute productName : String;
    attribute completedSteps : Integer = 0;
    attribute totalSteps : Integer;
    attribute qualityStatus : String = "Pending";
}

item def DetectedPart {
    attribute partId : String;
    attribute position : Position;
    attribute confidence : Real;
}

item def SafetyReading {
    attribute timestamp : TimeValue;
    attribute nearestDistance : Distance;
    attribute status : SafetyStatus;
}

// ===== Port Definitions =====

port def CommandPort {
    out command : CommandKind;
    in status : RobotState;
}

port def StatusPort {
    out robotState : RobotState;
    out progressMessage : String;
    out currentStepId : Integer;
}

port def SafetyPort {
    out safetyStatus : SafetyStatus;
    out nearestDistance : Distance;
    out reading : SafetyReading;
}

port def VisionPort {
    out detectedParts : DetectedPart[0..*];
    out inspectionResult : Boolean;
}

port def MotionPort {
    in targetJointAngles : Angle[6];
    in targetVelocity : Velocity;
    out currentJointAngles : Angle[6];
    out currentPosition : Position;
}

port def GripperPort {
    in gripperCommand : GripperState;
    out gripperFeedback : GripperState;
    out partHeld : Boolean;
}

port def AudioPort {
    out alertType : String;
    out volume : VolumeLevel;
}

port def LEDPort {
    out color : LEDColor;
    out blinking : Boolean;
}

port def DisplayPort {
    out displayContent : String;
    out displayImage : String;
    out approvalRequest : Boolean;
    out stepId : Integer;
}

// ===== Part Definitions: Leaf Components =====

part def Joint {
    attribute jointId : Integer;
    attribute minAngle : Angle;
    attribute maxAngle : Angle;
    attribute currentAngle : Angle;
    attribute maxAngularVelocity : AngularVelocity;
    attribute torque : Force;
    part motor;
    part encoder;
}

part def Link {
    attribute linkId : Integer;
    attribute length : Length;
    attribute mass : Mass;
    attribute material : String;
}

part def LEDElement {
    attribute elementId : Integer;
    attribute color : LEDColor = LEDColor::Off;
    attribute isOn : Boolean = false;
}

part def Speaker {
    attribute speakerId : Integer;
    attribute maxPower : Power = 5;
    attribute impedance : Real = 8;
}

part def LaserScanner {
    attribute scannerId : Integer;
    attribute scanRange : Distance = 3000;
    attribute scanRate : Frequency = 25;
    attribute angularResolution : Angle = 0.5;
    attribute protectiveFieldRange : Distance = 500;
    attribute warningFieldRange : Distance = 1000;
}

part def ProximitySensor {
    attribute sensorId : Integer;
    attribute sensingRange : Distance = 1000;
    attribute detected : Boolean = false;
    attribute measuredDistance : Distance;
}

part def Fixture {
    attribute fixtureId : String;
    attribute fixtureType : String;
    attribute clampingForce : Force = 50;
    attribute isEngaged : Boolean = false;
}

part def ComponentStorage {
    attribute storageId : String;
    attribute storageType : String;
    attribute capacity : Integer;
    attribute storedParts : AssemblyPart[0..*];
}

// ===== Part Definitions: Subsystems =====

part def RoboticArm {
    attribute numberOfAxes : Integer = 6;
    attribute maxReach : Length = 850;
    attribute maxPayload : Mass = 10;
    attribute maxVelocity : Velocity = 250;
    attribute repeatability : Length = 0.02;

    port motionIn : MotionPort;
    port gripperOut : GripperPort;

    part joints : Joint[6];
    part links : Link[6];

    attribute currentJointAngles : Angle[6];
    attribute currentEndEffectorPosition : Position;
    attribute currentVelocity : Velocity;
    attribute isMoving : Boolean = false;

    action def executeMove(target : Position, velocity : Velocity) {
        // Compute inverse kinematics and move to target
    }

    action def homeJoints() {
        // Return all joints to home position
    }

    action def stopMotion() {
        // Immediately decelerate and stop all joints
    }
}

part def Gripper {
    attribute maxOpeningWidth : Length = 80;
    attribute gripForce : Force = 40;
    attribute stroke : Length = 50;

    port gripperIn : GripperPort;

    attribute state : GripperState = GripperState::Open;
    attribute heldPart : AssemblyPart[0..1];
    attribute partDetected : Boolean = false;

    action def grasp(part : AssemblyPart) {
        // Close gripper around part with controlled force
    }

    action def release() {
        // Open gripper to release held part
    }
}

part def VisionSystem {
    attribute cameraType : String = "RGB-D";
    attribute resolution : String = "1280x720";
    attribute frameRate : Frequency = 30;
    attribute fieldOfView : Angle = 87;
    attribute minDetectionRange : Length = 100;
    attribute maxDetectionRange : Length = 4000;

    port visionOut : VisionPort;

    part rgbSensor;
    part depthSensor;
    part illumination;

    action def identifyParts() : DetectedPart[0..*] {
        // Process RGB-D data to identify and locate parts on workstation
    }

    action def locatePart(partId : String) : Position {
        // Return precise position of specified part
    }

    action def inspectAssembly() : Boolean {
        // Inspect current assembly state for quality verification
    }

    action def calibrate() {
        // Calibrate camera intrinsics and extrinsics
    }
}

part def SafetySystem {
    attribute monitoringRange : Distance = 1500;
    attribute warningThreshold : Distance = 500;
    attribute stopThreshold : Distance = 200;
    attribute scanCycle : TimeValue = 0.04;

    port safetyOut : SafetyPort;

    part laserScanners : LaserScanner[2];
    part proximitySensors : ProximitySensor[4];

    attribute currentStatus : SafetyStatus = SafetyStatus::Safe;
    attribute nearestOperatorDistance : Distance = 1500;
    attribute lastReading : SafetyReading;

    action def monitorWorkspace() {
        // Continuously scan workspace using laser scanners and proximity sensors
    }

    action def evaluateSafety(nearestDistance : Distance) : SafetyStatus {
        if nearestDistance <= stopThreshold then {
            return SafetyStatus::Unsafe;
        } else if nearestDistance <= warningThreshold then {
            return SafetyStatus::Warning;
        } else {
            return SafetyStatus::Safe;
        }
    }

    action def triggerEmergencyStop() {
        // Signal emergency stop to control unit
    }
}

part def TouchscreenInterface {
    attribute screenSize : String = "15 inch";
    attribute resolution : String = "1920x1080";
    attribute touchType : String = "Capacitive multi-touch";

    port commandOut : CommandPort;
    port statusIn : StatusPort;
    port displayIn : DisplayPort;

    part display;
    part touchSensor;
    part graphicsController;

    attribute currentDisplayedState : RobotState = RobotState::Idle;
    attribute currentMessage : String = "System Ready";
    attribute approvalDialogVisible : Boolean = false;

    action def displayStatus(state : RobotState, message : String) {
        // Update screen with robot status and progress message
    }

    action def captureCommand() : CommandKind {
        // Capture touch input and translate to system command
    }

    action def showApprovalDialog(step : AssemblyStep) {
        // Display approval/rejection dialog for critical step
    }

    action def showEmergencyStopButton() {
        // Prominently display emergency stop button
    }
}

part def LEDIndicator {
    attribute ledCount : Integer = 3;
    attribute currentColor : LEDColor = LEDColor::Off;
    attribute isBlinking : Boolean = false;

    port ledIn : LEDPort;

    part ledElements : LEDElement[3];

    action def setColor(color : LEDColor, blink : Boolean) {
        // Set all LED elements to specified color and blinking mode
    }

    action def turnOff() {
        // Turn off all LED elements
    }
}

part def AudioAlertSystem {
    attribute speakerCount : Integer = 2;
    attribute maxVolume : VolumeLevel = 100;
    attribute currentVolume : VolumeLevel = 50;

    port audioIn : AudioPort;

    part speakers : Speaker[2];

    action def playAlert(alertType : String, volume : VolumeLevel) {
        // Play specified audio alert through speakers
    }

    action def playApprovalRequest() {
        // Play distinctive tone to notify operator of pending approval
    }

    action def playWarning() {
        // Play warning tone when safety threshold is approached
    }

    action def playEmergencyAlarm() {
        // Play continuous alarm for emergency stop
    }
}

part def Workstation {
    attribute workstationId : String;
    attribute workAreaLength : Length = 2000;
    attribute workAreaWidth : Length = 1200;
    attribute workAreaHeight : Length = 800;
    attribute surfaceMaterial : String = "Aluminum";

    part fixtures : Fixture[1..*];
    part storageUnits : ComponentStorage[1..*];

    attribute assemblyProduct : AssemblyProduct[0..1];
    attribute availableParts : AssemblyPart[0..*];

    action def secureAssembly(product : AssemblyProduct) {
        // Engage fixtures to hold assembly in place
    }

    action def releaseAssembly() {
        // Disengage fixtures to release completed assembly
    }

    action def retrievePart(partId : String) : AssemblyPart {
        // Retrieve specified part from storage
    }
}

// ===== State Machine Definition =====

state machine def ControlStateMachine {

    state Idle {
        entry action {
            // Initialize system, home robot, set LED to green
        }
        do action {
            // Wait for operator start command
        }
    }

    state Planning {
        entry action {
            // Activate vision system to identify parts
            // Generate motion plan for current step
        }
        do action {
            // Compute joint trajectories and verify reachability
        }
    }

    state Executing {
        entry action {
            // Begin executing current assembly step
            // Set LED to blue, display progress
        }
        do action {
            // Send motion commands to arm, monitor execution
        }
    }

    state AwaitingApproval {
        entry action {
            // Pause robot motion
            // Display approval request on touchscreen
            // Set LED to yellow, play approval request tone
        }
        do action {
            // Wait for operator inspection and approval/rejection
        }
    }

    state Paused {
        entry action {
            // Stop motion, hold position
            // Set LED to yellow, display pause message
        }
        do action {
            // Monitor safety conditions, wait for resume
        }
    }

    state EmergencyStopped {
        entry action {
            // Immediately halt all motion, power off motors
            // Set LED to red, play emergency alarm
            // Display emergency stop on screen
        }
        do action {
            // Wait for reset command from operator
        }
    }

    transition Idle to Planning when startCommandReceived;
    transition Planning to Executing when safetyConfirmed and planReady;
    transition Planning to Paused when safetyViolation;
    transition Executing to AwaitingApproval when criticalStepCompleted;
    transition Executing to Planning when nonCriticalStepCompleted;
    transition Executing to Paused when safetyWarning;
    transition Executing to Paused when pauseCommandReceived;
    transition Executing to EmergencyStopped when emergencyStopReceived;
    transition AwaitingApproval to Planning when approveCommandReceived;
    transition AwaitingApproval to Executing when rejectCommandReceived;
    transition AwaitingApproval to EmergencyStopped when emergencyStopReceived;
    transition Paused to Executing when resumeCommandReceived and safetyConfirmed;
    transition Paused to EmergencyStopped when emergencyStopReceived;
    transition EmergencyStopped to Idle when resetCommandReceived;

    attribute startCommandReceived : Boolean;
    attribute safetyConfirmed : Boolean;
    attribute safetyWarning : Boolean;
    attribute safetyViolation : Boolean;
    attribute planReady : Boolean;
    attribute criticalStepCompleted : Boolean;
    attribute nonCriticalStepCompleted : Boolean;
    attribute pauseCommandReceived : Boolean;
    attribute resumeCommandReceived : Boolean;
    attribute approveCommandReceived : Boolean;
    attribute rejectCommandReceived : Boolean;
    attribute emergencyStopReceived : Boolean;
    attribute resetCommandReceived : Boolean;
}

// ===== Control Unit =====

part def ControlUnit {
    attribute controllerType : String = "Industrial PC";
    attribute clockSpeed : Frequency = 2000;
    attribute memorySize : Integer = 16;
    attribute firmwareVersion : String = "2.1.0";

    port commandIn : CommandPort;
    port statusOut : StatusPort;
    port safetyIn : SafetyPort;
    port visionIn : VisionPort;
    port motionOut : MotionPort;
    port gripperOut : GripperPort;
    port audioOut : AudioPort;
    port ledOut : LEDPort;
    port displayOut : DisplayPort;

    attribute currentState : RobotState = RobotState::Idle;
    attribute currentPlan : AssemblyPlan[0..1];
    attribute currentStep : AssemblyStep[0..1];
    attribute currentSafetyStatus : SafetyStatus = SafetyStatus::Safe;
    attribute stepExecutionProgress : Real = 0.0;
    attribute lastCommand : CommandKind;

    exhibit ControlStateMachine;

    action def processCommand(cmd : CommandKind) {
        // Interpret incoming command and update state machine triggers
    }

    action def planStep(step : AssemblyStep) : JointConfiguration {
        // Generate joint trajectory for the given assembly step
    }

    action def executeStep(step : AssemblyStep) {
        // Send motion commands to robotic arm for pick-and-place
    }

    action def requestApproval(step : AssemblyStep) {
        // Display step results and request operator approval
    }

    action def updateStatusDisplay(state : RobotState, message : String) {
        // Send status update to touchscreen
    }

    action def setLED(color : LEDColor, blink : Boolean) {
        // Set LED indicator color and blinking pattern
    }

    action def playAlert(alertType : String) {
        // Trigger audio alert
    }

    action def evaluateSafetyStatus() : SafetyStatus {
        // Read safety system data and determine if motion is safe
    }

    action def handleEmergencyStop() {
        // Immediately command all motion to stop
    }
}

// ===== Collaborative Robot (Composite) =====

part def CollaborativeRobot {
    attribute robotId : String;
    attribute robotName : String = "Cobot-Assembly-1";
    attribute manufacturer : String = "Advanced Robotics Inc.";
    attribute payloadCapacity : Mass = 10;
    attribute reach : Length = 850;

    port commandIn : CommandPort;
    port statusOut : StatusPort;
    port safetyIn : SafetyPort;
    port audioOut : AudioPort;
    port ledOut : LEDPort;
    port displayOut : DisplayPort;

    part arm : RoboticArm;
    part gripper : Gripper;
    part vision : VisionSystem;
    part safety : SafetySystem;
    part controller : ControlUnit;

    connection armMotion connect controller.motionOut to arm.motionIn;
    connection gripperControl connect controller.gripperOut to gripper.gripperIn;
    connection armGripperLink connect arm.gripperOut to gripper.gripperIn;
    connection visionData connect vision.visionOut to controller.visionIn;
    connection safetyData connect safety.safetyOut to controller.safetyIn;
    connection controllerStatus connect controller.statusOut to statusOut;
    connection controllerAudio connect controller.audioOut to audioOut;
    connection controllerLED connect controller.ledOut to ledOut;
    connection controllerDisplay connect controller.displayOut to displayOut;
    connection commandRelay connect commandIn to controller.commandIn;
    connection safetyRelay connect safetyIn to safety.safetyOut;
}

// ===== Human Operator =====

part def HumanOperator {
    attribute operatorId : String;
    attribute operatorName : String;
    attribute role : String = "Assembly Supervisor";
    attribute certificationLevel : String = "Level 2";

    action def issueCommand(cmd : CommandKind) {
        // Operator issues a command via touchscreen
    }

    action def inspectWork(step : AssemblyStep) : Boolean {
        // Operator visually inspects completed step
    }

    action def approveStep() {
        // Operator approves the completed step
    }

    action def rejectStep() {
        // Operator rejects the completed step
    }

    action def triggerEmergencyStop() {
        // Operator triggers emergency stop
    }

    action def loadPartsIntoStorage(parts : AssemblyPart[1..*]) {
        // Operator loads new parts into workstation storage
    }

    action def loadAssemblyPlan(plan : AssemblyPlan) {
        // Operator loads assembly plan into system
    }
}

// ===== Top-Level System =====

part def CollaborativeAssemblySystem {
    attribute systemId : String;
    attribute systemName : String = "Collaborative Robotic Assembly System";
    attribute installationDate : String;
    attribute systemVersion : String = "1.0.0";
    attribute facilityLocation : String;

    part robot : CollaborativeRobot;
    part touchscreen : TouchscreenInterface;
    part ledIndicator : LEDIndicator;
    part audioAlert : AudioAlertSystem;
    part workstation : Workstation;
    part operator : HumanOperator;

    connection operatorCommand connect touchscreen.commandOut to robot.commandIn;
    connection robotStatus connect robot.statusOut to touchscreen.statusIn;
    connection robotDisplay connect robot.displayOut to touchscreen.displayIn;
    connection robotLED connect robot.ledOut to ledIndicator.ledIn;
    connection robotAudio connect robot.audioOut to audioAlert.audioIn;

    attribute systemActive : Boolean = false;
    attribute totalAssembliesCompleted : Integer = 0;
    attribute totalEmergencyStops : Integer = 0;

    action def systemStartup() {
        // Initialize all subsystems, perform self-test
    }

    action def systemShutdown() {
        // Safely shut down all subsystems
    }

    action def performSelfTest() : Boolean {
        // Run diagnostic checks on all components
    }

    action def logEvent(eventType : String, description : String) {
        // Record system event in audit log
    }
}

// ===== Requirements =====

requirement def SafetyMonitoringRequirement {
    doc /* The system shall continuously monitor the workspace using laser scanners and proximity sensors to ensure the human operator maintains a safe distance from the robot. */
    attribute id : String = "REQ-001";
    attribute priority : String = "Critical";
    attribute verificationMethod : String = "Test";
}

requirement def EmergencyStopRequirement {
    doc /* The operator shall always have the ability to issue an emergency stop command that immediately halts all robotic motion. */
    attribute id : String = "REQ-002";
    attribute priority : String = "Critical";
    attribute responseTime : TimeValue = 0.5;
    attribute verificationMethod : String = "Test";
}

requirement def HumanApprovalRequirement {
    doc /* After completing a critical assembly step, the system shall pause and request approval from the human operator before proceeding. */
    attribute id : String = "REQ-003";
    attribute priority : String = "High";
    attribute verificationMethod : String = "Inspection";
}

requirement def VisionSystemRequirement {
    doc /* The robot control unit shall use an RGB-D vision system to identify and locate required parts at the workstation. */
    attribute id : String = "REQ-004";
    attribute priority : String = "High";
    attribute detectionAccuracy : Length = 1.0;
    attribute verificationMethod : String = "Test";
}

requirement def OperatorInterfaceRequirement {
    doc /* The system shall provide a touchscreen interface for the operator to issue commands including start, pause, approve, reject, and emergency stop. */
    attribute id : String = "REQ-005";
    attribute priority : String = "High";
    attribute verificationMethod : String = "Demonstration";
}

requirement def VisualFeedbackRequirement {
    doc /* The robot shall communicate its status to the operator through visual feedback on the touchscreen, audio alerts, and colored LED status indicators. */
    attribute id : String = "REQ-006";
    attribute priority : String = "Medium";
    attribute verificationMethod : String = "Demonstration";
}

requirement def StateMachineRequirement {
    doc /* The system shall operate through distinct states: idle, planning, executing, awaiting human approval, paused, and emergency stopped. */
    attribute id : String = "REQ-007";
    attribute priority : String = "High";
    attribute verificationMethod : String = "Analysis";
}

requirement def RetryRequirement {
    doc /* If the operator rejects a completed step, the robot shall be able to retry the step upon instruction. */
    attribute id : String = "REQ-008";
    attribute priority : String = "Medium";
    attribute verificationMethod : String = "Test";
}

requirement def WorkstationRequirement {
    doc /* The workstation shall include fixtures for holding the assembly in place and storage for necessary components. */
    attribute id : String = "REQ-009";
    attribute priority : String = "High";
    attribute verificationMethod : String = "Inspection";
}

requirement def RoboticArmRequirement {
    doc /* The robotic arm shall be multi-axis with a gripper for manipulating various assembly parts. */
    attribute id : String = "REQ-010";
    attribute priority : String = "High";
    attribute minAxes : Integer = 6;
    attribute verificationMethod : String = "Inspection";
}

requirement def SafeStateRequirement {
    doc /* If the operator gets too close to the robot, the robot shall pause or enter a safe state. */
    attribute id : String = "REQ-011";
    attribute priority : String = "Critical";
    attribute safeDistance : Distance = 200;
    attribute verificationMethod : String = "Test";
}

requirement def AssemblyPlanRequirement {
    doc /* The system shall support structured assembly plans with sequential steps, each marked as critical or non-critical. */
    attribute id : String = "REQ-012";
    attribute priority : String = "Medium";
    attribute verificationMethod : String = "Analysis";
}

// ===== Requirement Group =====

part def SystemRequirementsPackage {
    requirement safetyMonitoringReq : SafetyMonitoringRequirement;
    requirement emergencyStopReq : EmergencyStopRequirement;
    requirement humanApprovalReq : HumanApprovalRequirement;
    requirement visionSystemReq : VisionSystemRequirement;
    requirement operatorInterfaceReq : OperatorInterfaceRequirement;
    requirement visualFeedbackReq : VisualFeedbackRequirement;
    requirement stateMachineReq : StateMachineRequirement;
    requirement retryReq : RetryRequirement;
    requirement workstationReq : WorkstationRequirement;
    requirement roboticArmReq : RoboticArmRequirement;
    requirement safeStateReq : SafeStateRequirement;
    requirement assemblyPlanReq : AssemblyPlanRequirement;
}

}
