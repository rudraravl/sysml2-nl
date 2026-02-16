package SelfMakingBedSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def BedState {
        attribute isMade : Boolean;
        attribute sheetTension : ForceValue;
        attribute blanketAlignment : LengthValue;
        attribute pillowPosition : LengthValue;
    }
    
    attribute def OccupancyStatus {
        attribute isOccupied : Boolean;
        attribute vacantDuration : TimeValue;
    }
    
    attribute def ActuatorCommand {
        attribute motorSpeed : AngularVelocityValue;
        attribute targetPosition : LengthValue;
        attribute operationDuration : TimeValue;
    }
    
    item def BedSheet {
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute currentTension : ForceValue;
        attribute targetTension : ForceValue;
    }
    
    item def Blanket {
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute foldPosition : LengthValue;
    }
    
    item def Pillow {
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute height : LengthValue;
        attribute targetAlignment : LengthValue;
    }
    
    port def OccupancySensorPort {
        out occupancyData : OccupancyStatus;
    }
    
    port def SheetActuatorPort {
        in tensionCommand : ActuatorCommand;
        out tensionStatus : ForceValue;
    }
    
    port def BlanketActuatorPort {
        in foldCommand : ActuatorCommand;
        out foldStatus : Boolean;
    }
    
    port def PillowActuatorPort {
        in arrangeCommand : ActuatorCommand;
        out arrangeStatus : Boolean;
    }
    
    port def ControllerPort {
        in sensorInput : OccupancyStatus;
        out sheetControl : ActuatorCommand;
        out blanketControl : ActuatorCommand;
        out pillowControl : ActuatorCommand;
    }
    
    part def OccupancySensor {
        port sensorOutput : OccupancySensorPort;
        attribute detectionThreshold : ForceValue;
        attribute samplingRate : FrequencyValue;
        
        action detectOccupancy {
            out status : OccupancyStatus;
        }
    }
    
    part def SheetTensioningActuator {
        port actuatorControl : SheetActuatorPort;
        attribute maxTension : ForceValue;
        attribute tensioningSpeed : SpeedValue;
        
        action applyTension {
            in command : ActuatorCommand;
            out appliedTension : ForceValue;
        }
    }
    
    part def BlanketFoldingActuator {
        port actuatorControl : BlanketActuatorPort;
        attribute foldingSpeed : SpeedValue;
        attribute maxFoldLength : LengthValue;
        
        action executeFold {
            in command : ActuatorCommand;
            out completed : Boolean;
        }
    }
    
    part def PillowArrangementActuator {
        port actuatorControl : PillowActuatorPort;
        attribute positioningPrecision : LengthValue;
        attribute movementSpeed : SpeedValue;
        
        action positionPillow {
            in command : ActuatorCommand;
            out positioned : Boolean;
        }
    }
    
    part def BedMakingController {
        port sensorInterface : ~OccupancySensorPort;
        port sheetInterface : ~SheetActuatorPort;
        port blanketInterface : ~BlanketActuatorPort;
        port pillowInterface : ~PillowActuatorPort;
        
        attribute currentBedState : BedState;
        attribute makingInProgress : Boolean;
        
        perform action executeBedMaking[*] ordered references MakeBedSequence;
    }
    
    action def MonitorOccupancy {
        out occupancyReading : OccupancyStatus;
    }
    
    action def TensionSheets {
        in targetTension : ForceValue;
        out achievedTension : ForceValue;
    }
    
    action def FoldBlanket {
        in targetFoldPosition : LengthValue;
        out foldCompleted : Boolean;
    }
    
    action def ArrangePillows {
        in targetPosition : LengthValue;
        out arrangementCompleted : Boolean;
    }
    
    action def FinalizeBedMaking {
        out bedMadeSuccessfully : Boolean;
    }
    
    action MakeBedSequence {
        first start;
        then merge monitoringLoop;
        
        then action monitorOccupancy : MonitorOccupancy {
            out occupancyReading : OccupancyStatus;
        }
        
        then decide;
            if monitorOccupancy.occupancyReading.isOccupied then monitoringLoop;
            if not monitorOccupancy.occupancyReading.isOccupied and 
               monitorOccupancy.occupancyReading.vacantDuration >= 60.0 then tensionSheets;
        
        action tensionSheets : TensionSheets {
            in targetTension : ForceValue = 8.0;
            out achievedTension : ForceValue;
        }
        then foldBlanket;
        
        action foldBlanket : FoldBlanket {
            in targetFoldPosition : LengthValue = 0.5;
            out foldCompleted : Boolean;
        }
        then arrangePillows;
        
        action arrangePillows : ArrangePillows {
            in targetPosition : LengthValue = 0.2;
            out arrangementCompleted : Boolean;
        }
        then finalize;
        
        action finalize : FinalizeBedMaking {
            out bedMadeSuccessfully : Boolean;
        }
        then done;
    }
    
    part def SelfMakingBed;
    
    part selfMakingBed : SelfMakingBed {
        part bedFrame {
            attribute frameLength : LengthValue = 2.0;
            attribute frameWidth : LengthValue = 1.5;
            attribute frameHeight : LengthValue = 0.6;
        }
        
        part mattress {
            attribute mattressLength : LengthValue = 2.0;
            attribute mattressWidth : LengthValue = 1.5;
            attribute mattressThickness : LengthValue = 0.25;
        }
        
        part bedding {
            part bottomSheet : BedSheet {
                attribute length = 2.2;
                attribute width = 1.7;
                attribute targetTension = 8.0;
            }
            part topSheet : BedSheet {
                attribute length = 2.2;
                attribute width = 1.7;
                attribute targetTension = 6.0;
            }
            part blanket : Blanket {
                attribute length = 2.0;
                attribute width = 1.8;
            }
            part pillow1 : Pillow {
                attribute length = 0.6;
                attribute width = 0.4;
                attribute height = 0.15;
            }
            part pillow2 : Pillow {
                attribute length = 0.6;
                attribute width = 0.4;
                attribute height = 0.15;
            }
        }
        
        part sensingSystem {
            part occupancySensor1 : OccupancySensor {
                attribute detectionThreshold = 5.0;
                attribute samplingRate = 1.0;
            }
            part occupancySensor2 : OccupancySensor {
                attribute detectionThreshold = 5.0;
                attribute samplingRate = 1.0;
            }
        }
        
        part actuationSystem {
            part sheetTensioner1 : SheetTensioningActuator {
                attribute maxTension = 15.0;
                attribute tensioningSpeed = 0.05;
            }
            part sheetTensioner2 : SheetTensioningActuator {
                attribute maxTension = 15.0;
                attribute tensioningSpeed = 0.05;
            }
            part blanketFolder : BlanketFoldingActuator {
                attribute foldingSpeed = 0.1;
                attribute maxFoldLength = 1.0;
            }
            part pillowArranger1 : PillowArrangementActuator {
                attribute positioningPrecision = 0.01;
                attribute movementSpeed = 0.08;
            }
            part pillowArranger2 : PillowArrangementActuator {
                attribute positioningPrecision = 0.01;
                attribute movementSpeed = 0.08;
            }
        }
        
        part controller : BedMakingController {
            attribute makingInProgress = false;
        }
        
        connect sensingSystem.occupancySensor1.sensorOutput to controller.sensorInterface;
        connect controller.sheetInterface to actuationSystem.sheetTensioner1.actuatorControl;
        connect controller.blanketInterface to actuationSystem.blanketFolder.actuatorControl;
        connect controller.pillowInterface to actuationSystem.pillowArranger1.actuatorControl;
        
        part sensingSystem.occupancySensor1 {
            perform controller.executeBedMaking.monitorOccupancy;
        }
        
        part actuationSystem.sheetTensioner1 {
            perform controller.executeBedMaking.tensionSheets;
        }
        
        part actuationSystem.blanketFolder {
            perform controller.executeBedMaking.foldBlanket;
        }
        
        part actuationSystem.pillowArranger1 {
            perform controller.executeBedMaking.arrangePillows;
        }
    }
    
    requirement def AutomaticBedMakingRequirement {
        doc /* The self-making bed system shall automatically make the bed 
               when the bed has been vacant for at least 60 seconds. */
        
        subject bed : SelfMakingBed;
        
        require constraint {
            bed.controller.currentBedState.isMade == true
        }
    }
    
    requirement def BedMakingQualityRequirement {
        doc /* The bed making process shall achieve proper sheet tension,
               blanket positioning, and pillow arrangement to meet quality standards. */
        
        subject bed : SelfMakingBed;
        
        require constraint sheetTensionConstraint {
            bed.bedding.bottomSheet.currentTension >= 7.0 and
            bed.bedding.topSheet.currentTension >= 5.0
        }
        
        require constraint blanketPositionConstraint {
            bed.bedding.blanket.foldPosition <= 0.6
        }
        
        require constraint pillowAlignmentConstraint {
            bed.bedding.pillow1.targetAlignment <= 0.25 and
            bed.bedding.pillow2.targetAlignment <= 0.25
        }
    }
    
    requirement def OccupancyDetectionRequirement {
        doc /* The system shall accurately detect bed occupancy with a minimum
               sampling rate of 1 Hz and force threshold of 5 N. */
        
        subject sensor : OccupancySensor;
        
        require constraint {
            sensor.samplingRate >= 1.0 and
            sensor.detectionThreshold >= 5.0
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The bed making system shall not operate when the bed is occupied
               to ensure user safety and prevent injury. */
        
        subject bed : SelfMakingBed;
        
        require constraint safetyInterlock {
            bed.sensingSystem.occupancySensor1.sensorOutput.occupancyData.isOccupied == true implies
            bed.controller.makingInProgress == false
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* The bed making cycle shall complete within 120 seconds from
               initiation to finalization. */
        
        subject bed : SelfMakingBed;
        
        require constraint cycleTimeConstraint {
            bed.controller.executeBedMaking.finalize.bedMadeSuccessfully == true
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for the self-making bed system defining
               automatic operation, quality standards, occupancy detection,
               safety compliance, and performance criteria. */
        
        require automaticOperation : AutomaticBedMakingRequirement;
        require qualityStandards : BedMakingQualityRequirement;
        require occupancyDetection : OccupancyDetectionRequirement;
        require safetyCompliance : SafetyRequirement;
        require performanceStandards : PerformanceRequirement;
    }
}
