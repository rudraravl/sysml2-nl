package IndustrialRoboticSystem {

import ScalarValues::*;

// ===== Units =====

unit V;
unit mm;
unit N;
unit mm_per_s;
unit Nm;
unit deg;
unit deg_per_s;
unit percent;
unit kg;
unit A;
unit Hz;
unit s;

// ===== Value Types =====

value type Voltage :> Real {
    unit V;
    attribute minValue : Voltage = 0.0;
    attribute maxValue : Voltage = 10.0;
}

value type Distance :> Real {
    unit mm;
}

value type ForceValue :> Real {
    unit N;
}

value type LinearVelocity :> Real {
    unit mm_per_s;
}

value type Torque :> Real {
    unit Nm;
}

value type Angle :> Real {
    unit deg;
}

value type AngularVelocity :> Real {
    unit deg_per_s;
}

value type Percentage :> Real {
    unit percent;
}

value type Mass :> Real {
    unit kg;
}

value type Current :> Real {
    unit A;
}

value type Frequency :> Real {
    unit Hz;
}

value type TimeValue :> Real {
    unit s;
}

value type GearRatioValue :> Real;

// ===== Item Definitions =====

item def AnalogCommandSignal {
    attribute joint1Voltage : Voltage;
    attribute joint2Voltage : Voltage;
    attribute joint3Voltage : Voltage;
    attribute joint4Voltage : Voltage;
    attribute joint5Voltage : Voltage;
    attribute joint6Voltage : Voltage;
    attribute timestamp : TimeValue;
}

item def PositionData {
    attribute x : Distance;
    attribute y : Distance;
    attribute z : Distance;
    attribute timestamp : TimeValue;
}

item def ForceData {
    attribute gripForce : ForceValue;
    attribute timestamp : TimeValue;
}

item def VelocityData {
    attribute endEffectorVelocity : LinearVelocity;
    attribute timestamp : TimeValue;
}

item def CombinedFeedback {
    attribute position : PositionData;
    attribute force : ForceData;
    attribute velocity : VelocityData;
}

item def MechanicalPower {
    attribute torque : Torque;
    attribute angularSpeed : AngularVelocity;
}

item def PowerFlow {
    attribute voltage : Voltage;
    attribute current : Current;
}

item def SafetySignal {
    attribute isSecured : Boolean;
    attribute emergencyStop : Boolean;
}

// ===== Port Definitions =====

port def AnalogCommandOutPort {
    out command : AnalogCommandSignal;
}

port def AnalogCommandInPort {
    in command : AnalogCommandSignal;
}

port def FeedbackOutPort {
    out feedback : CombinedFeedback;
}

port def FeedbackInPort {
    in feedback : CombinedFeedback;
}

port def ControlVoltageOutPort {
    out controlVoltage : Voltage;
}

port def ControlVoltageInPort {
    in controlVoltage : Voltage;
}

port def MechanicalOutputPort {
    out mechanicalPower : MechanicalPower;
}

port def MechanicalInputPort {
    in mechanicalPower : MechanicalPower;
}

port def PowerOutputPort {
    out power : PowerFlow;
}

port def PowerInputPort {
    in power : PowerFlow;
}

port def SafetyOutputPort {
    out safetySignal : SafetySignal;
}

port def SafetyInputPort {
    in safetySignal : SafetySignal;
}

// ===== Action Definitions =====

action def AnalogControlLoopAction {
    in commandVoltage : Voltage;
    in positionFeedback : PositionData;
    in velocityFeedback : VelocityData;
    in forceFeedback : ForceData;
    out controlOutput : Voltage;

    attribute gain : Real = 5.0;
    attribute filterCutoff : Frequency = 100.0;

    action computeError {
        in command : Voltage;
        in measured : Voltage;
        out errorSignal : Voltage;
    }

    action amplifyError {
        in errorSignal : Voltage;
        in gainValue : Real;
        out amplifiedVoltage : Voltage;
    }

    action lowPassFilter {
        in inputVoltage : Voltage;
        in cutoffFrequency : Frequency;
        out filteredVoltage : Voltage;
    }

    flow from computeError.errorSignal to amplifyError.errorSignal;
    flow from amplifyError.amplifiedVoltage to lowPassFilter.inputVoltage;
    flow from lowPassFilter.filteredVoltage to controlOutput;
}

action def CalibrationRoutineAction {
    action homeJoints;
    action verifyPositionSensors;
    action checkForceSensor;
    action checkVelocitySensor;
    action confirmCalibrationComplete;

    flow from homeJoints to verifyPositionSensors;
    flow from verifyPositionSensors to checkForceSensor;
    flow from checkForceSensor to checkVelocitySensor;
    flow from checkVelocitySensor to confirmCalibrationComplete;
}

action def PickAndPlaceAction {
    action moveToPickupLocation;
    action lowerToWorkpiece;
    action graspWorkpiece;
    action liftWorkpiece;
    action moveToTargetLocation;
    action lowerAtTarget;
    action releaseWorkpiece;
    action returnToHome;

    flow from moveToPickupLocation to lowerToWorkpiece;
    flow from lowerToWorkpiece to graspWorkpiece;
    flow from graspWorkpiece to liftWorkpiece;
    flow from liftWorkpiece to moveToTargetLocation;
    flow from moveToTargetLocation to lowerAtTarget;
    flow from lowerAtTarget to releaseWorkpiece;
    flow from releaseWorkpiece to returnToHome;
}

action def PerformanceMonitoringAction {
    in feedback : CombinedFeedback;
    in taskResult : Boolean;
    out completionRate : Percentage;
    out positionAccuracy : Distance;

    action updateTaskCount;
    action computeCompletionRate;
    action measurePositionAccuracy;

    flow from updateTaskCount to computeCompletionRate;
    flow from computeCompletionRate to measurePositionAccuracy;
}

// ===== Requirement Definitions =====

requirement def TaskCompletionRateReq {
    doc "The industrial robotic system shall achieve a task completion rate greater than 95 percent across all automated operations.";
    subject system : IndustrialRoboticSystemDef;
    attribute minCompletionRate : Percentage = 95.0;
    objective {
        assert system.measuredCompletionRate > minCompletionRate
    }
}

requirement def PositioningAccuracyReq {
    doc "The analog robot arm shall position the end effector with an accuracy of less than 0.5 mm from the commanded target position.";
    subject robot : AnalogRobotArmDef;
    attribute maxPositionError : Distance = 0.5;
    objective {
        assert robot.measuredPositioningAccuracy < maxPositionError
    }
}

requirement def SafeAnalogVoltageReq {
    doc "All analog control voltages within the robot arm shall be maintained within a safe operating range of 0 to 10 volts.";
    subject robot : AnalogRobotArmDef;
    attribute minSafeVoltage : Voltage = 0.0;
    attribute maxSafeVoltage : Voltage = 10.0;
    objective {
        assert robot.currentControlVoltage >= minSafeVoltage
            and robot.currentControlVoltage <= maxSafeVoltage
    }
}

requirement def SafetyEnclosureReq {
    doc "The safety enclosure shall remain secured during all robot operational states except idle.";
    subject cell : WorkCellDef;
    attribute requiresSecuredDuringOperation : Boolean = true;
    objective {
        assert cell.safetyEnclosure.isSecured == true
    }
}

// ===== Part Definitions =====

// --- Servo Motor ---

part def ServoMotorDef {
    attribute ratedTorque : Torque = 2.0;
    attribute maxSpeed : AngularVelocity = 3000.0;
    attribute currentTorque : Torque;
    attribute currentSpeed : AngularVelocity;

    port controlInput : ControlVoltageInPort;
    port mechanicalOutput : MechanicalOutputPort;

    action driveAction {
        in controlVoltage : Voltage;
        out outputTorque : Torque;
        out outputSpeed : AngularVelocity;
    }
}

// --- Gear Reduction System ---

part def GearReductionDef {
    attribute gearRatio : GearRatioValue = 100.0;
    attribute efficiency : Real = 0.85;
    attribute outputTorque : Torque;
    attribute outputSpeed : AngularVelocity;

    port mechanicalInput : MechanicalInputPort;
    port mechanicalOutput : MechanicalOutputPort;

    action reduceSpeed {
        in inputSpeed : AngularVelocity;
        in inputTorque : Torque;
        out reducedSpeed : AngularVelocity;
        out increasedTorque : Torque;
    }
}

// --- End-of-Arm Gripper ---

part def EndOfArmGripperDef {
    attribute maxGripForce : ForceValue = 50.0;
    attribute minGripForce : ForceValue = 5.0;
    attribute currentGripForce : ForceValue;
    attribute gripperIsOpen : Boolean;
    attribute gripperIsGripping : Boolean;

    port mechanicalInput : MechanicalInputPort;

    state gripperStateMachine {
        state open {
            entry {
                gripperIsOpen = true;
                gripperIsGripping = false;
                currentGripForce = 0.0;
            }
        }

        state closed {
            entry {
                gripperIsOpen = false;
                gripperIsGripping = false;
                currentGripForce = minGripForce;
            }
        }

        state gripping {
            entry {
                gripperIsOpen = false;
                gripperIsGripping = true;
                currentGripForce = maxGripForce;
            }
        }

        transition from open to closed when closeGripperCommand;
        transition from closed to gripping when objectContactDetected;
        transition from gripping to closed when gripReleaseCommand;
        transition from closed to open when openGripperCommand;
        transition from gripping to open when fullReleaseCommand;
    }

    action gripObjectAction {
        in targetForce : ForceValue;
        out appliedForce : ForceValue;
    }

    action releaseObjectAction {
        out releasedForce : ForceValue;
    }
}

// --- Actuator Assembly ---

part def ActuatorAssemblyDef {
    attribute numJoints : Integer = 6;
    attribute assemblyType : String = "6-DOF Analog Servo";

    part servoMotor : ServoMotorDef;
    part gearReduction : GearReductionDef;
    part gripper : EndOfArmGripperDef;

    port controlInput : ControlVoltageInPort;
    port powerInput : PowerInputPort;

    connection motorToGear connect servoMotor.mechanicalOutput to gearReduction.mechanicalInput;
    connection gearToGripper connect gearReduction.mechanicalOutput to gripper.mechanicalInput;
    connection controlToMotor connect controlInput to servoMotor.controlInput;
}

// --- Position Sensor ---

part def PositionSensorDef {
    attribute accuracy : Distance = 0.1;
    attribute measuredX : Distance;
    attribute measuredY : Distance;
    attribute measuredZ : Distance;

    port positionOutput : FeedbackOutPort;
    port powerInput : PowerInputPort;

    action measurePosition {
        out positionData : PositionData;
    }
}

// --- Force Sensor ---

part def ForceSensorDef {
    attribute maxRange : ForceValue = 100.0;
    attribute measuredForce : ForceValue;

    port forceOutput : FeedbackOutPort;
    port powerInput : PowerInputPort;

    action measureForce {
        out forceData : ForceData;
    }
}

// --- Velocity Sensor ---

part def VelocitySensorDef {
    attribute maxRange : LinearVelocity = 500.0;
    attribute measuredVelocity : LinearVelocity;

    port velocityOutput : FeedbackOutPort;
    port powerInput : PowerInputPort;

    action measureVelocity {
        out velocityData : VelocityData;
    }
}

// --- Sensor System ---

part def SensorSystemDef {
    part positionSensor : PositionSensorDef;
    part forceSensor : ForceSensorDef;
    part velocitySensor : VelocitySensorDef;

    port feedbackOutput : FeedbackOutPort;
    port powerInput : PowerInputPort;

    connection posToOutput connect positionSensor.positionOutput to feedbackOutput;
    connection forceToOutput connect forceSensor.forceOutput to feedbackOutput;
    connection velToOutput connect velocitySensor.velocityOutput to feedbackOutput;
    connection powerToPos connect powerInput to positionSensor.powerInput;
    connection powerToForce connect powerInput to forceSensor.powerInput;
    connection powerToVel connect powerInput to velocitySensor.powerInput;
}

// --- Analog Control Circuit ---

part def AnalogControlCircuitDef {
    attribute gain : Real = 5.0;
    attribute filterCutoff : Frequency = 100.0;
    attribute currentError : Voltage;
    attribute currentControlVoltage : Voltage;
    attribute isLoopActive : Boolean = false;

    port commandInput : AnalogCommandInPort;
    port feedbackInput : FeedbackInPort;
    port controlOutput : ControlVoltageOutPort;
    port powerInput : PowerInputPort;

    action controlLoop : AnalogControlLoopAction;

    // The control circuit continuously compares the command voltage with
    // sensor feedback, computes the error, amplifies it, and applies a
    // low-pass filter to produce a smooth control voltage output.
    // The control voltage drives the servo motor in the actuator assembly.
}

// --- Robot Power Supply ---

part def RobotPowerSupplyDef {
    attribute outputVoltage : Voltage = 24.0;
    attribute outputCurrent : Current = 10.0;
    attribute isPoweredOn : Boolean = false;
    attribute powerRating : Real = 240.0;

    port powerOutput : PowerOutputPort;

    state powerState {
        state off;
        state on;
        transition from off to on when powerSwitchOn;
        transition from on to off when powerSwitchOff;
    }
}

// --- Analog Robot Arm ---

part def AnalogRobotArmDef {
    attribute measuredPositioningAccuracy : Distance;
    attribute currentControlVoltage : Voltage;
    attribute isCalibrated : Boolean = false;
    attribute taskCount : Integer = 0;
    attribute successfulTasks : Integer = 0;
    attribute failedTasks : Integer = 0;
    attribute measuredCompletionRate : Percentage;

    port commandInput : AnalogCommandInPort;
    port feedbackOutput : FeedbackOutPort;
    port powerInput : PowerInputPort;
    port safetyInput : SafetyInputPort;

    part actuatorAssembly : ActuatorAssemblyDef;
    part sensorSystem : SensorSystemDef;
    part analogControlCircuit : AnalogControlCircuitDef;
    part powerSupply : RobotPowerSupplyDef;

    connection commandToControlCircuit connect commandInput to analogControlCircuit.commandInput;
    connection sensorToControlCircuit connect sensorSystem.feedbackOutput to analogControlCircuit.feedbackInput;
    connection controlToActuator connect analogControlCircuit.controlOutput to actuatorAssembly.controlInput;
    connection sensorToOutput connect sensorSystem.feedbackOutput to feedbackOutput;
    connection powerToActuator connect powerSupply.powerOutput to actuatorAssembly.powerInput;
    connection powerToSensors connect powerSupply.powerOutput to sensorSystem.powerInput;
    connection powerToControlCircuit connect powerSupply.powerOutput to analogControlCircuit.powerInput;
    connection externalPowerToSupply connect powerInput to powerSupply.powerOutput;

    state operationalState {
        attribute calibrationComplete : Boolean = false;
        attribute taskComplete : Boolean = false;
        attribute errorDetected : Boolean = false;

        state idle {
            entry {
                isCalibrated = false;
                taskComplete = false;
                errorDetected = false;
            }
        }

        state calibrating {
            entry {
                // Begin calibration routine
            }
            do {
                // Home all joints, verify position sensors,
                // check force and velocity sensors, confirm calibration
            }
            exit {
                isCalibrated = true;
            }
        }

        state executing {
            entry {
                // Start pick-and-place task execution
            }
            do {
                // Move to pickup position, lower, grasp workpiece,
                // lift, move to target, lower, release, return home
            }
        }

        state completed {
            entry {
                taskCount = taskCount + 1;
                successfulTasks = successfulTasks + 1;
                measuredCompletionRate = (successfulTasks * 100.0) / taskCount;
                taskComplete = true;
            }
        }

        state fault {
            entry {
                errorDetected = true;
                taskCount = taskCount + 1;
                failedTasks = failedTasks + 1;
                measuredCompletionRate = (successfulTasks * 100.0) / taskCount;
            }
        }

        transition from idle to calibrating when startCalibrationCommand;
        transition from calibrating to executing when calibrationComplete;
        transition from calibrating to fault when calibrationError;
        transition from executing to completed when taskComplete;
        transition from executing to fault when errorDetected;
        transition from completed to idle when resetCommand;
        transition from fault to idle when faultResetCommand;
    }
}

// --- Display ---

part def DisplayDef {
    attribute screenSize : Real = 15.0;
    attribute widthPixels : Integer = 1920;
    attribute heightPixels : Integer = 1080;

    action displayFeedbackData {
        in feedback : CombinedFeedback;
    }

    action displayRobotStatus {
        in operationalState : String;
    }

    action displayCompletionRate {
        in rate : Percentage;
    }
}

// --- Input Controls ---

part def InputControlsDef {
    attribute numButtons : Integer = 12;
    attribute numJoysticks : Integer = 2;
    attribute numDials : Integer = 6;

    port commandOutput : AnalogCommandOutPort;

    action generateAnalogCommand {
        in operatorInput : Real;
        out command : AnalogCommandSignal;
    }
}

// --- Operator Interface ---

part def OperatorInterfaceDef {
    part display : DisplayDef;
    part inputControls : InputControlsDef;

    port commandOutput : AnalogCommandOutPort;
    port feedbackInput : FeedbackInPort;

    connection inputToCommand connect inputControls.commandOutput to commandOutput;
    connection feedbackToDisplay connect feedbackInput to display.displayFeedbackData;
}

// --- Data Acquisition System ---

part def DataAcquisitionDef {
    attribute samplingRate : Frequency = 1000.0;
    attribute bufferSize : Integer = 10000;
    attribute isRecording : Boolean = false;

    port feedbackInput : FeedbackInPort;

    action acquireFeedback {
        in feedback : CombinedFeedback;
    }

    action processFeedbackData {
        in rawFeedback : CombinedFeedback;
        out processedData : CombinedFeedback;
    }
}

// --- Control Station ---

part def ControlStationDef {
    attribute stationId : String = "CS-001";
    attribute isOperational : Boolean = true;

    port commandOutput : AnalogCommandOutPort;
    port feedbackInput : FeedbackInPort;

    part operatorInterface : OperatorInterfaceDef;
    part dataAcquisition : DataAcquisitionDef;

    connection commandToOutput connect operatorInterface.commandOutput to commandOutput;
    connection feedbackToDAQ connect feedbackInput to dataAcquisition.feedbackInput;
    connection feedbackToUI connect feedbackInput to operatorInterface.feedbackInput;
}

// --- Workpiece ---

part def WorkpieceDef {
    attribute mass : Mass = 2.0;
    attribute length : Distance = 100.0;
    attribute width : Distance = 50.0;
    attribute height : Distance = 30.0;
    attribute material : String = "Aluminum";
    attribute isGrasped : Boolean = false;
}

// --- Fixture ---

part def FixtureDef {
    attribute clampingForce : ForceValue = 200.0;
    attribute isSecured : Boolean = false;
    attribute fixtureType : String = "V-Block";

    action clampWorkpieceAction {
        in workpiece : WorkpieceDef;
    }

    action releaseWorkpieceAction {
        in workpiece : WorkpieceDef;
    }

    state fixtureState {
        state released;
        state clamped;
        transition from released to clamped when clampCommand;
        transition from clamped to released when releaseCommand;
    }
}

// --- Safety Enclosure ---

part def SafetyEnclosureDef {
    attribute isSecured : Boolean = false;
    attribute doorInterlockActive : Boolean = false;
    attribute enclosureMaterial : String = "Plexiglass";
    attribute enclosureHeight : Distance = 2500.0;

    port safetyOutput : SafetyOutputPort;

    action activateInterlock {
        out signal : SafetySignal;
    }

    action deactivateInterlock {
        out signal : SafetySignal;
    }

    state enclosureState {
        state unsecured {
            entry {
                isSecured = false;
                doorInterlockActive = false;
            }
        }
        state secured {
            entry {
                isSecured = true;
                doorInterlockActive = true;
            }
        }
        transition from unsecured to secured when doorClosed;
        transition from secured to unsecured when doorOpened;
    }
}

// --- Work Cell ---

part def WorkCellDef {
    attribute cellId : String = "WC-001";
    attribute cellWidth : Distance = 2000.0;
    attribute cellDepth : Distance = 1500.0;
    attribute cellHeight : Distance = 2500.0;

    part workpiece : WorkpieceDef;
    part fixture : FixtureDef;
    part safetyEnclosure : SafetyEnclosureDef;

    port safetyOutput : SafetyOutputPort;

    connection enclosureSafety connect safetyEnclosure.safetyOutput to safetyOutput;
}

// --- Top-Level Industrial Robotic System ---

part def IndustrialRoboticSystemDef {
    attribute systemId : String = "IRS-001";
    attribute measuredCompletionRate : Percentage;
    attribute systemStatus : String = "Offline";
    attribute totalTasksAttempted : Integer = 0;
    attribute totalTasksCompleted : Integer = 0;

    part robotArm : AnalogRobotArmDef;
    part controlStation : ControlStationDef;
    part workCell : WorkCellDef;

    connection stationToRobotCommand connect controlStation.commandOutput to robotArm.commandInput;
    connection robotToStationFeedback connect robotArm.feedbackOutput to controlStation.feedbackInput;
    connection cellSafetyToRobot connect workCell.safetyOutput to robotArm.safetyInput;

    action monitorSystemPerformance : PerformanceMonitoringAction;

    // The system continuously monitors the robot arm performance including
    // task completion rate, positioning accuracy, and safe voltage levels.
    // The control station generates analog commands and receives feedback
    // for operator display and data acquisition.
}

// ===== Requirement Usages =====

requirement taskCompletionRequirement : TaskCompletionRateReq {
    doc "The industrial robotic system shall achieve a task completion rate greater than 95 percent across all automated operations including picking, placing, assembly, and inspection tasks.";
    attribute minCompletionRate : Percentage = 95.0;
}

requirement positioningAccuracyRequirement : PositioningAccuracyReq {
    doc "The analog robot arm shall position the end effector with an accuracy of less than 0.5 mm from the commanded target position during all operational states.";
    attribute maxPositionError : Distance = 0.5;
}

requirement safeVoltageRequirement : SafeAnalogVoltageReq {
    doc "All analog control voltages within the robot arm control circuit shall be maintained within a safe operating range of 0 to 10 volts to prevent damage to the servo motors and associated circuitry.";
    attribute minSafeVoltage : Voltage = 0.0;
    attribute maxSafeVoltage : Voltage = 10.0;
}

requirement enclosureSafetyRequirement : SafetyEnclosureReq {
    doc "The work cell safety enclosure shall remain secured with interlock active during all robot operational states except idle to protect human personnel during automated operation.";
}

// ===== Part Usages and Satisfaction =====

part industrialRobotSystem : IndustrialRoboticSystemDef;

satisfy taskCompletionRequirement by industrialRobotSystem;
satisfy positioningAccuracyRequirement by industrialRobotSystem.robotArm;
satisfy safeVoltageRequirement by industrialRobotSystem.robotArm;
satisfy enclosureSafetyRequirement by industrialRobotSystem.workCell;

}
