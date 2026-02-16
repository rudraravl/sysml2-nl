package StereotaxisMagneticNavigationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def MagneticFieldStrength :> Real;
    attribute def PositionAccuracy :> LengthValue;
    attribute def OrientationAngle :> Real;
    attribute def TipForce :> ForceValue;
    attribute def ImageResolution :> LengthValue;
    
    enum def NavigationMode {
        manual;
        semiAutomated;
        fullyAutomated;
    }
    
    enum def ProcedurePhase {
        initialization;
        planning;
        navigation;
        intervention;
        retraction;
        completed;
        aborted;
    }
    
    item def MagneticCatheter {
        attribute length : LengthValue;
        attribute tipMagnetization : MagneticFieldStrength;
        attribute flexibility : Real;
        port tipPosition {
            out x : LengthValue;
            out y : LengthValue;
            out z : LengthValue;
        }
        port tipOrientation {
            out azimuth : OrientationAngle;
            out elevation : OrientationAngle;
        }
    }
    
    item def Patient {
        attribute patientID : String;
        part anatomy {
            attribute vesselDiameter : LengthValue;
            attribute targetDepth : LengthValue;
        }
    }
    
    item def NavigationPath {
        attribute waypoints : PositionAccuracy[*];
        attribute totalLength : LengthValue;
    }
    
    value def MagneticFieldVector {
        attribute strength : MagneticFieldStrength;
        attribute azimuth : OrientationAngle;
        attribute elevation : OrientationAngle;
    }
    
    part def ExternalMagnetSystem {
        attribute maxFieldStrength : MagneticFieldStrength;
        attribute fieldGradient : Real;
        
        part northMagnet {
            attribute fieldStrength : MagneticFieldStrength;
            attribute orientation : OrientationAngle;
            attribute position : LengthValue[3];
        }
        
        part southMagnet {
            attribute fieldStrength : MagneticFieldStrength;
            attribute orientation : OrientationAngle;
            attribute position : LengthValue[3];
        }
        
        port magneticFieldOutput {
            out fieldVector : MagneticFieldVector;
            in targetOrientation : OrientationAngle;
            in targetStrength : MagneticFieldStrength;
        }
        
        action GenerateMagneticField {
            in desiredOrientation : OrientationAngle;
            in desiredStrength : MagneticFieldStrength;
            out appliedField : MagneticFieldVector;
        }
    }
    
    part def FluoroscopyImagingSystem {
        attribute frameRate : Real;
        attribute resolution : ImageResolution;
        attribute exposureDose : Real;
        
        port imageOutput {
            out realTimeImage : String;
            out catheterPosition : PositionAccuracy;
            out vesselGeometry : String;
        }
        
        action AcquireImage {
            out imageData : String;
            out detectedPosition : PositionAccuracy;
        }
    }
    
    part def NavigationWorkstation {
        attribute processingPower : Real;
        attribute softwareVersion : String;
        
        part pathPlanningModule {
            attribute algorithmType : String;
        }
        
        part fieldControlModule {
            attribute controlFrequency : Real;
        }
        
        part userInterface {
            attribute displayResolution : String;
            attribute touchEnabled : Boolean;
        }
        
        port commandOutput {
            out magnetFieldCommands : MagneticFieldVector;
            out navigationCommands : String;
        }
        
        port sensorInput {
            in catheterStatus : PositionAccuracy;
            in imageData : String;
            in forceData : TipForce;
        }
        
        action PlanNavigationPath {
            in startPosition : PositionAccuracy;
            in targetPosition : PositionAccuracy;
            in vesselGeometry : String;
            out plannedPath : NavigationPath;
        }
        
        action ComputeFieldControl {
            in currentPosition : PositionAccuracy;
            in desiredPosition : PositionAccuracy;
            in currentOrientation : OrientationAngle;
            out fieldCommand : MagneticFieldVector;
        }
    }
    
    part def SafetyMonitoringSystem {
        attribute maxAllowedForce : TipForce;
        attribute maxProcedureDuration : DurationValue;
        attribute forceThreshold : TipForce;
        
        port safetySignals {
            in currentForce : TipForce;
            in procedureTime : DurationValue;
            in catheterPosition : PositionAccuracy;
            out emergencyStop : Boolean;
            out warningAlert : String;
        }
        
        action MonitorSafety {
            in force : TipForce;
            in elapsedTime : DurationValue;
            out stopSignal : Boolean;
        }
    }
    
    action def NavigateCatheterToTarget {
        first start;
        then merge monitorPosition;
        
        action monitorPosition {
            in imageData : String;
            out currentPosition : PositionAccuracy;
            out errorDistance : LengthValue;
        }
        
        then decide;
            if monitorPosition.errorDistance > 1.5 [mm] then adjustMagneticField;
            if monitorPosition.errorDistance <= 1.5 [mm] then verifyTarget;
        
        action adjustMagneticField {
            in currentPos : PositionAccuracy = monitorPosition.currentPosition;
            in error : LengthValue = monitorPosition.errorDistance;
            out newFieldVector : MagneticFieldVector;
        }
        then monitorPosition;
        
        action verifyTarget {
            out isTargetReached : Boolean;
        }
        then decide;
            if verifyTarget.isTargetReached then completeNavigation;
            if not verifyTarget.isTargetReached then monitorPosition;
        
        action completeNavigation;
        then done;
    }
    
    state def StereotaxisProcedureStates {
        in attribute currentPhase : ProcedurePhase;
        
        entry; then idle;
        
        state idle;
        transition idle_to_planning
            first idle
            accept startProcedure
            then planning;
        
        state planning {
            do action planPath : NavigationWorkstation::PlanNavigationPath;
        }
        transition planning_to_navigation
            first planning
            accept pathApproved
            then navigation;
        
        state navigation {
            do action navigate : NavigateCatheterToTarget;
        }
        transition navigation_to_intervention
            first navigation
            accept targetReached
            then intervention;
        
        transition navigation_to_retraction
            first navigation
            accept safetyViolation
            then retraction;
        
        state intervention;
        transition intervention_to_retraction
            first intervention
            accept interventionComplete
            then retraction;
        
        state retraction;
        transition retraction_to_completed
            first retraction
            accept catheterRemoved
            then completed;
        
        state completed;
        
        state aborted;
        transition any_to_aborted
            accept emergencyAbort
            then aborted;
    }
    
    part def StereotaxisSystem {
        doc /* A robotic magnetic navigation system that enables precise remote control 
             * of flexible catheters and guidewires through the cardiovascular system 
             * using externally applied magnetic fields for minimally invasive procedures.
             */
        
        attribute currentPhase : ProcedurePhase;
        attribute navigationMode : NavigationMode;
        attribute procedureStartTime : DurationValue;
        attribute totalProcedureTime : DurationValue;
        
        ref item patient : Patient;
        ref item catheter : MagneticCatheter;
        
        part magnetSystem : ExternalMagnetSystem {
            attribute :>> maxFieldStrength = 0.08;
            attribute :>> fieldGradient = 0.15;
        }
        
        part imagingSystem : FluoroscopyImagingSystem {
            attribute :>> frameRate = 15.0;
            attribute :>> resolution = 0.3 [mm];
            attribute :>> exposureDose = 0.5;
        }
        
        part workstation : NavigationWorkstation {
            attribute :>> processingPower = 4.0;
            attribute :>> softwareVersion = "9.2.1";
        }
        
        part safetySystem : SafetyMonitoringSystem {
            attribute :>> maxAllowedForce = 0.8 [N];
            attribute :>> maxProcedureDuration = 180.0 [min];
            attribute :>> forceThreshold = 0.5 [N];
        }
        
        connection imagingToWorkstation connect
            imagingSystem.imageOutput to workstation.sensorInput;
        
        connection workstationToMagnets connect
            workstation.commandOutput to magnetSystem.magneticFieldOutput;
        
        connection safetyToWorkstation connect
            safetySystem.safetySignals to workstation.sensorInput;
        
        perform action primaryNavigation : NavigateCatheterToTarget;
        
        exhibit state procedureLifecycle : StereotaxisProcedureStates {
            in attribute :>> currentPhase = currentPhase;
        }
    }
    
    requirement <'REQ-STEREO-001'> remoteMagneticNavigation {
        doc /* The Stereotaxis system shall enable precise remote magnetic navigation 
             * of flexible medical devices through complex vascular anatomy using 
             * computer-controlled external magnetic fields.
             */
        subject system : StereotaxisSystem;
    }
    
    requirement <'REQ-STEREO-002'> catheterPositioningAccuracy {
        doc /* The system shall achieve catheter tip positioning accuracy within 
             * 1.5 mm of the planned target location during navigation.
             */
        subject system : StereotaxisSystem;
        assert constraint {
            system.imagingSystem.resolution <= 0.5 [mm]
        }
    }
    
    requirement <'REQ-STEREO-003'> magneticFieldControl {
        doc /* The magnetic navigation system shall provide precise control of 
             * magnetic field strength up to 0.08 Tesla and field gradient of 
             * at least 0.15 T/m to manipulate catheter orientation.
             */
        subject magnets : StereotaxisSystem::magnetSystem;
        assert constraint {
            magnets.maxFieldStrength >= 0.08 and
            magnets.fieldGradient >= 0.15
        }
    }
    
    requirement <'REQ-STEREO-004'> realTimeImagingGuidance {
        doc /* The imaging system shall provide real-time fluoroscopic visualization 
             * at minimum 15 frames per second with spatial resolution of 0.5 mm or better.
             */
        subject imaging : StereotaxisSystem::imagingSystem;
        assert constraint {
            imaging.frameRate >= 15.0 and
            imaging.resolution <= 0.5 [mm]
        }
    }
    
    requirement <'REQ-STEREO-005'> safetyMonitoring {
        doc /* The system shall continuously monitor catheter tip forces and automatically 
             * halt navigation if forces exceed 0.8 N or procedure duration exceeds 180 minutes.
             */
        subject safety : StereotaxisSystem::safetySystem;
        assert constraint {
            safety.maxAllowedForce <= 1.0 [N] and
            safety.maxProcedureDuration <= 240.0 [min]
        }
    }
    
    requirement <'REQ-STEREO-006'> navigationModes {
        doc /* The system shall support manual, semi-automated, and fully automated 
             * navigation modes to accommodate varying procedural complexity and 
             * physician preference.
             */
        subject system : StereotaxisSystem;
    }
    
    part stereotaxisSystem : StereotaxisSystem {
        attribute :>> currentPhase = ProcedurePhase::initialization;
        attribute :>> navigationMode = NavigationMode::semiAutomated;
        attribute :>> procedureStartTime = 0.0 [s];
        attribute :>> totalProcedureTime = 0.0 [s];
    }
    
    satisfy remoteMagneticNavigation by stereotaxisSystem;
    satisfy catheterPositioningAccuracy by stereotaxisSystem;
    satisfy magneticFieldControl by stereotaxisSystem.magnetSystem;
    satisfy realTimeImagingGuidance by stereotaxisSystem.imagingSystem;
    satisfy safetyMonitoring by stereotaxisSystem.safetySystem;
    satisfy navigationModes by stereotaxisSystem;
}
