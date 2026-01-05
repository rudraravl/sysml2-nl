package MultileafCollimatorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def LeafPosition :> LengthValue;
    attribute def DoseRate :> Real;
    
    attribute def BeamProfile {
        attribute intensity : Real;
        attribute energyLevel : EnergyValue;
        attribute fieldWidth : LengthValue;
        attribute fieldHeight : LengthValue;
    }
    
    item def RadiationBeam {
        attribute profile : BeamProfile;
        attribute isActive : Boolean;
    }
    
    item def ShapedBeam :> RadiationBeam {
        attribute conformanceAccuracy : LengthValue;
    }
    
    item def TreatmentPlan {
        attribute targetVolume : VolumeValue;
        attribute prescribedDose : Real;
        attribute leafPositionMap : LeafPosition[160];
    }
    
    enum def LeafState {
        idle;
        moving;
        positioned;
        error;
    }
    
    enum def SystemMode {
        standby;
        setup;
        treating;
        paused;
        shutdown;
    }
    
    port def BeamInputPort {
        in beam : RadiationBeam;
    }
    
    port def BeamOutputPort {
        out shapedBeam : ShapedBeam;
    }
    
    port def ControlPort {
        in command : Real;
        out feedback : Real;
    }
    
    port def PlanPort {
        in plan : TreatmentPlan;
    }
    
    part def Leaf {
        attribute position : LeafPosition;
        attribute targetPosition : LeafPosition;
        attribute velocity : Real;
        attribute maxSpeed : Real;
        attribute currentState : LeafState;
        
        port control : ControlPort;
    }
    
    part def LeafBank {
        attribute bankIdentifier : String;
        attribute numberOfLeaves : Integer;
        
        part leaves : Leaf[80];
        
        port bankControl : ControlPort[80];
        
        connection leafControlConnections
            connect leaves.control to bankControl;
    }
    
    part def MotorDrive {
        attribute controlSignal : Real;
        attribute encoderPosition : Real;
        attribute currentDraw : Real;
        
        port motorControl : ControlPort;
    }
    
    part def PositionSensor {
        attribute resolution : LengthValue;
        attribute accuracy : LengthValue;
        attribute reading : LeafPosition;
        
        port sensorOutput;
    }
    
    part def CollimatorController {
        attribute activePlan : TreatmentPlan;
        attribute positionTolerance : LengthValue;
        attribute allLeavesPositioned : Boolean;
        
        port planInput : PlanPort;
        port leafControl : ControlPort[160];
        port statusOutput;
        
        action def LoadTreatmentPlan {
            in plan : TreatmentPlan;
            out loaded : Boolean;
        }
        
        action def PositionAllLeaves {
            in targetPositions : LeafPosition[160];
            out positioningComplete : Boolean;
        }
        
        action def VerifyPositions {
            in actualPositions : LeafPosition[160];
            in targetPositions : LeafPosition[160];
            in tolerance : LengthValue;
            out verified : Boolean;
        }
    }
    
    part def RadiationSource {
        attribute beamEnergy : EnergyValue;
        attribute outputIntensity : Real;
        attribute isEmitting : Boolean;
        
        port beamOutput : BeamOutputPort;
        port enableControl;
        
        action def ActivateBeam {
            in safetyPermit : Boolean;
            out beamOn : Boolean;
        }
        
        action def DeactivateBeam {
            out beamOff : Boolean;
        }
    }
    
    part def SafetyInterlock {
        attribute interlockStatus : Boolean;
        attribute doorClosed : Boolean;
        attribute emergencyStop : Boolean;
        attribute leavesVerified : Boolean;
        
        port safetySignal;
        port interlockControl;
        
        action def CheckSafetyConditions {
            in doorStatus : Boolean;
            in eStopStatus : Boolean;
            in leafStatus : Boolean;
            out safeToOperate : Boolean;
        }
    }
    
    part def MultileafCollimator {
        attribute totalLeaves : Integer;
        attribute maxFieldSize : AreaValue;
        attribute leafWidth : LengthValue;
        attribute positionAccuracy : LengthValue;
        attribute currentMode : SystemMode;
        
        part bankA : LeafBank {
            attribute :>> bankIdentifier = "Bank_A";
            attribute :>> numberOfLeaves = 80;
        }
        
        part bankB : LeafBank {
            attribute :>> bankIdentifier = "Bank_B";
            attribute :>> numberOfLeaves = 80;
        }
        
        part motorDrives : MotorDrive[160];
        part positionSensors : PositionSensor[160];
        part controller : CollimatorController {
            attribute :>> positionTolerance = 0.1 [mm];
        }
        
        part housingStructure {
            attribute material : String;
            attribute shieldingThickness : LengthValue;
        }
        
        port beamInput : BeamInputPort;
        port shapedBeamOutput : BeamOutputPort;
        port planInterface : PlanPort;
        port systemControl;
        
        connection motorControlA
            connect controller.leafControl to motorDrives.motorControl;
        
        connection sensorFeedbackA
            connect positionSensors.sensorOutput to controller.leafControl;
        
        connection bankAControl
            connect motorDrives.motorControl to bankA.bankControl;
        
        connection bankBControl
            connect motorDrives.motorControl to bankB.bankControl;
    }
    
    part radiationTherapySystem {
        part mlc : MultileafCollimator {
            attribute :>> totalLeaves = 160;
            attribute :>> maxFieldSize = 400 [mm^2];
            attribute :>> leafWidth = 5 [mm];
            attribute :>> positionAccuracy = 0.1 [mm];
            attribute :>> currentMode = SystemMode::standby;
        }
        
        part source : RadiationSource {
            attribute :>> beamEnergy = 6 [MeV];
            attribute :>> outputIntensity = 600;
            attribute :>> isEmitting = false;
        }
        
        part safetySystem : SafetyInterlock {
            attribute :>> interlockStatus = true;
            attribute :>> doorClosed = true;
            attribute :>> emergencyStop = false;
            attribute :>> leavesVerified = false;
        }
        
        part treatmentPlanner {
            port planOutput : PlanPort;
        }
        
        connection beamPath
            connect source.beamOutput to mlc.beamInput;
        
        connection planConnection
            connect treatmentPlanner.planOutput to mlc.planInterface;
        
        connection safetyConnection
            connect safetySystem.safetySignal to source.enableControl;
    }
    
    action def MonitorLeafPositions {
        in sensorReadings : LeafPosition[160];
        out currentPositions : LeafPosition[160];
        out maxDeviation : LengthValue;
    }
    
    action def AdjustLeafPositions {
        in targetPositions : LeafPosition[160];
        in currentPositions : LeafPosition[160];
        in tolerance : LengthValue;
        out adjustmentCommands : Real[160];
    }
    
    action def ShapeRadiationBeam {
        in incomingBeam : RadiationBeam;
        in leafConfiguration : LeafPosition[160];
        out shapedBeam : ShapedBeam;
    }
    
    action deliverTreatment {
        first start;
        
        then action loadPlan : radiationTherapySystem.mlc.controller.LoadTreatmentPlan {
            in plan;
            out loaded;
        }
        
        then merge positioningLoop;
        
        then action monitorPositions : MonitorLeafPositions {
            in sensorReadings;
            out currentPositions;
            out maxDeviation;
        }
        
        then decide;
            if monitorPositions.maxDeviation > 0.1 [mm] then adjustPositions;
            if monitorPositions.maxDeviation <= 0.1 [mm] then verifyReady;
        
        action adjustPositions : AdjustLeafPositions {
            in targetPositions = loadPlan.plan.leafPositionMap;
            in currentPositions = monitorPositions.currentPositions;
            in tolerance = 0.1 [mm];
            out adjustmentCommands;
        }
        then positioningLoop;
        
        action verifyReady : radiationTherapySystem.mlc.controller.VerifyPositions {
            in actualPositions = monitorPositions.currentPositions;
            in targetPositions = loadPlan.plan.leafPositionMap;
            in tolerance = 0.1 [mm];
            out verified;
        }
        
        then action checkSafety : radiationTherapySystem.safetySystem.CheckSafetyConditions {
            in doorStatus = radiationTherapySystem.safetySystem.doorClosed;
            in eStopStatus = radiationTherapySystem.safetySystem.emergencyStop;
            in leafStatus = verifyReady.verified;
            out safeToOperate;
        }
        
        then decide;
            if checkSafety.safeToOperate then activateBeam;
            if !checkSafety.safeToOperate then abortTreatment;
        
        action activateBeam : radiationTherapySystem.source.ActivateBeam {
            in safetyPermit = checkSafety.safeToOperate;
            out beamOn;
        }
        
        then action shapeBeam : ShapeRadiationBeam {
            in incomingBeam;
            in leafConfiguration = loadPlan.plan.leafPositionMap;
            out shapedBeam;
        }
        
        then merge treatmentMonitoring;
        
        then action continuousMonitor : MonitorLeafPositions {
            in sensorReadings;
            out currentPositions;
            out maxDeviation;
        }
        
        then decide;
            if treatmentComplete then deactivateBeam;
            if !treatmentComplete && continuousMonitor.maxDeviation <= 0.1 [mm] then treatmentMonitoring;
            if continuousMonitor.maxDeviation > 0.1 [mm] then emergencyStop;
        
        action deactivateBeam : radiationTherapySystem.source.DeactivateBeam {
            out beamOff;
        }
        then completeTreatment;
        
        action emergencyStop;
        then abortTreatment;
        
        action abortTreatment;
        then done;
        
        action completeTreatment;
        then done;
    }
    
    requirement <'REQ-MLC-001'> primaryFunction {
        doc /* The multileaf collimator system shall shape the radiation beam 
             * to precisely conform to the target treatment volume, enabling 
             * delivery of therapeutic radiation dose to tumors while minimizing 
             * exposure to surrounding healthy tissue.
             */
        subject mlc :>> radiationTherapySystem.mlc;
    }
    
    requirement <'REQ-MLC-002'> positioningAccuracy {
        doc /* Each collimator leaf shall be positioned with an accuracy 
             * of 0.1 mm or better to ensure precise beam shaping.
             */
        subject mlc :>> radiationTherapySystem.mlc;
        assert constraint {
            mlc.positionAccuracy <= 0.1 [mm]
        }
    }
    
    requirement <'REQ-MLC-003'> fieldCoverage {
        doc /* The collimator shall support a maximum field size of at least 
             * 400 square millimeters to accommodate various treatment areas.
             */
        subject mlc :>> radiationTherapySystem.mlc;
        assert constraint {
            mlc.maxFieldSize >= 400 [mm^2]
        }
    }
    
    requirement <'REQ-MLC-004'> safetyInterlock {
        doc /* The system shall prevent radiation activation unless all leaves 
             * are verified to be in their correct positions within tolerance 
             * and all safety interlocks are satisfied.
             */
        subject system :>> radiationTherapySystem;
    }
    
    requirement <'REQ-MLC-005'> leafCount {
        doc /* The collimator shall incorporate 160 individually controllable 
             * leaves to provide fine-grained beam shaping capability.
             */
        subject mlc :>> radiationTherapySystem.mlc;
        assert constraint {
            mlc.totalLeaves == 160
        }
    }
    
    requirement <'REQ-MLC-006'> emergencyResponse {
        doc /* The system shall be capable of immediate radiation shutdown 
             * and safe state transition in response to emergency conditions.
             */
        subject system :>> radiationTherapySystem;
    }
    
    satisfy primaryFunction by radiationTherapySystem.mlc;
    satisfy positioningAccuracy by radiationTherapySystem.mlc;
    satisfy fieldCoverage by radiationTherapySystem.mlc;
    satisfy safetyInterlock by radiationTherapySystem.safetySystem;
    satisfy leafCount by radiationTherapySystem.mlc;
    satisfy emergencyResponse by radiationTherapySystem;
}
