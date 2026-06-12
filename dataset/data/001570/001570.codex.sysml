package SelfReconfiguringModularRobotSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def Count :> Integer;
    attribute def Identifier :> String;

    attribute def Length_m :> Real {
        unit = "m";
    }

    attribute def Mass_kg :> Real {
        unit = "kg";
    }

    attribute def Time_s :> Real {
        unit = "s";
    }

    attribute def Energy_J :> Real {
        unit = "J";
    }

    attribute def Power_W :> Real {
        unit = "W";
    }

    attribute def Voltage_V :> Real {
        unit = "V";
    }

    attribute def Current_A :> Real {
        unit = "A";
    }

    attribute def Force_N :> Real {
        unit = "N";
    }

    attribute def Torque_Nm :> Real {
        unit = "N*m";
    }

    attribute def Speed_mps :> Real {
        unit = "m/s";
    }

    attribute def Angle_deg :> Real {
        unit = "deg";
    }

    enum def TerrainClass {
        enum flatFloor;
        enum narrowGap;
        enum verticalStep;
        enum rubbleField;
        enum pipeInterior;
        enum unknown;
    }

    enum def RobotMorphology {
        enum snake;
        enum quadruped;
        enum rollingLoop;
        enum bridge;
        enum manipulatorArm;
        enum cluster;
    }

    enum def ModuleHealthState {
        enum nominal;
        enum degraded;
        enum failed;
        enum isolated;
    }

    enum def DockingState {
        enum undocked;
        enum aligning;
        enum latched;
        enum powerCoupled;
        enum dataCoupled;
        enum verified;
    }

    enum def MissionPhase {
        enum idle;
        enum survey;
        enum configure;
        enum traverse;
        enum inspect;
        enum manipulate;
        enum recover;
        enum returnHome;
        enum safeStop;
    }

    item def EnergyPacket {
        attribute voltage : Voltage_V;
        attribute current : Current_A;
        attribute power : Power_W;
    }

    item def ControlCommand {
        attribute commandId : Identifier;
        attribute targetModule : Identifier;
        attribute requestedMorphology : RobotMorphology;
        attribute priority : Integer;
    }

    item def DockingCommand {
        attribute sourceModule : Identifier;
        attribute targetModule : Identifier;
        attribute desiredFace : Integer;
        attribute latchForce : Force_N;
    }

    item def ModuleStatus {
        attribute moduleId : Identifier;
        attribute health : ModuleHealthState;
        attribute batteryStateOfCharge : Percent;
        attribute jointAngle : Angle_deg;
        attribute dockState : DockingState;
    }

    item def TerrainMap {
        attribute mapId : Identifier;
        attribute terrainClass : TerrainClass;
        attribute obstacleHeight : Length_m;
        attribute gapWidth : Length_m;
        attribute traversableConfidence : Percent;
    }

    item def PayloadSample {
        attribute sampleId : Identifier;
        attribute mass : Mass_kg;
        attribute captured : Boolean;
    }

    item def InspectionData {
        attribute targetId : Identifier;
        attribute imageQuality : Percent;
        attribute distanceToTarget : Length_m;
        attribute defectProbability : Percent;
    }

    port def PowerPort {
        out item powerOut : EnergyPacket;
        in item powerIn : EnergyPacket;
    }

    port def DataPort {
        out item statusOut : ModuleStatus;
        in item commandIn : ControlCommand;
        out item terrainOut : TerrainMap;
        out item inspectionOut : InspectionData;
    }

    port def DockPort {
        in item dockCommand : DockingCommand;
        out item dockStatus : ModuleStatus;
    }

    port def MechanicalLoadPort {
        in item appliedTorque : Torque_Nm;
        out item reactionForce : Force_N;
    }

    port def PayloadPort {
        in item sampleRequest : ControlCommand;
        out item sampleOut : PayloadSample;
    }

    port def OperatorCommandPort {
        in item missionCommand : ControlCommand;
        out item missionStatus : ModuleStatus;
        out item missionMap : TerrainMap;
        out item missionInspection : InspectionData;
    }

    action def SenseTerrain {
        in item priorMap : TerrainMap;
        out item updatedMap : TerrainMap;
    }

    action def SelectMorphology {
        in item terrain : TerrainMap;
        in attribute availableModules : Count;
        out attribute morphology : RobotMorphology;
    }

    action def ExecuteReconfiguration {
        in attribute morphology : RobotMorphology;
        in item command : DockingCommand;
        out attribute completed : Boolean;
    }

    action def TraverseTerrain {
        in attribute morphology : RobotMorphology;
        in item terrain : TerrainMap;
        out attribute distanceAdvanced : Length_m;
        out attribute energyUsed : Energy_J;
    }

    action def InspectTarget {
        in item terrain : TerrainMap;
        out item inspection : InspectionData;
    }

    action def CapturePayload {
        in item request : ControlCommand;
        out item sample : PayloadSample;
    }

    action def IsolateFailedModule {
        in item failedStatus : ModuleStatus;
        out attribute isolated : Boolean;
    }

    part def ElectroMechanicalDock {
        attribute latchCapacity : Force_N = 120.0;
        attribute alignmentTolerance : Length_m = 0.003;
        attribute maxDockTime : Time_s = 8.0;
        attribute state : DockingState = DockingState::undocked;

        port dockA : DockPort;
        port dockB : DockPort;
        port powerCoupler : PowerPort;
        port dataCoupler : DataPort;
    }

    part def RevoluteJoint {
        attribute maxTorque : Torque_Nm = 4.5;
        attribute maxSpeed : Angle_deg = 180.0;
        attribute rangeMin : Angle_deg = -180.0;
        attribute rangeMax : Angle_deg = 180.0;
        attribute commandedAngle : Angle_deg = 0.0;
        attribute measuredAngle : Angle_deg = 0.0;

        port load : MechanicalLoadPort;
        port command : DataPort;
        port power : PowerPort;
    }

    part def BatteryPack {
        attribute nominalVoltage : Voltage_V = 24.0;
        attribute capacity : Energy_J = 86400.0;
        attribute stateOfCharge : Percent = 100.0;
        attribute maxContinuousPower : Power_W = 60.0;

        port powerBus : PowerPort;
    }

    part def ModuleController {
        attribute moduleId : Identifier;
        attribute processorLoad : Percent = 0.0;
        attribute health : ModuleHealthState = ModuleHealthState::nominal;
        attribute localClock : Time_s = 0.0;

        port network : DataPort;
        port actuatorCommand : DataPort;
        port dockCommand : DockPort;
    }

    part def SensorSuite {
        attribute lidarRange : Length_m = 8.0;
        attribute cameraFieldOfView : Angle_deg = 120.0;
        attribute imuUpdatePeriod : Time_s = 0.01;
        attribute proximityRange : Length_m = 0.2;

        port data : DataPort;
        perform action sense : SenseTerrain;
    }

    part def ReconfigurableModule {
        attribute moduleId : Identifier;
        attribute mass : Mass_kg = 1.8;
        attribute bodyLength : Length_m = 0.18;
        attribute bodyWidth : Length_m = 0.09;
        attribute bodyHeight : Length_m = 0.09;
        attribute health : ModuleHealthState = ModuleHealthState::nominal;
        attribute dockState : DockingState = DockingState::undocked;

        port powerPort : PowerPort;
        port dataPort : DataPort;
        port northDock : DockPort;
        port southDock : DockPort;
        port eastDock : DockPort;
        port westDock : DockPort;
        port loadPort : MechanicalLoadPort;

        part battery : BatteryPack;
        part controller : ModuleController;
        part joint : RevoluteJoint;
        part sensor : SensorSuite;
        part northLatch : ElectroMechanicalDock;
        part southLatch : ElectroMechanicalDock;
        part eastLatch : ElectroMechanicalDock;
        part westLatch : ElectroMechanicalDock;

        connect battery.powerBus to powerPort;
        connect battery.powerBus to joint.power;
        connect controller.network to dataPort;
        connect controller.actuatorCommand to joint.command;
        connect sensor.data to dataPort;
        connect joint.load to loadPort;
        connect northLatch.dockA to northDock;
        connect southLatch.dockA to southDock;
        connect eastLatch.dockA to eastDock;
        connect westLatch.dockA to westDock;
    }

    part def EndEffectorModule :> ReconfigurableModule {
        attribute gripperForce : Force_N = 35.0;
        attribute payloadCapacity : Mass_kg = 0.75;

        port payload : PayloadPort;

        perform action capture : CapturePayload;
    }

    part def CommunicationHub {
        attribute radioRange : Length_m = 150.0;
        attribute dataRateMbps : Real = 12.0;
        attribute packetLoss : Percent = 0.0;

        port operatorLink : OperatorCommandPort;
        port robotNetwork : DataPort;
    }

    part def MorphologyPlanner {
        attribute selectedMorphology : RobotMorphology = RobotMorphology::snake;
        attribute minimumUsableModules : Count = 6;
        attribute reconfigurationTimeout : Time_s = 45.0;

        port terrainInput : DataPort;
        port commandOutput : DataPort;
        port dockOutput : DockPort;

        perform action select : SelectMorphology;
        perform action reconfigure : ExecuteReconfiguration;
    }

    part def MissionSupervisor {
        attribute missionPhase : MissionPhase = MissionPhase::idle;
        attribute primaryTaskComplete : Boolean = false;
        attribute requiredInspectionConfidence : Percent = 85.0;
        attribute maximumMissionTime : Time_s = 1800.0;
        attribute minimumReturnEnergy : Energy_J = 25000.0;

        port operator : OperatorCommandPort;
        port network : DataPort;
        port payload : PayloadPort;

        perform action inspect : InspectTarget;
        perform action traverse : TraverseTerrain;
    }

    part def SelfReconfiguringModularRobot {
        attribute moduleCount : Count = 16;
        attribute availableModules : Count = 16;
        attribute currentMorphology : RobotMorphology = RobotMorphology::snake;
        attribute maximumSpeedSnake : Speed_mps = 0.18;
        attribute maximumSpeedQuadruped : Speed_mps = 0.42;
        attribute maximumBridgeSpan : Length_m = 1.2;
        attribute maximumStepHeight : Length_m = 0.55;
        attribute totalMass : Mass_kg = 30.0;

        port externalCommand : OperatorCommandPort;
        port payloadInterface : PayloadPort;

        part supervisor : MissionSupervisor;
        part planner : MorphologyPlanner;
        part comms : CommunicationHub;

        part module01 : ReconfigurableModule {
            attribute moduleId = "M01";
        }
        part module02 : ReconfigurableModule {
            attribute moduleId = "M02";
        }
        part module03 : ReconfigurableModule {
            attribute moduleId = "M03";
        }
        part module04 : ReconfigurableModule {
            attribute moduleId = "M04";
        }
        part module05 : ReconfigurableModule {
            attribute moduleId = "M05";
        }
        part module06 : ReconfigurableModule {
            attribute moduleId = "M06";
        }
        part module07 : ReconfigurableModule {
            attribute moduleId = "M07";
        }
        part module08 : ReconfigurableModule {
            attribute moduleId = "M08";
        }
        part module09 : ReconfigurableModule {
            attribute moduleId = "M09";
        }
        part module10 : ReconfigurableModule {
            attribute moduleId = "M10";
        }
        part module11 : ReconfigurableModule {
            attribute moduleId = "M11";
        }
        part module12 : ReconfigurableModule {
            attribute moduleId = "M12";
        }
        part module13 : ReconfigurableModule {
            attribute moduleId = "M13";
        }
        part module14 : ReconfigurableModule {
            attribute moduleId = "M14";
        }
        part manipulator01 : EndEffectorModule {
            attribute moduleId = "E01";
        }
        part manipulator02 : EndEffectorModule {
            attribute moduleId = "E02";
        }

        connect externalCommand to comms.operatorLink;
        connect comms.robotNetwork to supervisor.network;
        connect supervisor.network to planner.terrainInput;
        connect supervisor.payload to payloadInterface;
        connect manipulator01.payload to payloadInterface;

        connect module01.southDock to module02.northDock;
        connect module02.southDock to module03.northDock;
        connect module03.southDock to module04.northDock;
        connect module04.southDock to module05.northDock;
        connect module05.southDock to module06.northDock;
        connect module06.southDock to module07.northDock;
        connect module07.southDock to module08.northDock;
        connect module08.southDock to module09.northDock;
        connect module09.southDock to module10.northDock;
        connect module10.southDock to module11.northDock;
        connect module11.southDock to module12.northDock;
        connect module12.southDock to module13.northDock;
        connect module13.southDock to module14.northDock;
        connect module14.southDock to manipulator01.northDock;
        connect manipulator01.southDock to manipulator02.northDock;

        connect module01.dataPort to comms.robotNetwork;
        connect module02.dataPort to comms.robotNetwork;
        connect module03.dataPort to comms.robotNetwork;
        connect module04.dataPort to comms.robotNetwork;
        connect module05.dataPort to comms.robotNetwork;
        connect module06.dataPort to comms.robotNetwork;
        connect module07.dataPort to comms.robotNetwork;
        connect module08.dataPort to comms.robotNetwork;
        connect module09.dataPort to comms.robotNetwork;
        connect module10.dataPort to comms.robotNetwork;
        connect module11.dataPort to comms.robotNetwork;
        connect module12.dataPort to comms.robotNetwork;
        connect module13.dataPort to comms.robotNetwork;
        connect module14.dataPort to comms.robotNetwork;
        connect manipulator01.dataPort to comms.robotNetwork;
        connect manipulator02.dataPort to comms.robotNetwork;
    }

    part def OperatorStation {
        attribute operatorId : Identifier = "OPS-1";
        attribute commandedMission : MissionPhase = MissionPhase::survey;

        port robotLink : OperatorCommandPort;
    }

    part def PrimaryTaskEnvironment {
        attribute missionAreaLength : Length_m = 30.0;
        attribute missionAreaWidth : Length_m = 12.0;
        attribute pipeDiameter : Length_m = 0.55;
        attribute rubbleStepHeight : Length_m = 0.45;
        attribute inspectionTargetDistance : Length_m = 22.0;
        attribute payloadMass : Mass_kg = 0.45;
        attribute expectedTerrain : TerrainClass = TerrainClass::rubbleField;
    }

    part roboticSystem {
        part operatorStation : OperatorStation;
        part robot : SelfReconfiguringModularRobot;
        part environment : PrimaryTaskEnvironment;

        connect operatorStation.robotLink to robot.externalCommand;
    }

    state def MissionStateMachine {
        entry action initialize;

        state idle;
        state survey;
        state configureForTerrain;
        state traverseObstacle;
        state inspectAsset;
        state collectPayload;
        state recoverFault;
        state returnHome;
        state complete;
        state emergencyStop;

        transition first idle;

        transition idle_to_survey
            first idle
            then survey;

        transition survey_to_configure
            first survey
            then configureForTerrain
            if roboticSystem.robot.supervisor.missionPhase == MissionPhase::survey;

        transition configure_to_traverse
            first configureForTerrain
            then traverseObstacle
            if roboticSystem.robot.availableModules >= roboticSystem.robot.planner.minimumUsableModules;

        transition traverse_to_inspect
            first traverseObstacle
            then inspectAsset
            if roboticSystem.robot.currentMorphology == RobotMorphology::quadruped or roboticSystem.robot.currentMorphology == RobotMorphology::snake;

        transition inspect_to_collect
            first inspectAsset
            then collectPayload
            if roboticSystem.robot.supervisor.primaryTaskComplete == false;

        transition collect_to_return
            first collectPayload
            then returnHome;

        transition return_to_complete
            first returnHome
            then complete;

        transition any_fault_to_recover
            first survey
            then recoverFault
            if roboticSystem.robot.module01.health == ModuleHealthState::failed;

        transition recover_to_configure
            first recoverFault
            then configureForTerrain
            if roboticSystem.robot.availableModules >= roboticSystem.robot.planner.minimumUsableModules;

        transition low_energy_to_return
            first traverseObstacle
            then returnHome
            if roboticSystem.robot.module01.battery.stateOfCharge < 25.0;

        transition emergency
            first inspectAsset
            then emergencyStop
            if roboticSystem.robot.availableModules < roboticSystem.robot.planner.minimumUsableModules;
    }

    requirement def PrimaryTaskRequirement {
        subject robot : SelfReconfiguringModularRobot;
        attribute requiredConfidence : Percent = 85.0;

        require constraint {
            robot.supervisor.primaryTaskComplete == true
        }

        doc /* The robotic system shall perform inspection and payload retrieval in obstructed terrain using a self-reconfiguring modular robot as the primary task mechanism. */
    }

    requirement def ReconfigurationRequirement {
        subject robot : SelfReconfiguringModularRobot;
        attribute maximumAllowedTime : Time_s = 45.0;

        require constraint {
            robot.planner.reconfigurationTimeout <= maximumAllowedTime
        }

        doc /* The robot shall autonomously change morphology among snake, quadruped, bridge, and manipulator-arm configurations based on sensed terrain and task needs. */
    }

    requirement def ModularContinuityRequirement {
        subject robot : SelfReconfiguringModularRobot;
        attribute minimumModules : Count = 6;

        require constraint {
            robot.availableModules >= minimumModules
        }

        doc /* The robot shall continue mission execution after isolating any single failed module when at least six modules remain available. */
    }

    requirement def TraversalRequirement {
        subject robot : SelfReconfiguringModularRobot;
        attribute requiredStepHeight : Length_m = 0.45;
        attribute requiredGapWidth : Length_m = 1.0;

        require constraint {
            robot.maximumStepHeight >= requiredStepHeight and robot.maximumBridgeSpan >= requiredGapWidth
        }

        doc /* The robot shall traverse rubble, vertical steps, and narrow gaps by selecting a morphology matched to the terrain class. */
    }

    requirement def DockingRequirement {
        subject robot : SelfReconfiguringModularRobot;
        attribute requiredLatchCapacity : Force_N = 100.0;
        attribute requiredTolerance : Length_m = 0.005;

        require constraint {
            robot.module01.northLatch.latchCapacity >= requiredLatchCapacity and
            robot.module01.northLatch.alignmentTolerance <= requiredTolerance
        }

        doc /* Each module docking interface shall mechanically latch, transfer power, exchange data, and verify the connection before load-bearing motion. */
    }

    requirement def EnergyRequirement {
        subject robot : SelfReconfiguringModularRobot;
        attribute requiredReserve : Energy_J = 25000.0;

        require constraint {
            robot.supervisor.minimumReturnEnergy >= requiredReserve
        }

        doc /* The robot shall preserve enough energy reserve to reconfigure and return to the operator station after completing the primary task. */
    }

    requirement def PayloadRequirement {
        subject robot : SelfReconfiguringModularRobot;
        attribute requiredPayloadMass : Mass_kg = 0.45;

        require constraint {
            robot.manipulator01.payloadCapacity >= requiredPayloadMass
        }

        doc /* The robot shall form a manipulator-arm morphology and retrieve a payload sample of at least 0.45 kg. */
    }

    requirement def OperatorCommunicationRequirement {
        subject robot : SelfReconfiguringModularRobot;
        attribute requiredRange : Length_m = 100.0;

        require constraint {
            robot.comms.radioRange >= requiredRange
        }

        doc /* The robotic system shall report mission phase, module health, terrain map, and inspection data to the operator station throughout the mission. */
    }

    satisfy PrimaryTaskRequirement by roboticSystem.robot;
    satisfy ReconfigurationRequirement by roboticSystem.robot.planner;
    satisfy ModularContinuityRequirement by roboticSystem.robot;
    satisfy TraversalRequirement by roboticSystem.robot;
    satisfy DockingRequirement by roboticSystem.robot.module01.northLatch;
    satisfy EnergyRequirement by roboticSystem.robot.supervisor;
    satisfy PayloadRequirement by roboticSystem.robot.manipulator01;
    satisfy OperatorCommunicationRequirement by roboticSystem.robot.comms;

    action missionExecution {
        first start;
        then senseTerrain : SenseTerrain {
            in priorMap = TerrainMap {
                attribute mapId = "initial";
                attribute terrainClass = TerrainClass::unknown;
                attribute obstacleHeight = 0.0;
                attribute gapWidth = 0.0;
                attribute traversableConfidence = 0.0;
            }
        }
        then chooseMorphology : SelectMorphology {
            in terrain = senseTerrain.updatedMap;
            in availableModules = roboticSystem.robot.availableModules;
        }
        then reconfigure : ExecuteReconfiguration {
            in morphology = chooseMorphology.morphology;
            in command = DockingCommand {
                attribute sourceModule = "M01";
                attribute targetModule = "M02";
                attribute desiredFace = 2;
                attribute latchForce = 110.0;
            }
        }
        then traverse : TraverseTerrain {
            in morphology = chooseMorphology.morphology;
            in terrain = senseTerrain.updatedMap;
        }
        then inspect : InspectTarget {
            in terrain = senseTerrain.updatedMap;
        }
        then capture : CapturePayload {
            in request = ControlCommand {
                attribute commandId = "CAPTURE-SAMPLE";
                attribute targetModule = "E01";
                attribute requestedMorphology = RobotMorphology::manipulatorArm;
                attribute priority = 10;
            }
        }
        then done;
    }

}