package ImplantableLoopRecorder {
    private import ScalarValues::*;

    package Definitions {
        attribute def VoltageValue :> Real;
        attribute def HeartRateValue :> Real;
        attribute def BatteryLevelValue :> Real;
        attribute def TimeValue :> Real;
        attribute def CapacityValue :> Real;

        item def AnalogECGSignal {
            attribute amplitude : VoltageValue;
            attribute timestamp : TimeValue;
        }
        item def DigitalECGWaveform {
            attribute sampleCount : Integer;
            attribute samplingRate : Real;
            attribute timestamp : TimeValue;
        }
        item def FilteredECGWaveform {
            attribute heartRate : HeartRateValue;
            attribute rhythmQuality : Real;
            attribute timestamp : TimeValue;
        }
        item def CardiacEvent {
            attribute preEventBuffer : FilteredECGWaveform[0..*];
            attribute eventSegment : FilteredECGWaveform;
            attribute postEventBuffer : FilteredECGWaveform[0..*];
            attribute detectionTime : TimeValue;
            attribute classification : String;
        }
        item def DeviceStatus {
            attribute batteryLevel : BatteryLevelValue;
            attribute operatingState : String;
            attribute timestamp : TimeValue;
        }
        item def TelemetryPacket {
            attribute events : CardiacEvent[0..*];
            attribute status : DeviceStatus;
        }

        attribute def InitializationCompleteSignal;
        attribute def ArrhythmiaDetectedSignal;
        attribute def RecordingCompleteSignal;
        attribute def TelemetryRequestSignal;
        attribute def TransmissionCompleteSignal;
        attribute def LowBatteryAlert;
        attribute def BatteryRestoredSignal;

        port def AnalogOutPort {
            out analogSignal : AnalogECGSignal;
        }
        port def AnalogInPort {
            in analogSignal : AnalogECGSignal;
        }
        port def DigitalOutPort {
            out digitalSignal : DigitalECGWaveform;
        }
        port def DigitalInPort {
            in digitalSignal : DigitalECGWaveform;
        }
        port def FilteredOutPort {
            out filteredSignal : FilteredECGWaveform;
        }
        port def FilteredInPort {
            in filteredSignal : FilteredECGWaveform;
        }
        port def EventOutPort {
            out cardiacEvent : CardiacEvent;
        }
        port def EventInPort {
            in cardiacEvent : CardiacEvent;
        }
        port def PowerOutPort {
            out power : VoltageValue;
        }
        port def PowerInPort {
            in power : VoltageValue;
        }
        port def TelemetryOutPort {
            out telemetryPacket : TelemetryPacket;
        }
        port def TelemetryCmdPort {
            in telemetryCommand : TelemetryRequestSignal;
        }
        port def StatusOutPort {
            out deviceStatus : DeviceStatus;
        }
        port def StatusInPort {
            in deviceStatus : DeviceStatus;
        }

        action def 'Initialize System';
        action def 'Sense Cardiac Signal' {
            out rawSignal : AnalogECGSignal;
        }
        action def 'Amplify Cardiac Signal' {
            in rawSignal : AnalogECGSignal;
            out amplifiedSignal : AnalogECGSignal;
        }
        action def 'Convert Analog to Digital' {
            in analogSignal : AnalogECGSignal;
            out digitalWaveform : DigitalECGWaveform;
        }
        action def 'Filter and Extract Features' {
            in digitalWaveform : DigitalECGWaveform;
            out filteredWaveform : FilteredECGWaveform;
        }
        action def 'Detect Arrhythmia' {
            in filteredWaveform : FilteredECGWaveform;
            out detectedEvent : CardiacEvent;
        }
        action def 'Record Event to Loop Memory' {
            in cardiacEvent : CardiacEvent;
            in preEventBuffer : FilteredECGWaveform[0..*];
        }
        action def 'Transmit Telemetry' {
            in events : CardiacEvent[0..*];
            in status : DeviceStatus;
            out packet : TelemetryPacket;
        }
        action def 'Conserve Battery Power';

        state def ILRStates;

        part def SensingElectrode {
            port outPort : AnalogOutPort;
            perform action sense : 'Sense Cardiac Signal';
        }
        part def SignalAmplifier {
            port inPort : AnalogInPort;
            port outPort : AnalogOutPort;
            port powerIn : PowerInPort;
            perform action amplify : 'Amplify Cardiac Signal';
        }
        part def AnalogToDigitalConverter {
            port inPort : AnalogInPort;
            port outPort : DigitalOutPort;
            port powerIn : PowerInPort;
            perform action convert : 'Convert Analog to Digital';
        }
        part def SignalProcessor {
            port inPort : DigitalInPort;
            port outPort : FilteredOutPort;
            port powerIn : PowerInPort;
            perform action process : 'Filter and Extract Features';
        }
        part def ArrhythmiaDetectionEngine {
            port inPort : FilteredInPort;
            port outPort : EventOutPort;
            port powerIn : PowerInPort;
            perform action detect : 'Detect Arrhythmia';
        }
        part def LoopMemory {
            port filteredIn : FilteredInPort;
            port eventIn : EventInPort;
            port eventOut : EventOutPort;
            port powerIn : PowerInPort;
            attribute bufferSize : Integer = 600;
            attribute recordedEvents : CardiacEvent[0..*];
            perform action record : 'Record Event to Loop Memory';
        }
        part def BatteryPowerSource {
            port powerOut : PowerOutPort;
            port statusOut : StatusOutPort;
            attribute batteryLevel : BatteryLevelValue;
            attribute ratedCapacity : CapacityValue;
            attribute lowThreshold : BatteryLevelValue = 10;
        }
        part def MicrocontrollerUnit {
            port statusIn : StatusInPort;
            port telemetryCmd : TelemetryCmdPort;
            port powerIn : PowerInPort;
            attribute operatingState : String;
        }
        part def WirelessTelemetryUnit {
            port dataIn : EventInPort;
            port cmdIn : TelemetryCmdPort;
            port outPort : TelemetryOutPort;
            port powerIn : PowerInPort;
            perform action transmit : 'Transmit Telemetry';
        }

        part def ImplantableLoopRecorder {
            port externalTelemetry : TelemetryOutPort;
            port externalCommand : TelemetryCmdPort;
            exhibit state ilrStates : ILRStates;

            part electrode1 : SensingElectrode;
            part electrode2 : SensingElectrode;
            part amplifier : SignalAmplifier;
            part adc : AnalogToDigitalConverter;
            part processor : SignalProcessor;
            part detectionEngine : ArrhythmiaDetectionEngine;
            part loopMemory : LoopMemory;
            part battery : BatteryPowerSource;
            part mcu : MicrocontrollerUnit;
            part telemetryUnit : WirelessTelemetryUnit;

            connect electrode1.outPort to amplifier.inPort;
            connect electrode2.outPort to amplifier.inPort;
            connect amplifier.outPort to adc.inPort;
            connect adc.outPort to processor.inPort;
            connect processor.outPort to detectionEngine.inPort;
            connect processor.outPort to loopMemory.filteredIn;
            connect detectionEngine.outPort to loopMemory.eventIn;
            connect loopMemory.eventOut to telemetryUnit.dataIn;
            connect telemetryUnit.outPort to externalTelemetry;
            connect externalCommand to telemetryUnit.cmdIn;
            connect externalCommand to mcu.telemetryCmd;
            connect battery.powerOut to amplifier.powerIn;
            connect battery.powerOut to adc.powerIn;
            connect battery.powerOut to processor.powerIn;
            connect battery.powerOut to detectionEngine.powerIn;
            connect battery.powerOut to loopMemory.powerIn;
            connect battery.powerOut to mcu.powerIn;
            connect battery.powerOut to telemetryUnit.powerIn;
            connect battery.statusOut to mcu.statusIn;
        }

        requirement def 'Continuous Heart Rhythm Monitoring' {
            /* The ILR shall continuously monitor the patient's heart rhythm for the lifetime of the device using two sensing electrodes. */
        }
        requirement def 'Arrhythmia Detection and Classification' {
            /* The ILR shall automatically detect and classify cardiac arrhythmias in real-time from the filtered ECG waveform. */
        }
        requirement def 'Loop Memory Buffer' {
            /* The ILR shall maintain a circular buffer of continuous ECG data that overwrites itself, preserving pre-event, event, and post-event data upon arrhythmia detection. */
        }
        requirement def 'Secure Wireless Telemetry' {
            /* The ILR shall securely transmit stored event recordings and device status to an external programmer or home monitoring system. */
        }
        requirement def 'Low Power Conservation' {
            /* The ILR shall enter a low-power mode when the battery level falls below a defined threshold to conserve energy. */
        }
        requirement def 'Long Battery Life' {
            /* The ILR shall operate for a minimum of 2 years on a single battery power source. */
        }
        requirement def 'Signal Processing Chain' {
            /* The ILR shall amplify, digitize, filter, and extract heart rate features from the raw cardiac signal before arrhythmia analysis. */
        }
    }

    package Usages {
        private import Definitions::*;

        action 'initialize system' : 'Initialize System';
        action 'sense cardiac signal' : 'Sense Cardiac Signal';
        action 'amplify cardiac signal' : 'Amplify Cardiac Signal';
        action 'convert analog to digital' : 'Convert Analog to Digital';
        action 'filter and extract features' : 'Filter and Extract Features';
        action 'detect arrhythmia' : 'Detect Arrhythmia';
        action 'record event to loop memory' : 'Record Event to Loop Memory';
        action 'transmit telemetry' : 'Transmit Telemetry';
        action 'conserve battery power' : 'Conserve Battery Power';

        state ilrStates : ILRStates {
            entry; then startup;

            state startup {
                entry 'initialize system';
            }
            accept InitializationCompleteSignal
                then continuousMonitoring;

            state continuousMonitoring {
                do 'sense cardiac signal';
                do 'amplify cardiac signal';
                do 'convert analog to digital';
                do 'filter and extract features';
                do 'detect arrhythmia';
            }
            accept ArrhythmiaDetectedSignal
                then eventRecording;
            accept TelemetryRequestSignal
                then transmittingData;
            accept LowBatteryAlert
                then lowPowerMode;

            state eventRecording {
                do 'record event to loop memory';
            }
            accept RecordingCompleteSignal
                then continuousMonitoring;

            state transmittingData {
                do 'transmit telemetry';
            }
            accept TransmissionCompleteSignal
                then continuousMonitoring;

            state lowPowerMode {
                do 'conserve battery power';
            }
            accept BatteryRestoredSignal
                then continuousMonitoring;
        }

        part ilrSystem : ImplantableLoopRecorder;

        requirement continuousMonitoringReq : 'Continuous Heart Rhythm Monitoring';
        requirement arrhythmiaDetectionReq : 'Arrhythmia Detection and Classification';
        requirement loopMemoryReq : 'Loop Memory Buffer';
        requirement telemetryReq : 'Secure Wireless Telemetry';
        requirement lowPowerReq : 'Low Power Conservation';
        requirement batteryLifeReq : 'Long Battery Life';
        requirement signalProcessingReq : 'Signal Processing Chain';

        satisfy continuousMonitoringReq by ilrSystem.electrode1;
        satisfy continuousMonitoringReq by ilrSystem.electrode2;
        satisfy arrhythmiaDetectionReq by ilrSystem.detectionEngine;
        satisfy loopMemoryReq by ilrSystem.loopMemory;
        satisfy telemetryReq by ilrSystem.telemetryUnit;
        satisfy lowPowerReq by ilrSystem.battery;
        satisfy batteryLifeReq by ilrSystem.battery;
        satisfy signalProcessingReq by ilrSystem.processor;
    }
}
