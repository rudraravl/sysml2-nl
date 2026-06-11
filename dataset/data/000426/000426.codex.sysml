package AspirationTherapySystemModel {

    import ScalarValues::*;
    import SI::*;

    attribute def Volume_ml :> Real {
        unit = "mL";
    }

    attribute def FlowRate_ml_per_min :> Real {
        unit = "mL/min";
    }

    attribute def Pressure_kPa :> Real {
        unit = "kPa";
    }

    attribute def Time_s :> Real {
        unit = "s";
    }

    attribute def Temperature_C :> Real {
        unit = "degC";
    }

    attribute def BatteryPercent :> Real {
        unit = "%";
    }

    attribute def SterilityState :> String;
    attribute def TherapyMode :> String;
    attribute def AlarmSeverity :> String;

    item def AspiratedFluid {
        attribute volume : Volume_ml;
        attribute temperature : Temperature_C;
        attribute containsTissueFragments : Boolean;
        attribute biohazardStatus : SterilityState;
    }

    item def NegativePressure {
        attribute setpoint : Pressure_kPa;
        attribute measuredPressure : Pressure_kPa;
        attribute tolerance : Pressure_kPa;
    }

    item def TherapyCommand {
        attribute requestedMode : TherapyMode;
        attribute targetPressure : Pressure_kPa;
        attribute targetFlowRate : FlowRate_ml_per_min;
        attribute maxSessionVolume : Volume_ml;
    }

    item def TherapyStatus {
        attribute active : Boolean;
        attribute deliveredPressure : Pressure_kPa;
        attribute measuredFlowRate : FlowRate_ml_per_min;
        attribute collectedVolume : Volume_ml;
        attribute alarmActive : Boolean;
    }

    item def AlarmSignal {
        attribute severity : AlarmSeverity;
        attribute message : String;
        attribute latched : Boolean;
    }

    port def FluidInletPort {
        in item fluid : AspiratedFluid;
    }

    port def FluidOutletPort {
        out item fluid : AspiratedFluid;
    }

    port def VacuumPort {
        out item vacuum : NegativePressure;
    }

    port def CommandPort {
        in item command : TherapyCommand;
    }

    port def StatusPort {
        out item status : TherapyStatus;
    }

    port def AlarmPort {
        out item alarm : AlarmSignal;
    }

    port def PowerPort {
        in attribute supplyVoltage : Real;
        out attribute loadCurrent : Real;
    }

    part def PatientInterface {
        port tissueAccess : FluidInletPort;
        port therapyLine : FluidOutletPort;

        attribute insertionDepth_mm : Real;
        attribute occlusionDetected : Boolean;
        attribute sterileBarrierIntact : Boolean;
    }

    part def AspirationCatheter {
        port proximalEnd : FluidInletPort;
        port distalEnd : FluidOutletPort;

        attribute innerDiameter_mm : Real;
        attribute workingLength_mm : Real;
        attribute kinkDetected : Boolean;
        attribute primed : Boolean;
    }

    part def DisposableTubingSet {
        port catheterSide : FluidInletPort;
        port pumpSide : FluidOutletPort;

        attribute installed : Boolean;
        attribute leakDetected : Boolean;
        attribute singleUse : Boolean = true;
        attribute sterile : Boolean;
    }

    part def VacuumPump {
        port suctionOutput : VacuumPort;
        port fluidInput : FluidInletPort;
        port fluidOutput : FluidOutletPort;
        port electricalInput : PowerPort;

        attribute commandedPressure : Pressure_kPa;
        attribute actualPressure : Pressure_kPa;
        attribute maximumPressure : Pressure_kPa = 80.0;
        attribute minimumPressure : Pressure_kPa = 5.0;
        attribute motorSpeed_rpm : Real;
        attribute enabled : Boolean;
    }

    part def CollectionCanister {
        port inlet : FluidInletPort;
        port ventVacuum : VacuumPort;

        attribute capacity : Volume_ml = 1000.0;
        attribute collectedVolume : Volume_ml;
        attribute full : Boolean;
        attribute sealed : Boolean;
        attribute biohazardLabelPresent : Boolean;
    }

    part def PressureSensor {
        port sensedVacuum : VacuumPort;

        attribute measuredPressure : Pressure_kPa;
        attribute calibrated : Boolean;
        attribute samplingPeriod : Time_s = 0.05;
    }

    part def FlowSensor {
        port sensedFluid : FluidInletPort;

        attribute measuredFlowRate : FlowRate_ml_per_min;
        attribute calibrated : Boolean;
        attribute minimumDetectableFlow : FlowRate_ml_per_min = 1.0;
    }

    part def UserInterface {
        port clinicianCommands : CommandPort;
        port systemStatus : StatusPort;
        port systemAlarms : AlarmPort;

        attribute displayEnabled : Boolean;
        attribute selectedMode : TherapyMode;
        attribute targetPressure : Pressure_kPa;
        attribute startButtonPressed : Boolean;
        attribute stopButtonPressed : Boolean;
        attribute muteAlarmPressed : Boolean;
    }

    part def ControlUnit {
        port commandInput : CommandPort;
        port statusOutput : StatusPort;
        port alarmOutput : AlarmPort;
        port pumpCommand : VacuumPort;

        attribute therapyActive : Boolean;
        attribute targetPressure : Pressure_kPa;
        attribute targetFlowRate : FlowRate_ml_per_min;
        attribute sessionVolumeLimit : Volume_ml;
        attribute sessionElapsedTime : Time_s;
        attribute faultLatched : Boolean;
    }

    part def BatteryPowerModule {
        port powerOutput : PowerPort;

        attribute chargeLevel : BatteryPercent;
        attribute mainsConnected : Boolean;
        attribute lowBattery : Boolean;
        attribute outputVoltage : Real = 24.0;
    }

    part def AspirationTherapySystem {
        port command : CommandPort;
        port status : StatusPort;
        port alarm : AlarmPort;
        port patientAccess : FluidInletPort;

        part patientInterface : PatientInterface;
        part catheter : AspirationCatheter;
        part tubing : DisposableTubingSet;
        part pump : VacuumPump;
        part canister : CollectionCanister;
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part ui : UserInterface;
        part controller : ControlUnit;
        part battery : BatteryPowerModule;

        attribute primaryFunction : String =
            "Apply controlled negative pressure through a sterile patient interface to remove unwanted fluid or soft material and collect it safely in a sealed container while monitoring pressure, flow, volume, and alarms.";

        attribute readyForTherapy : Boolean;
        attribute therapyMode : TherapyMode;
        attribute totalCollectedVolume : Volume_ml;
        attribute deliveredPressure : Pressure_kPa;

        connect patientAccess to patientInterface.tissueAccess;
        connect patientInterface.therapyLine to catheter.proximalEnd;
        connect catheter.distalEnd to tubing.catheterSide;
        connect tubing.pumpSide to pump.fluidInput;
        connect pump.fluidOutput to canister.inlet;
        connect pump.suctionOutput to pressureSensor.sensedVacuum;
        connect tubing.pumpSide to flowSensor.sensedFluid;
        connect battery.powerOutput to pump.electricalInput;
        connect command to ui.clinicianCommands;
        connect ui.clinicianCommands to controller.commandInput;
        connect controller.statusOutput to ui.systemStatus;
        connect controller.alarmOutput to ui.systemAlarms;
        connect ui.systemStatus to status;
        connect ui.systemAlarms to alarm;
        connect controller.pumpCommand to pump.suctionOutput;
    }

    action def InitializeTherapySystem {
        in part system : AspirationTherapySystem;
        out attribute initialized : Boolean;

        first start;
        then verifyDisposableInstalled;
        then verifySensorsCalibrated;
        then verifyCanisterReady;
        then verifyBatteryOrMainsPower;
        then initialized = system.tubing.installed and
                           system.tubing.sterile and
                           system.pressureSensor.calibrated and
                           system.flowSensor.calibrated and
                           system.canister.sealed and
                           not system.canister.full and
                           not system.battery.lowBattery;
    }

    action def RegulateAspiration {
        in part system : AspirationTherapySystem;
        in item command : TherapyCommand;
        out item status : TherapyStatus;

        first receiveCommand;
        then setTargetPressure;
        then enablePump;
        then monitorPressureAndFlow;
        then adjustMotorSpeed;
        then updateCollectedVolume;
        then status.active = system.controller.therapyActive;
        then status.deliveredPressure = system.pressureSensor.measuredPressure;
        then status.measuredFlowRate = system.flowSensor.measuredFlowRate;
        then status.collectedVolume = system.canister.collectedVolume;
        then status.alarmActive = system.controller.faultLatched;
    }

    action def StopAspiration {
        in part system : AspirationTherapySystem;
        out item status : TherapyStatus;

        first disablePump;
        then ventResidualVacuum;
        then sealFluidPath;
        then status.active = false;
        then status.deliveredPressure = 0.0;
        then status.measuredFlowRate = 0.0;
        then status.collectedVolume = system.canister.collectedVolume;
        then status.alarmActive = system.controller.faultLatched;
    }

    state def TherapyOperatingState {
        entry action InitializeTherapySystem;

        state Off;
        state SelfTest;
        state Ready;
        state Aspirating;
        state Paused;
        state Complete;
        state Fault;

        transition initial then Off;

        transition Off_to_SelfTest
            first Off
            accept TherapyCommand
            if command.requestedMode == "PowerOn"
            then SelfTest;

        transition SelfTest_to_Ready
            first SelfTest
            if readyForTherapy
            then Ready;

        transition SelfTest_to_Fault
            first SelfTest
            if not readyForTherapy
            then Fault;

        transition Ready_to_Aspirating
            first Ready
            accept TherapyCommand
            if command.requestedMode == "StartAspiration"
            do RegulateAspiration
            then Aspirating;

        transition Aspirating_to_Paused
            first Aspirating
            accept TherapyCommand
            if command.requestedMode == "Pause"
            do StopAspiration
            then Paused;

        transition Paused_to_Aspirating
            first Paused
            accept TherapyCommand
            if command.requestedMode == "Resume"
            do RegulateAspiration
            then Aspirating;

        transition Aspirating_to_Complete
            first Aspirating
            if totalCollectedVolume >= controller.sessionVolumeLimit
            do StopAspiration
            then Complete;

        transition Aspirating_to_Fault
            first Aspirating
            if canister.full or tubing.leakDetected or catheter.kinkDetected or battery.lowBattery
            do StopAspiration
            then Fault;

        transition Ready_to_Off
            first Ready
            accept TherapyCommand
            if command.requestedMode == "PowerOff"
            then Off;

        transition Complete_to_Ready
            first Complete
            accept TherapyCommand
            if command.requestedMode == "ResetSession"
            then Ready;

        transition Fault_to_Ready
            first Fault
            accept TherapyCommand
            if command.requestedMode == "ClearFault" and readyForTherapy
            then Ready;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : AspirationTherapySystem;

        doc /* The aspiration therapy system shall provide controlled negative pressure through a sterile fluid path to remove targeted fluid or soft material from the patient interface and collect it in a sealed canister. */

        require constraint {
            system.readyForTherapy implies
            system.patientInterface.sterileBarrierIntact and
            system.tubing.installed and
            system.canister.sealed
        }
    }

    requirement def PressureControlRequirement {
        subject system : AspirationTherapySystem;

        attribute allowedPressureError : Pressure_kPa = 5.0;

        doc /* During active aspiration, measured negative pressure shall remain within the specified tolerance of the clinician-selected target pressure. */

        require constraint {
            system.controller.therapyActive implies
            abs(system.pressureSensor.measuredPressure - system.controller.targetPressure) <= allowedPressureError
        }
    }

    requirement def FluidContainmentRequirement {
        subject system : AspirationTherapySystem;

        doc /* Aspirated material shall remain contained within the catheter, tubing, pump fluid path, and sealed collection canister during therapy. */

        require constraint {
            system.tubing.leakDetected == false and
            system.canister.sealed == true
        }
    }

    requirement def CanisterCapacityRequirement {
        subject system : AspirationTherapySystem;

        doc /* Therapy shall stop before collected volume exceeds the usable capacity of the collection canister. */

        require constraint {
            system.canister.collectedVolume <= system.canister.capacity
        }
    }

    requirement def AlarmRequirement {
        subject system : AspirationTherapySystem;

        doc /* The system shall generate an alarm when aspiration cannot be delivered safely or when therapy limits are reached. */

        require constraint {
            (system.canister.full or
             system.tubing.leakDetected or
             system.catheter.kinkDetected or
             system.battery.lowBattery) implies
            system.controller.faultLatched
        }
    }

    requirement def SingleUseSterilePathRequirement {
        subject system : AspirationTherapySystem;

        doc /* The patient-contacting disposable fluid path shall be sterile before therapy and identified as single-use. */

        require constraint {
            system.tubing.singleUse == true and
            system.tubing.sterile == true and
            system.catheter.primed == true
        }
    }

    requirement def StatusReportingRequirement {
        subject system : AspirationTherapySystem;

        doc /* The system shall report therapy activity, pressure, flow rate, collected volume, and alarm state to the user interface. */

        require constraint {
            system.status.status.active == system.controller.therapyActive and
            system.status.status.deliveredPressure == system.pressureSensor.measuredPressure and
            system.status.status.measuredFlowRate == system.flowSensor.measuredFlowRate and
            system.status.status.collectedVolume == system.canister.collectedVolume
        }
    }

    satisfy PrimaryFunctionRequirement by AspirationTherapySystem;
    satisfy PressureControlRequirement by ControlUnit;
    satisfy FluidContainmentRequirement by DisposableTubingSet;
    satisfy CanisterCapacityRequirement by CollectionCanister;
    satisfy AlarmRequirement by ControlUnit;
    satisfy SingleUseSterilePathRequirement by DisposableTubingSet;
    satisfy StatusReportingRequirement by UserInterface;

}