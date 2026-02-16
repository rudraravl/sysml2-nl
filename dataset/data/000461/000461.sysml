package ImplantableLoopRecorderSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def ECGWaveform {
        attribute timestamp : Time::DateTime;
        attribute pWaveAmplitude : Real;
        attribute qrsComplexAmplitude : Real;
        attribute tWaveAmplitude : Real;
        attribute rrInterval : DurationValue;
        attribute heartRate : Real;
    }
    
    attribute def ArrhythmiaClassification {
        attribute eventType : String;
        attribute severity : String;
        attribute confidence : Real;
        attribute detectionTime : Time::DateTime;
    }
    
    attribute def BatteryStatus {
        attribute remainingCapacity : Real;
        attribute voltage : Real;
        attribute estimatedLifetime : DurationValue;
        attribute chargeCycles : Integer;
    }
    
    item def CardiacSignal {
        attribute voltage : Real;
        attribute timestamp : Time::DateTime;
        attribute leadConfiguration : String;
    }
    
    item def StoredEvent {
        attribute eventId : String;
        attribute preEventData : ECGWaveform[*] ordered;
        attribute eventData : ECGWaveform[*] ordered;
        attribute postEventData : ECGWaveform[*] ordered;
        attribute classification : ArrhythmiaClassification;
    }
    
    item def TelemetryData {
        attribute deviceId : String;
        attribute transmissionTime : Time::DateTime;
        attribute events : StoredEvent[*];
        attribute deviceStatus : BatteryStatus;
    }
    
    port def SensingPort {
        out item signal : CardiacSignal;
    }
    
    port def ProcessingPort {
        in item rawSignal : CardiacSignal;
        out item processedWaveform : ECGWaveform;
    }
    
    port def TelemetryPort {
        out item transmittedData : TelemetryData;
        in item programmingCommand : String;
    }
    
    part def SensingElectrode {
        attribute impedance : Real;
        attribute surfaceArea : AreaValue;
        
        port sensingOutput : SensingPort;
        
        perform action captureCardiacActivity {
            out electricalSignal : CardiacSignal;
        }
    }
    
    part def SignalAmplifier {
        attribute gain : Real;
        attribute bandwidth : FrequencyValue;
        attribute inputImpedance : Real;
        
        port signalInput : ~SensingPort;
        port amplifiedOutput : SensingPort;
        
        perform action amplifySignal {
            in rawSignal : CardiacSignal;
            out amplifiedSignal : CardiacSignal;
        }
    }
    
    part def AnalogToDigitalConverter {
        attribute samplingRate : FrequencyValue;
        attribute resolution : Integer;
        
        port analogInput : ~SensingPort;
        port digitalOutput : ProcessingPort;
        
        perform action convertSignal {
            in analogSignal : CardiacSignal;
            out digitalWaveform : ECGWaveform;
        }
    }
    
    part def SignalProcessor {
        attribute filterCutoffFrequency : FrequencyValue;
        attribute processingAlgorithm : String;
        
        port dataInput : ~ProcessingPort;
        
        perform action filterAndProcess {
            in rawWaveform : ECGWaveform;
            out cleanWaveform : ECGWaveform;
        }
        
        perform action extractFeatures {
            in waveform : ECGWaveform;
            out heartRate : Real;
            out rhythmCharacteristics : String;
        }
    }
    
    part def ArrhythmiaDetectionEngine {
        attribute detectionSensitivity : Real;
        attribute algorithmVersion : String;
        attribute falsePositiveRate : Real;
        
        perform action analyzeRhythm {
            in waveform : ECGWaveform;
            out arrhythmiaDetected : Boolean;
            out classification : ArrhythmiaClassification;
        }
        
        perform action validateEvent {
            in classification : ArrhythmiaClassification;
            out confirmed : Boolean;
        }
    }
    
    part def LoopMemory {
        attribute totalCapacity : Real;
        attribute usedCapacity : Real;
        attribute loopDuration : DurationValue;
        attribute storedEvents : StoredEvent[*];
        
        perform action maintainLoopBuffer {
            in continuousData : ECGWaveform;
            out bufferedData : ECGWaveform[*] ordered;
        }
        
        perform action storeEvent {
            in preEventBuffer : ECGWaveform[*];
            in eventTrigger : ArrhythmiaClassification;
            in postEventData : ECGWaveform[*];
            out savedEvent : StoredEvent;
        }
        
        perform action retrieveEvents {
            in queryParameters : String;
            out events : StoredEvent[*];
        }
    }
    
    part def WirelessTelemetryUnit {
        attribute transmissionFrequency : FrequencyValue;
        attribute transmissionPower : PowerValue;
        attribute communicationProtocol : String;
        attribute encryptionEnabled : Boolean;
        
        port telemetryInterface : TelemetryPort;
        
        perform action transmitData {
            in eventData : StoredEvent[*];
            in deviceStatus : BatteryStatus;
            out telemetryPacket : TelemetryData;
        }
        
        perform action receiveCommands {
            out programmingInstruction : String;
        }
    }
    
    part def BatteryPowerSource {
        attribute nominalVoltage : Real;
        attribute capacity : Real;
        attribute currentDraw : Real;
        attribute status : BatteryStatus;
        
        perform action monitorBattery {
            out batteryStatus : BatteryStatus;
        }
        
        perform action supplyPower {
            out powerOutput : PowerValue;
        }
    }
    
    part def MicrocontrollerUnit {
        attribute processorSpeed : FrequencyValue;
        attribute memorySize : Real;
        attribute operatingMode : String;
        
        perform action coordinateOperations {
            in sensorData : ECGWaveform;
            in detectionResult : ArrhythmiaClassification;
            out controlSignal : String;
        }
        
        perform action managePowerModes {
            in batteryStatus : BatteryStatus;
            out powerMode : String;
        }
    }
    
    state def RecorderOperatingStates {
        entry; then initializing;
        
        state initializing;
        
        transition init_to_monitoring
            first initializing
            accept when selfTestPassed
            then continuousMonitoring;
        
        state continuousMonitoring {
            entry assign recordingActive := true;
            
            state normalRecording;
            
            state eventRecording;
            
            transition normal_to_event
                first normalRecording
                accept when arrhythmiaDetected
                then eventRecording;
            
            transition event_to_normal
                first eventRecording
                accept after eventCaptureDuration
                then normalRecording;
        }
        
        transition monitoring_to_transmit
            first continuousMonitoring
            accept when telemetrySessionRequested
            then transmittingData;
        
        state transmittingData;
        
        transition transmit_to_monitoring
            first transmittingData
            accept when transmissionComplete
            then continuousMonitoring;
        
        transition any_to_lowpower
            first continuousMonitoring
            accept when batteryLevelLow
            then lowPowerMode;
        
        state lowPowerMode;
        
        transition lowpower_to_monitoring
            first lowPowerMode
            accept when batteryRecovered
            then continuousMonitoring;
        
        state done;
    }
    
    action def ContinuousCardiacMonitoring {
        in attribute sampleRate : FrequencyValue;
        in attribute loopBufferSize : Integer;
        out attribute detectedEvents : StoredEvent[*] := ( );
        
        private attribute circularBuffer : ECGWaveform[*] := ( );
        private attribute bufferIndex : Integer := 0;
        
        first start;
        then merge monitoringLoop;
        
        loop action monitorCycle {
            action acquireSignal {
                out cardiacSignal : CardiacSignal;
            }
            then action digitizeSignal {
                in signal = acquireSignal.cardiacSignal;
                out waveform : ECGWaveform;
            }
            then action processWaveform {
                in raw = digitizeSignal.waveform;
                out processed : ECGWaveform;
            }
            then action updateBuffer {
                in newData = processWaveform.processed;
            }
            then assign circularBuffer := 
                if circularBuffer->size() >= loopBufferSize
                then circularBuffer->subSequence(2, circularBuffer->size())->including(processWaveform.processed)
                else circularBuffer->including(processWaveform.processed);
            then action detectArrhythmia {
                in waveform = processWaveform.processed;
                out detected : Boolean;
                out classification : ArrhythmiaClassification;
            }
            then decide;
                if detectArrhythmia.detected then captureEvent;
                else continueMonitoring;
            
            action captureEvent {
                action recordPreEvent {
                    in buffer = circularBuffer;
                    out preEventData : ECGWaveform[*];
                }
                then action recordEventData {
                    out eventData : ECGWaveform[*];
                }
                then action recordPostEvent {
                    out postEventData : ECGWaveform[*];
                }
                then action saveEvent {
                    in pre = recordPreEvent.preEventData;
                    in event = recordEventData.eventData;
                    in post = recordPostEvent.postEventData;
                    in classification = detectArrhythmia.classification;
                    out storedEvent : StoredEvent;
                }
                then assign detectedEvents := detectedEvents->including(saveEvent.storedEvent);
            }
            
            merge continueMonitoring;
        } until batteryDepleted or memoryFull;
        
        then done;
    }
    
    action def TransmitDiagnosticData {
        in attribute storedEvents : StoredEvent[*];
        in attribute deviceStatus : BatteryStatus;
        in attribute deviceId : String;
        out attribute transmissionSuccess : Boolean;
        
        first start;
        then action establishConnection {
            out connectionEstablished : Boolean;
        }
        then if establishConnection.connectionEstablished {
            action prepareDataPacket {
                in events = storedEvents;
                in status = deviceStatus;
                in id = deviceId;
                out telemetryPacket : TelemetryData;
            }
            then action encryptData {
                in packet = prepareDataPacket.telemetryPacket;
                out encryptedPacket : TelemetryData;
            }
            then action transmitPacket {
                in data = encryptData.encryptedPacket;
                out transmitted : Boolean;
            }
            then action verifyTransmission {
                in status = transmitPacket.transmitted;
                out verified : Boolean;
            }
            then assign transmissionSuccess := verifyTransmission.verified;
        }
        then done;
    }
    
    part def ImplantableLoopRecorder;
    
    part implantableLoopRecorder : ImplantableLoopRecorder {
        attribute deviceSerialNumber : String;
        attribute implantationDate : Time::DateTime;
        attribute patientId : String;
        attribute operationalStatus : String;
        
        part leadElectrodes : SensingElectrode[2] {
            perform continuousMonitoring.acquireSignal;
        }
        
        part amplifier : SignalAmplifier {
            perform continuousMonitoring.digitizeSignal;
        }
        
        part adc : AnalogToDigitalConverter {
            perform continuousMonitoring.processWaveform;
        }
        
        part processor : SignalProcessor {
            perform continuousMonitoring.updateBuffer;
        }
        
        part detectionEngine : ArrhythmiaDetectionEngine {
            perform continuousMonitoring.detectArrhythmia;
        }
        
        part memory : LoopMemory {
            perform continuousMonitoring.captureEvent.saveEvent;
        }
        
        part telemetry : WirelessTelemetryUnit {
            perform diagnosticTransmission;
        }
        
        part battery : BatteryPowerSource {
            perform action providePower;
        }
        
        part mcu : MicrocontrollerUnit {
            perform action orchestrateSystem;
        }
        
        connection electrodeToAmplifier connect
            leadElectrodes.sensingOutput to amplifier.signalInput;
        
        connection amplifierToADC connect
            amplifier.amplifiedOutput to adc.analogInput;
        
        connection adcToProcessor connect
            adc.digitalOutput to processor.dataInput;
        
        perform action continuousMonitoring : ContinuousCardiacMonitoring {
            in sampleRate = 256.0;
            in loopBufferSize = 1000;
        }
        
        perform action diagnosticTransmission : TransmitDiagnosticData {
            in storedEvents = memory.storedEvents;
            in deviceStatus = battery.status;
            in deviceId = deviceSerialNumber;
        }
        
        exhibit state deviceOperation : RecorderOperatingStates;
    }
    
    requirement def ContinuousMonitoringRequirement {
        doc /* The device shall continuously monitor cardiac electrical activity 24 hours per day. */
        
        subject recorder : ImplantableLoopRecorder;
        
        require constraint {
            recorder.operationalStatus == "active"
        }
    }
    
    requirement def ArrhythmiaDetectionRequirement {
        doc /* The device shall automatically detect and record cardiac arrhythmias including atrial fibrillation, bradycardia, and tachycardia. */
        
        subject detector : ArrhythmiaDetectionEngine;
        
        require constraint {
            detector.detectionSensitivity >= 0.95 and
            detector.falsePositiveRate <= 0.05
        }
    }
    
    requirement def DataStorageRequirement {
        doc /* The device shall store at least 42 minutes of continuous ECG data and up to 30 arrhythmia events. */
        
        subject memory : LoopMemory;
        
        require constraint {
            memory.totalCapacity >= 42.0 and
            memory.storedEvents->size() <= 30
        }
    }
    
    requirement def BatteryLifetimeRequirement {
        doc /* The device battery shall provide at least 36 months of continuous operation. */
        
        subject battery : BatteryPowerSource;
        
        require constraint {
            battery.status.estimatedLifetime >= 36.0
        }
    }
    
    requirement def TelemetryRequirement {
        doc /* The device shall wirelessly transmit stored diagnostic data to external programming and monitoring systems. */
        
        subject telemetry : WirelessTelemetryUnit;
        
        require constraint {
            telemetry.encryptionEnabled == true and
            telemetry.transmissionPower > 0.0
        }
    }
    
    requirement def LoopRecordingRequirement {
        doc /* The device shall maintain a continuous loop buffer of pre-event cardiac data to capture arrhythmia onset. */
        
        subject memory : LoopMemory;
        
        require constraint {
            memory.loopDuration >= 5.0
        }
    }
    
    requirement <'ILR-SYS-001'> primarySystemRequirement {
        doc /* 
            The Implantable Loop Recorder system shall provide long-term, continuous 
            subcutaneous monitoring of cardiac electrical activity to detect, record, 
            and transmit infrequent arrhythmia events in patients with unexplained 
            syncope, palpitations, or suspected cardiac rhythm disorders. The system 
            shall automatically detect arrhythmias, preserve pre-event and post-event 
            ECG data in a continuous loop buffer, store clinically significant events, 
            and enable wireless transmission of diagnostic data to healthcare providers 
            for remote monitoring and clinical decision-making.
        */
        
        subject ilr : ImplantableLoopRecorder;
        
        assume constraint deviceImplanted {
            ilr.implantationDate != null and
            ilr.patientId != null
        }
        
        require continuousMonitoring : ContinuousMonitoringRequirement;
        require arrhythmiaDetection : ArrhythmiaDetectionRequirement;
        require dataStorage : DataStorageRequirement;
        require batteryLifetime : BatteryLifetimeRequirement;
        require telemetryCapability : TelemetryRequirement;
        require loopRecording : LoopRecordingRequirement;
    }
}
