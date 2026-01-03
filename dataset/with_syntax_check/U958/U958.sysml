package ABB_RoboticManufacturingCell {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def AngleValue :> Real;
    attribute def SpeedValue :> Real;
    attribute def AccelerationValue :> Real;
    attribute def PositionCoordinate :> LengthValue;
    
    enum def RobotOperationalMode {
        manual;
        automatic;
        maintenance;
        emergency_stop;
    }
    
    enum def GripperState {
        open;
        closed;
        gripping;
        releasing;
    }
    
    enum def ConveyorState {
        stopped;
        running;
        fault;
    }
    
    item def Component {
        attribute partNumber : String;
        attribute mass : MassValue;
        attribute dimensions : LengthValue[3];
    }
    
    item def ControlCommand {
        attribute timestamp : TimeValue;
        attribute commandType : String;
    }
    
    item def StatusFeedback {
        attribute timestamp : TimeValue;
        attribute statusCode : Integer;
        attribute statusMessage : String;
    }
    
    port def RobotControlPort {
        out command : ControlCommand;
        in feedback : StatusFeedback;
    }
    
    port def PowerSupplyPort {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
        attribute frequency : FrequencyValue;
    }
    
    port def SafetyPort {
        in emergencyStop : Boolean;
        out safetyStatus : Boolean;
    }
    
    port def ConveyorControlPort {
        out speed : SpeedValue;
        in position : PositionCoordinate;
    }
    
    part def RobotController {
        attribute cycleTime : TimeValue;
        attribute processingCapacity : Real;
        port mainControl : RobotControlPort;
        port power : PowerSupplyPort;
        port safety : SafetyPort;
        
        perform action executeProgram : ExecuteRobotProgram;
    }
    
    part def ServoAxis {
        attribute axisNumber : Integer;
        attribute maxTorque : TorqueValue;
        attribute maxSpeed : SpeedValue;
        attribute currentAngle : AngleValue;
        attribute targetAngle : AngleValue;
        port control : RobotControlPort;
    }
    
    part def EndEffector {
        attribute gripForce : ForceValue;
        attribute openingWidth : LengthValue;
        attribute currentState : GripperState;
        port actuator : RobotControlPort;
        port sensor : RobotControlPort;
    }
    
    part def IRB6700Robot {
        attribute reachDistance : LengthValue;
        attribute maxPayload : MassValue;
        attribute repeatability : LengthValue;
        attribute operatingMode : RobotOperationalMode;
        
        part axis1 : ServoAxis {
            attribute :>> axisNumber = 1;
            attribute :>> maxTorque = 400.0 [SI::N * SI::m];
            attribute :>> maxSpeed = 100.0;
        }
        
        part axis2 : ServoAxis {
            attribute :>> axisNumber = 2;
            attribute :>> maxTorque = 400.0 [SI::N * SI::m];
            attribute :>> maxSpeed = 90.0;
        }
        
        part axis3 : ServoAxis {
            attribute :>> axisNumber = 3;
            attribute :>> maxTorque = 280.0 [SI::N * SI::m];
            attribute :>> maxSpeed = 90.0;
        }
        
        part axis4 : ServoAxis {
            attribute :>> axisNumber = 4;
            attribute :>> maxTorque = 190.0 [SI::N * SI::m];
            attribute :>> maxSpeed = 170.0;
        }
        
        part axis5 : ServoAxis {
            attribute :>> axisNumber = 5;
            attribute :>> maxTorque = 190.0 [SI::N * SI::m];
            attribute :>> maxSpeed = 120.0;
        }
        
        part axis6 : ServoAxis {
            attribute :>> axisNumber = 6;
            attribute :>> maxTorque = 94.0 [SI::N * SI::m];
            attribute :>> maxSpeed = 190.0;
        }
        
        part gripper : EndEffector {
            attribute :>> gripForce = 500.0 [SI::N];
            attribute :>> openingWidth = 150.0 [SI::mm];
        }
        
        port robotControl : RobotControlPort;
        port powerInput : PowerSupplyPort;
        port safetyInterface : SafetyPort;
    }
    
    part def ConveyorSystem {
        attribute beltLength : LengthValue;
        attribute beltWidth : LengthValue;
        attribute transportSpeed : SpeedValue;
        attribute currentState : ConveyorState;
        
        port control : ConveyorControlPort;
        port power : PowerSupplyPort;
        
        perform action transportComponents : TransportMaterial;
    }
    
    part def VisionSystem {
        attribute resolution : Integer[2];
        attribute frameRate : FrequencyValue;
        attribute detectionAccuracy : LengthValue;
        
        port dataOutput : RobotControlPort;
        port power : PowerSupplyPort;
        
        perform action detectComponent : DetectAndLocate;
    }
    
    part def SafetySystem {
        attribute emergencyStopActive : Boolean;
        attribute lightCurtainStatus : Boolean;
        attribute safetyZoneViolation : Boolean;
        
        port safetyMonitor : SafetyPort;
        port power : PowerSupplyPort;
        
        perform action monitorSafety : MonitorSafetyConditions;
    }
    
    part def PowerDistributionUnit {
        attribute inputVoltage : ElectricPotentialValue;
        attribute outputVoltage : ElectricPotentialValue;
        attribute maxCurrent : ElectricCurrentValue;
        
        port mainInput : PowerSupplyPort;
        port robotOutput : PowerSupplyPort;
        port conveyorOutput : PowerSupplyPort;
        port visionOutput : PowerSupplyPort;
        port safetyOutput : PowerSupplyPort;
        port controllerOutput : PowerSupplyPort;
    }
    
    action def LoadProgram {
        in programPath : String;
        out loaded : Boolean;
    }
    
    action def ValidateProgram {
        in programPath : String;
        out valid : Boolean;
    }
    
    action def ExecuteMotion {
        out complete : Boolean;
    }
    
    action def ExecuteRobotProgram {
        in programPath : String;
        out executionStatus : Boolean;
        
        first start;
        then action loadProg : LoadProgram {
            in programPath = programPath;
        }
        then action validateProg : ValidateProgram {
            in programPath = programPath;
        }
        then action executeMotionAction : ExecuteMotion;
        then done;
    }
    
    action def ActivateBelt {
        in speed : SpeedValue;
        out activated : Boolean;
    }
    
    action def MonitorPosition {
        out currentPosition : PositionCoordinate;
    }
    
    action def StopAtTarget {
        in targetPosition : PositionCoordinate;
        out stopped : Boolean;
    }
    
    action def TransportMaterial {
        in speed : SpeedValue;
        out position : PositionCoordinate;
        
        first start;
        then action activateBeltAction : ActivateBelt {
            in speed = speed;
        }
        then action monitorPositionAction : MonitorPosition;
        then action stopAtTargetAction : StopAtTarget {
            in targetPosition = monitorPositionAction.currentPosition;
        }
        then done;
    }
    
    action def CaptureImage {
        out imageData : String;
    }
    
    action def ProcessImage {
        in imageData : String;
        out processedData : String;
    }
    
    action def CalculatePose {
        in processedData : String;
        out componentPosition : PositionCoordinate[3];
        out componentOrientation : AngleValue[3];
    }
    
    action def DetectAndLocate {
        out componentPosition : PositionCoordinate[3];
        out componentOrientation : AngleValue[3];
        out detectionConfidence : Real;
        
        first start;
        then action captureImageAction : CaptureImage;
        then action processImageAction : ProcessImage {
            in imageData = captureImageAction.imageData;
        }
        then action calculatePoseAction : CalculatePose {
            in processedData = processImageAction.processedData;
        }
        then done;
    }
    
    action def CheckEmergencyStop {
        out stopActive : Boolean;
    }
    
    action def CheckLightCurtains {
        out curtainOK : Boolean;
    }
    
    action def CheckSafetyZones {
        out zonesOK : Boolean;
    }
    
    action def MonitorSafetyConditions {
        in zoneStatus : Boolean[*];
        out safetyOK : Boolean;
        
        first start;
        then action checkEmergencyStopAction : CheckEmergencyStop;
        then action checkLightCurtainsAction : CheckLightCurtains;
        then action checkSafetyZonesAction : CheckSafetyZones;
        then done;
    }
    
    action def WaitForComponent {
        out componentReady : Boolean;
    }
    
    action def MoveRobotToPosition {
        in targetPosition : PositionCoordinate[3];
        out positionReached : Boolean;
    }
    
    action def CloseGripper {
        out gripped : Boolean;
    }
    
    action def OpenGripper {
        out released : Boolean;
    }
    
    action def PickAndPlaceOperation {
        in pickupLocation : PositionCoordinate[3];
        in placeLocation : PositionCoordinate[3];
        in component : Component;
        out operationComplete : Boolean;
        
        first start;
        then action waitForComponentAction : WaitForComponent;
        then action visionLocate : DetectAndLocate;
        then action moveToPickup : MoveRobotToPosition {
            in targetPosition = pickupLocation;
        }
        then action activateGripper : CloseGripper;
        then action moveToPlace : MoveRobotToPosition {
            in targetPosition = placeLocation;
        }
        then action releaseGripper : OpenGripper;
        then action returnHome : MoveRobotToPosition {
            in targetPosition = (0.0 [SI::mm], 500.0 [SI::mm], 300.0 [SI::mm]);
        }
        then done;
    }
    
    state def RobotCellStateMachine {
        entry; then initialization;
        
        state initialization {
            entry assign currentMode = RobotOperationalMode::manual;
        }
        
        transition init_to_ready
            first initialization
            then ready;
        
        state ready {
            entry assign currentMode = RobotOperationalMode::automatic;
        }
        
        transition ready_to_operating
            first ready
            accept StartProduction
            then operating;
        
        state operating;
        
        transition operating_to_ready
            first operating
            accept StopProduction
            then ready;
        
        transition any_to_emergency
            first initialization, ready, operating, maintenance
            accept EmergencyStopActivated
            then emergencyStop;
        
        state emergencyStop {
            entry assign currentMode = RobotOperationalMode::emergency_stop;
        }
        
        transition emergency_to_maintenance
            first emergencyStop
            accept EmergencyCleared
            then maintenance;
        
        state maintenance {
            entry assign currentMode = RobotOperationalMode::maintenance;
        }
        
        transition maintenance_to_ready
            first maintenance
            accept MaintenanceComplete
            then ready;
        
        attribute currentMode : RobotOperationalMode;
    }
    
    part def ABB_ManufacturingCell {
        attribute cellIdentifier : String;
        attribute productionRate : Real;
        attribute uptime : Real;
        
        part controller : RobotController {
            attribute :>> cycleTime = 3.5 [SI::s];
            attribute :>> processingCapacity = 1000.0;
        }
        
        part robot : IRB6700Robot {
            attribute :>> reachDistance = 2650.0 [SI::mm];
            attribute :>> maxPayload = 200.0 [SI::kg];
            attribute :>> repeatability = 0.05 [SI::mm];
        }
        
        part conveyor : ConveyorSystem {
            attribute :>> beltLength = 3000.0 [SI::mm];
            attribute :>> beltWidth = 600.0 [SI::mm];
            attribute :>> transportSpeed = 0.5;
        }
        
        part vision : VisionSystem {
            attribute :>> resolution = (1920, 1080);
            attribute :>> frameRate = 60.0 [SI::Hz];
            attribute :>> detectionAccuracy = 0.1 [SI::mm];
        }
        
        part safety : SafetySystem {
            attribute :>> emergencyStopActive = false;
            attribute :>> lightCurtainStatus = true;
            attribute :>> safetyZoneViolation = false;
        }
        
        part powerDistribution : PowerDistributionUnit {
            attribute :>> inputVoltage = 400.0 [SI::V];
            attribute :>> outputVoltage = 400.0 [SI::V];
            attribute :>> maxCurrent = 100.0 [SI::A];
        }
        
        connection controllerToRobot connect controller.mainControl to robot.robotControl;
        connection controllerToConveyor connect controller.mainControl to conveyor.control;
        connection visionToController connect vision.dataOutput to controller.mainControl;
        connection safetyToController connect safety.safetyMonitor to controller.safety;
        connection safetyToRobot connect safety.safetyMonitor to robot.safetyInterface;
        
        connection powerToController connect powerDistribution.controllerOutput to controller.power;
        connection powerToRobot connect powerDistribution.robotOutput to robot.powerInput;
        connection powerToConveyor connect powerDistribution.conveyorOutput to conveyor.power;
        connection powerToVision connect powerDistribution.visionOutput to vision.power;
        connection powerToSafety connect powerDistribution.safetyOutput to safety.power;
        
        perform action cellOperation : PickAndPlaceOperation[*] ordered;
        exhibit state cellBehavior : RobotCellStateMachine;
    }
    
    requirement <'REQ-ABB-001'> primaryFunction {
        doc /* The ABB Manufacturing Cell shall autonomously pick components from an 
             * incoming conveyor system using vision-guided robotic manipulation and 
             * precisely place them at designated assembly locations with high 
             * repeatability and throughput. */
        subject cell : ABB_ManufacturingCell;
    }
    
    requirement <'REQ-ABB-002'> payloadCapability {
        doc /* The robot shall handle components with mass up to 200 kg. */
        subject robot :>> abbCell.robot;
        assert constraint {
            robot.maxPayload >= 200.0 [SI::kg]
        }
    }
    
    requirement <'REQ-ABB-003'> positioningAccuracy {
        doc /* The robot shall achieve positioning repeatability of 0.05 mm or better. */
        subject robot :>> abbCell.robot;
        assert constraint {
            robot.repeatability <= 0.05 [SI::mm]
        }
    }
    
    requirement <'REQ-ABB-004'> cycleTimePerformance {
        doc /* The system shall complete a pick and place cycle within 4 seconds. */
        subject controller :>> abbCell.controller;
        assert constraint {
            controller.cycleTime <= 4.0 [SI::s]
        }
    }
    
    requirement <'REQ-ABB-005'> visionAccuracy {
        doc /* The vision system shall detect component position with accuracy of 0.2 mm or better. */
        subject vision :>> abbCell.vision;
        assert constraint {
            vision.detectionAccuracy <= 0.2 [SI::mm]
        }
    }
    
    requirement <'REQ-ABB-006'> safetyCompliance {
        doc /* The system shall incorporate safety monitoring with emergency stop capability 
             * and light curtain protection in accordance with ISO 10218 standards. */
        subject safety :>> abbCell.safety;
    }
    
    part abbCell : ABB_ManufacturingCell {
        attribute :>> cellIdentifier = "ABB-CELL-001";
        attribute :>> productionRate = 1000.0;
        attribute :>> uptime = 0.95;
    }
    
    satisfy primaryFunction by abbCell;
    satisfy payloadCapability by abbCell.robot;
    satisfy positioningAccuracy by abbCell.robot;
    satisfy cycleTimePerformance by abbCell.controller;
    satisfy visionAccuracy by abbCell.vision;
    satisfy safetyCompliance by abbCell.safety;
}
