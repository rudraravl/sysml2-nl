package ManumationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def TaskID;
    attribute def OperationMode;
    attribute def SafetyStatus;
    
    item def Workpiece {
        attribute id : String;
        attribute mass : MassValue;
        attribute dimensions : LengthValue[3];
        attribute currentStage : String;
        attribute qualityStatus : String;
    }
    
    item def Gripper {
        attribute gripperId : String;
        attribute maxGripForce : ForceValue;
        attribute gripperState : String;
    }
    
    item def ToolHead {
        attribute toolId : String;
        attribute toolType : String;
        attribute operationalHours : DurationValue;
    }
    
    attribute def JointPosition {
        attribute joint1 : Real;
        attribute joint2 : Real;
        attribute joint3 : Real;
        attribute joint4 : Real;
        attribute joint5 : Real;
        attribute joint6 : Real;
    }
    
    attribute def CartesianPosition {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }
    
    port def WorkpieceInputPort {
        in item workpieceIn : Workpiece;
    }
    
    port def WorkpieceOutputPort {
        out item workpieceOut : Workpiece;
    }
    
    port def ControlCommandPort {
        in attribute commandSignal : String;
        in attribute targetPosition : CartesianPosition;
        out attribute statusFeedback : String;
        out attribute currentPosition : CartesianPosition;
    }
    
    port def PowerSupplyPort {
        in attribute voltage : ElectricPotentialValue;
        in attribute current : ElectricCurrentValue;
    }
    
    port def SensorDataPort {
        out attribute forceReading : ForceValue;
        out attribute positionReading : CartesianPosition;
        out attribute velocityReading : SpeedValue;
    }
    
    part def ManipulatorUnit {
        attribute numberOfJoints : Integer;
        attribute maxReach : LengthValue;
        attribute maxPayload : MassValue;
        attribute currentJointPosition : JointPosition;
        attribute targetJointPosition : JointPosition;
        
        port controlPort : ControlCommandPort;
        port powerPort : PowerSupplyPort;
        port sensorPort : SensorDataPort;
        
        part endEffector : Gripper {
            attribute :>> maxGripForce = 500[N];
        }
        
        perform action moveToTarget {
            in targetPos : CartesianPosition;
            out finalPos : CartesianPosition;
            out moveSuccess : Boolean;
        }
        
        perform action graspObject {
            in workpiece : Workpiece;
            in gripForce : ForceValue;
            out graspSuccess : Boolean;
        }
        
        perform action releaseObject {
            out releaseSuccess : Boolean;
        }
    }
    
    part def WorkStation {
        attribute stationID : String;
        attribute operationType : String;
        attribute processingTime : DurationValue;
        attribute isOccupied : Boolean;
        
        port workpieceInput : WorkpieceInputPort;
        port workpieceOutput : WorkpieceOutputPort;
        port controlPort : ControlCommandPort;
        port powerPort : PowerSupplyPort;
        
        part tooling : ToolHead;
        
        perform action executeOperation {
            in workpieceIn : Workpiece;
            in operationParameters : String;
            out workpieceOut : Workpiece;
            out operationSuccess : Boolean;
        }
    }
    
    part def VisionSystem {
        attribute cameraResolution : String;
        attribute fieldOfView : Real;
        attribute detectionAccuracy : Real;
        
        port controlPort : ControlCommandPort;
        port powerPort : PowerSupplyPort;
        
        perform action detectWorkpiece {
            out workpieceDetected : Boolean;
            out workpiecePosition : CartesianPosition;
        }
        
        perform action verifyQuality {
            in workpiece : Workpiece;
            out qualityPass : Boolean;
            out defectList : String[*];
        }
    }
    
    part def TransportSystem {
        attribute conveyorSpeed : SpeedValue;
        attribute conveyorLength : LengthValue;
        attribute bufferCapacity : Integer;
        
        port workpieceInput : WorkpieceInputPort;
        port workpieceOutput : WorkpieceOutputPort;
        port controlPort : ControlCommandPort;
        port powerPort : PowerSupplyPort;
        
        perform action transportWorkpiece {
            in workpiece : Workpiece;
            in destination : String;
            out transportTime : DurationValue;
            out transportSuccess : Boolean;
        }
    }
    
    part def CentralController {
        attribute operatingMode : String;
        attribute cycleCount : Integer;
        attribute productionRate : Real;
        
        perform action planSequence;
        perform action coordinateOperations;
        perform action monitorSafety;
        perform action optimizePerformance;
    }
    
    action def PickWorkpiece {
        in workpiece : Workpiece;
        in pickLocation : CartesianPosition;
        out pickSuccess : Boolean;
    }
    
    action def PlaceWorkpiece {
        in workpiece : Workpiece;
        in placeLocation : CartesianPosition;
        out placeSuccess : Boolean;
    }
    
    action def ProcessWorkpiece {
        in workpiece : Workpiece;
        in processingStation : String;
        in processingDuration : DurationValue;
        out processedWorkpiece : Workpiece;
    }
    
    action def InspectWorkpiece {
        in workpiece : Workpiece;
        out inspectionResult : Boolean;
        out qualityScore : Real;
    }
    
    action def TransferWorkpiece {
        in workpiece : Workpiece;
        in fromLocation : String;
        in toLocation : String;
        out transferSuccess : Boolean;
    }
    
    action def SystemCheck {
        out success : Boolean;
    }
    
    action def Diagnostics;
    action def SafeShutdown;
    action def EmergencyProcedure;
    
    attribute def StartProduction;
    attribute def PauseCommand;
    attribute def StopCommand;
    attribute def ResumeCommand;
    attribute def ResetCommand;
    attribute def EmergencyStop;
    attribute def ClearEmergency;
    
    state def ManumationOperationalStates {
        in attribute currentMode : String;
        
        entry; then initialization;
        
        state initialization {
            do action systemCheck : SystemCheck;
        }
        then decide;
            if systemCheck.success then ready;
            if !systemCheck.success then fault;
        
        state ready;
        accept startProduction : StartProduction;
        then operating;
        
        state operating;
        accept pauseCommand : PauseCommand;
        then paused;
        accept stopCommand : StopCommand;
        then shutdown;
        
        state paused;
        accept resumeCommand : ResumeCommand;
        then operating;
        
        state fault {
            do action diagnostics : Diagnostics;
        }
        accept resetCommand : ResetCommand;
        then initialization;
        
        state shutdown {
            do action safeShutdown : SafeShutdown;
        }
        then done;
        
        accept emergencyStop : EmergencyStop;
        then emergencyState;
        
        state emergencyState {
            do action emergencyProcedure : EmergencyProcedure;
        }
        accept clearEmergency : ClearEmergency;
        then initialization;
    }
    
    action def AutomatedManumationCycle {
        in workpieceQueue : Workpiece[*];
        in productionTarget : Integer;
        out completedProducts : Workpiece[*] := ();
        out rejectedProducts : Workpiece[*] := ();
        out cycleStatistics : String;
        
        private attribute processedCount := 0;
        private attribute acceptedCount := 0;
        private attribute rejectedCount := 0;
        
        first start;
        then merge continueProduction;
        
        then decide;
            if processedCount < productionTarget then processNextWorkpiece;
            if processedCount >= productionTarget then finalize;
        
        action processNextWorkpiece {
            private attribute currentWorkpiece := workpieceQueue#(processedCount);
            
            action detectAndLocate {
                action visionDetect : InspectWorkpiece {
                    in workpiece = currentWorkpiece;
                    out inspectionResult;
                    out qualityScore;
                }
            }
            then decide;
                if detectAndLocate.visionDetect.inspectionResult then pickAndProcess;
                if !detectAndLocate.visionDetect.inspectionResult then rejectWorkpiece;
            
            action pickAndProcess {
                action pickUp : PickWorkpiece {
                    in workpiece = currentWorkpiece;
                    out pickSuccess;
                }
                then action transfer1 : TransferWorkpiece {
                    in workpiece = currentWorkpiece;
                    in fromLocation = "InputBuffer";
                    in toLocation = "ProcessingStation1";
                    out transferSuccess;
                }
                then action process1 : ProcessWorkpiece {
                    in workpiece = currentWorkpiece;
                    in processingStation = "Station1";
                    in processingDuration = 30[s];
                    out processedWorkpiece;
                }
                then action transfer2 : TransferWorkpiece {
                    in workpiece = process1.processedWorkpiece;
                    in fromLocation = "ProcessingStation1";
                    in toLocation = "ProcessingStation2";
                    out transferSuccess;
                }
                then action process2 : ProcessWorkpiece {
                    in workpiece = process1.processedWorkpiece;
                    in processingStation = "Station2";
                    in processingDuration = 45[s];
                    out processedWorkpiece;
                }
                then action finalInspection : InspectWorkpiece {
                    in workpiece = process2.processedWorkpiece;
                    out inspectionResult;
                    out qualityScore;
                }
                then decide;
                    if finalInspection.inspectionResult then acceptProduct;
                    if !finalInspection.inspectionResult then rejectWorkpiece;
                
                action acceptProduct {
                    then assign completedProducts := completedProducts->including(process2.processedWorkpiece);
                    then assign acceptedCount := acceptedCount + 1;
                }
                then incrementProcessed;
            }
            
            action rejectWorkpiece {
                then assign rejectedProducts := rejectedProducts->including(currentWorkpiece);
                then assign rejectedCount := rejectedCount + 1;
            }
            then incrementProcessed;
            
            action incrementProcessed {
                then assign processedCount := processedCount + 1;
            }
        }
        then continueProduction;
        
        action finalize;
        then done;
    }
    
    part def ManumationCell {
        part manipulator1 : ManipulatorUnit;
        part manipulator2 : ManipulatorUnit;
        part station1 : WorkStation;
        part station2 : WorkStation;
        part station3 : WorkStation;
        part visionUnit : VisionSystem;
        part inputConveyor : TransportSystem;
        part outputConveyor : TransportSystem;
        part interStationConveyor : TransportSystem;
        part controller : CentralController;
    }
    
    part manumationCell : ManumationCell {
        doc /* 
            Manumation Cell: An integrated automated manufacturing system combining 
            manipulation and automation technologies for flexible, intelligent production.
            
            Primary Function: To autonomously perform complex manufacturing operations by 
            intelligently coordinating robotic manipulation, material handling, processing, 
            and quality inspection to transform raw workpieces into finished products with 
            minimal human intervention and maximum efficiency.
        */
        
        part :>> manipulator1 {
            attribute :>> numberOfJoints = 6;
            attribute :>> maxReach = 1800[mm];
            attribute :>> maxPayload = 30[kg];
        }
        
        part :>> manipulator2 {
            attribute :>> numberOfJoints = 6;
            attribute :>> maxReach = 1500[mm];
            attribute :>> maxPayload = 20[kg];
        }
        
        part :>> station1 {
            attribute :>> stationID = "WS-01";
            attribute :>> operationType = "Machining";
            attribute :>> processingTime = 30[s];
        }
        
        part :>> station2 {
            attribute :>> stationID = "WS-02";
            attribute :>> operationType = "Assembly";
            attribute :>> processingTime = 45[s];
        }
        
        part :>> station3 {
            attribute :>> stationID = "WS-03";
            attribute :>> operationType = "Finishing";
            attribute :>> processingTime = 25[s];
        }
        
        part :>> visionUnit {
            attribute :>> cameraResolution = "4K";
            attribute :>> fieldOfView = 90.0;
            attribute :>> detectionAccuracy = 0.98;
        }
        
        part :>> inputConveyor {
            attribute :>> conveyorSpeed = 0.5[m/s];
            attribute :>> conveyorLength = 12[m];
            attribute :>> bufferCapacity = 25;
        }
        
        part :>> outputConveyor {
            attribute :>> conveyorSpeed = 0.4[m/s];
            attribute :>> conveyorLength = 10[m];
            attribute :>> bufferCapacity = 20;
        }
        
        part :>> interStationConveyor {
            attribute :>> conveyorSpeed = 0.3[m/s];
            attribute :>> conveyorLength = 8[m];
            attribute :>> bufferCapacity = 15;
        }
        
        part :>> controller {
            attribute :>> operatingMode = "Automatic";
            attribute :>> cycleCount = 0;
            attribute :>> productionRate = 150.0;
        }
        
        connection c1 connect inputConveyor.workpieceOutput to station1.workpieceInput;
        connection c2 connect station1.workpieceOutput to interStationConveyor.workpieceInput;
        connection c3 connect interStationConveyor.workpieceOutput to station2.workpieceInput;
        connection c4 connect station2.workpieceOutput to station3.workpieceInput;
        connection c5 connect station3.workpieceOutput to outputConveyor.workpieceInput;
        
        perform action productionCycle : AutomatedManumationCycle[*] ordered;
    }
    
    requirement def PerformanceRequirement {
        doc /* The manumation system shall meet specified performance criteria. */
        
        subject system : ManumationCell;
        
        require constraint {
            system.controller.productionRate >= 120.0
        }
    }
    
    requirement def AccuracyRequirement {
        doc /* The manumation system shall maintain high positioning and processing accuracy. */
        
        subject manipulator : ManipulatorUnit;
        
        require constraint {
            manipulator.maxReach >= 1500[mm] and
            manipulator.maxPayload >= 20[kg]
        }
    }
    
    requirement def QualityRequirement {
        doc /* The manumation system shall ensure product quality through inspection. */
        
        subject vision : VisionSystem;
        
        require constraint {
            vision.detectionAccuracy >= 0.95
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The manumation system shall operate safely with emergency response capability. */
        
        subject system : ManumationCell;
    }
    
    requirement <'MAN-SYS-001'> manumationSystemRequirements {
        doc /* 
            The manumation system shall integrate robotic manipulation with automated 
            manufacturing processes to achieve flexible, efficient, high-quality production 
            with comprehensive safety and monitoring capabilities.
        */
        
        require PerformanceRequirement;
        require AccuracyRequirement;
        require QualityRequirement;
        require SafetyRequirement;
    }
}
