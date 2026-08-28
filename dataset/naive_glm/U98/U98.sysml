package CardiacPacemakerSystem {
    import ScalarValues::*;
    
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'mA'; }
    value type HeartRate :> Real { unit 'bpm'; }
    value type TimeDuration :> Real { unit 'ms'; }
    
    item HeartSignal {
        attr amplitude : Voltage;
        attr rate : HeartRate;
    }
    
    item PacingPulse {
        attr amplitude : Voltage;
        attr duration : TimeDuration;
    }
    
    item TelemetryData {
        attr patientHeartRate : HeartRate;
        attr batteryVoltage : Voltage;
    }
    
    item ProgramSettings {
        attr minRate : HeartRate;
        attr maxRate : HeartRate;
        attr avDelay : TimeDuration;
        attr therapyMode : String;
    }

    requirement def PacemakerSystemRequirement {
        doc "The system shall monitor the heart and deliver electrical therapy for slow or irregular rhythms."
    }
    
    requirement def BatteryLifeRequirement {
        doc "The battery shall last for at least 10 years under normal operation."
    }
    
    requirement def DualChamberTherapyRequirement {
        doc "The system shall provide dual-chamber therapy via atrial and ventricular leads."
    }
    
    requirement def SensingRequirement {
        doc "The sensing amplifier shall detect intrinsic heart signals."
    }
    
    requirement def PacingRequirement {
        doc "The pulse generator shall deliver pacing pulses when intrinsic rate is below minimum."
    }
    
    requirement def TelemetryRequirement {
        doc "The system shall allow wireless programming and data retrieval."
    }

    port def ElectricalPort {
        out signal : HeartSignal;
        in pulse : PacingPulse;
    }
    
    port def RatePort {
        out rate : HeartRate;
    }
    
    port def CommandPort {
        out command : String;
    }
    
    port def SettingsPort {
        out settings : ProgramSettings;
    }
    
    port def DiagnosticsPort {
        out data : TelemetryData;
    }

    part def Heart {
        port atrialTissue : ElectricalPort;
        port ventricularTissue : ElectricalPort;
    }
    
    part def Lead {
        port proximal : ElectricalPort;
        port distal : ElectricalPort;
    }
    
    part def Battery {
        attr voltage : Voltage = 2.8;
        attr capacity : TimeDuration = 525600000;
        satisfy BatteryLifeRequirement;
    }
    
    part def SensingAmplifier {
        port atrialIn : ElectricalPort;
        port ventricularIn : ElectricalPort;
        port rateOut : RatePort;
        satisfy SensingRequirement;
    }
    
    part def TimingCircuit {
        port commandIn : CommandPort;
        port timingOut : RatePort;
        attr avDelay : TimeDuration = 150;
    }
    
    part def PulseGenerator {
        port commandIn : CommandPort;
        port atrialOut : ElectricalPort;
        port ventricularOut : ElectricalPort;
        satisfy PacingRequirement;
    }
    
    part def Telemetry {
        port wirelessSettings : SettingsPort;
        port wirelessDiagnostics : DiagnosticsPort;
        port logicSettingsOut : SettingsPort;
        port logicDiagnosticsIn : DiagnosticsPort;
        satisfy TelemetryRequirement;
    }
    
    part def ControlLogic {
        port rateIn : RatePort;
        port timingIn : RatePort;
        port pulseOut : CommandPort;
        port timingOut : CommandPort;
        port settingsIn : SettingsPort;
        port diagnosticsOut : DiagnosticsPort;
        
        attr minRate : HeartRate = 60;
        attr maxRate : HeartRate = 120;
        attr therapyMode : String = "DDD";
        
        state {
            state Monitoring;
            state Pacing;
            transition Monitoring -> Pacing when (rateIn.rate < minRate);
            transition Pacing -> Monitoring when (rateIn.rate >= minRate);
        }
    }
    
    part def Pacemaker {
        port atrialLeadConnection : ElectricalPort;
        port ventricularLeadConnection : ElectricalPort;
        port telemetrySettings : SettingsPort;
        port telemetryDiagnostics : DiagnosticsPort;
        
        part battery : Battery;
        part sensingAmplifier : SensingAmplifier;
        part timingCircuit : TimingCircuit;
        part pulseGenerator : PulseGenerator;
        part controlLogic : ControlLogic;
        part telemetry : Telemetry;
        
        satisfy PacemakerSystemRequirement;
        satisfy DualChamberTherapyRequirement;
        
        connect atrialLeadConnection to sensingAmplifier.atrialIn;
        connect ventricularLeadConnection to sensingAmplifier.ventricularIn;
        
        connect sensingAmplifier.rateOut to controlLogic.rateIn;
        
        connect controlLogic.timingOut to timingCircuit.commandIn;
        connect timingCircuit.timingOut to controlLogic.timingIn;
        
        connect controlLogic.pulseOut to pulseGenerator.commandIn;
        
        connect pulseGenerator.atrialOut to atrialLeadConnection;
        connect pulseGenerator.ventricularOut to ventricularLeadConnection;
        
        connect telemetrySettings to telemetry.wirelessSettings;
        connect telemetryDiagnostics to telemetry.wirelessDiagnostics;
        
        connect telemetry.logicSettingsOut to controlLogic.settingsIn;
        connect controlLogic.diagnosticsOut to telemetry.logicDiagnosticsIn;
    }
    
    part def PacemakerSystem {
        part patientHeart : Heart;
        part pacemakerDevice : Pacemaker;
        part atrialLead : Lead;
        part ventricularLead : Lead;
        
        connect pacemakerDevice.atrialLeadConnection to atrialLead.proximal;
        connect atrialLead.distal to patientHeart.atrialTissue;
        
        connect pacemakerDevice.ventricularLeadConnection to ventricularLead.proximal;
        connect ventricularLead.distal to patientHeart.ventricularTissue;
    }
}
