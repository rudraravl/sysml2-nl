package NegativePressureWoundTherapyModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def PressureValue :> Real {
        unit = "kPa";
    }

    attribute def FlowRateValue :> Real {
        unit = "mL/min";
    }

    attribute def VolumeValue :> Real {
        unit = "mL";
    }

    attribute def TimeValue :> Real {
        unit = "s";
    }

    attribute def BatteryChargeValue :> Real {
        unit = "%";
    }

    attribute def TherapyIntensityValue :> Real {
        unit = "kPa";
    }

    enum def TherapyMode {
        enum continuous;
        enum intermittent;
        enum paused;
    }

    enum def AlarmSeverity {
        enum advisory;
        enum warning;
        enum critical;
    }

    item def Air;
    item def WoundExudate;
    item def FilteredAir;
    item def ElectricalEnergy;
    item def ControlSignal;
    item def AlarmSignal;
    item def UserCommand;
    item def TherapyStatus;
    item def NegativePressure;
    item def DressingSealStatus;

    port def FluidPort {
        in item airIn : Air;
        out item exudateOut : WoundExudate;
    }

    port def SuctionPort {
        in item exudateAndAir : WoundExudate;
        out item negativePressure : NegativePressure;
    }

    port def ExhaustPort {
        out item exhaustAir : FilteredAir;
    }

    port def ElectricalPort {
        in item electricalInput : ElectricalEnergy;
    }

    port def ControlPort {
        in item command : UserCommand;
        out item status : TherapyStatus;
        out item alarm : AlarmSignal;
    }

    port def SensorPort {
        out item measuredPressure : NegativePressure;
        out item measuredFlow : WoundExudate;
        out item sealStatus : DressingSealStatus;
    }

    action def DeliverNegativePressure {
        in targetPressure : PressureValue;
        in therapyMode : TherapyMode;
        out deliveredPressure : PressureValue;
        out removedFluidRate : FlowRateValue;

        action regulatePump;
        action evacuateAirAndExudate;
        action stabilizeWoundBedPressure;

        first start;
        then regulatePump;
        then evacuateAirAndExudate;
        then stabilizeWoundBedPressure;
        then done;
    }

    action def DetectLeak {
        in measuredPressure : PressureValue;
        in commandedPressure : PressureValue;
        in measuredFlow : FlowRateValue;
        out leakDetected : Boolean;

        action comparePressureError;
        action evaluateFlowPersistence;
        action declareLeak;

        first start;
        then comparePressureError;
        then evaluateFlowPersistence;
        then declareLeak;
        then done;
    }

    action def ManageCanisterCapacity {
        in collectedVolume : VolumeValue;
        in maxVolume : VolumeValue;
        out canisterFull : Boolean;

        action measureVolume;
        action compareCapacity;
        action inhibitPumpIfFull;

        first start;
        then measureVolume;
        then compareCapacity;
        then inhibitPumpIfFull;
        then done;
    }

    action def GenerateAlarm {
        in severity : AlarmSeverity;
        in alarmText : String;
        out alarmSignal : AlarmSignal;

        action activateVisualIndicator;
        action activateAudibleIndicator;
        action publishAlarmStatus;

        first start;
        then activateVisualIndicator;
        then activateAudibleIndicator;
        then publishAlarmStatus;
        then done;
    }

    state def TherapyControllerStateMachine {
        state Off;
        state SelfTest;
        state Ready;
        state Priming;
        state TherapyActive;
        state ContinuousTherapy;
        state IntermittentOn;
        state IntermittentOff;
        state Paused;
        state Alarmed;
        state Shutdown;

        entry action initializeController;
        do action monitorTherapy;

        transition initial then Off;

        transition Off_to_SelfTest
            first Off
            accept UserCommand
            then SelfTest;

        transition SelfTest_to_Ready
            first SelfTest
            if selfTestPassed == true
            then Ready;

        transition Ready_to_Priming
            first Ready
            accept UserCommand
            then Priming;

        transition Priming_to_TherapyActive
            first Priming
            if dressingSealEstablished == true
            then TherapyActive;

        transition TherapyActive_to_Continuous
            first TherapyActive
            if selectedMode == TherapyMode::continuous
            then ContinuousTherapy;

        transition TherapyActive_to_IntermittentOn
            first TherapyActive
            if selectedMode == TherapyMode::intermittent
            then IntermittentOn;

        transition IntermittentOn_to_IntermittentOff
            first IntermittentOn
            after 300 [s]
            then IntermittentOff;

        transition IntermittentOff_to_IntermittentOn
            first IntermittentOff
            after 120 [s]
            then IntermittentOn;

        transition Continuous_to_Paused
            first ContinuousTherapy
            accept UserCommand
            then Paused;

        transition IntermittentOn_to_Paused
            first IntermittentOn
            accept UserCommand
            then Paused;

        transition Paused_to_TherapyActive
            first Paused
            accept UserCommand
            then TherapyActive;

        transition Therapy_to_Alarmed
            first TherapyActive
            if criticalAlarmPresent == true
            then Alarmed;

        transition Alarmed_to_Ready
            first Alarmed
            accept UserCommand
            if alarmCleared == true
            then Ready;

        transition Ready_to_Shutdown
            first Ready
            accept UserCommand
            then Shutdown;
    }

    part def WoundDressing {
        attribute sealed : Boolean;
        attribute contactArea : Real {
            unit = "cm^2";
        }

        port woundInterface : FluidPort;
        port suctionInterface : SuctionPort;
    }

    part def SuctionTube {
        attribute internalVolume : VolumeValue = 18.0;
        attribute kinkDetected : Boolean;

        port dressingEnd : SuctionPort;
        port pumpEnd : SuctionPort;
    }

    part def VacuumPump {
        attribute maximumVacuum : PressureValue = -25.0;
        attribute minimumVacuum : PressureValue = -5.0;
        attribute nominalFlowRate : FlowRateValue = 250.0;
        attribute pumpEnabled : Boolean;

        port inlet : SuctionPort;
        port outlet : ExhaustPort;
        port power : ElectricalPort;
        port control : ControlPort;
    }

    part def ExudateCanister {
        attribute maximumCapacity : VolumeValue = 300.0;
        attribute collectedVolume : VolumeValue;
        attribute full : Boolean;

        port inlet : SuctionPort;
        port vent : ExhaustPort;
    }

    part def HydrophobicFilter {
        attribute saturated : Boolean;
        attribute bacterialEfficiency : Real = 99.9 {
            unit = "%";
        }

        port inlet : ExhaustPort;
        port outlet : ExhaustPort;
    }

    part def PressureSensor {
        attribute rangeLow : PressureValue = -30.0;
        attribute rangeHigh : PressureValue = 5.0;
        attribute measuredPressure : PressureValue;

        port pneumaticTap : SuctionPort;
        port signal : SensorPort;
    }

    part def FlowSensor {
        attribute measuredFlow : FlowRateValue;
        attribute minimumDetectableFlow : FlowRateValue = 1.0;

        port fluidPath : SuctionPort;
        port signal : SensorPort;
    }

    part def CanisterLevelSensor {
        attribute measuredVolume : VolumeValue;
        attribute fullThreshold : VolumeValue = 285.0;

        port signal : SensorPort;
    }

    part def BatteryPack {
        attribute chargeRemaining : BatteryChargeValue;
        attribute nominalRuntime : TimeValue = 28800.0;
        attribute lowChargeThreshold : BatteryChargeValue = 15.0;

        port output : ElectricalPort;
    }

    part def PowerAdapter {
        attribute inputVoltage : Real = 120.0 {
            unit = "V";
        }
        attribute outputVoltage : Real = 12.0 {
            unit = "V";
        }

        port output : ElectricalPort;
    }

    part def UserInterface {
        attribute selectedTargetPressure : PressureValue = -16.7;
        attribute selectedMode : TherapyMode = TherapyMode::continuous;
        attribute alarmMuted : Boolean;

        port userControl : ControlPort;
    }

    part def Microcontroller {
        attribute commandedPressure : PressureValue = -16.7;
        attribute pressureTolerance : PressureValue = 2.0;
        attribute selectedMode : TherapyMode = TherapyMode::continuous;
        attribute criticalAlarmPresent : Boolean;
        attribute alarmCleared : Boolean;
        attribute selfTestPassed : Boolean;
        attribute dressingSealEstablished : Boolean;

        port ui : ControlPort;
        port pumpControl : ControlPort;
        port sensorInput : SensorPort;

        behavior controllerBehavior : TherapyControllerStateMachine;
    }

    part def AlarmModule {
        attribute audibleLevel : Real = 70.0 {
            unit = "dBA";
        }
        attribute visualIndicatorActive : Boolean;
        attribute audibleIndicatorActive : Boolean;

        port alarmControl : ControlPort;
    }

    part def NegativePressureWoundTherapySystem {
        attribute primaryFunction : String =
            "Apply controlled sub-atmospheric pressure to a sealed wound dressing to remove exudate, reduce edema, support perfusion, and promote wound bed stabilization.";

        attribute targetPressure : PressureValue = -16.7;
        attribute allowablePressureError : PressureValue = 2.0;
        attribute maximumCanisterVolume : VolumeValue = 300.0;
        attribute maximumContinuousRunTime : TimeValue = 86400.0;
        attribute operatingMode : TherapyMode = TherapyMode::continuous;

        part dressing : WoundDressing;
        part tube : SuctionTube;
        part pump : VacuumPump;
        part canister : ExudateCanister;
        part filter : HydrophobicFilter;
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part levelSensor : CanisterLevelSensor;
        part battery : BatteryPack;
        part adapter : PowerAdapter;
        part ui : UserInterface;
        part controller : Microcontroller;
        part alarm : AlarmModule;

        port patientWoundInterface : FluidPort;
        port operatorInterface : ControlPort;
        port externalPowerInput : ElectricalPort;
        port exhaust : ExhaustPort;

        connect patientWoundInterface to dressing.woundInterface;
        connect dressing.suctionInterface to tube.dressingEnd;
        connect tube.pumpEnd to canister.inlet;
        connect canister.vent to pump.inlet;
        connect pump.outlet to filter.inlet;
        connect filter.outlet to exhaust;

        connect pressureSensor.pneumaticTap to tube.pumpEnd;
        connect flowSensor.fluidPath to tube.pumpEnd;
        connect levelSensor.signal to controller.sensorInput;
        connect pressureSensor.signal to controller.sensorInput;
        connect flowSensor.signal to controller.sensorInput;

        connect ui.userControl to operatorInterface;
        connect ui.userControl to controller.ui;
        connect controller.pumpControl to pump.control;
        connect controller.ui to alarm.alarmControl;

        connect adapter.output to pump.power;
        connect battery.output to pump.power;
        connect externalPowerInput to adapter.output;

        perform therapyDelivery : DeliverNegativePressure {
            in targetPressure = targetPressure;
            in therapyMode = operatingMode;
            out deliveredPressure;
            out removedFluidRate;
        }

        perform leakDetection : DetectLeak {
            in measuredPressure = pressureSensor.measuredPressure;
            in commandedPressure = targetPressure;
            in measuredFlow = flowSensor.measuredFlow;
            out leakDetected;
        }

        perform canisterManagement : ManageCanisterCapacity {
            in collectedVolume = canister.collectedVolume;
            in maxVolume = canister.maximumCapacity;
            out canisterFull;
        }

        perform alarmGeneration : GenerateAlarm {
            in severity = AlarmSeverity::critical;
            in alarmText = "Therapy interrupted: leak, blockage, low power, or full canister condition.";
            out alarmSignal;
        }
    }

    requirement def ControlledNegativePressureRequirement {
        subject system : NegativePressureWoundTherapySystem;

        doc
        /* The system shall regulate wound dressing pressure to the selected target pressure within the allowable tolerance during active therapy. */

        require constraint {
            abs(system.pressureSensor.measuredPressure - system.targetPressure) <= system.allowablePressureError
        }
    }

    requirement def ExudateRemovalRequirement {
        subject system : NegativePressureWoundTherapySystem;

        doc
        /* The system shall remove wound exudate from the sealed dressing and collect it in a replaceable canister without exposing the pump exhaust path to liquid. */

        require constraint {
            system.canister.collectedVolume <= system.canister.maximumCapacity
        }
    }

    requirement def CanisterFullProtectionRequirement {
        subject system : NegativePressureWoundTherapySystem;

        doc
        /* The system shall stop active suction and raise a critical alarm when collected exudate reaches the canister full threshold. */

        require constraint {
            system.levelSensor.measuredVolume < system.levelSensor.fullThreshold or system.pump.pumpEnabled == false
        }
    }

    requirement def LeakDetectionRequirement {
        subject system : NegativePressureWoundTherapySystem;

        doc
        /* The system shall detect loss of dressing seal when pressure cannot be maintained despite sustained pump flow. */

        require constraint {
            system.dressing.sealed == true or system.controller.criticalAlarmPresent == true
        }
    }

    requirement def BatteryOperationRequirement {
        subject system : NegativePressureWoundTherapySystem;

        doc
        /* The system shall support portable operation from internal battery power and shall alarm before battery charge is insufficient for continued therapy. */

        require constraint {
            system.battery.chargeRemaining >= system.battery.lowChargeThreshold or system.controller.criticalAlarmPresent == true
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : NegativePressureWoundTherapySystem;

        doc
        /* The primary function of the system shall be to provide controlled negative pressure at the wound interface while removing exudate into a protected collection path. */

        require constraint {
            system.targetPressure < 0.0 and system.canister.maximumCapacity > 0.0
        }
    }

    satisfy ControlledNegativePressureRequirement by NegativePressureWoundTherapySystem;
    satisfy ExudateRemovalRequirement by NegativePressureWoundTherapySystem;
    satisfy CanisterFullProtectionRequirement by NegativePressureWoundTherapySystem;
    satisfy LeakDetectionRequirement by NegativePressureWoundTherapySystem;
    satisfy BatteryOperationRequirement by NegativePressureWoundTherapySystem;
    satisfy PrimaryFunctionRequirement by NegativePressureWoundTherapySystem;

    part npwtSystem : NegativePressureWoundTherapySystem;
}