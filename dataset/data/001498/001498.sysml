package MicroboticsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MicrobotID;
    attribute def SwarmCommand;
    attribute def TaskStatus;
    attribute def EnvironmentState;
    
    attribute def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }
    
    attribute def SensorData {
        attribute temperature : ThermodynamicTemperatureValue;
        attribute obstacleDistance : LengthValue;
        attribute targetDetected : Boolean;
    }
    
    attribute def MotionCommand {
        attribute velocity : SpeedValue;
        attribute direction : Position3D;
    }
    
    port def SensorPort {
        out data : SensorData;
    }
    
    port def CommunicationPort {
        in commands : SwarmCommand;
        out status : TaskStatus;
        inout position : Position3D;
    }
    
    port def ActuatorPort {
        in motion : MotionCommand;
    }
    
    port def PowerPort {
        attribute voltage : VoltageValue;
        attribute current : ElectricCurrentValue;
    }
    
    part def SensorModule {
        port sensorOut : SensorPort;
        port powerIn : PowerPort;
        
        action def AcquireSensorData {
            out environmentData : SensorData;
        }
    }
    
    part def LocomotionModule {
        port actuatorIn : ActuatorPort;
        port powerIn : PowerPort;
        attribute maxSpeed : SpeedValue;
        
        action def ExecuteMotion {
            in command : MotionCommand;
            in currentPosition : Position3D;
            out newPosition : Position3D;
        }
    }
    
    part def CommunicationModule {
        port commPort : CommunicationPort;
        port powerIn : PowerPort;
        attribute transmitPower : PowerValue;
        
        action def TransmitPosition {
            in position : Position3D;
            out transmitted : Boolean;
        }
        
        action def ReceiveCommand {
            out command : SwarmCommand;
        }
    }
    
    part def PowerModule {
        port powerOut : PowerPort;
        attribute batteryCapacity : EnergyValue;
        attribute currentCharge : Real;
        
        action def SupplyPower {
            in demand : PowerValue;
            out available : Boolean;
        }
    }
    
    part def ControlProcessor {
        action def ProcessSensorInput {
            in sensorData : SensorData;
            out navigationDecision : MotionCommand;
        }
        
        action def CoordinateWithSwarm {
            in localPosition : Position3D;
            in neighborPositions : Position3D[*];
            out formationCommand : MotionCommand;
        }
        
        action def ExecuteTask {
            in taskCommand : SwarmCommand;
            in environmentData : SensorData;
            out actionSequence : MotionCommand[*];
        }
    }
    
    part def Microbot {
        attribute id : MicrobotID;
        attribute currentPosition : Position3D;
        attribute operationalStatus : TaskStatus;
        
        port sensorInterface : SensorPort;
        port commInterface : CommunicationPort;
        port actuatorInterface : ActuatorPort;
        
        part sensors : SensorModule;
        part locomotion : LocomotionModule;
        part communication : CommunicationModule;
        part power : PowerModule;
        part processor : ControlProcessor;
        
        connect sensors.sensorOut to sensorInterface;
        connect communication.commPort to commInterface;
        connect locomotion.actuatorIn to actuatorInterface;
        connect power.powerOut to sensors.powerIn;
        connect power.powerOut to locomotion.powerIn;
        connect power.powerOut to communication.powerIn;
        
        perform action operateMicrobot : MicrobotOperation;
    }
    
    action def MicrobotOperation {
        in initialPosition : Position3D;
        in missionCommand : SwarmCommand;
        out finalPosition : Position3D;
        out missionComplete : Boolean;
        
        first start;
        then merge operationCycle;
        
        action sense : SensorModule::AcquireSensorData {
            out environmentData : SensorData;
        }
        
        then action processEnvironment : ControlProcessor::ProcessSensorInput {
            in sensorData = sense.environmentData;
            out navigationDecision : MotionCommand;
        }
        
        then action communicate : CommunicationModule::TransmitPosition {
            in position = initialPosition;
            out transmitted : Boolean;
        }
        
        then action receiveOrders : CommunicationModule::ReceiveCommand {
            out command : SwarmCommand;
        }
        
        then decide;
            if receiveOrders.command == missionCommand then executeMovement;
            else operationCycle;
        
        action executeMovement : LocomotionModule::ExecuteMotion {
            in command = processEnvironment.navigationDecision;
            in currentPosition = initialPosition;
            out newPosition : Position3D;
        }
        
        then assign finalPosition := executeMovement.newPosition;
        then operationCycle;
    }
    
    part def SwarmCoordinator {
        attribute swarmSize : Integer;
        attribute activeMembers : Integer;
        attribute missionObjective : String;
        
        action def AggregateSwarmState {
            in individualPositions : Position3D[*];
            in individualStatus : TaskStatus[*];
            out swarmCenterOfMass : Position3D;
            out swarmHealth : Real;
        }
        
        action def GenerateSwarmCommands {
            in objective : String;
            in swarmState : Position3D;
            out commands : SwarmCommand[*];
        }
        
        action def MonitorSwarmPerformance {
            in swarmHealth : Real;
            out adjustmentNeeded : Boolean;
        }
    }
    
    action def SwarmCollectiveOperation {
        in targetArea : Position3D;
        in numberOfBots : Integer;
        in missionType : String;
        out areaCovered : Boolean;
        out taskCompleted : Boolean;
        
        first start;
        
        action initializeSwarm {
            in swarmSize : Integer = numberOfBots;
            out initialPositions : Position3D[*];
        }
        
        then merge coordinationLoop;
        
        action aggregateState : SwarmCoordinator::AggregateSwarmState {
            in individualPositions : Position3D[*];
            in individualStatus : TaskStatus[*];
            out swarmCenterOfMass : Position3D;
            out swarmHealth : Real;
        }
        
        then action generateCommands : SwarmCoordinator::GenerateSwarmCommands {
            in objective : String = missionType;
            in swarmState : Position3D = aggregateState.swarmCenterOfMass;
            out commands : SwarmCommand[*];
        }
        
        then action monitorPerformance : SwarmCoordinator::MonitorSwarmPerformance {
            in swarmHealth : Real = aggregateState.swarmHealth;
            out adjustmentNeeded : Boolean;
        }
        
        then for botCommand in generateCommands.commands {
            perform action individualOperation : MicrobotOperation {
                in initialPosition : Position3D;
                in missionCommand : SwarmCommand = botCommand;
                out finalPosition : Position3D;
                out missionComplete : Boolean;
            }
        }
        
        then action evaluateProgress {
            in completedPositions : Position3D[*];
            in target : Position3D = targetArea;
            out coverageAchieved : Boolean;
        }
        
        then decide;
            if evaluateProgress.coverageAchieved then completeMission;
            if not evaluateProgress.coverageAchieved then coordinationLoop;
        
        action completeMission {
            then assign areaCovered := true;
            then assign taskCompleted := true;
        }
        
        then done;
    }
    
    part def MicroboticsSystem {
        doc /* 
        A microbotics system composed of multiple miniature autonomous robots 
        that collectively perform complex tasks through distributed sensing, 
        coordinated movement, and inter-robot communication. The system's 
        primary function is to deploy a swarm of microbots to autonomously 
        explore, map, and manipulate objects in environments inaccessible 
        to larger systems, achieving objectives through emergent collective 
        behavior and adaptive task allocation.
        */
        
        attribute systemID : String;
        attribute operationalMode : String;
        attribute deploymentArea : Position3D;
        
        part coordinator : SwarmCoordinator {
            attribute swarmSize = 100;
            attribute activeMembers = 100;
            attribute missionObjective = "area_coverage_and_mapping";
        }
        
        part microbot[100] : Microbot {
            attribute currentPosition : Position3D;
            attribute operationalStatus : TaskStatus;
        }
        
        perform action primaryMission : SwarmCollectiveOperation {
            in targetArea : Position3D = deploymentArea;
            in numberOfBots : Integer = 100;
            in missionType : String = coordinator.missionObjective;
            out areaCovered : Boolean;
            out taskCompleted : Boolean;
        }
    }
    
    part microboticsSystem : MicroboticsSystem;
    
    requirement def SwarmCoordinationRequirement {
        doc /* 
        The microbotics system shall coordinate multiple microbots to 
        collectively perform tasks through distributed sensing, real-time 
        communication, and synchronized movement with minimum 90% swarm 
        operational availability.
        */
        
        require constraint minimumActiveSwarm {
            microboticsSystem.coordinator.activeMembers >= 
                0.9 * microboticsSystem.coordinator.swarmSize
        }
        
        require constraint communicationLatency {
            doc /* Inter-robot communication latency shall not exceed 100 milliseconds. */
        }
    }
    
    requirement def CollectiveTaskRequirement {
        doc /* 
        The system shall enable microbots to work together to achieve 
        objectives that individual robots cannot accomplish alone, including 
        distributed area coverage, collaborative object manipulation, and 
        adaptive environmental mapping.
        */
        
        assume constraint autonomousOperation {
            microboticsSystem.operationalMode == "autonomous"
        }
        
        require swarmCoord : SwarmCoordinationRequirement;
        
        require constraint taskCompletionRate {
            doc /* Task completion rate shall exceed 85% for assigned missions. */
        }
    }
    
    requirement def MicrobotSizeRequirement {
        doc /* 
        Individual microbots shall have maximum dimensions not exceeding 
        10 millimeters to enable operation in confined spaces.
        */
        
        subject microboticsSystem.microbot;
        
        require constraint maxDimension {
            doc /* Maximum microbot dimension <= 10 mm */
        }
    }
    
    requirement def PowerEfficiencyRequirement {
        doc /* 
        Each microbot shall operate continuously for minimum 60 minutes 
        on internal power supply to ensure mission completion.
        */
        
        subject microboticsSystem.microbot.power;
        
        require constraint minimumOperatingTime {
            doc /* Operating time >= 60 minutes at nominal load */
        }
    }
    
    requirement <'SYS-MICRO-001'> primarySystemRequirement {
        doc /* 
        The microbotics system shall autonomously deploy and coordinate 
        a swarm of miniature robots to perform distributed sensing, 
        collaborative manipulation, and adaptive task execution in 
        complex and confined environments through decentralized control 
        and inter-robot communication, achieving mission objectives 
        unattainable by individual robots or larger systems.
        */
        
        subject microboticsSystem;
        
        assume constraint environmentAccessible {
            doc /* 
            The operational environment is accessible to microbots and 
            allows wireless communication with signal strength sufficient 
            for swarm coordination.
            */
        }
        
        require collectiveTask : CollectiveTaskRequirement;
        require sizeConstraint : MicrobotSizeRequirement;
        require powerEfficiency : PowerEfficiencyRequirement;
        
        require constraint swarmScalability {
            microboticsSystem.coordinator.swarmSize >= 50 and 
            microboticsSystem.coordinator.swarmSize <= 500
        }
    }
}
