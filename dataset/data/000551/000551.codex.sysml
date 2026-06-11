package BirthingChairSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Angle {
        :> scalar;
        unit = "deg";
    }

    attribute def Force {
        :> scalar;
        unit = "N";
    }

    attribute def Mass {
        :> scalar;
        unit = "kg";
    }

    attribute def Length {
        :> scalar;
        unit = "mm";
    }

    attribute def Time {
        :> scalar;
        unit = "s";
    }

    attribute def Pressure {
        :> scalar;
        unit = "kPa";
    }

    attribute def ElectricalPower {
        :> scalar;
        unit = "W";
    }

    attribute def Voltage {
        :> scalar;
        unit = "V";
    }

    attribute def BooleanSignal {
        :> Boolean;
    }

    item def OccupantBody {
        attribute occupantMass : Mass;
        attribute seatedPostureAngle : Angle;
        attribute pelvicSupportLoad : Force;
    }

    item def SupportLoad {
        attribute verticalLoad : Force;
        attribute lateralLoad : Force;
        attribute momentLoad : Force;
    }

    item def PositionCommand {
        attribute targetBackrestAngle : Angle;
        attribute targetSeatTiltAngle : Angle;
        attribute targetLegSupportAngle : Angle;
        attribute targetHeight : Length;
    }

    item def PositionStatus {
        attribute actualBackrestAngle : Angle;
        attribute actualSeatTiltAngle : Angle;
        attribute actualLegSupportAngle : Angle;
        attribute actualHeight : Length;
        attribute locked : BooleanSignal;
    }

    item def ClinicalAccess {
        attribute perinealAccessClearance : Length;
        attribute caregiverReachClearance : Length;
    }

    item def PowerFlow {
        attribute supplyVoltage : Voltage;
        attribute availablePower : ElectricalPower;
    }

    item def HygieneState {
        attribute surfaceClean : BooleanSignal;
        attribute fluidBarrierInstalled : BooleanSignal;
        attribute removablePadsAttached : BooleanSignal;
    }

    port def BodySupportPort {
        in item body : OccupantBody;
        out item supportedLoad : SupportLoad;
    }

    port def LoadTransferPort {
        in item loadIn : SupportLoad;
        out item loadOut : SupportLoad;
    }

    port def ControlPort {
        in item command : PositionCommand;
        out item status : PositionStatus;
    }

    port def AccessPort {
        out item access : ClinicalAccess;
    }

    port def PowerPort {
        in item power : PowerFlow;
    }

    port def HygienePort {
        inout item hygiene : HygieneState;
    }

    port def SafetySignalPort {
        inout attribute emergencyStopActive : BooleanSignal;
        inout attribute sideRailLocked : BooleanSignal;
        inout attribute wheelBrakeLocked : BooleanSignal;
    }

    action def ReceiveOccupant {
        in item occupant : OccupantBody;
        out item supportedLoad : SupportLoad;

        attribute maximumAdmittedMass : Mass = 180 [kg];
        attribute admissionComplete : BooleanSignal;
    }

    action def AdjustBirthingPosture {
        in item command : PositionCommand;
        out item status : PositionStatus;

        attribute backrestAngleRangeMinimum : Angle = 20 [deg];
        attribute backrestAngleRangeMaximum : Angle = 80 [deg];
        attribute seatTiltRangeMinimum : Angle = -5 [deg];
        attribute seatTiltRangeMaximum : Angle = 18 [deg];
        attribute legSupportRangeMinimum : Angle = 0 [deg];
        attribute legSupportRangeMaximum : Angle = 75 [deg];
        attribute heightRangeMinimum : Length = 520 [mm];
        attribute heightRangeMaximum : Length = 850 [mm];
    }

    action def StabilizeChair {
        in item load : SupportLoad;
        out attribute stable : BooleanSignal;

        attribute maximumStaticLoad : Force = 2200 [N];
        attribute minimumTipMargin : Length = 75 [mm];
    }

    action def ProvideClinicalAccess {
        out item access : ClinicalAccess;

        attribute minimumPerinealClearance : Length = 300 [mm];
        attribute minimumCaregiverReachClearance : Length = 450 [mm];
    }

    action def LockForDelivery {
        inout item status : PositionStatus;
        out attribute lockedForDelivery : BooleanSignal;
    }

    action def PrepareForCleaning {
        inout item hygiene : HygieneState;
        out attribute readyForCleaning : BooleanSignal;
    }

    state def BirthingChairOperationalState {
        entry action initializeStatus;

        state Idle;
        state OccupantTransfer;
        state Positioning;
        state LaborSupport;
        state DeliverySupport;
        state EmergencyStop;
        state Cleaning;

        transition first Idle;

        transition acceptOccupant
            first Idle
            then OccupantTransfer;

        transition occupantSeated
            first OccupantTransfer
            then Positioning;

        transition postureAdjusted
            first Positioning
            then LaborSupport;

        transition deliveryAccessRequired
            first LaborSupport
            then DeliverySupport;

        transition deliveryComplete
            first DeliverySupport
            then Cleaning;

        transition cleaningComplete
            first Cleaning
            then Idle;

        transition emergencyFromTransfer
            first OccupantTransfer
            then EmergencyStop;

        transition emergencyFromPositioning
            first Positioning
            then EmergencyStop;

        transition emergencyFromLabor
            first LaborSupport
            then EmergencyStop;

        transition emergencyFromDelivery
            first DeliverySupport
            then EmergencyStop;

        transition resetAfterEmergency
            first EmergencyStop
            then Idle;
    }

    part def BirthingChairSystem {
        attribute systemMass : Mass = 95 [kg];
        attribute ratedOccupantMass : Mass = 180 [kg];
        attribute primaryFunction : String = "Support and position a birthing patient in stable, adjustable postures that improve comfort, clinical access, and safe delivery care.";

        port occupantInterface : BodySupportPort;
        port caregiverControl : ControlPort;
        port clinicalAccessInterface : AccessPort;
        port electricalInterface : PowerPort;
        port hygieneInterface : HygienePort;
        port safetyInterface : SafetySignalPort;

        part chairFrame : StructuralFrame;
        part seatAssembly : SeatAssembly;
        part backrestAssembly : BackrestAssembly;
        part legSupportAssembly : LegSupportAssembly;
        part heightAdjustmentAssembly : HeightAdjustmentAssembly;
        part armSupportAssembly : ArmSupportAssembly;
        part baseAssembly : MobileBaseAssembly;
        part restraintAndSafetyAssembly : RestraintAndSafetyAssembly;
        part controlAssembly : ControlAssembly;
        part hygieneAssembly : HygieneAssembly;

        connection occupantToSeat
            connect occupantInterface to seatAssembly.patientSupportPort;

        connection seatLoadToFrame
            connect seatAssembly.frameLoadPort to chairFrame.seatLoadPort;

        connection backrestLoadToFrame
            connect backrestAssembly.frameLoadPort to chairFrame.backrestLoadPort;

        connection legLoadToFrame
            connect legSupportAssembly.frameLoadPort to chairFrame.legLoadPort;

        connection frameToHeightLift
            connect chairFrame.baseLoadPort to heightAdjustmentAssembly.supportLoadPort;

        connection heightLiftToBase
            connect heightAdjustmentAssembly.baseLoadPort to baseAssembly.loadTransferPort;

        connection controlToBackrest
            connect controlAssembly.backrestControlPort to backrestAssembly.controlPort;

        connection controlToSeat
            connect controlAssembly.seatControlPort to seatAssembly.controlPort;

        connection controlToLegSupport
            connect controlAssembly.legControlPort to legSupportAssembly.controlPort;

        connection controlToHeight
            connect controlAssembly.heightControlPort to heightAdjustmentAssembly.controlPort;

        connection externalControlToController
            connect caregiverControl to controlAssembly.externalControlPort;

        connection clinicalAccessProvided
            connect clinicalAccessInterface to seatAssembly.accessPort;

        connection powerToControl
            connect electricalInterface to controlAssembly.powerPort;

        connection safetyToBase
            connect safetyInterface to baseAssembly.safetyPort;

        connection safetyToRestraints
            connect safetyInterface to restraintAndSafetyAssembly.safetyPort;

        connection hygieneToPads
            connect hygieneInterface to hygieneAssembly.hygienePort;

        perform action receiveOccupant : ReceiveOccupant;
        perform action adjustPosture : AdjustBirthingPosture;
        perform action stabilizeChair : StabilizeChair;
        perform action provideAccess : ProvideClinicalAccess;
        perform action lockForDelivery : LockForDelivery;
        perform action prepareCleaning : PrepareForCleaning;

        exhibit state operationalState : BirthingChairOperationalState;
    }

    part def StructuralFrame {
        attribute frameMaterial : String = "powder coated stainless steel";
        attribute yieldLoad : Force = 3500 [N];
        attribute torsionalStiffness : Force = 1200 [N];

        port seatLoadPort : LoadTransferPort;
        port backrestLoadPort : LoadTransferPort;
        port legLoadPort : LoadTransferPort;
        port baseLoadPort : LoadTransferPort;
    }

    part def SeatAssembly {
        attribute seatWidth : Length = 620 [mm];
        attribute seatDepth : Length = 540 [mm];
        attribute seatTiltAngle : Angle = 0 [deg];
        attribute cushionPressureLimit : Pressure = 12 [kPa];

        port patientSupportPort : BodySupportPort;
        port frameLoadPort : LoadTransferPort;
        port controlPort : ControlPort;
        port accessPort : AccessPort;

        part contouredSeatPan : SeatPan;
        part removableSeatCushion : Cushion;
        part pelvicOpening : ClinicalOpening;
    }

    part def SeatPan {
        attribute width : Length = 620 [mm];
        attribute depth : Length = 540 [mm];
        attribute maximumLoad : Force = 1800 [N];
    }

    part def Cushion {
        attribute thickness : Length = 80 [mm];
        attribute pressureRedistributionLimit : Pressure = 12 [kPa];
        attribute removable : BooleanSignal = true;
        attribute fluidResistant : BooleanSignal = true;
    }

    part def ClinicalOpening {
        attribute openingWidth : Length = 300 [mm];
        attribute openingDepth : Length = 260 [mm];
        attribute accessClearance : Length = 320 [mm];
    }

    part def BackrestAssembly {
        attribute backrestAngle : Angle = 55 [deg];
        attribute minimumAngle : Angle = 20 [deg];
        attribute maximumAngle : Angle = 80 [deg];

        port frameLoadPort : LoadTransferPort;
        port controlPort : ControlPort;

        part backrestPanel : BackrestPanel;
        part lumbarPad : Cushion;
        part backrestActuator : LinearActuator;
    }

    part def BackrestPanel {
        attribute height : Length = 720 [mm];
        attribute width : Length = 560 [mm];
        attribute maximumLoad : Force = 900 [N];
    }

    part def LegSupportAssembly {
        attribute legSupportAngle : Angle = 30 [deg];
        attribute minimumAngle : Angle = 0 [deg];
        attribute maximumAngle : Angle = 75 [deg];

        port frameLoadPort : LoadTransferPort;
        port controlPort : ControlPort;

        part leftLegSupport : LegSupport;
        part rightLegSupport : LegSupport;
        part legActuator : LinearActuator;
    }

    part def LegSupport {
        attribute padLength : Length = 420 [mm];
        attribute padWidth : Length = 180 [mm];
        attribute maximumLoad : Force = 450 [N];
        attribute lateralAdjustmentRange : Length = 160 [mm];
    }

    part def HeightAdjustmentAssembly {
        attribute chairHeight : Length = 650 [mm];
        attribute minimumHeight : Length = 520 [mm];
        attribute maximumHeight : Length = 850 [mm];

        port supportLoadPort : LoadTransferPort;
        port baseLoadPort : LoadTransferPort;
        port controlPort : ControlPort;

        part liftColumn : LiftColumn;
        part heightActuator : LinearActuator;
    }

    part def LiftColumn {
        attribute stroke : Length = 330 [mm];
        attribute maximumLiftLoad : Force = 2400 [N];
        attribute lockedWhenUnpowered : BooleanSignal = true;
    }

    part def ArmSupportAssembly {
        attribute armrestHeight : Length = 240 [mm];
        attribute armrestLength : Length = 420 [mm];

        part leftArmSupport : ArmSupport;
        part rightArmSupport : ArmSupport;
    }

    part def ArmSupport {
        attribute maximumLoad : Force = 300 [N];
        attribute foldAway : BooleanSignal = true;
        attribute gripSurface : String = "cleanable textured polymer";
    }

    part def MobileBaseAssembly {
        attribute wheelDiameter : Length = 125 [mm];
        attribute baseWidth : Length = 760 [mm];
        attribute baseLength : Length = 900 [mm];

        port loadTransferPort : LoadTransferPort;
        port safetyPort : SafetySignalPort;

        part basePlate : BasePlate;
        part frontLeftCaster : LockingCaster;
        part frontRightCaster : LockingCaster;
        part rearLeftCaster : LockingCaster;
        part rearRightCaster : LockingCaster;
    }

    part def BasePlate {
        attribute footprintWidth : Length = 760 [mm];
        attribute footprintLength : Length = 900 [mm];
        attribute minimumTipMargin : Length = 75 [mm];
    }

    part def LockingCaster {
        attribute diameter : Length = 125 [mm];
        attribute brakeLocked : BooleanSignal = true;
        attribute swivelLocked : BooleanSignal = false;
        attribute maximumCasterLoad : Force = 700 [N];
    }

    part def RestraintAndSafetyAssembly {
        port safetyPort : SafetySignalPort;

        part leftSideRail : SideRail;
        part rightSideRail : SideRail;
        part emergencyStopSwitch : EmergencyStopSwitch;
        part loadSensor : LoadSensor;
        part positionLock : MechanicalPositionLock;
    }

    part def SideRail {
        attribute raised : BooleanSignal = true;
        attribute locked : BooleanSignal = true;
        attribute railHeight : Length = 230 [mm];
    }

    part def EmergencyStopSwitch {
        attribute active : BooleanSignal = false;
        attribute resetRequired : BooleanSignal = true;
    }

    part def LoadSensor {
        attribute measuredLoad : Force;
        attribute overloadThreshold : Force = 2200 [N];
    }

    part def MechanicalPositionLock {
        attribute locked : BooleanSignal = true;
        attribute lockHoldingForce : Force = 2500 [N];
    }

    part def ControlAssembly {
        port externalControlPort : ControlPort;
        port backrestControlPort : ControlPort;
        port seatControlPort : ControlPort;
        port legControlPort : ControlPort;
        port heightControlPort : ControlPort;
        port powerPort : PowerPort;

        part caregiverPendant : CaregiverPendant;
        part embeddedController : EmbeddedController;
        part powerSupply : PowerSupply;
    }

    part def CaregiverPendant {
        attribute buttonCount : Integer = 8;
        attribute cableLength : Length = 1800 [mm];
        attribute sealedIngressProtection : String = "IP54";
    }

    part def EmbeddedController {
        attribute controlCycleTime : Time = 0.05 [s];
        attribute emergencyStopLatency : Time = 0.10 [s];
        attribute positionAccuracy : Length = 5 [mm];
    }

    part def PowerSupply {
        attribute nominalVoltage : Voltage = 24 [V];
        attribute maximumOutputPower : ElectricalPower = 240 [W];
        attribute batteryBackupEnabled : BooleanSignal = true;
    }

    part def LinearActuator {
        attribute stroke : Length = 250 [mm];
        attribute maximumPushForce : Force = 1800 [N];
        attribute maximumPullForce : Force = 1200 [N];
        attribute ratedPower : ElectricalPower = 80 [W];
        attribute selfLocking : BooleanSignal = true;
    }

    part def HygieneAssembly {
        port hygienePort : HygienePort;

        part removablePadSet : RemovablePadSet;
        part fluidBarrier : FluidBarrier;
        part cleanableSurfaceSet : CleanableSurfaceSet;
    }

    part def RemovablePadSet {
        attribute attached : BooleanSignal = true;
        attribute disinfectable : BooleanSignal = true;
        attribute replacementTime : Time = 60 [s];
    }

    part def FluidBarrier {
        attribute installed : BooleanSignal = true;
        attribute barrierCoverageWidth : Length = 620 [mm];
        attribute barrierCoverageDepth : Length = 700 [mm];
    }

    part def CleanableSurfaceSet {
        attribute nonPorous : BooleanSignal = true;
        attribute cleaningAgentCompatible : BooleanSignal = true;
        attribute maximumCleaningTime : Time = 300 [s];
    }

    requirement def PrimaryFunctionRequirement {
        subject chair : BirthingChairSystem;

        require constraint {
            chair.primaryFunction == "Support and position a birthing patient in stable, adjustable postures that improve comfort, clinical access, and safe delivery care."
        }
    }

    requirement def OccupantSupportRequirement {
        subject chair : BirthingChairSystem;

        require constraint {
            chair.ratedOccupantMass >= 180 [kg]
        }
    }

    requirement def AdjustablePostureRequirement {
        subject chair : BirthingChairSystem;

        require constraint {
            chair.backrestAssembly.minimumAngle <= 20 [deg] and
            chair.backrestAssembly.maximumAngle >= 80 [deg] and
            chair.legSupportAssembly.maximumAngle >= 75 [deg] and
            chair.heightAdjustmentAssembly.minimumHeight <= 520 [mm] and
            chair.heightAdjustmentAssembly.maximumHeight >= 850 [mm]
        }
    }

    requirement def StabilityRequirement {
        subject chair : BirthingChairSystem;

        require constraint {
            chair.baseAssembly.basePlate.minimumTipMargin >= 75 [mm] and
            chair.baseAssembly.baseWidth >= 760 [mm] and
            chair.baseAssembly.baseLength >= 900 [mm]
        }
    }

    requirement def ClinicalAccessRequirement {
        subject chair : BirthingChairSystem;

        require constraint {
            chair.seatAssembly.pelvicOpening.accessClearance >= 300 [mm]
        }
    }

    requirement def EmergencyStopRequirement {
        subject chair : BirthingChairSystem;

        require constraint {
            chair.controlAssembly.embeddedController.emergencyStopLatency <= 0.10 [s]
        }
    }

    requirement def HygieneRequirement {
        subject chair : BirthingChairSystem;

        require constraint {
            chair.hygieneAssembly.removablePadSet.disinfectable == true and
            chair.hygieneAssembly.fluidBarrier.installed == true and
            chair.hygieneAssembly.cleanableSurfaceSet.maximumCleaningTime <= 300 [s]
        }
    }

    requirement def BrakeLockRequirement {
        subject chair : BirthingChairSystem;

        require constraint {
            chair.baseAssembly.frontLeftCaster.brakeLocked == true and
            chair.baseAssembly.frontRightCaster.brakeLocked == true and
            chair.baseAssembly.rearLeftCaster.brakeLocked == true and
            chair.baseAssembly.rearRightCaster.brakeLocked == true
        }
    }

    satisfy PrimaryFunctionRequirement by BirthingChairSystem;
    satisfy OccupantSupportRequirement by BirthingChairSystem;
    satisfy AdjustablePostureRequirement by BirthingChairSystem;
    satisfy StabilityRequirement by BirthingChairSystem;
    satisfy ClinicalAccessRequirement by BirthingChairSystem;
    satisfy EmergencyStopRequirement by BirthingChairSystem;
    satisfy HygieneRequirement by BirthingChairSystem;
    satisfy BrakeLockRequirement by BirthingChairSystem;
}