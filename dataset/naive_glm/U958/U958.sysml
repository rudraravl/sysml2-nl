package RoboticManufacturingCell {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value def MassValue :> Real { unit 'kg'; }
    value def LengthValue :> Real { unit 'm'; }
    value def SpeedValue :> Real { unit 'm/s'; }
    value def ForceValue :> Real { unit 'N'; }
    value def VoltageValue :> Real { unit 'V'; }
    value def CurrentValue :> Real { unit 'A'; }
    value def AngleValue :> Real { unit 'deg'; }
    value def AccuracyValue :> Real { unit 'mm'; }

    // ---- Item types ----
    item def Component {
        attribute partId : String;
        attribute mass : MassValue;
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute height : LengthValue;
    }

    item def ImageData {
        attribute timestamp : String;
        attribute resolution : String;
    }

    item def PositionData {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }

    item def MovementCommand {
        attribute targetPosition : PositionData;
        attribute speed : SpeedValue;
        attribute acceleration : Real;
    }

    item def GripCommand {
        attribute engage : Boolean;
        attribute force : ForceValue;
    }

    item def JointFeedback {
        attribute jointId : Integer;
        attribute currentAngle : AngleValue;
        attribute torque : Real;
    }

    item def ConveyorStatus {
        attribute running : Boolean;
        attribute speed : SpeedValue;
        attribute partPresent : Boolean;
    }

    // ---- Port definitions ----
    port def RobotControlPort {
        out movementCommands : MovementCommand[0..*];
        out gripCommands : GripCommand[0..*];
        in jointFeedback : JointFeedback[0..*];
    }

    port def VisionDataPort {
        out positionData : PositionData[0..*];
        out componentId : String[0..*];
        out imageData : ImageData[0..*];
    }

    port def ConveyorControlPort {
        out speedCommand : SpeedValue;
        out runCommand : Boolean;
        in conveyorStatus : ConveyorStatus;
    }

    port def SafetyPort {
        out emergencyStop : Boolean;
        out intrusionDetected : Boolean;
        out safetyStatus : String;
    }

    port def PowerPort {
        in voltage : VoltageValue;
        in current : CurrentValue;
    }

    port def JointControlPort {
        in targetAngle : AngleValue;
        out feedback : JointFeedback;
    }

    // ---- Part definitions ----
    part def JointServo {
        attribute jointId : Integer;
        attribute maxAngle : AngleValue;
        attribute currentAngle : AngleValue;
        attribute maxTorque : Real;
        port powerIn : PowerPort;
        port controlPort : JointControlPort;
    }

    part def EndEffector {
        attribute maxGripForce : ForceValue;
        attribute currentForce : ForceValue;
        attribute engaged : Boolean;
        port powerIn : PowerPort;
        port gripControl {
            in command : GripCommand;
        }
    }

    part def ABB_IRB_6700 {
        attribute maxPayload : MassValue = 200 [kg];
        attribute maxReach : LengthValue = 2.6 [m];
        attribute numAxes : Integer = 6;
        attribute manufacturer : String = "ABB";

        port controlPort : RobotControlPort;
        port powerIn : PowerPort;

        part joint1 : JointServo {
            :>> jointId = 1;
            :>> maxAngle = 360 [deg];
        }
        part joint2 : JointServo {
            :>> jointId = 2;
            :>> maxAngle = 360 [deg];
        }
        part joint3 : JointServo {
            :>> jointId = 3;
            :>> maxAngle = 360 [deg];
        }
        part joint4 : JointServo {
            :>> jointId = 4;
            :>> maxAngle = 360 [deg];
        }
        part joint5 : JointServo {
            :>> jointId = 5;
            :>> maxAngle = 360 [deg];
        }
        part joint6 : JointServo {
            :>> jointId = 6;
            :>> maxAngle = 360 [deg];
        }

        part endEffector : EndEffector {
            :>> maxGripForce = 500 [N];
        }

        connection powerToJoint1 connect powerIn to joint1.powerIn;
        connection powerToJoint2 connect powerIn to joint2.powerIn;
        connection powerToJoint3 connect powerIn to joint3.powerIn;
        connection powerToJoint4 connect powerIn to joint4.powerIn;
        connection powerToJoint5 connect powerIn to joint5.powerIn;
        connection powerToJoint6 connect powerIn to joint6.powerIn;
        connection powerToGripper connect powerIn to endEffector.powerIn;
    }

    part def ConveyorSystem {
        attribute beltSpeed : SpeedValue;
        attribute maxSpeed : SpeedValue = 0.5 [m/s];
        attribute beltLength : LengthValue;
        attribute running : Boolean;

        port controlPort : ConveyorControlPort;
        port powerIn : PowerPort;

        attribute pickupAreaPosition : PositionData;

        action def TransportComponent {
            in component : Component;
            in speed : SpeedValue;
            out delivered : Boolean;
        }
    }

    part def VisionSystem {
        attribute accuracy : AccuracyValue = 0.1 [mm];
        attribute cameraResolution : String;
        attribute fieldOfView : AngleValue;

        port dataPort : VisionDataPort;
        port powerIn : PowerPort;

        action def CaptureAndProcess {
            in rawImage : ImageData;
            out position : PositionData;
            out partId : String;
        }

        action def Calibrate {
            out calibrationResult : Boolean;
        }
    }

    part def RobotController {
        attribute productionProgram : String;
        attribute cycleTime : Real;
        attribute connected : Boolean;

        port robotControl : RobotControlPort;
        port visionInput : VisionDataPort;
        port conveyorControl : ConveyorControlPort;
        port safetyInput : SafetyPort;
        port powerIn : PowerPort;

        action def ExecuteProductionCycle {
            in position : PositionData;
            in partId : String;
            in conveyorStatus : ConveyorStatus;
            out movement : MovementCommand;
            out grip : GripCommand;
            out conveyorSpeed : SpeedValue;
            out conveyorRun : Boolean;
        }

        action def PlanTrajectory {
            in target : PositionData;
            out movement : MovementCommand;
        }
    }

    part def EmergencyStopButton {
        attribute activated : Boolean;
        attribute location : String;
        port safetyOut : SafetyPort;
    }

    part def LightCurtain {
        attribute intrusionDetected : Boolean;
        attribute protectedZone : String;
        attribute range : LengthValue;
        port safetyOut : SafetyPort;
    }

    part def SafetySystem {
        attribute active : Boolean;
        attribute monitoringEnabled : Boolean;

        port safetyPort : SafetyPort;
        port powerIn : PowerPort;

        part eStopButton1 : EmergencyStopButton {
            :>> location = "Operator Panel";
        }
        part eStopButton2 : EmergencyStopButton {
            :>> location = "Cell Entrance";
        }
        part lightCurtain1 : LightCurtain {
            :>> protectedZone = "Robot Workspace Front";
            :>> range = 3.0 [m];
        }
        part lightCurtain2 : LightCurtain {
            :>> protectedZone = "Robot Workspace Rear";
            :>> range = 3.0 [m];
        }

        connection eStop1ToSafety connect eStopButton1.safetyOut to safetyPort;
        connection eStop2ToSafety connect eStopButton2.safetyOut to safetyPort;
        connection lc1ToSafety connect lightCurtain1.safetyOut to safetyPort;
        connection lc2ToSafety connect lightCurtain2.safetyOut to safetyPort;
    }

    part def PowerDistributionUnit {
        attribute inputVoltage : VoltageValue = 480 [V];
        attribute inputCurrent : CurrentValue = 100 [A];
        attribute robotVoltage : VoltageValue = 480 [V];
        attribute conveyorVoltage : VoltageValue = 240 [V];
        attribute visionVoltage : VoltageValue = 24 [V];
        attribute controllerVoltage : VoltageValue = 24 [V];
        attribute safetyVoltage : VoltageValue = 24 [V];

        port robotPower : PowerPort;
        port conveyorPower : PowerPort;
        port visionPower : PowerPort;
        port controllerPower : PowerPort;
        port safetyPower : PowerPort;
        port mainInput : PowerPort;
    }

    // ---- Enumeration ----
    enum def OperationalMode {
        automatic;
        manual;
        maintenance;
        emergency_stop;
    }

    // ---- Main cell ----
    part def RoboticManufacturingCell {
        attribute currentMode : OperationalMode;
        attribute cellId : String;
        attribute productionRate : Real;

        port mainPower : PowerPort;

        part powerUnit : PowerDistributionUnit;
        part robot : ABB_IRB_6700;
        part conveyor : ConveyorSystem {
            :>> beltSpeed = 0.3 [m/s];
            :>> beltLength = 5.0 [m];
        }
        part vision : VisionSystem {
            :>> cameraResolution = "2048x2048";
            :>> fieldOfView = 45 [deg];
        }
        part controller : RobotController {
            :>> productionProgram = "PickPlace_v3";
            :>> cycleTime = 8.0;
        }
        part safety : SafetySystem;

        // Power distribution connections
        connection mainToPDU connect mainPower to powerUnit.mainInput;
        connection powerToRobot connect powerUnit.robotPower to robot.powerIn;
        connection powerToConveyor connect powerUnit.conveyorPower to conveyor.powerIn;
        connection powerToVision connect powerUnit.visionPower to vision.powerIn;
        connection powerToController connect powerUnit.controllerPower to controller.powerIn;
        connection powerToSafety connect powerUnit.safetyPower to safety.powerIn;

        // Control and data connections
        connection controllerToRobot connect controller.robotControl to robot.controlPort;
        connection controllerToConveyor connect controller.conveyorControl to conveyor.controlPort;
        connection visionToController connect vision.dataPort to controller.visionInput;
        connection safetyToController connect safety.safetyPort to controller.safetyInput;

        // State machine for operational modes
        state def CellStates {
            entry action assignInitialMode {
                RoboticManufacturingCell::currentMode = OperationalMode::automatic;
            }
            then automatic;

            state automatic {
                entry action enterAutomatic {
                    RoboticManufacturingCell::currentMode = OperationalMode::automatic;
                }
                then producing;

                state producing {
                    entry; then picking;
                    state picking;
                    transition pickingToPlacing from picking to placing;
                    state placing;
                    transition placingToPicking from placing to picking;
                }

                transition autoToManual from automatic to manual
                    when controller.safetyInput.emergencyStop == false
                    if controllerInputManualCommand;
                transition autoToMaintenance from automatic to maintenance
                    if maintenanceRequested;
            }

            state manual {
                entry action enterManual {
                    RoboticManufacturingCell::currentMode = OperationalMode::manual;
                }
                then setup;

                state setup {
                    entry; then jogging;
                    state jogging;
                }

                transition manualToAuto from manual to automatic
                    if automaticRequested;
                transition manualToMaintenance from manual to maintenance
                    if maintenanceRequested;
            }

            state maintenance {
                entry action enterMaintenance {
                    RoboticManufacturingCell::currentMode = OperationalMode::maintenance;
                }
                then servicing;

                state servicing {
                    entry; then inspecting;
                    state inspecting;
                }

                transition maintenanceToManual from maintenance to manual
                    if manualRequested;
            }

            state emergency_stop {
                entry action enterEmergency {
                    RoboticManufacturingCell::currentMode = OperationalMode::emergency_stop;
                }
                then halted;

                state halted {
                    entry action haltAllMotion {
                        // Halt robot joints
                        robot.joint1.currentAngle = robot.joint1.currentAngle;
                        robot.joint2.currentAngle = robot.joint2.currentAngle;
                        robot.joint3.currentAngle = robot.joint3.currentAngle;
                        robot.joint4.currentAngle = robot.joint4.currentAngle;
                        robot.joint5.currentAngle = robot.joint5.currentAngle;
                        robot.joint6.currentAngle = robot.joint6.currentAngle;
                        // Halt conveyor
                        conveyor.running = false;
                        // Release gripper
                        robot.endEffector.engaged = false;
                    }
                }
            }

            // Emergency stop transitions from any operational state
            transition autoToEmergency from automatic to emergency_stop
                when controller.safetyInput.emergencyStop == true
                or controller.safetyInput.intrusionDetected == true;
            transition manualToEmergency from manual to emergency_stop
                when controller.safetyInput.emergencyStop == true
                or controller.safetyInput.intrusionDetected == true;
            transition maintenanceToEmergency from maintenance to emergency_stop
                when controller.safetyInput.emergencyStop == true
                or controller.safetyInput.intrusionDetected == true;

            // Recovery from emergency stop
            transition emergencyToManual from emergency_stop to manual
                when controller.safetyInput.emergencyStop == false
                and controller.safetyInput.intrusionDetected == false
                if resetRequested;
        }

        exhibit state behavior : CellStates;

        // Main production action
        action def RunProductionCycle {
            in incomingComponent : Component;
            in capturedImage : ImageData;
            out placedComponent : Component;

            action captureAndIdentify : vision.CaptureAndProcess {
                in rawImage = capturedImage;
                out position;
                out partId;
            }

            action planTrajectory : controller.PlanTrajectory {
                in target = captureAndIdentify.position;
                out movement;
            }

            action moveRobotToPickup {
                in movementCommand = planTrajectory.movement;
            }

            action engageGripper {
                in gripCmd : GripCommand;
            }

            action moveRobotToPlacement {
                in movementCommand : MovementCommand;
            }

            action releaseGripper {
                in gripCmd : GripCommand;
            }

            then captureAndIdentify;
            then planTrajectory;
            then moveRobotToPickup;
            then engageGripper;
            then moveRobotToPlacement;
            then releaseGripper;

            succession s1 first captureAndIdentify then planTrajectory;
            succession s2 first planTrajectory then moveRobotToPickup;
            succession s3 first moveRobotToPickup then engageGripper;
            succession s4 first engageGripper then moveRobotToPlacement;
            succession s5 first moveRobotToPlacement then releaseGripper;
        }
    }

    // ---- Requirements ----
    requirement def PickAndPlaceRequirement {
        doc /* The manufacturing cell shall autonomously identify components arriving on the conveyor, pick them up using the industrial robot, and place them accurately at a designated assembly fixture. */
        subject cell : RoboticManufacturingCell;
    }

    requirement def RobotPayloadRequirement {
        doc /* The ABB IRB 6700 robot shall handle payloads up to 200 kg. */
        subject robot : ABB_IRB_6700;
        constraint { robot.maxPayload >= 200 [kg] }
    }

    requirement def RobotReachRequirement {
        doc /* The ABB IRB 6700 robot shall have a reach of at least 2.6 meters. */
        subject robot : ABB_IRB_6700;
        constraint { robot.maxReach >= 2.6 [m] }
    }

    requirement def SixAxisRequirement {
        doc /* The robot shall have six servo-driven axes for complex movement. */
        subject robot : ABB_IRB_6700;
        constraint { robot.numAxes == 6 }
    }

    requirement def GripperForceRequirement {
        doc /* The end effector shall exert sufficient force to securely hold components. */
        subject gripper : EndEffector;
        constraint { gripper.maxGripForce >= 500 [N] }
    }

    requirement def VisionAccuracyRequirement {
        doc /* The vision system shall determine component position and orientation with sub-millimeter accuracy. */
        subject vision : VisionSystem;
        constraint { vision.accuracy < 1.0 [mm] }
    }

    requirement def ConveyorSyncRequirement {
        doc /* The conveyor speed shall be controllable to synchronize with the production cycle. */
        subject conveyor : ConveyorSystem;
        constraint { conveyor.maxSpeed >= 0.5 [m/s] }
    }

    requirement def SafetyHaltRequirement {
        doc /* The safety system shall immediately halt all motion when a person enters the robot workspace or an emergency stop is activated. */
        subject safety : SafetySystem;
    }

    requirement def OperationalModeRequirement {
        doc /* The cell shall support automatic, manual, maintenance, and emergency_stop operational modes. */
        subject cell : RoboticManufacturingCell;
    }

    requirement def PowerDistributionRequirement {
        doc /* The power distribution unit shall supply appropriate voltage and current to all cell components. */
        subject pdu : PowerDistributionUnit;
        constraint { pdu.inputVoltage == 480 [V] }
    }

    requirement def ControllerOrchestrationRequirement {
        doc /* The robot controller shall receive location data from the vision system and send movement commands to the robot axes, gripper, and conveyor. */
        subject controller : RobotController;
    }

    requirement package ManufacturingCellRequirements {
        requirement r1 : PickAndPlaceRequirement;
        requirement r2 : RobotPayloadRequirement;
        requirement r3 : RobotReachRequirement;
        requirement r4 : SixAxisRequirement;
        requirement r5 : GripperForceRequirement;
        requirement r6 : VisionAccuracyRequirement;
        requirement r7 : ConveyorSyncRequirement;
        requirement r8 : SafetyHaltRequirement;
        requirement r9 : OperationalModeRequirement;
        requirement r10 : PowerDistributionRequirement;
        requirement r11 : ControllerOrchestrationRequirement;
    }

    // ---- Verification actions ----
    action def VerifyPayload {
        subject robot : ABB_IRB_6700;
        objective { robot.maxPayload >= 200 [kg] }
    }

    action def VerifyReach {
        subject robot : ABB_IRB_6700;
        objective { robot.maxReach >= 2.6 [m] }
    }

    action def VerifyVisionAccuracy {
        subject vision : VisionSystem;
        objective { vision.accuracy < 1.0 [mm] }
    }

    action def VerifySafetyHalt {
        subject safety : SafetySystem;
        objective { safety.active == true }
    }

    // ---- Satisfaction ----
    satisfaction def PayloadSatisfaction {
        subject robot : ABB_IRB_6700;
        requirement r2 : RobotPayloadRequirement;
    }

    satisfaction def ReachSatisfaction {
        subject robot : ABB_IRB_6700;
        requirement r3 : RobotReachRequirement;
    }

    satisfaction def VisionSatisfaction {
        subject vision : VisionSystem;
        requirement r6 : VisionAccuracyRequirement;
    }

}
