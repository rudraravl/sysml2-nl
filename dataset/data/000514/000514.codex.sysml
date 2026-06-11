package TranscranialDirectCurrentStimulationSystem {

    import ScalarValues::*;
    import SI::*;

    value def ElectricCurrent_mA {
        unit = "mA";
        quantityKind = "electric current";
    }

    value def ElectricPotential_V {
        unit = "V";
        quantityKind = "electric potential";
    }

    value def ElectricalResistance_ohm {
        unit = "ohm";
        quantityKind = "electrical resistance";
    }

    value def Time_s {
        unit = "s";
        quantityKind = "time";
    }

    value def Time_min {
        unit = "min";
        quantityKind = "time";
    }

    value def Temperature_C {
        unit = "degC";
        quantityKind = "temperature";
    }

    value def ChargeDensity_mC_per_cm2 {
        unit = "mC/cm^2";
        quantityKind = "charge density";
    }

    value def ContactArea_cm2 {
        unit = "cm^2";
        quantityKind = "area";
    }

    enum def SessionMode {
        enum sham;
        enum lowIntensity;
        enum standardIntensity;
        enum clinicianLocked;
    }

    enum def FaultCode {
        enum noFault;
        enum highImpedance;
        enum openElectrode;
        enum overCurrent;
        enum overVoltage;
        enum overTemperature;
        enum batteryLow;
        enum emergencyStop;
        enum sessionTimeout;
    }

    item def StimulationCurrent {
        attribute magnitude : ElectricCurrent_mA;
        attribute polarity : Integer;
        attribute rampLimited : Boolean;
    }

    item def VoltageFeedback {
        attribute electrodeVoltage : ElectricPotential_V;
    }

    item def ImpedanceMeasurement {
        attribute impedance : ElectricalResistance_ohm;
        attribute valid : Boolean;
    }

    item def TemperatureMeasurement {
        attribute temperature : Temperature_C;
        attribute sensorValid : Boolean;
    }

    item def SessionPrescription {
        attribute targetCurrent : ElectricCurrent_mA;
        attribute rampUpTime : Time_s;
        attribute stimulationDuration : Time_min;
        attribute rampDownTime : Time_s;
        attribute mode : SessionMode;
        attribute maximumChargeDensity : ChargeDensity_mC_per_cm2;
    }

    item def SessionStatus {
        attribute elapsedTime : Time_s;
        attribute deliveredCurrent : ElectricCurrent_mA;
        attribute measuredImpedance : ElectricalResistance_ohm;
        attribute activeFault : FaultCode;
        attribute stimulationActive : Boolean;
    }

    port def ElectrodeOutputPort {
        out current : StimulationCurrent;
        in voltage : VoltageFeedback;
        in impedance : ImpedanceMeasurement;
        in temperature : TemperatureMeasurement;
    }

    port def CommandPort {
        in prescription : SessionPrescription;
        in startCommand : Boolean;
        in stopCommand : Boolean;
        out status : SessionStatus;
    }

    port def PowerPort {
        in supplyVoltage : ElectricPotential_V;
        out loadCurrent : ElectricCurrent_mA;
    }

    port def ControlPort {
        out commandedCurrent : StimulationCurrent;
        in feedbackVoltage : VoltageFeedback;
        in feedbackImpedance : ImpedanceMeasurement;
        in feedbackTemperature : TemperatureMeasurement;
        out enableOutput : Boolean;
        out fault : FaultCode;
    }

    port def UserInterfacePort {
        in selectedPrescription : SessionPrescription;
        in startPressed : Boolean;
        in stopPressed : Boolean;
        out displayedStatus : SessionStatus;
        out audibleAlarm : Boolean;
    }

    action def ValidateElectrodeContact {
        in measuredImpedance : ElectricalResistance_ohm;
        in measuredTemperature : Temperature_C;
        out contactAcceptable : Boolean;

        constraint acceptableImpedance {
            measuredImpedance >= 500 [ohm] and measuredImpedance <= 20000 [ohm]
        }

        constraint acceptableTemperature {
            measuredTemperature <= 41 [degC]
        }
    }

    action def RampCurrent {
        in startCurrent : ElectricCurrent_mA;
        in targetCurrent : ElectricCurrent_mA;
        in rampTime : Time_s;
        out commandedCurrent : ElectricCurrent_mA;

        constraint monotonicRamp {
            rampTime >= 5 [s]
        }
    }

    action def RegulateDirectCurrent {
        in targetCurrent : ElectricCurrent_mA;
        in measuredVoltage : ElectricPotential_V;
        in measuredImpedance : ElectricalResistance_ohm;
        out regulatedCurrent : ElectricCurrent_mA;

        constraint outputLimit {
            targetCurrent <= 2.0 [mA]
        }

        constraint voltageCompliance {
            measuredVoltage <= 40 [V]
        }
    }

    action def MonitorSafety {
        in current : ElectricCurrent_mA;
        in voltage : ElectricPotential_V;
        in impedance : ElectricalResistance_ohm;
        in temperature : Temperature_C;
        in elapsedTime : Time_s;
        in prescribedDuration : Time_min;
        out fault : FaultCode;

        constraint currentLimit {
            current <= 2.0 [mA]
        }

        constraint voltageLimit {
            voltage <= 40 [V]
        }

        constraint temperatureLimit {
            temperature <= 41 [degC]
        }
    }

    action def DeliverTranscranialDirectCurrentStimulation {
        in prescription : SessionPrescription;
        in startCommand : Boolean;
        in stopCommand : Boolean;
        out status : SessionStatus;

        action validateContact : ValidateElectrodeContact;
        action rampUp : RampCurrent;
        action regulate : RegulateDirectCurrent;
        action monitor : MonitorSafety;
        action rampDown : RampCurrent;

        objective {
            deliver a controlled, low-amplitude direct electrical current between scalp electrodes to modulate cortical excitability while continuously limiting current, voltage, contact impedance, temperature, charge density, and session duration
        }
    }

    state def StimulationSessionStateMachine {
        in startCommand : Boolean;
        in stopCommand : Boolean;
        in contactAcceptable : Boolean;
        in activeFault : FaultCode;
        in elapsedTime : Time_s;
        in prescribedDuration : Time_min;

        state Off;
        state Ready;
        state ContactCheck;
        state RampUp;
        state Stimulating;
        state RampDown;
        state Completed;
        state Faulted;

        transition initial then Off;

        transition Off_to_Ready
            first Off
            accept startCommand
            then Ready;

        transition Ready_to_ContactCheck
            first Ready
            then ContactCheck;

        transition ContactCheck_to_RampUp
            first ContactCheck
            if contactAcceptable
            then RampUp;

        transition ContactCheck_to_Faulted
            first ContactCheck
            if not contactAcceptable
            then Faulted;

        transition RampUp_to_Stimulating
            first RampUp
            then Stimulating;

        transition Stimulating_to_RampDown_ByStop
            first Stimulating
            accept stopCommand
            then RampDown;

        transition Stimulating_to_RampDown_ByTime
            first Stimulating
            if elapsedTime >= prescribedDuration
            then RampDown;

        transition Stimulating_to_Faulted
            first Stimulating
            if activeFault != FaultCode::noFault
            then Faulted;

        transition RampDown_to_Completed
            first RampDown
            then Completed;

        transition Completed_to_Off
            first Completed
            then Off;

        transition Faulted_to_Off
            first Faulted
            accept stopCommand
            then Off;
    }

    part def RechargeableBattery {
        attribute nominalVoltage : ElectricPotential_V = 7.4 [V];
        attribute lowVoltageThreshold : ElectricPotential_V = 6.4 [V];

        port powerOut : PowerPort;
    }

    part def IsolatedPowerSupply {
        attribute outputVoltageLimit : ElectricPotential_V = 40 [V];
        attribute patientLeakageLimit : ElectricCurrent_mA = 0.01 [mA];

        port batteryIn : PowerPort;
        port isolatedOut : PowerPort;
    }

    part def CurrentRegulator {
        attribute maximumCurrent : ElectricCurrent_mA = 2.0 [mA];
        attribute currentResolution : ElectricCurrent_mA = 0.05 [mA];
        attribute voltageComplianceLimit : ElectricPotential_V = 40 [V];

        port powerIn : PowerPort;
        port control : ControlPort;
        port anodeOut : ElectrodeOutputPort;
        port cathodeOut : ElectrodeOutputPort;

        perform action regulateCurrent : RegulateDirectCurrent;
    }

    part def ImpedanceMonitor {
        attribute testCurrent : ElectricCurrent_mA = 0.1 [mA];
        attribute minimumAllowedImpedance : ElectricalResistance_ohm = 500 [ohm];
        attribute maximumAllowedImpedance : ElectricalResistance_ohm = 20000 [ohm];

        port anodeSense : ElectrodeOutputPort;
        port cathodeSense : ElectrodeOutputPort;
        port control : ControlPort;
    }

    part def ThermalMonitor {
        attribute maximumElectrodeTemperature : Temperature_C = 41 [degC];

        port anodeThermalSense : ElectrodeOutputPort;
        port cathodeThermalSense : ElectrodeOutputPort;
        port control : ControlPort;
    }

    part def SafetySupervisor {
        attribute absoluteCurrentLimit : ElectricCurrent_mA = 2.2 [mA];
        attribute absoluteVoltageLimit : ElectricPotential_V = 42 [V];
        attribute maximumSessionDuration : Time_min = 30 [min];

        port control : ControlPort;

        perform action monitor : MonitorSafety;
    }

    part def TreatmentController {
        attribute defaultRampUpTime : Time_s = 30 [s];
        attribute defaultRampDownTime : Time_s = 30 [s];
        attribute defaultDuration : Time_min = 20 [min];
        attribute defaultCurrent : ElectricCurrent_mA = 1.5 [mA];

        port userCommand : CommandPort;
        port regulatorControl : ControlPort;
        port safetyControl : ControlPort;

        state sessionStates : StimulationSessionStateMachine;

        perform action treatmentFunction : DeliverTranscranialDirectCurrentStimulation;
    }

    part def UserInterface {
        attribute alarmEnabled : Boolean = true;

        port ui : UserInterfacePort;
        port command : CommandPort;
    }

    part def ScalpElectrode {
        attribute contactArea : ContactArea_cm2 = 25 [cm^2];
        attribute hydrogelPresent : Boolean;
        attribute maximumChargeDensity : ChargeDensity_mC_per_cm2 = 216 [mC/cm^2];

        port patientContact : ElectrodeOutputPort;
    }

    part def ElectrodeLead {
        attribute conductorResistance : ElectricalResistance_ohm = 2 [ohm];

        port deviceEnd : ElectrodeOutputPort;
        port electrodeEnd : ElectrodeOutputPort;
    }

    part def PatientHeadInterface {
        part anode : ScalpElectrode {
            attribute contactArea = 25 [cm^2];
        }

        part cathode : ScalpElectrode {
            attribute contactArea = 25 [cm^2];
        }

        port anodeConnection : ElectrodeOutputPort;
        port cathodeConnection : ElectrodeOutputPort;
    }

    part def TDCSDevice {
        attribute deviceName : String = "Controlled Transcranial Direct Current Stimulator";
        attribute intendedUse : String = "Non-invasive delivery of regulated direct current through scalp electrodes for modulation of cortical excitability under supervised conditions.";

        part battery : RechargeableBattery;
        part isolatedSupply : IsolatedPowerSupply;
        part controller : TreatmentController;
        part regulator : CurrentRegulator;
        part impedanceMonitor : ImpedanceMonitor;
        part thermalMonitor : ThermalMonitor;
        part safetySupervisor : SafetySupervisor;
        part userInterface : UserInterface;

        port clinicianInterface : UserInterfacePort;
        port anodeLeadPort : ElectrodeOutputPort;
        port cathodeLeadPort : ElectrodeOutputPort;

        connect battery.powerOut to isolatedSupply.batteryIn;
        connect isolatedSupply.isolatedOut to regulator.powerIn;

        connect userInterface.command to controller.userCommand;
        connect clinicianInterface to userInterface.ui;

        connect controller.regulatorControl to regulator.control;
        connect controller.safetyControl to safetySupervisor.control;
        connect safetySupervisor.control to regulator.control;

        connect regulator.anodeOut to impedanceMonitor.anodeSense;
        connect regulator.cathodeOut to impedanceMonitor.cathodeSense;
        connect regulator.anodeOut to thermalMonitor.anodeThermalSense;
        connect regulator.cathodeOut to thermalMonitor.cathodeThermalSense;

        connect impedanceMonitor.control to controller.regulatorControl;
        connect thermalMonitor.control to controller.regulatorControl;

        connect regulator.anodeOut to anodeLeadPort;
        connect regulator.cathodeOut to cathodeLeadPort;
    }

    part def TDCSSystem {
        part device : TDCSDevice;
        part anodeLead : ElectrodeLead;
        part cathodeLead : ElectrodeLead;
        part patientInterface : PatientHeadInterface;

        connect device.anodeLeadPort to anodeLead.deviceEnd;
        connect anodeLead.electrodeEnd to patientInterface.anodeConnection;
        connect patientInterface.anodeConnection to patientInterface.anode.patientContact;

        connect device.cathodeLeadPort to cathodeLead.deviceEnd;
        connect cathodeLead.electrodeEnd to patientInterface.cathodeConnection;
        connect patientInterface.cathodeConnection to patientInterface.cathode.patientContact;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : TDCSSystem;

        require constraint {
            system.device.controller.treatmentFunction objective equals "deliver a controlled, low-amplitude direct electrical current between scalp electrodes to modulate cortical excitability while continuously limiting current, voltage, contact impedance, temperature, charge density, and session duration"
        }
    }

    requirement def CurrentControlRequirement {
        subject regulator : CurrentRegulator;

        require constraint {
            regulator.maximumCurrent <= 2.0 [mA]
        }
    }

    requirement def VoltageComplianceRequirement {
        subject regulator : CurrentRegulator;

        require constraint {
            regulator.voltageComplianceLimit <= 40 [V]
        }
    }

    requirement def ElectrodeContactRequirement {
        subject monitor : ImpedanceMonitor;

        require constraint {
            monitor.minimumAllowedImpedance >= 500 [ohm] and monitor.maximumAllowedImpedance <= 20000 [ohm]
        }
    }

    requirement def ThermalSafetyRequirement {
        subject monitor : ThermalMonitor;

        require constraint {
            monitor.maximumElectrodeTemperature <= 41 [degC]
        }
    }

    requirement def SessionDurationRequirement {
        subject supervisor : SafetySupervisor;

        require constraint {
            supervisor.maximumSessionDuration <= 30 [min]
        }
    }

    requirement def ChargeDensityRequirement {
        subject electrode : ScalpElectrode;

        require constraint {
            electrode.maximumChargeDensity <= 216 [mC/cm^2]
        }
    }

    requirement def IsolationRequirement {
        subject supply : IsolatedPowerSupply;

        require constraint {
            supply.patientLeakageLimit <= 0.01 [mA]
        }
    }

    satisfy PrimaryFunctionRequirement by TDCSSystem;
    satisfy CurrentControlRequirement by CurrentRegulator;
    satisfy VoltageComplianceRequirement by CurrentRegulator;
    satisfy ElectrodeContactRequirement by ImpedanceMonitor;
    satisfy ThermalSafetyRequirement by ThermalMonitor;
    satisfy SessionDurationRequirement by SafetySupervisor;
    satisfy ChargeDensityRequirement by ScalpElectrode;
    satisfy IsolationRequirement by IsolatedPowerSupply;
}