package ILR_System {
    import ScalarValues::*;
    import ISQ::*;

    value def Voltage :> Real { unit 'V'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def Time :> Real { unit 's'; }
    value def BatteryLevel :> Real { unit '%'; }

    item def RawECGSignal {
        attribute amplitude : Voltage;
        attribute frequency : Frequency;
    }
    item def DigitalECGSignal {
        attribute sampleRate : Frequency;
        attribute data : Real[0..*];
    }
    item def FilteredECGSignal {
        attribute sampleRate : Frequency;
        attribute data : Real[0..*];
    }
    item def HeartRateData {
        attribute bpm : Frequency;
    }
    item def ArrhythmiaEvent {
        attribute type : String;
        attribute timestamp : Time;
    }
    item def EventRecord {
        attribute preBuffer : FilteredECGSignal;
        attribute event : ArrhythmiaEvent;
        attribute postBuffer : FilteredECGSignal;
    }
    item def DeviceStatus {
        attribute batteryLevel : BatteryLevel;
        attribute state : String;
    }
    item def TelemetryData {
        attribute records : EventRecord[0..*];
        attribute status : DeviceStatus;
    }

    part def SensingElectrode {
        out rawSignal : RawECGSignal;
    }
    part def SignalAmplifier {
        in rawSignal : RawECGSignal;
        out amplifiedSignal : RawECGSignal;
    }
    part def AnalogToDigitalConverter {
        in analogSignal : RawECGSignal;
        out digitalSignal : DigitalECGSignal;
    }
    part def SignalProcessor {
        in digitalSignal : DigitalECGSignal;
        out filteredSignal : FilteredECGSignal;
        out heartRate : HeartRateData;
    }
    part def ArrhythmiaDetectionEngine {
        in filteredSignal : FilteredECGSignal;
        in heartRate : HeartRateData;
        out arrhythmiaEvent : ArrhythmiaEvent;
    }
    part def LoopMemory {
        in continuousStream : FilteredECGSignal;
        in triggerEvent : ArrhythmiaEvent;
        out savedRecord : EventRecord;
        attribute bufferDuration : Time = 30 [s];
    }
    part def BatteryPowerSource {
        out power : Voltage;
        out status : DeviceStatus;
        attribute level : BatteryLevel;
    }
    part def MicrocontrollerUnit {
        in arrhythmiaEvent : ArrhythmiaEvent;
        in status : DeviceStatus;
        out controlCommands : String;
    }
    part def WirelessTelemetryUnit {
        in records : EventRecord[0..*];
        in status : DeviceStatus;
        out telemetryData : TelemetryData;
    }

    part def ImplantableLoopRecorder {
        port telemetryPort : TelemetryData;
        
        part electrodes : SensingElectrode[2];
        part amplifier : SignalAmplifier;
        part adc : AnalogToDigitalConverter;
        part processor : SignalProcessor;
        part detectionEngine : ArrhythmiaDetectionEngine;
        part memory : LoopMemory;
        part battery : BatteryPowerSource;
        part mcu : MicrocontrollerUnit;
        part telemetry : WirelessTelemetryUnit;
        
        connection rawToAmp connect electrodes.rawSignal to amplifier.rawSignal;
        connection ampToAdc connect amplifier.amplifiedSignal to adc.analogSignal;
        connection adcToProc connect adc.digitalSignal to processor.digitalSignal;
        connection procToDetect connect processor.filteredSignal to detectionEngine.filteredSignal;
        connection hrToDetect connect processor.heartRate to detectionEngine.heartRate;
        connection procToMem connect processor.filteredSignal to memory.continuousStream;
        connection detectToMem connect detectionEngine.arrhythmiaEvent to memory.triggerEvent;
        connection detectToMcu connect detectionEngine.arrhythmiaEvent to mcu.arrhythmiaEvent;
        connection memToTel connect memory.savedRecord to telemetry.records;
        connection battToMcu connect battery.status to mcu.status;
        connection battToTel connect battery.status to telemetry.status;
        connection telToPort connect telemetry.telemetryData to telemetryPort;
        
        attribute arrhythmiaDetected : Boolean;
        attribute recordSaved : Boolean;
        attribute telemetryRequested : Boolean;
        attribute transmissionComplete : Boolean;
        
        exhibit state behavior {
            state startup;
            state continuousMonitoring;
            state eventRecording;
            state transmittingData;
            state lowPowerMode;
            
            transition first startup then continuousMonitoring;
            transition continuousMonitoring to eventRecording when arrhythmiaDetected;
            transition eventRecording to continuousMonitoring when recordSaved;
            transition continuousMonitoring to transmittingData when telemetryRequested;
            transition transmittingData to continuousMonitoring when transmissionComplete;
            transition continuousMonitoring to lowPowerMode when battery.level < 20 [%];
            transition lowPowerMode to continuousMonitoring when battery.level > 30 [%];
        }
    }

    requirement def DiagnosticCapability {
        subject ilr : ImplantableLoopRecorder;
        objective {
            doc "The ILR shall continuously monitor and record heart rhythm to diagnose infrequent cardiac arrhythmias.";
        }
    }
    requirement def ContinuousMonitoring {
        subject ilr : ImplantableLoopRecorder;
        objective {
            doc "The ILR shall continuously monitor heart rhythm in the continuousMonitoring state.";
        }
    }
    requirement def EventRecording {
        subject ilr : ImplantableLoopRecorder;
        objective {
            doc "The ILR shall save pre-event, event, and post-event data when an arrhythmia is detected.";
        }
    }
    requirement def Telemetry {
        subject ilr : ImplantableLoopRecorder;
        objective {
            doc "The ILR shall securely transmit stored event recordings and device status to an external system.";
        }
    }
    requirement def LowPower {
        subject ilr : ImplantableLoopRecorder;
        objective {
            doc "The ILR shall enter lowPowerMode if battery level is low.";
        }
    }
}
