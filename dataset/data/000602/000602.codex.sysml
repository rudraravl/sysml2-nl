package EucomedBasedInfusionSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Volume_ml :> Real {
        unit = "mL";
    }

    attribute def FlowRate_ml_per_h :> Real {
        unit = "mL/h";
    }

    attribute def Pressure_kPa :> Real {
        unit = "kPa";
    }

    attribute def Time_s :> Real {
        unit = "s";
    }

    attribute def BatteryPercent :> Real {
        unit = "%";
    }

    attribute def DoseMass_mg :> Real {
        unit = "mg";
    }

    enum def AlarmPriority {
        enum low;
        enum medium;
        enum high;
    }

    item def MedicationFluid {
        attribute medicationName : String;
        attribute concentration : Real;
        attribute availableVolume : Volume_ml;
        attribute prescribedDose : DoseMass_mg;
    }

    item def InfusionCommand {
        attribute targetRate : FlowRate_ml_per_h;
        attribute targetVolume : Volume_ml;
        attribute therapyDuration : Time_s;
        attribute clinicianId : String;
    }

    item def InfusionStatus {
        attribute deliveredVolume : Volume_ml;
        attribute activeRate : FlowRate_ml_per_h;
        attribute linePressure : Pressure_kPa;
        attribute batteryState : BatteryPercent;
        attribute therapyRunning : Boolean;
    }

    item def AlarmSignal {
        attribute message : String;
        attribute priority : AlarmPriority;
        attribute active : Boolean;
    }

    port def FluidInPort {
        in item fluid : MedicationFluid;
    }

    port def FluidOutPort {
        out item fluid : MedicationFluid;
    }

    port def CommandPort {
        in item command : InfusionCommand;
    }

    port def StatusPort {
        out item status : InfusionStatus;
    }

    port def AlarmPort {
        out item alarm : AlarmSignal;
    }

    port def PowerPort {
        in attribute supplyVoltage : Real;
        out attribute loadCurrent : Real;
    }

    part def DisposableInfusionSet {
        port inlet : FluidInPort;
        port outlet : FluidOutPort;

        attribute primed : Boolean;
        attribute sterileBarrierIntact : Boolean;
        attribute maxPressure : Pressure_kPa = 200.0;
    }

    part def DrugReservoir {
        port outlet : FluidOutPort;

        attribute loadedFluid : MedicationFluid;
        attribute reservoirVolume : Volume_ml;
        attribute minimumUsableVolume : Volume_ml = 1.0;
    }

    part def PumpMechanism {
        port inlet : FluidInPort;
        port outlet : FluidOutPort;

        attribute commandedRate : FlowRate_ml_per_h;
        attribute measuredRate : FlowRate_ml_per_h;
        attribute motorEnabled : Boolean;
        attribute occlusionPressureLimit : Pressure_kPa = 120.0;
    }

    part def SensorSuite {
        port statusOut : StatusPort;

        attribute measuredPressure : Pressure_kPa;
        attribute measuredDeliveredVolume : Volume_ml;
        attribute batteryCharge : BatteryPercent;
        attribute airInLineDetected : Boolean;
        attribute doorOpen : Boolean;
    }

    part def UserInterface {
        port commandOut : CommandPort;
        port statusIn : StatusPort;
        port alarmIn : AlarmPort;

        attribute displayActive : Boolean;
        attribute confirmationRequired : Boolean;
        attribute lastClinicianId : String;
    }

    part def ControlProcessor {
        port commandIn : CommandPort;
        port pumpCommandOut : CommandPort;
        port statusIn : StatusPort;
        port statusOut : StatusPort;
        port alarmOut : AlarmPort;

        attribute requestedRate : FlowRate_ml_per_h;
        attribute requestedVolume : Volume_ml;
        attribute deliveredVolume : Volume_ml;
        attribute therapyAuthorized : Boolean;
        attribute faultLatched : Boolean;
    }

    part def BatteryModule {
        port powerOut : PowerPort;

        attribute chargeRemaining : BatteryPercent;
        attribute minimumOperatingCharge : BatteryPercent = 15.0;
        attribute rechargeable : Boolean = true;
    }

    part def MainsPowerAdapter {
        port powerOut : PowerPort;

        attribute inputVoltage : Real = 230.0;
        attribute outputVoltage : Real = 12.0;
    }

    part def MedicalInfusionPump {
        port medicationIn : FluidInPort;
        port medicationOut : FluidOutPort;
        port clinicianCommand : CommandPort;
        port therapyStatus : StatusPort;
        port alarmNotification : AlarmPort;
        port externalPower : PowerPort;

        part reservoir : DrugReservoir;
        part infusionSet : DisposableInfusionSet;
        part pump : PumpMechanism;
        part sensors : SensorSuite;
        part controller : ControlProcessor;
        part ui : UserInterface;
        part battery : BatteryModule;
        part mainsAdapter : MainsPowerAdapter;

        connect medicationIn to reservoir.outlet;
        connect reservoir.outlet to pump.inlet;
        connect pump.outlet to infusionSet.inlet;
        connect infusionSet.outlet to medicationOut;

        connect clinicianCommand to ui.commandOut;
        connect ui.commandOut to controller.commandIn;
        connect controller.pumpCommandOut to pump.inlet;

        connect sensors.statusOut to controller.statusIn;
        connect controller.statusOut to therapyStatus;
        connect controller.statusOut to ui.statusIn;
        connect controller.alarmOut to alarmNotification;
        connect controller.alarmOut to ui.alarmIn;

        connect externalPower to mainsAdapter.powerOut;
        connect battery.powerOut to externalPower;

        perform action validatePrescription {
            in item command : InfusionCommand;
            out attribute valid : Boolean;

            valid = command.targetRate > 0.0 and
                    command.targetVolume > 0.0 and
                    command.therapyDuration > 0.0;
        }

        perform action regulateInfusion {
            in item command : InfusionCommand;
            in item status : InfusionStatus;
            out attribute adjustedRate : FlowRate_ml_per_h;

            adjustedRate = command.targetRate;
        }

        perform action raiseSafetyAlarm {
            in attribute pressure : Pressure_kPa;
            in attribute battery : BatteryPercent;
            out item alarm : AlarmSignal;

            if pressure > 120.0 {
                alarm.message = "Occlusion pressure limit exceeded";
                alarm.priority = AlarmPriority::high;
                alarm.active = true;
            } else if battery < 15.0 {
                alarm.message = "Battery below minimum operating reserve";
                alarm.priority = AlarmPriority::medium;
                alarm.active = true;
            } else {
                alarm.message = "No active safety alarm";
                alarm.priority = AlarmPriority::low;
                alarm.active = false;
            }
        }

        state def TherapyLifecycle {
            state Off;
            state SelfTest;
            state Ready;
            state Programmed;
            state Infusing;
            state Paused;
            state Complete;
            state Alarmed;

            initial then Off;

            transition Off_to_SelfTest
                first Off
                accept PowerApplied
                then SelfTest;

            transition SelfTest_to_Ready
                first SelfTest
                accept SelfTestPassed
                then Ready;

            transition SelfTest_to_Alarmed
                first SelfTest
                accept SelfTestFailed
                then Alarmed;

            transition Ready_to_Programmed
                first Ready
                accept ValidPrescriptionEntered
                then Programmed;

            transition Programmed_to_Infusing
                first Programmed
                accept StartConfirmed
                then Infusing;

            transition Infusing_to_Paused
                first Infusing
                accept PauseRequested
                then Paused;

            transition Paused_to_Infusing
                first Paused
                accept ResumeRequested
                then Infusing;

            transition Infusing_to_Complete
                first Infusing
                accept TargetVolumeDelivered
                then Complete;

            transition Infusing_to_Alarmed
                first Infusing
                accept UnsafeConditionDetected
                then Alarmed;

            transition Alarmed_to_Ready
                first Alarmed
                accept FaultCleared
                then Ready;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject pump : MedicalInfusionPump;

        doc /* The system shall provide controlled, monitored delivery of prescribed medication fluid from a reservoir to a patient through a disposable infusion set. */
    }

    requirement def EucomedMedicalTechnologyContextRequirement {
        subject pump : MedicalInfusionPump;

        doc /* The system shall represent a Eucomed-style medical technology system whose high-level purpose is to support diagnosis, prevention, monitoring, treatment, or alleviation of disease by safely administering therapy in a clinical care environment. */
    }

    requirement def FlowAccuracyRequirement {
        subject pump : PumpMechanism;

        attribute commandedRate : FlowRate_ml_per_h;
        attribute measuredRate : FlowRate_ml_per_h;

        require constraint {
            abs(measuredRate - commandedRate) <= commandedRate * 0.05
        }

        doc /* The pump mechanism shall maintain delivered flow within five percent of the commanded infusion rate during normal operation. */
    }

    requirement def OcclusionDetectionRequirement {
        subject pump : MedicalInfusionPump;

        attribute pressureLimit : Pressure_kPa = 120.0;

        require constraint {
            pump.sensors.measuredPressure <= pressureLimit or
            pump.controller.faultLatched == true
        }

        doc /* The system shall detect excessive downstream pressure and latch a fault alarm before continued infusion can create unsafe delivery conditions. */
    }

    requirement def BatteryReserveRequirement {
        subject pump : MedicalInfusionPump;

        attribute reserveLimit : BatteryPercent = 15.0;

        require constraint {
            pump.battery.chargeRemaining >= reserveLimit or
            pump.controller.faultLatched == true
        }

        doc /* The system shall warn the user when battery reserve is below the minimum operating threshold. */
    }

    requirement def SterilePathRequirement {
        subject set : DisposableInfusionSet;

        require constraint {
            set.primed == true and set.sterileBarrierIntact == true
        }

        doc /* The disposable fluid path shall be primed and maintain sterile barrier integrity before therapy starts. */
    }

    requirement def ClinicianAuthorizationRequirement {
        subject controller : ControlProcessor;

        require constraint {
            controller.therapyAuthorized == true
        }

        doc /* The controller shall start infusion only after clinician-entered therapy parameters are validated and confirmed. */
    }

    satisfy PrimaryFunctionRequirement by MedicalInfusionPump;
    satisfy EucomedMedicalTechnologyContextRequirement by MedicalInfusionPump;
    satisfy FlowAccuracyRequirement by PumpMechanism;
    satisfy OcclusionDetectionRequirement by MedicalInfusionPump;
    satisfy BatteryReserveRequirement by MedicalInfusionPump;
    satisfy SterilePathRequirement by DisposableInfusionSet;
    satisfy ClinicianAuthorizationRequirement by ControlProcessor;
}