package DextreModel {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQMass::*;
    import ISQForce::*;

    // ===== Value Types =====
    def LengthValue :> Real { unit 'm'; }
    def MassValue :> Real { unit 'kg'; }
    def ForceValue :> Real { unit 'N'; }
    def VoltageValue :> Real { unit 'V'; }
    def CurrentValue :> Real { unit 'A'; }
    def PowerValue :> Real { unit 'W'; }
    def AngleValue :> Real { unit 'rad'; }
    def PrecisionValue :> Real { unit 'mm'; }
    def IlluminanceValue :> Real { unit 'lx'; }
    def ResolutionValue :> Real { unit 'MP'; }

    // ===== Items =====
    item def Command;
    item def TeleopCommand :> Command;
    item def AutonomousSequence :> Command;
    item def HealthStatus;
    item def ImageData;
    item def SensorData;
    item def JointCommand;
    item def EndEffectorCommand;
    item def ToolCommand;
    item def PowerSignal;
    item def DCPower :> PowerSignal { attribute voltage : VoltageValue; attribute current : CurrentValue; }

    item def ORU {
        attribute mass : MassValue;
        attribute hasGrapplePoint : Boolean;
    }

    item def MaintenanceTool {
        attribute identifier : String;
        attribute mass : MassValue;
    }

    // ===== Port Definitions =====
    port def PowerPort {
        out power : DCPower;
    }

    port def PowerInPort {
        in power : DCPower;
    }

    port def CommandPort {
        in command : Command;
        out status : HealthStatus;
    }

    port def DataPort {
        out data : ImageData;
    }

    port def SensorPort {
        out sensorData : SensorData;
    }

    port def JointControlPort {
        in jointCmd : JointCommand;
    }

    port def EndEffectorControlPort {
        in eeCmd : EndEffectorCommand;
        out eeSensor : SensorData;
    }

    port def ToolInterfacePort {
        out toolCmd : ToolCommand;
    }

    port def GrapplePort {
        attribute maxGraspForce : ForceValue;
    }

    // ===== Requirements =====
    requirement def DualArmRequirement {
        doc "Dextre shall have two articulated robotic arms for bimanual tasks.";
        subject spdm : Dextre;
        require spdm.leftArm.armLength == 3.5 and spdm.rightArm.armLength == 3.5;
        require spdm.leftArm.jointCount == 7 and spdm.rightArm.jointCount == 7;
        require spdm.leftArm.payloadCapacity >= 600 and spdm.rightArm.payloadCapacity >= 600;
    }

    requirement def EndEffectorRequirement {
        doc "Each end effector shall grasp objects with controlled force up to 300 N.";
        subject ee : EndEffector;
        require ee.maxGraspForce >= 300;
        require ee.forceSensor.accuracy <= 1.0;
        require ee.proximitySensor.range >= 0.5;
    }

    requirement def VisionSystemRequirement {
        doc "Vision system shall provide sub-millimeter alignment verification.";
        subject vs : VisionSystem;
        require vs.cameraCount == 4;
        require vs.lightCount == 8;
        require vs.alignmentPrecision <= 1.0;
    }

    requirement def ControlModesRequirement {
        doc "Central computer shall support teleoperated, autonomous, and standby modes.";
        subject cc : CentralComputer;
        require cc.supportedModes == {'teleoperated', 'autonomous', 'standby'};
    }

    requirement def ToolStorageRequirement {
        doc "Tool storage unit shall have four bays for tools.";
        subject tsu : ToolStorageUnit;
        require tsu.bayCount == 4;
    }

    requirement def PowerSystemRequirement {
        doc "Power system shall draw from ISS grid and distribute to subsystems.";
        subject ps : PowerSystem;
        require ps.inputVoltage == 120;
        require ps.outputVoltage == 28;
    }

    // ===== Part Definitions =====

    part def ForceSensor {
        attribute accuracy : ForceValue = 0.5;
        port sensorOut : SensorPort;
        action def senseForce() : SensorData;
    }

    part def ProximitySensor {
        attribute range : LengthValue = 0.5;
        port sensorOut : SensorPort;
        action def senseProximity() : SensorData;
    }

    part def Camera {
        attribute resolution : ResolutionValue = 4.0;
        port imageOut : DataPort;
        action def captureImage() : ImageData;
    }

    part def LEDLight {
        attribute illuminance : IlluminanceValue = 500.0;
        attribute isOn : Boolean = false;
        action def turnOn();
        action def turnOff();
    }

    part def Joint {
        attribute index : Integer;
        attribute currentAngle : AngleValue = 0.0;
        attribute maxTorque : TorqueValue;
        port jointCtrl : JointControlPort;
        action def actuate(in targetAngle : AngleValue) {
            // Move joint to target angle
        }
    }

    part def EndEffector {
        attribute maxGraspForce : ForceValue = 300.0;
        attribute currentGraspForce : ForceValue = 0.0;
        attribute isGrasping : Boolean = false;
        part forceSensor : ForceSensor;
        part proximitySensor : ProximitySensor;
        port eeControl : EndEffectorControlPort;
        port grapple : GrapplePort;
        port toolInterface : ToolInterfacePort;

        action def grasp(in targetForce : ForceValue) {
            // Close gripper and apply controlled force
        }
        action def release() {
            // Open gripper
        }
        action def attachTool(in tool : MaintenanceTool) {
            // Attach a maintenance tool
        }
    }

    part def RoboticArm {
        attribute armLength : LengthValue = 3.5;
        attribute jointCount : Integer = 7;
        attribute payloadCapacity : MassValue = 600.0;
        attribute side : String;
        part joints : Joint[7] {
            // Seven joints for maximum flexibility
        }
        part endEffector : EndEffector;
        port armControl : JointControlPort;
        port eePort : EndEffectorControlPort;

        action def moveArm(in jointAngles : AngleValue[7]) {
            // Coordinate all joints to achieve desired pose
        }
        action def coordinatedGrasp(in targetForce : ForceValue) {
            endEffector.grasp(targetForce);
        }
    }

    part def VisionSystem {
        attribute cameraCount : Integer = 4;
        attribute lightCount : Integer = 8;
        attribute alignmentPrecision : PrecisionValue = 0.5;
        part cameras : Camera[4];
        part lights : LEDLight[8];
        port imageOut : DataPort;

        action def surveyWorksite() : ImageData {
            // Capture images from all cameras with illumination
        }
        action def trackTarget(in targetId : String) : ImageData {
            // Track a specific target
        }
        action def verifyAlignment(in componentId : String) : Boolean {
            // Verify sub-millimeter alignment
        }
    }

    part def ToolBay {
        attribute bayId : Integer;
        attribute isOccupied : Boolean = false;
        attribute storedTool : MaintenanceTool;
        action def stowTool(in tool : MaintenanceTool) {
            isOccupied := true;
            storedTool := tool;
        }
        action def retrieveTool() : MaintenanceTool {
            isOccupied := false;
            return storedTool;
        }
    }

    part def ToolStorageUnit {
        attribute bayCount : Integer = 4;
        part bays : ToolBay[4];
        action def storeTool(in bayId : Integer, in tool : MaintenanceTool) {
            bays[bayId].stowTool(tool);
        }
        action def getTool(in bayId : Integer) : MaintenanceTool {
            return bays[bayId].retrieveTool();
        }
    }

    part def CentralComputer {
        attribute supportedModes : String[3] = ['teleoperated', 'autonomous', 'standby'];
        attribute currentMode : String = 'standby';
        port cmdPort : CommandPort;
        port leftArmCtrl : JointControlPort;
        port rightArmCtrl : JointControlPort;
        port leftEeCtrl : EndEffectorControlPort;
        port rightEeCtrl : EndEffectorControlPort;
        port visionCtrl : DataPort;
        port powerIn : PowerInPort;

        state def OperatingMode {
            state standby {
                entry action { currentMode := 'standby'; }
                on cmdPort.command::TeleopCommand transition to teleoperated;
                on cmdPort.command::AutonomousSequence transition to autonomous;
            }
            state teleoperated {
                entry action { currentMode := 'teleoperated'; }
                on cmdPort.command::AutonomousSequence transition to autonomous;
                // Process teleop commands
                do action { /* forward joint commands to arms */ }
                on cmdPort.command::Command transition to standby
                    if cmdPort.command == null;
            }
            state autonomous {
                entry action { currentMode := 'autonomous'; }
                // Execute pre-programmed sequence
                do action { /* execute autonomous sequence step by step */ }
                on cmdPort.command::TeleopCommand transition to teleoperated;
                on cmdPort.command::Command transition to standby
                    if cmdPort.command == null;
            }
        }

        action def processCommand(in cmd : Command) {
            // Parse and route command to appropriate subsystem
        }
        action def coordinateBimanualTask(in leftArmAngles : AngleValue[7], in rightArmAngles : AngleValue[7]) {
            leftArmCtrl.jointCmd := leftArmAngles;
            rightArmCtrl.jointCmd := rightArmAngles;
        }
        action def monitorHealth() : HealthStatus {
            // Check all subsystem health indicators
        }
    }

    part def PowerSystem {
        attribute inputVoltage : VoltageValue = 120.0;
        attribute outputVoltage : VoltageValue = 28.0;
        attribute totalPowerBudget : PowerValue = 2000.0;
        port issPowerInput : PowerInPort;
        port armPowerOut : PowerPort;
        port computerPowerOut : PowerPort;
        port visionPowerOut : PowerPort;

        action def convertPower() {
            // Convert 120V ISS power to 28V distribution
        }
        action def distributePower() {
            // Distribute power to arms, computer, and vision system
        }
    }

    part def CentralBody {
        part coreElectronics;
        part toolStorage : ToolStorageUnit;
        port leftArmMount;
        port rightArmMount;
    }

    part def Dextre {
        attribute name : String = "Dextre";
        attribute designation : String = "SPDM";

        part centralBody : CentralBody;
        part leftArm : RoboticArm { side = "left"; }
        part rightArm : RoboticArm { side = "right"; }
        part visionSystem : VisionSystem;
        part centralComputer : CentralComputer;
        part powerSystem : PowerSystem;

        // Internal connections
        connection leftArmMountConnection connect centralBody.leftArmMount to leftArm;
        connection rightArmMountConnection connect centralBody.rightArmMount to rightArm;

        connection leftArmControl connect centralComputer.leftArmCtrl to leftArm.armControl;
        connection rightArmControl connect centralComputer.rightArmCtrl to rightArm.armControl;
        connection leftEeControl connect centralComputer.leftEeCtrl to leftArm.eePort;
        connection rightEeControl connect centralComputer.rightEeCtrl to rightArm.eePort;

        connection visionData connect visionSystem.imageOut to centralComputer.visionCtrl;

        connection issPower connect powerSystem.issPowerInput to centralComputer.powerIn;
        connection leftArmPower connect powerSystem.armPowerOut to leftArm;
        connection rightArmPower connect powerSystem.armPowerOut to rightArm;
        connection visionPower connect powerSystem.visionPowerOut to visionSystem;
        connection computerPower connect powerSystem.computerPowerOut to centralComputer;

        // Requirements satisfaction
        satisfy DualArmRequirement by spdm::self;
        satisfy VisionSystemRequirement by visionSystem;
        satisfy ControlModesRequirement by centralComputer;
        satisfy ToolStorageRequirement by centralBody.toolStorage;
        satisfy PowerSystemRequirement by powerSystem;

        action def performMaintenanceTask(in oru : ORU, in tool : MaintenanceTool) {
            // Full maintenance task workflow
            var survey : ImageData = visionSystem.surveyWorksite();
            centralBody.toolStorage.storeTool(1, tool);
            var retrievedTool : MaintenanceTool = centralBody.toolStorage.getTool(1);
            leftArm.coordinatedGrasp(150.0);
            rightArm.coordinatedGrasp(200.0);
            var aligned : Boolean = visionSystem.verifyAlignment(oru.identifier);
        }
    }

    // ===== Top-level configuration =====
    part dextreInstance : Dextre {
        // Instantiated configuration
    }

    // ===== Requirement group =====
    requirement group DextreRequirements {
        requirement dualArmReq : DualArmRequirement;
        requirement eeReq : EndEffectorRequirement;
        requirement visionReq : VisionSystemRequirement;
        requirement controlReq : ControlModesRequirement;
        requirement toolStorageReq : ToolStorageRequirement;
        requirement powerReq : PowerSystemRequirement;
    }
}
