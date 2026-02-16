package AutomatedHighwaySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VehicleIdentifier;
    attribute def LaneNumber;
    attribute def SegmentIdentifier;
    
    attribute def SafetyLevel :> Real;
    attribute def TrafficDensity :> Real;
    attribute def CommunicationLatency :> TimeValue;
    
    item def VehicleState {
        attribute vehicleID : VehicleIdentifier;
        attribute currentPosition : LengthValue;
        attribute currentSpeed : SpeedValue;
        attribute currentAcceleration : AccelerationValue;
        attribute assignedLane : LaneNumber;
        attribute heading : Real;
    }
    
    item def ControlInstruction {
        attribute targetVehicleID : VehicleIdentifier;
        attribute commandedSpeed : SpeedValue;
        attribute commandedLane : LaneNumber;
        attribute commandedSpacing : LengthValue;
        attribute priority : Integer;
    }
    
    item def SensorReading {
        attribute timestamp : TimeValue;
        attribute detectedVehicles : VehicleState[*];
        attribute roadCondition : Real;
        attribute visibility : LengthValue;
        attribute segmentID : SegmentIdentifier;
    }
    
    item def SafetyAlert {
        attribute alertLevel : SafetyLevel;
        attribute affectedSegment : SegmentIdentifier;
        attribute affectedVehicles : VehicleIdentifier[*];
        attribute recommendedAction : String;
    }
    
    port def VehicleCommPort {
        in controlCmd : ControlInstruction;
        out vehicleStatus : VehicleState;
        out emergencySignal : Boolean;
    }
    
    port def InfrastructureSensorPort {
        out sensorData : SensorReading;
    }
    
    port def ControlCenterPort {
        in aggregatedSensorData : SensorReading[*];
        in vehicleStates : VehicleState[*];
        out controlInstructions : ControlInstruction[*];
        out safetyAlerts : SafetyAlert[*];
    }
    
    port def SafetySystemPort {
        in vehicleStates : VehicleState[*];
        in sensorData : SensorReading[*];
        out alerts : SafetyAlert[*];
        out emergencyCommands : ControlInstruction[*];
    }
    
    part def RoadwaySensor {
        port sensorOutput : InfrastructureSensorPort;
        
        attribute scanFrequency : FrequencyValue;
        attribute coverageRange : LengthValue;
        attribute accuracy : Real;
        
        perform action collectData;
    }
    
    part def CommunicationNode {
        port vehicleLinks : VehicleCommPort[*];
        
        attribute maxConnections : Integer;
        attribute transmissionPower : PowerValue;
        attribute communicationLatency : CommunicationLatency;
        
        perform action relayMessages;
    }
    
    part def CentralTrafficController {
        port controlInterface : ControlCenterPort;
        
        attribute processingCapacity : Real;
        attribute updateRate : FrequencyValue;
        
        perform action coordinateTraffic;
    }
    
    part def SafetyManagementSystem {
        port safetyInterface : SafetySystemPort;
        
        attribute minimumSafeSpacing : LengthValue;
        attribute reactionTime : TimeValue;
        
        perform action monitorSafety;
    }
    
    part def ConnectedVehicle {
        port commInterface : VehicleCommPort;
        
        attribute vehicleMass : MassValue;
        attribute maxAcceleration : AccelerationValue;
        attribute maxDeceleration : AccelerationValue;
        attribute automationLevel : Integer;
        
        perform action executeCommands;
    }
    
    action def ScanTrafficSegment {
        in segmentID : SegmentIdentifier;
        in scanRange : LengthValue;
        out detectedVehicles : VehicleState[*];
        out trafficDensity : TrafficDensity;
        out averageSpeed : SpeedValue;
    }
    
    action def ComputeOptimalFlow {
        in vehicleStates : VehicleState[*];
        in currentDensity : TrafficDensity;
        in speedLimit : SpeedValue;
        out targetSpeed : SpeedValue;
        out targetSpacing : LengthValue;
        out laneRecommendations : LaneNumber[*];
    }
    
    action def GenerateControlCommands {
        in targetSpeed : SpeedValue;
        in targetSpacing : LengthValue;
        in vehicleList : VehicleState[*];
        in laneAssignments : LaneNumber[*];
        out commands : ControlInstruction[*];
    }
    
    action def TransmitToVehicles {
        in commands : ControlInstruction[*];
        in targetVehicleIDs : VehicleIdentifier[*];
    }
    
    action def EvaluateSafetyConditions {
        in vehicleStates : VehicleState[*];
        in minimumSpacing : LengthValue;
        in weatherConditions : Real;
        out safetyLevel : SafetyLevel;
        out violations : VehicleIdentifier[*];
    }
    
    action def IssueEmergencyProtocol {
        in safetyLevel : SafetyLevel;
        in violatingVehicles : VehicleIdentifier[*];
        out emergencyCommands : ControlInstruction[*];
        out alerts : SafetyAlert[*];
    }
    
    action def CoordinateHighwayTraffic {
        doc /* Primary control loop for automated highway traffic coordination. */
        
        first start;
        then merge operationLoop;
        
        action scanSegment : ScanTrafficSegment {
            in segmentID;
            in scanRange = 1000.0 [m];
            out detectedVehicles : VehicleState[*];
            out trafficDensity : TrafficDensity;
            out averageSpeed : SpeedValue;
        }
        
        then action computeFlow : ComputeOptimalFlow {
            in vehicleStates = scanSegment.detectedVehicles;
            in currentDensity = scanSegment.trafficDensity;
            in speedLimit = 120.0 [km/h];
            out targetSpeed : SpeedValue;
            out targetSpacing : LengthValue;
            out laneRecommendations : LaneNumber[*];
        }
        
        then action evaluateSafety : EvaluateSafetyConditions {
            in vehicleStates = scanSegment.detectedVehicles;
            in minimumSpacing = computeFlow.targetSpacing;
            in weatherConditions = 1.0;
            out safetyLevel : SafetyLevel;
            out violations : VehicleIdentifier[*];
        }
        
        then decide;
            if evaluateSafety.safetyLevel >= 0.8 then normalControl;
            if evaluateSafety.safetyLevel < 0.8 then emergencyControl;
        
        action normalControl {
            action generateCommands : GenerateControlCommands {
                in targetSpeed = computeFlow.targetSpeed;
                in targetSpacing = computeFlow.targetSpacing;
                in vehicleList = scanSegment.detectedVehicles;
                in laneAssignments = computeFlow.laneRecommendations;
                out commands : ControlInstruction[*];
            }
            
            then action transmit : TransmitToVehicles {
                in commands = generateCommands.commands;
                in targetVehicleIDs;
            }
        }
        then operationLoop;
        
        action emergencyControl : IssueEmergencyProtocol {
            in safetyLevel = evaluateSafety.safetyLevel;
            in violatingVehicles = evaluateSafety.violations;
            out emergencyCommands : ControlInstruction[*];
            out alerts : SafetyAlert[*];
        }
        then operationLoop;
    }
    
    state def VehicleOperationalState {
        entry;
        then manualMode;
        
        state manualMode {
            entry action disableAutomation;
        }
        
        transition manualMode to automatedMode
            first accept ahsEnrollment;
        
        state automatedMode {
            entry action enableAutomation;
            do action receiveControlCommands;
            do action adjustSpeed;
            do action maintainLanePosition;
            do action monitorSurroundings;
            
            state normalOperation;
            
            transition normalOperation to emergencyMode
                first accept emergencyAlert;
            
            state emergencyMode {
                entry action activateEmergencyBraking;
                do action broadcastWarning;
            }
            
            transition emergencyMode to normalOperation
                first accept clearanceSignal;
        }
        
        transition automatedMode to manualMode
            first accept ahsExit;
    }
    
    state def SystemOperationalState {
        entry;
        then initialization;
        
        state initialization {
            entry action systemCheck;
            entry action calibrateSensors;
        }
        
        transition initialization to activeOperation
            first accept systemReady;
        
        state activeOperation {
            do action continuousMonitoring;
            do action trafficCoordination;
            
            state normalOperations {
                do action optimizeFlow;
                do action updateCommands;
            }
            
            transition normalOperations to reducedCapacity
                first accept degradedConditions;
            
            state reducedCapacity {
                entry action lowerSpeedLimits;
                do action increaseSpacing;
            }
            
            transition reducedCapacity to normalOperations
                first accept conditionsImproved;
            
            transition normalOperations to safeMode
                first accept criticalFailure;
            
            state safeMode {
                entry action haltNewEnrollments;
                entry action guidedExitProtocol;
                do action minimizeRisk;
            }
        }
        
        transition activeOperation to maintenance
            first accept maintenanceRequest;
        
        state maintenance {
            entry action suspendOperations;
            do action diagnostics;
        }
        
        transition maintenance to initialization
            first accept maintenanceComplete;
    }
    
    part def HighwaySystem {
        part roadwaySensors : RoadwaySensor[*];
        part commNodes : CommunicationNode[*];
        part trafficController : CentralTrafficController;
        part safetySystem : SafetyManagementSystem;
        part enrolledVehicles : ConnectedVehicle[*];
    }
    
    part automatedHighway : HighwaySystem {
        doc /* 
            The Automated Highway System coordinates autonomous and connected vehicles 
            on dedicated roadway infrastructure to optimize traffic flow, maximize safety, 
            and increase highway capacity through centralized control and vehicle-to-infrastructure 
            communication. The system continuously monitors traffic conditions, computes optimal 
            speeds and spacing, and transmits real-time control commands to enrolled vehicles.
        */
        
        part redefines roadwaySensors : RoadwaySensor[20] {
            attribute :>> scanFrequency = 20.0 [Hz];
            attribute :>> coverageRange = 500.0 [m];
            attribute :>> accuracy = 0.95;
        }
        
        part redefines commNodes : CommunicationNode[15] {
            attribute :>> maxConnections = 100;
            attribute :>> transmissionPower = 50.0 [W];
            attribute :>> communicationLatency = 0.02 [s];
        }
        
        part redefines trafficController : CentralTrafficController {
            attribute :>> processingCapacity = 10000.0;
            attribute :>> updateRate = 10.0 [Hz];
            
            perform action coordinateTraffic : CoordinateHighwayTraffic;
        }
        
        part redefines safetySystem : SafetyManagementSystem {
            attribute :>> minimumSafeSpacing = 50.0 [m];
            attribute :>> reactionTime = 0.5 [s];
            
            perform action monitorSafety {
                first start;
                then merge continuousCheck;
                
                action checkVehicleSpacing {
                    in vehicleData : VehicleState[*];
                    in minSpacing : LengthValue;
                    out spacingOK : Boolean;
                }
                
                then decide;
                    if checkVehicleSpacing.spacingOK then continuousCheck;
                    if !checkVehicleSpacing.spacingOK then issueAlert;
                
                action issueAlert {
                    out alert : SafetyAlert;
                }
                then continuousCheck;
            }
        }
        
        part redefines enrolledVehicles : ConnectedVehicle[0..500] {
            attribute :>> vehicleMass = 1500.0 [kg];
            attribute :>> maxAcceleration = 3.0 [m/s^2];
            attribute :>> maxDeceleration = 8.0 [m/s^2];
            attribute :>> automationLevel = 4;
            
            perform action executeCommands {
                first start;
                then state vehicleState : VehicleOperationalState;
            }
        }
        
        perform action systemOperation {
            first start;
            then state systemState : SystemOperationalState;
        }
        
        connection sensorsToController connect 
            roadwaySensors.sensorOutput to trafficController.controlInterface;
        
        connection sensorsToSafety connect 
            roadwaySensors.sensorOutput to safetySystem.safetyInterface;
        
        connection controllerToComm connect 
            trafficController.controlInterface to commNodes.vehicleLinks;
        
        connection safetyToComm connect 
            safetySystem.safetyInterface to commNodes.vehicleLinks;
        
        connection commToVehicles connect 
            commNodes.vehicleLinks to enrolledVehicles.commInterface;
    }
    
    requirement def OperationalRequirement;
    
    requirement <'REQ-001'> safetySpacingRequirement : OperationalRequirement {
        doc /* 
            All vehicles under automated control shall maintain a minimum safe 
            following distance of at least 2 seconds of travel time at current speed.
        */
        
        subject vehicle : ConnectedVehicle;
        
        require constraint {
            doc /* Spacing >= current_speed * 2.0 [s] */
        }
    }
    
    requirement <'REQ-002'> communicationLatencyRequirement : OperationalRequirement {
        doc /* 
            Control commands shall be transmitted to vehicles with a maximum 
            end-to-end latency of 100 milliseconds.
        */
        
        subject commNode : CommunicationNode;
        
        require constraint {
            commNode.communicationLatency <= 0.1 [s]
        }
    }
    
    requirement <'REQ-003'> throughputRequirement : OperationalRequirement {
        doc /* 
            The system shall support a minimum traffic throughput of 2500 vehicles 
            per hour per lane during normal operations.
        */
        
        subject highway : HighwaySystem;
    }
    
    requirement <'REQ-004'> emergencyResponseRequirement : OperationalRequirement {
        doc /* 
            The safety management system shall detect hazardous conditions and 
            issue emergency commands within 500 milliseconds of detection.
        */
        
        subject safety : SafetyManagementSystem;
        
        require constraint {
            safety.reactionTime <= 0.5 [s]
        }
    }
    
    requirement <'REQ-005'> systemAvailabilityRequirement : OperationalRequirement {
        doc /* 
            The automated highway system shall maintain operational availability 
            of at least 99.5% over any 30-day period.
        */
        
        subject highway : HighwaySystem;
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for the Automated Highway System. */
        
        require safetySpacingRequirement;
        require communicationLatencyRequirement;
        require throughputRequirement;
        require emergencyResponseRequirement;
        require systemAvailabilityRequirement;
    }
}
