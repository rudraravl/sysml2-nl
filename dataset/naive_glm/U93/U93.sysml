package NeuroStimSystem {

import ScalarValues::*;

// =================================================================
// VALUE TYPES WITH UNITS
// =================================================================

value type Current_uA :> Real {
    attribute unitLabel : String = "microampere";
    attribute minVal : Real = 0;
    attribute maxVal : Real = 30000;
}
value type Frequency_Hz :> Real {
    attribute unitLabel : String = "hertz";
    attribute minVal : Real = 1;
    attribute maxVal : Real = 1000;
}
value type PulseWidth_us :> Real {
    attribute unitLabel : String = "microsecond";
    attribute minVal : Real = 10;
    attribute maxVal : Real = 1000;
}
value type Impedance_Ohm :> Real {
    attribute unitLabel : String = "ohm";
    attribute minVal : Real = 0;
    attribute maxVal : Real = 10000;
}
value type Voltage_V :> Real {
    attribute unitLabel : String = "volt";
}
value type Battery_pct :> Real {
    attribute unitLabel : String = "percent";
    attribute minVal : Real = 0;
    attribute maxVal : Real = 100;
}
value type Time_s :> Real {
    attribute unitLabel : String = "second";
}
value type Signal_uV :> Real {
    attribute unitLabel : String = "microvolt";
}
value type Power_mW :> Real {
    attribute unitLabel : String = "milliwatt";
}
value type BiomarkerLevel :> Real {
    attribute minVal : Real = 0;
    attribute maxVal : Real = 1;
}
value type Length_cm :> Real {
    attribute unitLabel : String = "centimeter";
}
value type Area_mm2 :> Real {
    attribute unitLabel : String = "square millimeter";
}

// =================================================================
// ITEM DEFINITIONS
// =================================================================

item def NeuralSignal {
    attribute amplitude : Signal_uV;
    attribute frequency : Frequency_Hz;
    attribute timestamp : Time_s;
    attribute channel : Integer;
}

item def SensingData {
    attribute filteredAmplitude : Signal_uV;
    attribute biomarkerLevel : BiomarkerLevel;
    attribute confidence : Real;
    attribute timestamp : Time_s;
    attribute channel : Integer;
}

item def StimulationCommand {
    attribute electrode : Integer;
    attribute amplitude : Current_uA;
    attribute frequency : Frequency_Hz;
    attribute pulseWidth : PulseWidth_us;
    attribute enable : Boolean;
}

item def StimulationPulse {
    attribute amplitude : Current_uA;
    attribute frequency : Frequency_Hz;
    attribute pulseWidth : PulseWidth_us;
    attribute electrode : Integer;
}

item def TherapyGoal {
    attribute targetBiomarker : BiomarkerLevel;
    attribute minAmplitude : Current_uA;
    attribute maxAmplitude : Current_uA;
    attribute adjustmentEnabled : Boolean;
}

item def SystemStatus {
    attribute batteryLevel : Battery_pct;
    attribute operatingState : String;
    attribute leadImpedance : Impedance_Ohm;
    attribute faultFlag : Boolean;
    attribute faultCode : String;
}

item def DiagnosticData {
    attribute status : SystemStatus;
    attribute therapyHistory : StimulationCommand[0..*];
    attribute impedanceTrend : Impedance_Ohm[0..*];
    attribute eventLog : String[0..*];
}

item def Configuration {
    attribute therapy : TherapyGoal;
    attribute maxSafeCurrent : Current_uA;
    attribute maxSafeImpedance : Impedance_Ohm;
    attribute minSafeImpedance : Impedance_Ohm;
    attribute patientId : String;
}

// =================================================================
// PORT DEFINITIONS
// =================================================================

port def NeuralSignalPort {
    out signal : NeuralSignal;
}

port def SensingDataPort {
    out data : SensingData;
}

port def StimulationCommandPort {
    out cmd : StimulationCommand;
}

port def StimulationPulsePort {
    out pulse : StimulationPulse;
}

port def PowerPort {
    out supplyVoltage : Voltage_V;
    out maxCurrent : Current_uA;
    out batteryLevel : Battery_pct;
}

port def StimMonitorPort {
    out deliveredCurrent : Current_uA;
    out leadImpedance : Impedance_Ohm;
}

port def SafetyAlertPort {
    out impedance : Impedance_Ohm;
    out deliveredCurrent : Current_uA;
    out faultDetected : Boolean;
    out faultCode : String;
}

port def TelemetryPort {
    in config : Configuration;
    out diag : DiagnosticData;
    out status : SystemStatus;
}

// =================================================================
// REQUIREMENT DEFINITIONS
// =================================================================

requirement def ClosedLoopControlReq {
    doc "The system shall continuously monitor neural activity and automatically adjust therapy in real-time to manage symptoms.";
}

requirement def SensingReq {
    doc "The sensing subsystem shall detect and filter raw neural signals to extract biomarker levels indicating the patient neurological state.";
}

requirement def StimulationReq {
    doc "The stimulation subsystem shall generate electrical pulses with configurable amplitude, frequency, and pulse width.";
}

requirement def SafetyMonitoringReq {
    doc "The safety subsystem shall monitor tissue impedance and delivered current and immediately halt therapy upon detecting unsafe conditions such as a broken lead.";
}

requirement def PowerMgmtReq {
    doc "The power subsystem shall provide stable power to all components and track remaining battery charge.";
}

requirement def TelemetryReq {
    doc "The system shall support wireless communication with an external programmer for configuration, safety limit setting, and diagnostic data download.";
}

requirement def StateMgmtReq {
    doc "The control subsystem shall manage system states including Standby, Active Therapy, Adjusting, and Fault.";
}

requirement def FaultResponseReq {
    doc "Upon detecting a fault the system shall enter a Fault state and safely halt all stimulation to prevent patient harm.";
}

requirement def LeadReq {
    doc "The lead assembly shall provide flexible wires with electrodes at the tip to both deliver therapeutic pulses and listen to neural signals in the target nervous system area.";
}

requirement def ProgrammerReq {
    doc "The external programmer shall allow clinicians to configure therapy, set safety limits, and download diagnostic data including battery level and system performance.";
}

// =================================================================
// PART DEFINITIONS
// =================================================================

// ---- Electrode ----
part def Electrode {
    attribute id : Integer;
    attribute positionDescription : String;
    attribute surfaceArea : Area_mm2;

    port leadNeural : NeuralSignalPort;
    port leadStim : ~StimulationPulsePort;
    port tissueNeural : ~NeuralSignalPort;
    port tissueStim : StimulationPulsePort;
}

// ---- Lead Assembly ----
part def LeadAssembly {
    attribute leadId : String;
    attribute leadType : String = "DBS";
    attribute electrodeCount : Integer = 4;
    attribute leadLength : Length_cm;

    part electrodes : Electrode[1..*];

    port ipgNeural : NeuralSignalPort;
    port ipgStim : ~StimulationPulsePort;
    port tissueNeural : ~NeuralSignalPort;
    port tissueStim : StimulationPulsePort;

    connection c1 connect ipgStim to electrodes.leadStim;
    connection c2 connect electrodes.leadNeural to ipgNeural;
    connection c3 connect tissueNeural to electrodes.tissueNeural;
    connection c4 connect electrodes.tissueStim to tissueStim;

    satisfy LeadReq;
}

// ---- Sensing Subsystem ----
part def SensingSubsystem {
    port neuralIn : ~NeuralSignalPort;
    port dataOut : SensingDataPort;
    port powerIn : ~PowerPort;

    attribute sampleRate : Frequency_Hz = 250;
    attribute filterBandwidth : Frequency_Hz = 500;
    attribute noiseFloor : Signal_uV = 5;
    attribute lastSensingData : SensingData;

    action acquireAndProcess {
        in rawSignal : NeuralSignal;
        out processedData : SensingData;
        processedData.filteredAmplitude = rawSignal.amplitude - noiseFloor;
        processedData.timestamp = rawSignal.timestamp;
        processedData.channel = rawSignal.channel;
        processedData.confidence = 0.9;
    }

    satisfy SensingReq;
}

// ---- Stimulation Subsystem ----
part def StimulationSubsystem {
    port cmdIn : ~StimulationCommandPort;
    port pulseOut : StimulationPulsePort;
    port powerIn : ~PowerPort;
    port monitorOut : StimMonitorPort;

    attribute activeAmplitude : Current_uA;
    attribute activeFrequency : Frequency_Hz;
    attribute activePulseWidth : PulseWidth_us;
    attribute activeElectrode : Integer;

    action generatePulse {
        in cmd : StimulationCommand;
        out pulse : StimulationPulse;
        pulse.amplitude = cmd.amplitude;
        pulse.frequency = cmd.frequency;
        pulse.pulseWidth = cmd.pulseWidth;
        pulse.electrode = cmd.electrode;
    }

    action measureOutput {
        out current : Current_uA;
        out impedance : Impedance_Ohm;
        current = activeAmplitude;
    }

    satisfy StimulationReq;
}

// ---- Safety Subsystem ----
part def SafetySubsystem {
    port monitorIn : ~StimMonitorPort;
    port alertOut : SafetyAlertPort;
    port powerIn : ~PowerPort;

    attribute maxImpedance : Impedance_Ohm = 5000;
    attribute minImpedance : Impedance_Ohm = 200;
    attribute maxCurrent : Current_uA = 25000;
    attribute currentImpedance : Impedance_Ohm;
    attribute currentDelivered : Current_uA;
    attribute faultDetected : Boolean = false;
    attribute faultCode : String;

    action checkImpedance {
        in measured : Impedance_Ohm;
        out fault : Boolean;
        out code : String;
        if (measured > maxImpedance) {
            fault = true;
            code = "OPEN_LEAD";
        } else {
            if (measured < minImpedance) {
                fault = true;
                code = "SHORT_CIRCUIT";
            } else {
                fault = false;
                code = "";
            }
        }
    }

    action checkCurrent {
        in measured : Current_uA;
        out fault : Boolean;
        out code : String;
        if (measured > maxCurrent) {
            fault = true;
            code = "OVERCURRENT";
        } else {
            fault = false;
            code = "";
        }
    }

    action continuousMonitor {
        in stimCurrent : Current_uA;
        in stimImpedance : Impedance_Ohm;
        out alert : Boolean;
        out alertCode : String;
        var impFault : Boolean;
        var curFault : Boolean;
        var impCode : String;
        var curCode : String;
        impFault = false;
        curFault = false;
        impCode = "";
        curCode = "";
        if (stimImpedance > maxImpedance) {
            impFault = true;
            impCode = "OPEN_LEAD";
        } else {
            if (stimImpedance < minImpedance) {
                impFault = true;
                impCode = "SHORT_CIRCUIT";
            }
        }
        if (stimCurrent > maxCurrent) {
            curFault = true;
            curCode = "OVERCURRENT";
        }
        if (impFault == true || curFault == true) {
            alert = true;
            if (impFault == true) {
                alertCode = impCode;
            } else {
                alertCode = curCode;
            }
        } else {
            alert = false;
            alertCode = "";
        }
    }

    satisfy SafetyMonitoringReq;
    satisfy FaultResponseReq;
}

// ---- Power Subsystem ----
part def PowerSubsystem {
    port powerOut : PowerPort;

    attribute batteryLevel : Battery_pct = 100;
    attribute batteryCapacity_mWh : Real = 5000;
    attribute supplyVoltage : Voltage_V = 3.7;
    attribute powerConsumption : Power_mW;
    attribute lowBatteryThreshold : Battery_pct = 10;

    action monitorCharge {
        out level : Battery_pct;
        level = batteryLevel;
    }

    action estimateRemainingLife {
        in currentConsumption : Power_mW;
        out remainingHours : Real;
        remainingHours = (batteryLevel * batteryCapacity_mWh) / (currentConsumption * 100.0);
    }

    satisfy PowerMgmtReq;
}

// ---- Control Subsystem ----
part def ControlSubsystem {
    port sensingIn : ~SensingDataPort;
    port cmdOut : StimulationCommandPort;
    port powerIn : ~PowerPort;
    port safetyIn : ~SafetyAlertPort;
    port telemetry : TelemetryPort;

    attribute therapyGoal : TherapyGoal;
    attribute currentSensing : SensingData;
    attribute batteryLevel : Battery_pct;
    attribute safetyFault : Boolean = false;
    attribute safetyFaultCode : String;
    attribute resetRequested : Boolean = false;
    attribute threshold : Real = 0.05;
    attribute currentCommand : StimulationCommand;
    attribute operatingState : String = "Standby";
    attribute systemStatus : SystemStatus;
    attribute diagnosticData : DiagnosticData;
    attribute configuration : Configuration;
    attribute therapyHistory : StimulationCommand[0..*];
    attribute impedanceTrend : Impedance_Ohm[0..*];

    action updateSensing {
        in data : SensingData;
        currentSensing = data;
    }

    action updateSafety {
        in fault : Boolean;
        in code : String;
        safetyFault = fault;
        safetyFaultCode = code;
    }

    action updateBattery {
        in level : Battery_pct;
        batteryLevel = level;
    }

    action applyConfiguration {
        in config : Configuration;
        therapyGoal = config.therapy;
        configuration = config;
    }

    action buildStatus {
        out status : SystemStatus;
        status.batteryLevel = batteryLevel;
        status.operatingState = operatingState;
        status.leadImpedance = currentSensing.filteredAmplitude;
        status.faultFlag = safetyFault;
        status.faultCode = safetyFaultCode;
    }

    action buildDiagnostic {
        out diag : DiagnosticData;
        diag.status = systemStatus;
        diag.therapyHistory = therapyHistory;
        diag.impedanceTrend = impedanceTrend;
    }

    state controlStates {
        state standby {
            entry {
                currentCommand.enable = false;
                operatingState = "Standby";
            }
        }

        state activeTherapy {
            entry {
                currentCommand.enable = true;
                if (currentCommand.amplitude < therapyGoal.minAmplitude) {
                    currentCommand.amplitude = therapyGoal.minAmplitude;
                }
                operatingState = "ActiveTherapy";
            }
        }

        state adjusting {
            entry {
                operatingState = "Adjusting";
            }
            do {
                if (currentSensing.biomarkerLevel > therapyGoal.targetBiomarker) {
                    currentCommand.amplitude = currentCommand.amplitude + 100;
                } else {
                    currentCommand.amplitude = currentCommand.amplitude - 100;
                }
                if (currentCommand.amplitude > therapyGoal.maxAmplitude) {
                    currentCommand.amplitude = therapyGoal.maxAmplitude;
                }
                if (currentCommand.amplitude < therapyGoal.minAmplitude) {
                    currentCommand.amplitude = therapyGoal.minAmplitude;
                }
            }
        }

        state fault {
            entry {
                currentCommand.enable = false;
                operatingState = "Fault";
            }
        }

        transition t_standby_to_active from standby to activeTherapy
            when (therapyGoal.adjustmentEnabled == true && batteryLevel > 10 && safetyFault == false);

        transition t_active_to_adjusting from activeTherapy to adjusting
            when (currentSensing.biomarkerLevel > therapyGoal.targetBiomarker + threshold || currentSensing.biomarkerLevel < therapyGoal.targetBiomarker - threshold);

        transition t_adjusting_to_active from adjusting to activeTherapy
            when (currentSensing.biomarkerLevel <= therapyGoal.targetBiomarker + threshold && currentSensing.biomarkerLevel >= therapyGoal.targetBiomarker - threshold);

        transition t_active_to_fault from activeTherapy to fault
            when (safetyFault == true);

        transition t_adjusting_to_fault from adjusting to fault
            when (safetyFault == true);

        transition t_fault_to_standby from fault to standby
            when (resetRequested == true);

        transition t_active_to_standby from activeTherapy to standby
            when (therapyGoal.adjustmentEnabled == false);
    }

    satisfy ClosedLoopControlReq;
    satisfy StateMgmtReq;
    satisfy TelemetryReq;
}

// ---- IPG (Implantable Pulse Generator) ----
part def IPG {
    attribute deviceId : String;
    attribute implantDate : Time_s;
    attribute firmwareVersion : String;

    part sensing : SensingSubsystem;
    part stimulation : StimulationSubsystem;
    part control : ControlSubsystem;
    part power : PowerSubsystem;
    part safety : SafetySubsystem;

    port leadNeural : ~NeuralSignalPort;
    port leadStim : StimulationPulsePort;
    port telemetry : TelemetryPort;

    connection c_lead_neural connect leadNeural to sensing.neuralIn;
    connection c_sensing_data connect sensing.dataOut to control.sensingIn;
    connection c_stim_cmd connect control.cmdOut to stimulation.cmdIn;
    connection c_stim_pulse connect stimulation.pulseOut to leadStim;
    connection c_power_sensing connect power.powerOut to sensing.powerIn;
    connection c_power_stim connect power.powerOut to stimulation.powerIn;
    connection c_power_control connect power.powerOut to control.powerIn;
    connection c_power_safety connect power.powerOut to safety.powerIn;
    connection c_stim_monitor connect stimulation.monitorOut to safety.monitorIn;
    connection c_safety_alert connect safety.alertOut to control.safetyIn;
    connection c_telemetry_delegate connect control.telemetry to telemetry;

    satisfy ClosedLoopControlReq;
    satisfy FaultResponseReq;
    satisfy TelemetryReq;
}

// ---- External Programmer ----
part def ExternalProgrammer {
    attribute programmerId : String;
    attribute clinicianId : String;

    port telemetry : ~TelemetryPort;

    attribute currentConfig : Configuration;
    attribute lastDiagnostic : DiagnosticData;
    attribute lastStatus : SystemStatus;

    action configureTherapy {
        in target : BiomarkerLevel;
        in minAmp : Current_uA;
        in maxAmp : Current_uA;
        in enabled : Boolean;
        out config : Configuration;
        config.therapy.targetBiomarker = target;
        config.therapy.minAmplitude = minAmp;
        config.therapy.maxAmplitude = maxAmp;
        config.therapy.adjustmentEnabled = enabled;
    }

    action setSafetyLimits {
        in maxCurrent : Current_uA;
        in maxImpedance : Impedance_Ohm;
        in minImpedance : Impedance_Ohm;
        out config : Configuration;
        config.maxSafeCurrent = maxCurrent;
        config.maxSafeImpedance = maxImpedance;
        config.minSafeImpedance = minImpedance;
    }

    action downloadDiagnostics {
        in diag : DiagnosticData;
        in status : SystemStatus;
        lastDiagnostic = diag;
        lastStatus = status;
    }

    satisfy ProgrammerReq;
}

// ---- Neural Target ----
part def NeuralTarget {
    attribute targetArea : String = "Subthalamic Nucleus";
    attribute tissueType : String = "Neural";

    port neuralOut : NeuralSignalPort;
    port stimIn : ~StimulationPulsePort;
}

// ---- Top-Level System Assembly ----
part def Neurostimulator {
    attribute systemId : String;
    attribute patientId : String;
    attribute implantLocation : String;

    part ipg : IPG;
    part lead : LeadAssembly;
    part programmer : ExternalProgrammer;
    part target : NeuralTarget;

    connection c_lead_neural_if connect lead.ipgNeural to ipg.leadNeural;
    connection c_lead_stim_if connect ipg.leadStim to lead.ipgStim;
    connection c_tissue_neural_if connect target.neuralOut to lead.tissueNeural;
    connection c_tissue_stim_if connect lead.tissueStim to target.stimIn;
    connection c_telemetry_wireless connect ipg.telemetry to programmer.telemetry;

    satisfy ClosedLoopControlReq;
    satisfy TelemetryReq;
}

}
