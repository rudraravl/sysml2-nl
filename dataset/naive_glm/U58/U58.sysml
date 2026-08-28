package GravityFedIVInfusionSystem {
    import ScalarValues::*;

    // ==========================================================
    // Units
    // ==========================================================
    unit mL;
    unit drop_per_min;
    unit mL_per_min;
    unit mmHg;
    unit cm;
    unit mL_per_drop;

    // ==========================================================
    // Value Types
    // ==========================================================
    attribute def VolumeValue :> Real;
    attribute def DripRateValue :> Real;
    attribute def FlowRateValue :> Real;
    attribute def PressureValue :> Real;
    attribute def HeightValue :> Real;
    attribute def DropSizeValue :> Real;
    attribute def TimeValue :> Real;

    // ==========================================================
    // Item Definitions
    // ==========================================================
    item def IVFluid {
        attribute name : String;
        attribute volume : VolumeValue;
        attribute isSterile : Boolean = true;
    }

    item def Air;

    // ==========================================================
    // Port Definitions
    // ==========================================================
    port def FluidOutlet {
        out fluid : IVFluid;
        attribute flowRate : FlowRateValue;
    }

    port def FluidInlet {
        in fluid : IVFluid;
        attribute flowRate : FlowRateValue;
    }

    port def AirVentPort {
        inout air : Air;
    }

    port def PatientPort {
        out fluid : IVFluid;
        attribute flowRate : FlowRateValue;
    }

    // ==========================================================
    // Connection Definitions
    // ==========================================================
    connection def FluidFlowConnection {
        end source : FluidOutlet;
        end target : FluidInlet;
        attribute conveyedFluid : IVFluid;
    }

    connection def AirVentLink {
        end ventA : AirVentPort;
        end ventB : AirVentPort;
    }

    // ==========================================================
    // Drip Orifice (sub-component of Drip Chamber)
    // ==========================================================
    part def DripOrifice {
        attribute diameter : HeightValue = 0.1;
        attribute isClear : Boolean = true;

        action def FormDrop;
        action def ClearObstruction;
    }

    // ==========================================================
    // IV Bag
    // ==========================================================
    part def IVBag {
        attribute bagCapacity : VolumeValue = 500;
        attribute currentVolume : VolumeValue;
        attribute suspensionHeight : HeightValue = 90;
        attribute fluidType : IVFluid;
        attribute isSterileSealed : Boolean = true;

        port outlet : FluidOutlet;
        port airVent : AirVentPort;

        action def FillBag {
            in fluidIn : IVFluid;
        }

        action def DrainFluid {
            out fluidOut : IVFluid;
        }

        action def BreakSeal {
            // Break the sterile seal before use
        }

        assert currentVolume >= 0;
        assert currentVolume <= bagCapacity;
        assert suspensionHeight > 0;
    }

    // ==========================================================
    // Drip Chamber
    // ==========================================================
    part def DripChamber {
        attribute chamberCapacity : VolumeValue = 5;
        attribute currentFluidLevel : VolumeValue;
        attribute dropSize : DropSizeValue = 0.05;
        attribute dropCount : Integer = 0;
        attribute dripRate : DripRateValue;
        attribute isTransparent : Boolean = true;
        attribute isDripVisible : Boolean = true;
        attribute isChamberEmpty : Boolean = false;
        attribute isChamberOverfilled : Boolean = false;
        attribute emptyThreshold : VolumeValue = 0.5;
        attribute overfillThreshold : VolumeValue = 4.5;

        part orifice : DripOrifice;

        port inlet : FluidInlet;
        port outlet : FluidOutlet;
        port airVent : AirVentPort;

        action def GenerateDrop {
            // Fluid passes through orifice forming a visible drop
            do action orifice.FormDrop;
        }

        action def CountDrops {
            // Clinician visually counts drops per minute
        }

        action def DetectEmpty {
            // Detects when chamber fluid level falls below emptyThreshold
        }

        action def DetectOverfilled {
            // Detects when chamber fluid level exceeds overfillThreshold
        }

        action def AdmitAir {
            // Air enters through the vent to prevent vacuum
        }

        assert currentFluidLevel >= 0;
        assert currentFluidLevel <= chamberCapacity;
        assert isTransparent == true;
        assert isDripVisible == true;
    }

    // ==========================================================
    // Delivery Tubing
    // ==========================================================
    part def DeliveryTubing {
        attribute length : HeightValue = 200;
        attribute innerDiameter : HeightValue = 0.3;
        attribute isConstricted : Boolean = false;
        attribute isPrimed : Boolean = false;
        attribute containsAir : Boolean = true;

        port inlet : FluidInlet;
        port outlet : FluidOutlet;

        action def ConductFluid {
            // Conducts fluid from inlet to outlet
        }

        action def PurgeAirBubbles {
            // Removes air from the tubing during priming
        }

        action def ConstrictFlow {
            in constrictionLevel : Real;
        }

        action def ReleaseFlow {
            // Releases constriction to restore full flow
        }

        assert length > 0;
        assert innerDiameter > 0;
    }

    // ==========================================================
    // Roller Clamp
    // ==========================================================
    part def RollerClamp {
        attribute openSetting : Real = 0.5;
        attribute flowMultiplier : Real;
        attribute minSetting : Real = 0;
        attribute maxSetting : Real = 1;
        attribute isFullyClosed : Boolean = false;
        attribute isFullyOpen : Boolean = false;

        action def AdjustRoller {
            in newSetting : Real;
            // Sliding the roller changes the open setting
        }

        action def ConstrictTubing {
            // Constricts the flexible tube to reduce flow
        }

        action def ReleaseTubing {
            // Releases constriction to increase flow
        }

        action def FullyClose {
            // Roller at minimum setting, flow stopped
        }

        action def FullyOpen {
            // Roller at maximum setting, maximum flow
        }

        assert openSetting >= minSetting;
        assert openSetting <= maxSetting;
        assert isFullyClosed == (openSetting == minSetting);
        assert isFullyOpen == (openSetting == maxSetting);
    }

    // ==========================================================
    // Luer Lock (Patient Connection)
    // ==========================================================
    part def LuerLock {
        attribute isLocked : Boolean = false;
        attribute isSecure : Boolean = false;
        attribute connectionType : String = "luer_lock";

        port patientConnection : PatientPort;

        action def Lock {
            // Securely attaches to patient IV line
            do action VerifySecureConnection;
        }

        action def Unlock {
            // Detaches from patient IV line
        }

        action def VerifySecureConnection {
            // Verifies the connection is properly secured
        }

        assert isLocked == isSecure;
    }

    // ==========================================================
    // Patient
    // ==========================================================
    part def Patient {
        attribute patientID : String;
        attribute catheterType : String = "peripheral";

        port ivAccess : FluidInlet;

        action def ReceiveFluid {
            in administeredFluid : IVFluid;
        }
    }

    // ==========================================================
    // Alarm System
    // ==========================================================
    part def AlarmSystem {
        attribute isEmptyAlarmActive : Boolean = false;
        attribute isOverfillAlarmActive : Boolean = false;
        attribute alarmMessage : String = "";
        attribute alarmAcknowledged : Boolean = false;
        attribute alarmPriority : String = "high";

        action def TriggerEmptyAlarm {
            // Alert caregiver that drip chamber is running empty
            do action SetAlarmMessage;
        }

        action def TriggerOverfillAlarm {
            // Alert caregiver that drip chamber is overfilled
            do action SetAlarmMessage;
        }

        action def ClearAlarm {
            // Reset alarm state
        }

        action def AcknowledgeAlarm {
            // Caregiver acknowledges alarm
        }

        action def SetAlarmMessage {
            in message : String;
        }

        assert alarmPriority == "high" or alarmPriority == "medium" or alarmPriority == "low";
    }

    // ==========================================================
    // Flow Controller
    // ==========================================================
    part def FlowController {
        attribute targetDripRate : DripRateValue;
        attribute measuredDripRate : DripRateValue;
        attribute isMonitoring : Boolean = false;
        attribute toleranceDrops : Integer = 2;

        action def SetTargetRate {
            in targetRate : DripRateValue;
        }

        action def MonitorDripRate {
            // Continuously monitors actual drip rate from drip chamber
        }

        action def CompareRates {
            // Compares measured rate to target
            out deviation : Real;
        }

        action def ReportDeviation {
            in measuredDeviation : Real;
            // Reports if measured rate deviates beyond tolerance
        }

        assert targetDripRate >= 0;
        assert measuredDripRate >= 0;
    }

    // ==========================================================
    // IV Infusion System (Composite)
    // ==========================================================
    part def IVInfusionSystem {
        // Trigger events for state machine
        attribute primingInitiated : Boolean = false;
        attribute primingComplete : Boolean = false;
        attribute infusionStarted : Boolean = false;
        attribute infusionPaused : Boolean = false;
        attribute infusionResumed : Boolean = false;
        attribute infusionStopped : Boolean = false;
        attribute chamberEmptyDetected : Boolean = false;
        attribute chamberOverfilledDetected : Boolean = false;
        attribute alarmCleared : Boolean = false;
        attribute systemReset : Boolean = false;

        // System-level attributes
        attribute heightDifference : HeightValue;
        attribute drivingPressure : PressureValue;
        attribute calculatedFlowRate : FlowRateValue;
        attribute dropFactor : Integer = 20;
        attribute systemIsSterile : Boolean = true;

        // Components
        part ivBag : IVBag;
        part dripChamber : DripChamber;
        part deliveryTubing : DeliveryTubing;
        part rollerClamp : RollerClamp;
        part luerLock : LuerLock;
        part patient : Patient;
        part alarmSystem : AlarmSystem;
        part flowController : FlowController;

        // Connections
        connection bagToChamber : FluidFlowConnection connect ivBag.outlet to dripChamber.inlet;
        connection chamberToTubing : FluidFlowConnection connect dripChamber.outlet to deliveryTubing.inlet;
        connection tubingToLuerLock : FluidFlowConnection connect deliveryTubing.outlet to luerLock.patientConnection;
        connection luerLockToPatient : FluidFlowConnection connect luerLock.patientConnection to patient.ivAccess;
        connection airVentLink : AirVentLink connect dripChamber.airVent to ivBag.airVent;

        // System actions
        action def InitializeSystem {
            // Initialize all components to default safe state
            do action VerifySterility;
        }

        action def VerifySterility {
            // Verify all fluid-path components are sterile
        }

        action def StartPriming {
            // Begin priming sequence
        }

        action def FillDripChamber {
            // Fill the drip chamber to appropriate level
            do action dripChamber.GenerateDrop;
        }

        action def PurgeAir {
            // Purge air from the delivery tubing
            do action deliveryTubing.PurgeAirBubbles;
        }

        action def StartInfusion {
            // Start fluid delivery to patient
            do action rollerClamp.ReleaseTubing;
        }

        action def DeliverFluid {
            // Continuously deliver fluid to patient at controlled rate
            do action dripChamber.CountDrops;
            do action flowController.MonitorDripRate;
            do action dripChamber.DetectEmpty;
            do action dripChamber.DetectOverfilled;
        }

        action def StopFluidDelivery {
            // Stop fluid delivery
            do action rollerClamp.ConstrictTubing;
        }

        action def PauseFluidDelivery {
            // Pause fluid delivery temporarily
            do action rollerClamp.ConstrictTubing;
        }

        action def ResumeFluidDelivery {
            // Resume fluid delivery after pause
            do action rollerClamp.ReleaseTubing;
        }

        action def StopInfusion {
            // Stop infusion entirely
            do action rollerClamp.FullyClose;
        }

        action def TriggerEmptyAlarm {
            do action alarmSystem.TriggerEmptyAlarm;
        }

        action def TriggerOverfillAlarm {
            do action alarmSystem.TriggerOverfillAlarm;
        }

        action def ClearAlarms {
            do action alarmSystem.ClearAlarm;
        }

        action def ResetSystem {
            // Reset system to initial idle state
        }

        action def CalculateDrivingPressure {
            // Calculate hydrostatic pressure from bag height
            // drivingPressure ~ heightDifference * 0.7355 mmHg/cm (approximate)
        }

        action def CalculateFlowRate {
            // flowRate = f(drivingPressure, rollerClamp.openSetting, tubing resistance)
        }

        // State Machine
        state InfusionStateMachine {
            state Idle {
                entry InitializeSystem;
                do VerifySterility;
            }

            state Priming {
                entry StartPriming;
                do FillDripChamber;
                exit PurgeAir;
            }

            state Ready;

            state Infusing {
                entry StartInfusion;
                do DeliverFluid;
                exit StopFluidDelivery;
            }

            state Paused {
                entry PauseFluidDelivery;
            }

            state Stopped {
                entry StopInfusion;
            }

            state AlarmEmpty {
                entry TriggerEmptyAlarm;
            }

            state AlarmOverfilled {
                entry TriggerOverfillAlarm;
            }

            transition from Idle to Priming when primingInitiated;
            transition from Priming to Ready when primingComplete;
            transition from Ready to Infusing when infusionStarted;
            transition from Infusing to Paused when infusionPaused;
            transition from Paused to Infusing when infusionResumed;
            transition from Infusing to Stopped when infusionStopped;
            transition from Paused to Stopped when infusionStopped;
            transition from Ready to Stopped when infusionStopped;
            transition from Infusing to AlarmEmpty when chamberEmptyDetected;
            transition from AlarmEmpty to Ready when alarmCleared;
            transition from Infusing to AlarmOverfilled when chamberOverfilledDetected;
            transition from AlarmOverfilled to Ready when alarmCleared;
            transition from AlarmEmpty to Stopped when infusionStopped;
            transition from AlarmOverfilled to Stopped when infusionStopped;
            transition from Stopped to Idle when systemReset;
        }

        assert systemIsSterile == true;
        assert heightDifference == ivBag.suspensionHeight;
        assert drivingPressure > 0;
    }

    // ==========================================================
    // Requirements
    // ==========================================================
    requirement def GravityDrivenFlow {
        doc { The IV infusion system shall deliver fluid using gravity as the sole driving force, with the IV bag suspended above the patient. }
        subject system : IVInfusionSystem;
        assert system.ivBag.suspensionHeight > 0;
        assert system.drivingPressure > 0;
        assert system.heightDifference > 0;
    }

    requirement def DripVisibilityRequirement {
        doc { The drip chamber shall be transparent and shall form distinct, visible drops through a small orifice, allowing a clinician to visually count drops per minute. }
        subject system : IVInfusionSystem;
        assert system.dripChamber.isTransparent == true;
        assert system.dripChamber.isDripVisible == true;
        assert system.dripChamber.dropSize > 0;
    }

    requirement def AirVentRequirement {
        doc { The drip chamber shall include an air vent to prevent vacuum formation in the IV bag, ensuring steady flow. }
        subject system : IVInfusionSystem;
        assert system.dripChamber.airVent.isAirVentPort == true;
    }

    requirement def FlowControlRequirement {
        doc { A roller clamp on the delivery tubing shall allow manual adjustment of the flow rate by constricting or opening the flexible tube. }
        subject system : IVInfusionSystem;
        assert system.rollerClamp.openSetting >= 0;
        assert system.rollerClamp.openSetting <= 1;
        assert system.rollerClamp.maxSetting == 1;
        assert system.rollerClamp.minSetting == 0;
    }

    requirement def SecurePatientConnectionRequirement {
        doc { The patient connection shall be a luer lock that securely attaches to the patient IV line and prevents accidental disconnection. }
        subject system : IVInfusionSystem;
        assert system.luerLock.isLocked == true;
        assert system.luerLock.isSecure == true;
        assert system.luerLock.connectionType == "luer_lock";
    }

    requirement def PrimingRequirement {
        doc { The system shall include a priming phase to fill the drip chamber and purge air from the tubing before infusion begins. }
        subject system : IVInfusionSystem;
        assert system.deliveryTubing.isPrimed == true;
        assert system.dripChamber.currentFluidLevel > 0;
        assert system.deliveryTubing.containsAir == false;
    }

    requirement def EmptyAlarmRequirement {
        doc { The system shall detect when the drip chamber runs empty and generate an alarm to alert the caregiver. }
        subject system : IVInfusionSystem;
        assert system.alarmSystem.isEmptyAlarmActive == true;
        assert system.dripChamber.isChamberEmpty == true;
    }

    requirement def OverfillAlarmRequirement {
        doc { The system shall detect when the drip chamber becomes overfilled and generate an alarm to alert the caregiver. }
        subject system : IVInfusionSystem;
        assert system.alarmSystem.isOverfillAlarmActive == true;
        assert system.dripChamber.isChamberOverfilled == true;
    }

    requirement def DripRateMonitoring {
        doc { The system shall allow monitoring of the drip rate in drops per minute for setting and verifying the infusion rate. }
        subject system : IVInfusionSystem;
        assert system.dripChamber.dripRate >= 0;
        assert system.flowController.measuredDripRate >= 0;
    }

    requirement def FlowControlRange {
        doc { The flow rate shall be adjustable from zero (fully closed) to the maximum gravity-driven flow rate (fully open). }
        subject system : IVInfusionSystem;
        assert system.rollerClamp.openSetting >= 0;
        assert system.rollerClamp.openSetting <= 1;
        assert system.rollerClamp.isFullyClosed == (system.rollerClamp.openSetting == 0);
        assert system.rollerClamp.isFullyOpen == (system.rollerClamp.openSetting == 1);
    }

    requirement def BagCapacity {
        doc { The IV bag shall have a capacity of at least 500 mL to accommodate standard infusion volumes. }
        subject system : IVInfusionSystem;
        assert system.ivBag.bagCapacity >= 500;
    }

    requirement def SterilityRequirement {
        doc { The entire fluid path from IV bag to patient connection shall be sterile and remain sealed until use. }
        subject system : IVInfusionSystem;
        assert system.systemIsSterile == true;
        assert system.ivBag.isSterileSealed == true;
        assert system.ivBag.fluidType.isSterile == true;
    }

    requirement def StateMachineRequirement {
        doc { The system shall operate through defined states including Idle, Priming, Ready, Infusing, Paused, Stopped, and alarm states for empty and overfilled conditions. }
        subject system : IVInfusionSystem;
    }

    requirement def PauseResumeRequirement {
        doc { The system shall allow pausing and resuming infusion without restarting the priming sequence. }
        subject system : IVInfusionSystem;
    }

    // ==========================================================
    // Requirements Package
    // ==========================================================
    package Requirements {
        requirement gravityFlowReq : GravityDrivenFlow;
        requirement dripVisibilityReq : DripVisibilityRequirement;
        requirement airVentReq : AirVentRequirement;
        requirement flowControlReq : FlowControlRequirement;
        requirement secureConnectionReq : SecurePatientConnectionRequirement;
        requirement primingReq : PrimingRequirement;
        requirement emptyAlarmReq : EmptyAlarmRequirement;
        requirement overfillAlarmReq : OverfillAlarmRequirement;
        requirement dripRateMonitoringReq : DripRateMonitoring;
        requirement flowControlRangeReq : FlowControlRange;
        requirement bagCapacityReq : BagCapacity;
        requirement sterilityReq : SterilityRequirement;
        requirement stateMachineReq : StateMachineRequirement;
        requirement pauseResumeReq : PauseResumeRequirement;
    }
}
