package PaintRobotPrimaryTaskSystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def Millimeter :> Real {
        unit = "mm";
    }

    attribute def LiterPerMinute :> Real {
        unit = "L/min";
    }

    attribute def Bar :> Real {
        unit = "bar";
    }

    attribute def DegreeCelsius :> Real {
        unit = "degC";
    }

    attribute def RevolutionsPerMinute :> Real {
        unit = "rpm";
    }

    item def PaintMaterial {
        attribute colorCode : String;
        attribute viscosity : Real;
        attribute solidsFraction : Percent;
        attribute temperature : DegreeCelsius;
    }

    item def CompressedAir {
        attribute pressure : Bar;
        attribute flowRate : LiterPerMinute;
        attribute dewPoint : DegreeCelsius;
    }

    item def Workpiece {
        attribute serialNumber : String;
        attribute surfaceArea : AreaValue;
        attribute requiredCoatingThickness : Millimeter;
        attribute allowableOverspray : Percent;
    }

    item def PaintedWorkpiece :> Workpiece {
        attribute measuredCoatingThickness : Millimeter;
        attribute coverage : Percent;
        attribute accepted : Boolean;
    }

    item def MotionCommand {
        attribute targetX : LengthValue;
        attribute targetY : LengthValue;
        attribute targetZ : LengthValue;
        attribute toolAngleA : AngleValue;
        attribute toolAngleB : AngleValue;
        attribute linearSpeed : SpeedValue;
    }

    item def SprayCommand {
        attribute enableSpray : Boolean;
        attribute paintFlow : LiterPerMinute;
        attribute atomizingAirPressure : Bar;
        attribute fanAirPressure : Bar;
        attribute patternWidth : Millimeter;
    }

    item def InspectionResult {
        attribute coatingThickness : Millimeter;
        attribute coverage : Percent;
        attribute defectCount : Integer;
        attribute pass : Boolean;
    }

    item def SafetySignal {
        attribute emergencyStopActive : Boolean;
        attribute guardDoorClosed : Boolean;
        attribute boothVentilationOk : Boolean;
        attribute fireSuppressionReady : Boolean;
    }

    port def PaintMaterialPort {
        in item paintIn : PaintMaterial;
        out item paintReturn : PaintMaterial;
    }

    port def AirPort {
        in item airIn : CompressedAir;
    }

    port def WorkpieceInputPort {
        in item rawWorkpiece : Workpiece;
    }

    port def WorkpieceOutputPort {
        out item finishedWorkpiece : PaintedWorkpiece;
    }

    port def MotionCommandPort {
        out item command : MotionCommand;
    }

    port def SprayCommandPort {
        out item command : SprayCommand;
    }

    port def SafetyPort {
        in item signal : SafetySignal;
    }

    port def InspectionPort {
        out item result : InspectionResult;
    }

    port def RobotToolPort {
        in item sprayCommand : SprayCommand;
        in item motionCommand : MotionCommand;
        in item paintSupply : PaintMaterial;
        in item atomizingAir : CompressedAir;
    }

    part def PaintRobotSystem {
        attribute nominalThroughput : Integer = 30;
        attribute maximumWorkpieceMass : MassValue = 25 [kg];
        attribute coatingThicknessTarget : Millimeter = 0.08;
        attribute minimumCoverage : Percent = 98.0;

        port workpieceIn : WorkpieceInputPort;
        port workpieceOut : WorkpieceOutputPort;
        port plantSafety : SafetyPort;

        part booth : PaintBooth;
        part robot : SixAxisPaintRobot;
        part controller : PaintCellController;
        part paintSupply : PaintSupplyUnit;
        part airSupply : AirPreparationUnit;
        part conveyor : WorkpieceConveyor;
        part fixture : RotaryFixture;
        part vision : VisionInspectionUnit;
        part exhaust : VentilationAndFiltrationUnit;
        part safetySystem : SafetyInterlockSystem;

        connect workpieceIn.rawWorkpiece to conveyor.input.rawWorkpiece;
        connect conveyor.positionedWorkpiece to fixture.loadedWorkpiece;
        connect fixture.workpieceForPainting to robot.workpieceTarget;
        connect robot.paintedOutput to vision.inspectedWorkpiece;
        connect vision.acceptedWorkpiece to conveyor.output.finishedWorkpiece;
        connect conveyor.output.finishedWorkpiece to workpieceOut.finishedWorkpiece;

        connect paintSupply.paintOut.paintIn to robot.paintPort.paintSupply;
        connect airSupply.processAir.airIn to robot.paintPort.atomizingAir;
        connect controller.motionOut.command to robot.motionPort.motionCommand;
        connect controller.sprayOut.command to robot.paintPort.sprayCommand;
        connect plantSafety.signal to safetySystem.externalSafety.signal;
        connect safetySystem.robotSafety.signal to robot.safety.signal;
        connect safetySystem.boothSafety.signal to booth.safety.signal;
        connect booth.exhaustFlow to exhaust.boothFlow;
        connect vision.inspectionOut.result to controller.inspectionIn.result;

        perform action paintPrimaryTask : PaintWorkpiece {
            in item workpiece = workpieceIn.rawWorkpiece;
            out item painted = workpieceOut.finishedWorkpiece;
        }
    }

    part def SixAxisPaintRobot {
        attribute payloadCapacity : MassValue = 10 [kg];
        attribute reach : LengthValue = 2.7 [m];
        attribute repeatability : Millimeter = 0.2;
        attribute maximumTcpSpeed : SpeedValue = 2.0 [m/s];

        port paintPort : RobotToolPort;
        port motionPort {
            in item motionCommand : MotionCommand;
        }
        port safety : SafetyPort;

        item workpieceTarget : Workpiece;
        item paintedOutput : PaintedWorkpiece;

        part base : RobotBase;
        part arm : ArticulatedArm;
        part wrist : HollowWrist;
        part sprayApplicator : ElectrostaticSprayApplicator;
        part teachPendant : TeachPendant;

        connect arm.wristInterface to wrist.armInterface;
        connect wrist.toolInterface to sprayApplicator.robotInterface;

        state def RobotOperationalState {
            entry action initializeServoDrives;
            state Off;
            state Standby;
            state Homing;
            state Ready;
            state Painting;
            state Paused;
            state Faulted;
            state EmergencyStopped;

            transition first Off then Standby
                accept PowerApplied;

            transition Standby then Homing
                accept StartUpCommand
                do action enableServoPower;

            transition Homing then Ready
                accept HomeComplete;

            transition Ready then Painting
                accept PaintCycleStart
                if safety.signal.guardDoorClosed and safety.signal.boothVentilationOk and not safety.signal.emergencyStopActive;

            transition Painting then Ready
                accept PaintPathComplete
                do action closeApplicatorNeedle;

            transition Painting then Paused
                accept PauseCommand
                do action closeApplicatorNeedle;

            transition Paused then Painting
                accept ResumeCommand
                if safety.signal.guardDoorClosed and safety.signal.boothVentilationOk;

            transition Ready then Faulted
                accept RobotFault;

            transition Painting then Faulted
                accept RobotFault
                do action closeApplicatorNeedle;

            transition Faulted then Standby
                accept FaultReset
                if not safety.signal.emergencyStopActive;

            transition Off then EmergencyStopped
                accept EmergencyStopPressed;

            transition Standby then EmergencyStopped
                accept EmergencyStopPressed;

            transition Homing then EmergencyStopped
                accept EmergencyStopPressed
                do action disableServoPower;

            transition Ready then EmergencyStopped
                accept EmergencyStopPressed
                do action disableServoPower;

            transition Painting then EmergencyStopped
                accept EmergencyStopPressed
                do action closeApplicatorNeedle, disableServoPower;

            transition EmergencyStopped then Standby
                accept EmergencyStopReset
                if safety.signal.guardDoorClosed;
        }

        exhibit state robotState : RobotOperationalState;
    }

    part def RobotBase {
        attribute mountingStiffness : Real;
        attribute enclosureRating : String = "IP65";
    }

    part def ArticulatedArm {
        attribute axisCount : Integer = 6;
        attribute axis1Limit : AngleValue = 170 [deg];
        attribute axis2Limit : AngleValue = 120 [deg];
        attribute axis3Limit : AngleValue = 165 [deg];
        attribute axis4Limit : AngleValue = 180 [deg];
        attribute axis5Limit : AngleValue = 135 [deg];
        attribute axis6Limit : AngleValue = 360 [deg];

        port wristInterface;
    }

    part def HollowWrist {
        attribute internalHoseDiameter : Millimeter = 10;
        attribute solventCompatible : Boolean = true;

        port armInterface;
        port toolInterface;
    }

    part def ElectrostaticSprayApplicator {
        attribute maximumVoltage : ElectricPotentialValue = 100 [kV];
        attribute nominalPaintFlow : LiterPerMinute = 0.45;
        attribute transferEfficiency : Percent = 78.0;
        attribute nozzleDiameter : Millimeter = 1.2;

        port robotInterface;
        port paintIn : PaintMaterialPort;
        port airIn : AirPort;

        action atomizeAndChargePaint {
            in item paint : PaintMaterial;
            in item air : CompressedAir;
            in item spray : SprayCommand;
            out attribute chargedDropletFlow : LiterPerMinute;
        }
    }

    part def TeachPendant {
        attribute displaySize : LengthValue = 0.18 [m];
        attribute emergencyStopButtonPresent : Boolean = true;
    }

    part def PaintCellController {
        attribute controlCycleTime : TimeValue = 0.004 [s];
        attribute storedPrograms : Integer = 50;

        port motionOut : MotionCommandPort;
        port sprayOut : SprayCommandPort;
        port inspectionIn {
            in item result : InspectionResult;
        }

        action computePaintPath {
            in item workpiece : Workpiece;
            out item motionProfile : MotionCommand;
        }

        action regulateSpray {
            in item workpiece : Workpiece;
            out item sprayProfile : SprayCommand;
        }

        action evaluateInspection {
            in item inspection : InspectionResult;
            out attribute reworkRequired : Boolean;
        }
    }

    part def PaintSupplyUnit {
        attribute tankCapacity : VolumeValue = 60 [L];
        attribute operatingPressure : Bar = 3.5;
        attribute filtrationRating : Millimeter = 0.025;
        attribute minimumLevel : Percent = 15.0;

        port paintOut : PaintMaterialPort;

        part reservoir : PaintReservoir;
        part pump : GearPump;
        part filter : InlinePaintFilter;
        part regulator : FluidPressureRegulator;

        connect reservoir.paintOutlet to pump.paintIn;
        connect pump.paintOut to filter.paintIn;
        connect filter.paintOut to regulator.paintIn;
        connect regulator.paintOut to paintOut.paintIn;
    }

    part def PaintReservoir {
        attribute capacity : VolumeValue = 60 [L];
        attribute currentLevel : Percent;
        port paintOutlet {
            out item paint : PaintMaterial;
        }
    }

    part def GearPump {
        attribute maximumFlow : LiterPerMinute = 2.0;
        attribute motorSpeed : RevolutionsPerMinute = 900;
        port paintIn {
            in item paint : PaintMaterial;
        }
        port paintOut {
            out item paint : PaintMaterial;
        }
    }

    part def InlinePaintFilter {
        attribute particleLimit : Millimeter = 0.025;
        port paintIn {
            in item paint : PaintMaterial;
        }
        port paintOut {
            out item paint : PaintMaterial;
        }
    }

    part def FluidPressureRegulator {
        attribute setPressure : Bar = 3.5;
        port paintIn {
            in item paint : PaintMaterial;
        }
        port paintOut {
            out item paint : PaintMaterial;
        }
    }

    part def AirPreparationUnit {
        attribute supplyPressure : Bar = 6.0;
        attribute outletPressure : Bar = 4.5;
        attribute maximumFlow : LiterPerMinute = 800;

        port processAir : AirPort;

        part dryer : AirDryer;
        part coalescingFilter : CoalescingFilter;
        part regulator : AirPressureRegulator;
    }

    part def AirDryer {
        attribute dewPointCapability : DegreeCelsius = -20;
    }

    part def CoalescingFilter {
        attribute oilRemovalEfficiency : Percent = 99.9;
    }

    part def AirPressureRegulator {
        attribute setPressure : Bar = 4.5;
    }

    part def WorkpieceConveyor {
        attribute conveyorSpeed : SpeedValue = 0.2 [m/s];
        attribute positionalAccuracy : Millimeter = 1.0;

        port input : WorkpieceInputPort;
        port output : WorkpieceOutputPort;

        item positionedWorkpiece : Workpiece;

        action indexWorkpiece {
            in item raw : Workpiece;
            out item positioned : Workpiece;
        }
    }

    part def RotaryFixture {
        attribute rotationSpeed : RevolutionsPerMinute = 12;
        attribute angularAccuracy : AngleValue = 0.5 [deg];
        attribute groundingResistance : ResistanceValue = 500 [ohm];

        item loadedWorkpiece : Workpiece;
        item workpieceForPainting : Workpiece;

        state def FixtureState {
            state Empty;
            state Loaded;
            state Clamped;
            state Rotating;
            state Released;

            transition first Empty then Loaded accept WorkpieceArrived;
            transition Loaded then Clamped accept ClampCommand;
            transition Clamped then Rotating accept PaintCycleStart;
            transition Rotating then Clamped accept PaintCycleComplete;
            transition Clamped then Released accept ReleaseCommand;
            transition Released then Empty accept WorkpieceRemoved;
        }

        exhibit state fixtureState : FixtureState;
    }

    part def PaintBooth {
        attribute boothLength : LengthValue = 6.0 [m];
        attribute boothWidth : LengthValue = 4.0 [m];
        attribute boothHeight : LengthValue = 3.2 [m];
        attribute faceVelocity : SpeedValue = 0.5 [m/s];
        attribute illuminationLevel : IlluminanceValue = 800 [lx];

        port safety : SafetyPort;
        port exhaustFlow {
            out item air : CompressedAir;
        }

        part enclosure : BoothEnclosure;
        part lighting : ExplosionProofLighting;
        part fireSuppression : FireSuppressionUnit;
    }

    part def BoothEnclosure {
        attribute material : String = "stainless steel";
        attribute doorCount : Integer = 2;
    }

    part def ExplosionProofLighting {
        attribute power : PowerValue = 500 [W];
        attribute certifiedForPaintVapor : Boolean = true;
    }

    part def FireSuppressionUnit {
        attribute agentMass : MassValue = 20 [kg];
        attribute ready : Boolean;
    }

    part def VentilationAndFiltrationUnit {
        attribute nominalFlow : VolumeFlowRateValue = 12000 [m^3/h];
        attribute filterEfficiency : Percent = 95.0;
        attribute minimumBoothVelocity : SpeedValue = 0.4 [m/s];

        port boothFlow {
            in item air : CompressedAir;
        }

        part exhaustFan : ExhaustFan;
        part oversprayFilter : OversprayFilter;
        part stack : ExhaustStack;
    }

    part def ExhaustFan {
        attribute motorPower : PowerValue = 7.5 [kW];
        attribute speed : RevolutionsPerMinute = 1450;
    }

    part def OversprayFilter {
        attribute captureEfficiency : Percent = 95.0;
        attribute pressureDropLimit : PressureValue = 250 [Pa];
    }

    part def ExhaustStack {
        attribute height : LengthValue = 8.0 [m];
    }

    part def VisionInspectionUnit {
        attribute cameraResolution : Integer = 12000000;
        attribute thicknessMeasurementAccuracy : Millimeter = 0.005;
        attribute inspectionTime : TimeValue = 8 [s];

        port inspectionOut : InspectionPort;

        item inspectedWorkpiece : PaintedWorkpiece;
        item acceptedWorkpiece : PaintedWorkpiece;

        action inspectCoating {
            in item painted : PaintedWorkpiece;
            out item result : InspectionResult;
        }
    }

    part def SafetyInterlockSystem {
        attribute safetyIntegrityLevel : String = "SIL 2";
        attribute emergencyStopResponseTime : TimeValue = 0.08 [s];

        port externalSafety : SafetyPort;
        port robotSafety {
            out item signal : SafetySignal;
        }
        port boothSafety {
            out item signal : SafetySignal;
        }

        part emergencyStopCircuit : EmergencyStopCircuit;
        part guardDoorSwitches : GuardDoorSwitchSet;
        part ventilationMonitor : VentilationMonitor;
        part fireMonitor : FireSuppressionMonitor;

        action combineSafetyInputs {
            in item external : SafetySignal;
            out item robotSafe : SafetySignal;
            out item boothSafe : SafetySignal;
        }
    }

    part def EmergencyStopCircuit {
        attribute channelCount : Integer = 2;
        attribute resetRequired : Boolean = true;
    }

    part def GuardDoorSwitchSet {
        attribute switchCount : Integer = 4;
        attribute lockedDuringPainting : Boolean = true;
    }

    part def VentilationMonitor {
        attribute minimumVelocity : SpeedValue = 0.4 [m/s];
    }

    part def FireSuppressionMonitor {
        attribute pressureOk : Boolean;
        attribute dischargeDetected : Boolean;
    }

    action def PaintWorkpiece {
        in item workpiece : Workpiece;
        out item painted : PaintedWorkpiece;

        first start;
        then load : LoadWorkpiece {
            in item raw = workpiece;
        }
        then verifySafety : VerifyPaintCellSafety;
        then preparePaint : PreparePaintMaterial;
        then generatePath : GenerateSprayPath {
            in item target = workpiece;
        }
        then executePainting : ExecuteRobotPainting {
            in item target = workpiece;
        }
        then flashOff : FlashOffCoating;
        then inspect : InspectPaintedWorkpiece;
        then unload : UnloadPaintedWorkpiece;
        then done;

        flow load.positioned to executePainting.target;
        flow executePainting.painted to flashOff.paintedIn;
        flow flashOff.paintedOut to inspect.paintedIn;
        flow inspect.acceptedPainted to unload.finished;
        flow unload.finished to painted;
    }

    action def LoadWorkpiece {
        in item raw : Workpiece;
        out item positioned : Workpiece;
    }

    action def VerifyPaintCellSafety {
        out attribute safeToPaint : Boolean;
    }

    action def PreparePaintMaterial {
        out item paintReady : PaintMaterial;
    }

    action def GenerateSprayPath {
        in item target : Workpiece;
        out item motion : MotionCommand;
        out item spray : SprayCommand;
    }

    action def ExecuteRobotPainting {
        in item target : Workpiece;
        out item painted : PaintedWorkpiece;
    }

    action def FlashOffCoating {
        in item paintedIn : PaintedWorkpiece;
        out item paintedOut : PaintedWorkpiece;
    }

    action def InspectPaintedWorkpiece {
        in item paintedIn : PaintedWorkpiece;
        out item result : InspectionResult;
        out item acceptedPainted : PaintedWorkpiece;
    }

    action def UnloadPaintedWorkpiece {
        in item finished : PaintedWorkpiece;
    }

    requirement def PrimaryTaskRequirement {
        doc /* The robotic system shall perform its primary production task by applying paint to workpieces using a paint robot. */
        subject system : PaintRobotSystem;
        require constraint {
            system.robot.payloadCapacity >= 10 [kg]
        }
    }

    requirement def CoatingCoverageRequirement {
        doc /* The paint robot shall achieve at least 98 percent coating coverage on each accepted workpiece. */
        subject result : InspectionResult;
        require constraint {
            result.coverage >= 98.0
        }
    }

    requirement def CoatingThicknessRequirement {
        doc /* The accepted coating thickness shall remain within plus or minus 0.015 mm of the target 0.08 mm coating thickness. */
        subject result : InspectionResult;
        require constraint {
            result.coatingThickness >= 0.065 and result.coatingThickness <= 0.095
        }
    }

    requirement def ThroughputRequirement {
        doc /* The paint cell shall complete at least 30 accepted painted workpieces per hour under nominal production conditions. */
        subject system : PaintRobotSystem;
        require constraint {
            system.nominalThroughput >= 30
        }
    }

    requirement def VentilationRequirement {
        doc /* The booth ventilation shall maintain an average face velocity of at least 0.4 m/s during spraying. */
        subject booth : PaintBooth;
        require constraint {
            booth.faceVelocity >= 0.4 [m/s]
        }
    }

    requirement def SafetyInterlockRequirement {
        doc /* The robot shall not enter the Painting state unless the emergency stop is inactive, guard doors are closed, booth ventilation is acceptable, and fire suppression is ready. */
        subject safety : SafetySignal;
        require constraint {
            not safety.emergencyStopActive and safety.guardDoorClosed and safety.boothVentilationOk and safety.fireSuppressionReady
        }
    }

    requirement def EmergencyStopRequirement {
        doc /* Emergency stop activation shall remove robot servo power and close the spray applicator needle within 0.1 seconds. */
        subject safetySystem : SafetyInterlockSystem;
        require constraint {
            safetySystem.emergencyStopResponseTime <= 0.1 [s]
        }
    }

    requirement def TransferEfficiencyRequirement {
        doc /* The electrostatic spray applicator shall provide at least 75 percent paint transfer efficiency. */
        subject applicator : ElectrostaticSprayApplicator;
        require constraint {
            applicator.transferEfficiency >= 75.0
        }
    }

    satisfy PrimaryTaskRequirement by PaintRobotSystem::paintPrimaryTask;
    satisfy CoatingCoverageRequirement by VisionInspectionUnit::inspectCoating;
    satisfy CoatingThicknessRequirement by VisionInspectionUnit::inspectCoating;
    satisfy ThroughputRequirement by PaintRobotSystem;
    satisfy VentilationRequirement by VentilationAndFiltrationUnit;
    satisfy SafetyInterlockRequirement by SafetyInterlockSystem::combineSafetyInputs;
    satisfy EmergencyStopRequirement by SafetyInterlockSystem;
    satisfy TransferEfficiencyRequirement by ElectrostaticSprayApplicator;

    analysis def PaintQualityAnalysis {
        in item inspection : InspectionResult;
        out attribute qualityMargin : Percent;

        objective {
            maximize qualityMargin;
        }

        constraint {
            qualityMargin == inspection.coverage - 98.0
        }
    }

    verification def CoatingInspectionVerification {
        subject result : InspectionResult;
        objective {
            result.pass == true
        }
    }

    verification def SafetyStopVerification {
        subject safetySystem : SafetyInterlockSystem;
        objective {
            safetySystem.emergencyStopResponseTime <= 0.1 [s]
        }
    }
}