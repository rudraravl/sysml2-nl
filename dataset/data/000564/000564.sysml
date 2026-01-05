package CannulatedBarSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def DiameterValue :> LengthValue;
    attribute def ForceValue :> Real;
    attribute def TorqueValue :> Real;
    attribute def AngularVelocityValue :> Real;

    enum def MaterialType {
        stainlessSteel;
        titaniumAlloy;
        carbonSteel;
    }

    enum def OperationalMode {
        idle;
        positioning;
        drilling;
        reaming;
        fastening;
        complete;
    }

    item def GuideWire {
        attribute diameter : DiameterValue;
        attribute length : LengthValue;
        attribute material : MaterialType;
    }

    item def CuttingTool {
        attribute outerDiameter : DiameterValue;
        attribute innerDiameter : DiameterValue;
        attribute length : LengthValue;
        attribute cuttingSpeed : AngularVelocityValue;
    }

    item def Fastener {
        attribute diameter : DiameterValue;
        attribute length : LengthValue;
        attribute threadPitch : LengthValue;
        attribute installationTorque : TorqueValue;
    }

    port def GuidancePort {
        in item wire : GuideWire;
        out item wire_out : GuideWire;
    }

    port def ToolPort {
        in item tool : CuttingTool;
        attribute appliedForce : ForceValue;
        attribute rotationalSpeed : AngularVelocityValue;
    }

    port def FastenerPort {
        in item fastener : Fastener;
        attribute appliedTorque : TorqueValue;
    }

    port def ManualControlPort {
        attribute gripForce : ForceValue;
        attribute positioningAngle : Real;
    }

    part def CannulatedBar {
        doc /* Hollow cylindrical bar with internal channel for guide wire passage */
        
        attribute outerDiameter : DiameterValue;
        attribute innerDiameter : DiameterValue;
        attribute barLength : LengthValue;
        attribute wallThickness : LengthValue;
        attribute material : MaterialType;
        attribute straightnessTolerance : LengthValue;
        attribute surfaceFinish : Real;

        port proximalEnd : GuidancePort;
        port distalEnd : GuidancePort;

        assert constraint wallThicknessDefinition {
            wallThickness == (outerDiameter - innerDiameter) / 2.0
        }

        assert constraint channelClearance {
            in wireDiameter : DiameterValue;
            innerDiameter >= wireDiameter + 0.5 [mm]
        }

        assert constraint structuralIntegrity {
            wallThickness >= 1.5 [mm]
        }
    }

    part def ErgonomicHandle {
        doc /* Handle assembly for manual control and positioning */
        
        attribute gripDiameter : DiameterValue;
        attribute handleLength : LengthValue;
        attribute maxGripForce : ForceValue;
        attribute texturedSurface : Boolean;

        port controlInterface : ManualControlPort;
        port barAttachment : GuidancePort;
    }

    part def DrillGuide {
        doc /* Precision guide sleeve for drilling operations */
        
        attribute guideDiameter : DiameterValue;
        attribute guideLength : LengthValue;
        attribute alignmentTolerance : LengthValue;

        port wireChannel : GuidancePort;
        port drillInterface : ToolPort;
    }

    part def DepthStop {
        doc /* Adjustable depth control mechanism */
        
        attribute maxDepth : LengthValue;
        attribute currentDepth : LengthValue;
        attribute adjustmentIncrement : LengthValue;

        assert constraint depthLimit {
            currentDepth <= maxDepth
        }
    }

    part def TargetSite {
        doc /* Surgical or mechanical target location */
        
        attribute accessAngle : Real;
        attribute targetDepth : LengthValue;
        attribute hardness : Real;

        port entryPoint : GuidancePort;
    }

    action def PositionSystem {
        doc /* Align cannulated bar with target trajectory */
        
        in targetAngle : Real;
        in targetDepth : LengthValue;
        out aligned : Boolean;
        out positionAccuracy : LengthValue;
    }

    action def InsertGuideWire {
        doc /* Insert guide wire through cannulated channel */
        
        in wire : GuideWire;
        in insertionDepth : LengthValue;
        out wirePositioned : Boolean;
        out actualDepth : LengthValue;
    }

    action def PerformDrilling {
        doc /* Execute drilling operation over guide wire */
        
        in tool : CuttingTool;
        in drillDepth : LengthValue;
        in rotationSpeed : AngularVelocityValue;
        out holeCreated : Boolean;
        out holeDiameter : DiameterValue;
    }

    action def InstallFastener {
        doc /* Install fastener through prepared channel */
        
        in fastener : Fastener;
        in targetTorque : TorqueValue;
        out fastenerSeated : Boolean;
        out finalTorque : TorqueValue;
    }

    action def RemoveInstrumentation {
        doc /* Remove guide wire and cannulated bar */
        
        out systemRemoved : Boolean;
    }

    action def ExecuteGuidedProcedure {
        doc /* Complete guided drilling and fastening procedure */
        
        in guideWire : GuideWire;
        in cuttingTool : CuttingTool;
        in fastener : Fastener;
        in targetDepth : LengthValue;
        in targetAngle : Real;
        out procedureSuccess : Boolean;

        first start;
        
        then action position : PositionSystem {
            in targetAngle = targetAngle;
            in targetDepth = targetDepth;
            out aligned : Boolean;
            out positionAccuracy : LengthValue;
        }

        then decide;
            if position.aligned then insertWire;
            else repositionSystem;

        action repositionSystem;
        then position;

        action insertWire : InsertGuideWire {
            in wire = guideWire;
            in insertionDepth = targetDepth;
            out wirePositioned : Boolean;
            out actualDepth : LengthValue;
        }

        then decide;
            if insertWire.wirePositioned then drill;
            else adjustWire;

        action adjustWire;
        then insertWire;

        action drill : PerformDrilling {
            in tool = cuttingTool;
            in drillDepth = targetDepth;
            in rotationSpeed = 1200.0;
            out holeCreated : Boolean;
            out holeDiameter : DiameterValue;
        }

        then action install : InstallFastener {
            in fastener = fastener;
            in targetTorque = fastener.installationTorque;
            out fastenerSeated : Boolean;
            out finalTorque : TorqueValue;
        }

        then action remove : RemoveInstrumentation {
            out systemRemoved : Boolean;
        }

        then decide;
            if install.fastenerSeated and remove.systemRemoved then success;
            else failure;

        action success {
            assign procedureSuccess = true;
        }
        then done;

        action failure {
            assign procedureSuccess = false;
        }
        then done;
    }

    state def SystemOperationStateMachine {
        entry; then idle;

        state idle {
            doc /* System ready for use */
        }
        transition idle_to_positioning
            first idle
            accept StartProcedure
            then positioning;

        state positioning {
            doc /* Aligning system with target */
            entry action alignWithTarget;
        }
        transition positioning_to_wireInsertion
            first positioning
            if alignmentAchieved
            then wireInsertion;

        state wireInsertion {
            doc /* Inserting guide wire through cannula */
            entry action advanceWire;
        }
        transition wireInsertion_to_drilling
            first wireInsertion
            if wireAtDepth
            then drilling;

        state drilling {
            doc /* Drilling over guide wire */
            do action rotateTool;
            do action advanceTool;
        }
        transition drilling_to_reaming
            first drilling
            if holeComplete
            then reaming;

        state reaming {
            doc /* Enlarging hole to final diameter */
            do action rotateReamer;
        }
        transition reaming_to_fastening
            first reaming
            if finalDiameterAchieved
            then fastening;

        state fastening {
            doc /* Installing fastener */
            entry action insertFastener;
            do action applyTorque;
        }
        transition fastening_to_complete
            first fastening
            if torqueReached
            then complete;

        state complete {
            doc /* Procedure finished successfully */
            entry action removeSystem;
        }
        transition complete_to_idle
            first complete
            accept ResetSystem
            then idle;

        transition positioning_to_idle
            first positioning
            accept AbortProcedure
            then idle;

        transition wireInsertion_to_idle
            first wireInsertion
            accept AbortProcedure
            then idle;

        transition drilling_to_idle
            first drilling
            accept AbortProcedure
            then idle;
    }

    part def CannulatedBarGuidanceSystem {
        doc /* Integrated system for precision guided drilling and fastening operations */

        attribute systemLength : LengthValue;
        attribute maxOperatingForce : ForceValue;
        attribute maxOperatingTorque : TorqueValue;
        attribute currentMode : OperationalMode;

        part cannulatedBar : CannulatedBar {
            attribute :>> outerDiameter : DiameterValue = 8.0 [mm];
            attribute :>> innerDiameter : DiameterValue = 3.5 [mm];
            attribute :>> barLength : LengthValue = 250.0 [mm];
            attribute :>> wallThickness : LengthValue = 2.25 [mm];
            attribute :>> material = MaterialType::stainlessSteel;
            attribute :>> straightnessTolerance : LengthValue = 0.2 [mm];
            attribute :>> surfaceFinish = 0.8;
        }

        part handle : ErgonomicHandle {
            attribute :>> gripDiameter : DiameterValue = 28.0 [mm];
            attribute :>> handleLength : LengthValue = 120.0 [mm];
            attribute :>> maxGripForce : ForceValue = 200.0;
            attribute :>> texturedSurface = true;
        }

        part drillGuide : DrillGuide {
            attribute :>> guideDiameter : DiameterValue = 6.5 [mm];
            attribute :>> guideLength : LengthValue = 45.0 [mm];
            attribute :>> alignmentTolerance : LengthValue = 0.1 [mm];
        }

        part depthStop : DepthStop {
            attribute :>> maxDepth : LengthValue = 100.0 [mm];
            attribute :>> currentDepth : LengthValue = 60.0 [mm];
            attribute :>> adjustmentIncrement : LengthValue = 1.0 [mm];
        }

        part targetSite : TargetSite {
            attribute :>> accessAngle = 45.0;
            attribute :>> targetDepth : LengthValue = 55.0 [mm];
            attribute :>> hardness = 850.0;
        }

        connection handleToBar connect
            handle.barAttachment to cannulatedBar.proximalEnd;

        connection barToGuide connect
            cannulatedBar.distalEnd to drillGuide.wireChannel;

        connection guideToTarget connect
            drillGuide.wireChannel to targetSite.entryPoint;

        item guideWire : GuideWire {
            attribute :>> diameter : DiameterValue = 2.8 [mm];
            attribute :>> length : LengthValue = 350.0 [mm];
            attribute :>> material = MaterialType::stainlessSteel;
        }

        item drillBit : CuttingTool {
            attribute :>> outerDiameter : DiameterValue = 6.0 [mm];
            attribute :>> innerDiameter : DiameterValue = 3.0 [mm];
            attribute :>> length : LengthValue = 180.0 [mm];
            attribute :>> cuttingSpeed : AngularVelocityValue = 1500.0;
        }

        item screw : Fastener {
            attribute :>> diameter : DiameterValue = 6.5 [mm];
            attribute :>> length : LengthValue = 65.0 [mm];
            attribute :>> threadPitch : LengthValue = 1.25 [mm];
            attribute :>> installationTorque : TorqueValue = 4.5;
        }

        perform action guidedProcedure : ExecuteGuidedProcedure {
            in guideWire = guideWire;
            in cuttingTool = drillBit;
            in fastener = screw;
            in targetDepth = targetSite.targetDepth;
            in targetAngle = targetSite.accessAngle;
            out procedureSuccess : Boolean;
        }

        exhibit state operationStateMachine : SystemOperationStateMachine;

        assert constraint systemLengthConstraint {
            systemLength == handle.handleLength + cannulatedBar.barLength + drillGuide.guideLength
        }

        assert constraint forceLimit {
            maxOperatingForce <= handle.maxGripForce
        }
    }

    requirement <'REQ-100'> primaryFunction {
        doc /* The Cannulated Bar Guidance System shall provide a stable, aligned pathway 
             * for guide wire insertion and subsequent drilling operations to enable precise 
             * placement of fasteners at predetermined depths and angles in target material. */

        subject system : CannulatedBarGuidanceSystem;

        require wireGuidance;
        require drillingAccuracy;
        require fastenerPlacement;
    }

    requirement <'REQ-101'> wireGuidance {
        doc /* The system shall guide a wire through the cannulated channel with 
             * sufficient clearance to prevent binding during insertion and removal. */

        subject bar :>> CannulatedBarGuidanceSystem::cannulatedBar;
        in wire :>> CannulatedBarGuidanceSystem::guideWire;

        assert constraint {
            bar.innerDiameter >= wire.diameter + 0.5 [mm]
        }
    }

    requirement <'REQ-102'> drillingAccuracy {
        doc /* The system shall maintain drilling alignment within 0.5 mm of the 
             * guide wire trajectory throughout the drilling operation. */

        subject guide :>> CannulatedBarGuidanceSystem::drillGuide;

        assert constraint {
            guide.alignmentTolerance <= 0.5 [mm]
        }
    }

    requirement <'REQ-103'> fastenerPlacement {
        doc /* The system shall enable fastener installation to the specified depth 
             * with torque control to ensure proper seating without damage. */

        subject system :>> CannulatedBarGuidanceSystem;
        in fastener :>> CannulatedBarGuidanceSystem::screw;

        assert constraint {
            system.maxOperatingTorque >= fastener.installationTorque
        }
    }

    requirement <'REQ-104'> structuralStrength {
        doc /* The cannulated bar shall maintain structural integrity under maximum 
             * operating forces without permanent deformation. */

        subject bar :>> CannulatedBarGuidanceSystem::cannulatedBar;
        subject system :>> CannulatedBarGuidanceSystem;

        assert constraint {
            bar.wallThickness >= 1.5 [mm] and
            system.maxOperatingForce <= 250.0
        }
    }

    requirement <'REQ-105'> depthControl {
        doc /* The system shall provide adjustable depth control with 1 mm increments 
             * to prevent over-penetration of the target material. */

        subject depthStop :>> CannulatedBarGuidanceSystem::depthStop;

        assert constraint {
            depthStop.adjustmentIncrement == 1.0 [mm] and
            depthStop.currentDepth <= depthStop.maxDepth
        }
    }

    part systemInstance : CannulatedBarGuidanceSystem;

    satisfy primaryFunction by systemInstance;
    satisfy wireGuidance by systemInstance.cannulatedBar;
    satisfy drillingAccuracy by systemInstance.drillGuide;
    satisfy fastenerPlacement by systemInstance;
    satisfy structuralStrength by systemInstance.cannulatedBar;
    satisfy depthControl by systemInstance.depthStop;
}
