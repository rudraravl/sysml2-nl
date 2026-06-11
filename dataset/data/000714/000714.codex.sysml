package OperatingTableSystemModel {

    import ScalarValues::*;
    import ISQ::*;

    attribute def Mass :> ISQ::mass;
    attribute def Length :> ISQ::length;
    attribute def Force :> ISQ::force;
    attribute def Angle :> ISQ::planeAngle;
    attribute def Time :> ISQ::time;
    attribute def ElectricPotential :> ISQ::electricPotential;
    attribute def Power :> ISQ::power;

    enum def TableMode {
        enum standby;
        enum positioning;
        enum locked;
        enum emergencyLowering;
        enum fault;
    }

    enum def MotionCommandKind {
        enum raiseHeight;
        enum lowerHeight;
        enum tiltTrendelenburg;
        enum tiltReverseTrendelenburg;
        enum tiltLeft;
        enum tiltRight;
        enum raiseBackSection;
        enum lowerBackSection;
        enum raiseLegSection;
        enum lowerLegSection;
        enum stopAllMotion;
        enum lockTable;
        enum unlockTable;
    }

    enum def LockState {
        enum unlocked;
        enum locking;
        enum locked;
        enum releasing;
    }

    item def ElectricalPower {
        attribute voltage : ElectricPotential;
        attribute availablePower : Power;
    }

    item def MotionCommand {
        attribute commandKind : MotionCommandKind;
        attribute requestedMagnitude : Real;
        attribute issuedAt : Time;
    }

    item def MotionStatus {
        attribute currentHeight : Length;
        attribute longitudinalTilt : Angle;
        attribute lateralTilt : Angle;
        attribute backSectionAngle : Angle;
        attribute legSectionAngle : Angle;
        attribute moving : Boolean;
        attribute activeMode : TableMode;
    }

    item def PatientLoad {
        attribute patientMass : Mass;
        attribute loadCenterOffsetLongitudinal : Length;
        attribute loadCenterOffsetLateral : Length;
    }

    item def AlarmSignal {
        attribute active : Boolean;
        attribute messageCode : String;
    }

    item def SterileAccessory {
        attribute accessoryMass : Mass;
        attribute mountedLength : Length;
    }

    port def PowerInPort {
        in item power : ElectricalPower;
    }

    port def ControlInputPort {
        in item command : MotionCommand;
    }

    port def StatusOutputPort {
        out item status : MotionStatus;
        out item alarm : AlarmSignal;
    }

    port def MechanicalSupportPort {
        in item load : PatientLoad;
        out item reactionForce : Force;
    }

    port def AccessoryMountPort {
        in item accessory : SterileAccessory;
    }

    part def PatientSupportSurface {
        attribute usableLength : Length = 2.05 [m];
        attribute usableWidth : Length = 0.56 [m];
        attribute radiolucentAreaLength : Length = 1.42 [m];
        attribute maximumSafePatientMass : Mass = 270 [kg];

        port supportPort : MechanicalSupportPort;
        port sideRailLeft : AccessoryMountPort;
        port sideRailRight : AccessoryMountPort;

        part headSection;
        part backSection {
            attribute angle : Angle;
        }
        part seatSection;
        part legSection {
            attribute angle : Angle;
        }
        part pressureReliefPad {
            attribute padThickness : Length = 0.08 [m];
        }
    }

    part def LiftColumn {
        attribute minimumHeight : Length = 0.62 [m];
        attribute maximumHeight : Length = 1.08 [m];
        attribute currentHeight : Length;
        attribute verticalLiftCapacity : Force = 3200 [N];

        port supportPort : MechanicalSupportPort;

        part telescopingColumn;
        part hydraulicCylinder;
        part heightSensor;
        part mechanicalEndStops;
    }

    part def ArticulationAssembly {
        attribute longitudinalTilt : Angle;
        attribute lateralTilt : Angle;
        attribute backSectionAngle : Angle;
        attribute legSectionAngle : Angle;
        attribute maximumTrendelenburgAngle : Angle = 30 [deg];
        attribute maximumLateralTiltAngle : Angle = 20 [deg];

        part trendelenburgActuator;
        part lateralTiltActuator;
        part backSectionActuator;
        part legSectionActuator;
        part positionSensors;
    }

    part def BaseAndMobilitySystem {
        attribute footprintLength : Length = 1.18 [m];
        attribute footprintWidth : Length = 0.62 [m];
        attribute lockState : LockState;

        part casterSet {
            part frontLeftCaster;
            part frontRightCaster;
            part rearLeftCaster;
            part rearRightCaster;
        }

        part floorLock {
            attribute clampingForce : Force = 1800 [N];
        }

        part levelingFeet;
    }

    part def ControlSystem {
        attribute mode : TableMode;
        attribute commandedMotion : MotionCommandKind;
        attribute emergencyStopActive : Boolean;

        port powerInput : PowerInPort;
        port controlInput : ControlInputPort;
        port statusOutput : StatusOutputPort;

        part mainController;
        part actuatorController;
        part safetyMonitor;
        part handPendantInterface;
        part footSwitchInterface;
        part displayInterface;
    }

    part def ElectricalPowerSystem {
        attribute nominalMainsVoltage : ElectricPotential = 120 [V];
        attribute batteryVoltage : ElectricPotential = 24 [V];
        attribute maximumOutputPower : Power = 650 [W];
        attribute batteryReserveTime : Time = 1800 [s];

        port mainsInput : PowerInPort;
        port controllerPowerOutput : PowerInPort;

        part acDcPowerSupply;
        part rechargeableBattery;
        part batteryCharger;
        part powerDistributionUnit;
        part fuseProtection;
    }

    part def SafetySystem {
        attribute overloadDetected : Boolean;
        attribute collisionRiskDetected : Boolean;
        attribute motionLimitReached : Boolean;
        attribute alarmActive : Boolean;

        port statusOutput : StatusOutputPort;

        part loadSensorArray;
        part tiltLimitSwitches;
        part heightLimitSwitches;
        part emergencyStopButton;
        part manualReleaseValve;
        part audibleAlarm;
        part visualAlarm;
    }

    part def OperatingTable {
        attribute tableMass : Mass = 185 [kg];
        attribute ratedPatientMass : Mass = 270 [kg];
        attribute currentMode : TableMode;

        port mainsPower : PowerInPort;
        port clinicianCommand : ControlInputPort;
        port systemStatus : StatusOutputPort;
        port patientInterface : MechanicalSupportPort;
        port accessoryRailLeft : AccessoryMountPort;
        port accessoryRailRight : AccessoryMountPort;

        part patientSurface : PatientSupportSurface;
        part liftColumn : LiftColumn;
        part articulation : ArticulationAssembly;
        part base : BaseAndMobilitySystem;
        part controller : ControlSystem;
        part powerSystem : ElectricalPowerSystem;
        part safety : SafetySystem;

        connect mainsPower to powerSystem.mainsInput;
        connect powerSystem.controllerPowerOutput to controller.powerInput;
        connect clinicianCommand to controller.controlInput;
        connect controller.statusOutput to systemStatus;
        connect safety.statusOutput to systemStatus;
        connect patientInterface to patientSurface.supportPort;
        connect patientSurface.supportPort to liftColumn.supportPort;
        connect accessoryRailLeft to patientSurface.sideRailLeft;
        connect accessoryRailRight to patientSurface.sideRailRight;

        perform action supportAndPositionPatient;
    }

    action def SupportAndPositionPatient {
        in item command : MotionCommand;
        in item patientLoad : PatientLoad;
        out item status : MotionStatus;
        out item alarm : AlarmSignal;

        first start;
        then validateLoad;
        then validateCommand;
        then unlockMotionIfRequired;
        then energizeSelectedActuator;
        then monitorMotion;
        then stopAtTargetOrLimit;
        then lockPosition;
        then publishStatus;
        then done;

        action validateLoad {
            if patientLoad.patientMass <= 270 [kg] then acceptLoad;
            else rejectLoad;
        }

        action validateCommand;
        action unlockMotionIfRequired;
        action energizeSelectedActuator;
        action monitorMotion;
        action stopAtTargetOrLimit;
        action lockPosition;
        action publishStatus;
    }

    state def OperatingTableControlStateMachine {
        entry action initializeController;

        state Off;
        state Standby;
        state Positioning;
        state Locked;
        state EmergencyLowering;
        state Fault;

        initial then Off;

        transition Off_to_Standby
            first Off
            accept ElectricalPower
            then Standby;

        transition Standby_to_Positioning
            first Standby
            accept MotionCommand
            if commandKind != MotionCommandKind::stopAllMotion
            then Positioning;

        transition Positioning_to_Locked
            first Positioning
            accept MotionStatus
            if moving == false
            then Locked;

        transition Locked_to_Standby
            first Locked
            accept MotionCommand
            if commandKind == MotionCommandKind::unlockTable
            then Standby;

        transition Any_to_EmergencyLowering
            first Standby
            accept MotionCommand
            if commandKind == MotionCommandKind::lowerHeight
            then EmergencyLowering;

        transition Positioning_to_Fault
            first Positioning
            accept AlarmSignal
            if active == true
            then Fault;

        transition Fault_to_Standby
            first Fault
            accept MotionCommand
            if commandKind == MotionCommandKind::stopAllMotion
            then Standby;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The operating table shall provide a stable, adjustable, and lockable patient support platform that enables clinicians to position a patient safely for surgical or procedural access. */
    }

    requirement def LoadCapacityRequirement {
        attribute requiredMassCapacity : Mass = 270 [kg];

        require constraint {
            OperatingTable::ratedPatientMass >= requiredMassCapacity
        }

        doc /* The table shall safely support a patient load of at least 270 kg throughout permitted height, tilt, and section articulation ranges. */
    }

    requirement def HeightAdjustmentRequirement {
        attribute minimumRequiredHeight : Length = 0.62 [m];
        attribute maximumRequiredHeight : Length = 1.08 [m];

        require constraint {
            LiftColumn::minimumHeight <= minimumRequiredHeight and
            LiftColumn::maximumHeight >= maximumRequiredHeight
        }

        doc /* The table shall provide powered vertical adjustment between the minimum and maximum clinical working heights. */
    }

    requirement def TiltRangeRequirement {
        attribute requiredTrendelenburg : Angle = 30 [deg];
        attribute requiredLateralTilt : Angle = 20 [deg];

        require constraint {
            ArticulationAssembly::maximumTrendelenburgAngle >= requiredTrendelenburg and
            ArticulationAssembly::maximumLateralTiltAngle >= requiredLateralTilt
        }

        doc /* The table shall provide controlled longitudinal and lateral tilt for surgical positioning. */
    }

    requirement def MotionSafetyRequirement {
        doc /* The control system shall stop powered motion when overload, collision risk, emergency stop, or travel-limit conditions are detected. */
    }

    requirement def PositionLockRequirement {
        doc /* The base and articulation mechanisms shall hold the selected patient position after motion commands complete. */
    }

    requirement def PowerContinuityRequirement {
        attribute minimumBatteryReserveTime : Time = 1800 [s];

        require constraint {
            ElectricalPowerSystem::batteryReserveTime >= minimumBatteryReserveTime
        }

        doc /* The table shall maintain positioning capability on battery power for at least 30 minutes when mains power is unavailable. */
    }

    satisfy PrimaryFunctionRequirement by OperatingTable;
    satisfy LoadCapacityRequirement by OperatingTable;
    satisfy HeightAdjustmentRequirement by LiftColumn;
    satisfy TiltRangeRequirement by ArticulationAssembly;
    satisfy MotionSafetyRequirement by SafetySystem;
    satisfy PositionLockRequirement by BaseAndMobilitySystem;
    satisfy PowerContinuityRequirement by ElectricalPowerSystem;

    part operatingTableSystem : OperatingTable {
        attribute currentMode = TableMode::standby;

        part normalPositioningBehavior : SupportAndPositionPatient;
        part controlBehavior : OperatingTableControlStateMachine;
    }
}