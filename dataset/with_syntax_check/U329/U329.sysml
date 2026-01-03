package NellcorPulseOximeterSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SpO2Percentage :> Real;
    attribute def HeartRateValue :> Real;
    attribute def SignalQualityIndex :> Real;
    
    enum def AlarmPriority {
        critical;
        warning;
        normal;
    }
    
    value def OxygenSaturationReading {
        attribute value : Real;
        attribute timestamp : ISQ::TimeValue;
        attribute confidence : Real;
    }
    
    value def PulseRateReading {
        attribute beatsPerMinute : Real;
        attribute timestamp : ISQ::TimeValue;
        attribute waveformAmplitude : Real;
    }
    
    value def OpticalSignal {
        attribute redLightIntensity : Real;
        attribute infraredLightIntensity : Real;
        attribute ambientLight : Real;
    }
    
    value def AlarmThresholds {
        attribute lowSpO2 : Real;
        attribute highHeartRate : Real;
        attribute lowHeartRate : Real;
    }
    
    port def SensorInterfacePort {
        out emittedLight : OpticalSignal;
        in detectedLight : OpticalSignal;
    }
    
    port def DataOutputPort {
        out spO2Data : OxygenSaturationReading;
        out pulseData : PulseRateReading;
        out signalQuality : Real;
    }
    
    port def DisplayInputPort {
        in spO2Value : OxygenSaturationReading;
        in pulseValue : PulseRateReading;
        in quality : Real;
    }
    
    port def AlarmInterfacePort {
        out alarmActive : AlarmPriority;
        in thresholds : AlarmThresholds;
    }
    
    part def OpticalSensor {
        attribute redLEDWavelength : ISQ::LengthValue = 660.0[nm];
        attribute infraredLEDWavelength : ISQ::LengthValue = 940.0[nm];
        attribute emissionPower : ISQ::PowerValue;
        
        port sensorPort : SensorInterfacePort;
        
        part redLED {
            attribute wavelength : ISQ::LengthValue = 660.0[nm];
        }
        
        part infraredLED {
            attribute wavelength : ISQ::LengthValue = 940.0[nm];
        }
        
        part photodetector {
            attribute responsivity : Real;
            attribute activeArea : ISQ::AreaValue;
        }
    }
    
    part def SignalProcessingUnit {
        attribute samplingFrequency : ISQ::FrequencyValue = 100.0[Hz];
        attribute filterBandwidth : ISQ::FrequencyValue = 0.5[Hz];
        attribute adcResolution : Real = 16.0;
        
        in rawOpticalSignal : OpticalSignal;
        out processedSpO2 : OxygenSaturationReading;
        out processedPulse : PulseRateReading;
        out qualityMetric : Real;
    }
    
    part def DisplayModule {
        attribute screenType : String = "LCD";
        attribute refreshRate : ISQ::FrequencyValue = 1.0[Hz];
        attribute displaySize : ISQ::LengthValue = 3.5[in];
        
        port displayPort : DisplayInputPort;
        
        part numericDisplay {
            attribute spO2Display : Real;
            attribute pulseDisplay : Real;
        }
        
        part waveformDisplay {
            attribute plethysmographWaveform : String;
        }
    }
    
    attribute def LowOxygenDetected;
    attribute def AbnormalPulseDetected;
    attribute def ConditionCleared;
    
    part def AlarmSubsystem {
        attribute audioVolume : Real;
        attribute visualIntensity : Real;
        
        port alarmPort : AlarmInterfacePort;
        
        part audioAlarm {
            attribute frequency : ISQ::FrequencyValue = 1000.0[Hz];
            attribute pattern : String;
        }
        
        part visualAlarm {
            attribute ledColor : String;
            attribute flashRate : ISQ::FrequencyValue;
        }
        
        state alarmController {
            entry; then idle;
            
            state idle {
                doc /* System monitoring within normal parameters */
            }
            accept lowOxygenDetected : LowOxygenDetected
                then criticalAlarm;
            accept abnormalPulseDetected : AbnormalPulseDetected
                then warningAlarm;
            
            state criticalAlarm {
                entry; then activateHighPriorityAlarm;
                doc /* SpO2 below critical threshold */
            }
            accept conditionCleared : ConditionCleared
                then idle;
            
            state warningAlarm {
                entry; then activateMediumPriorityAlarm;
                doc /* Pulse rate outside normal range */
            }
            accept conditionCleared : ConditionCleared
                then idle;
            
            action activateHighPriorityAlarm;
            action activateMediumPriorityAlarm;
        }
    }
    
    part def PowerSupply {
        attribute batteryCapacity : ISQ::EnergyValue;
        attribute outputVoltage : ISQ::ElectricPotentialValue = 5.0[V];
        attribute outputCurrent : ISQ::ElectricCurrentValue = 1.0[A];
        
        part battery {
            attribute chargeLevel : Real;
            attribute nominalVoltage : ISQ::ElectricPotentialValue = 3.7[V];
        }
        
        part voltageRegulator {
            attribute efficiency : Real = 0.85;
        }
    }
    
    action def EmitDualWavelengthLight {
        in redIntensity : Real;
        in infraredIntensity : Real;
        out emittedSignal : OpticalSignal;
    }
    
    action def DetectTransmittedLight {
        in incidentSignal : OpticalSignal;
        out detectedSignal : OpticalSignal;
    }
    
    action def FilterAndAmplify {
        in rawSignal : OpticalSignal;
        out filteredSignal : OpticalSignal;
    }
    
    action def CalculateSpO2 {
        in redAbsorption : Real;
        in infraredAbsorption : Real;
        out oxygenSaturation : OxygenSaturationReading;
        
        doc /* Calculate arterial oxygen saturation using Beer-Lambert law
             and empirical calibration curves based on ratio of ratios
             of red and infrared light absorption */
    }
    
    action def ExtractPulseRate {
        in plethysmographicWaveform : OpticalSignal;
        out heartRate : PulseRateReading;
        
        doc /* Detect pulse rate by identifying periodic peaks in the
             photoplethysmographic signal caused by arterial pulsation */
    }
    
    action def EvaluateAlarmConditions {
        in currentSpO2 : OxygenSaturationReading;
        in currentPulse : PulseRateReading;
        in limits : AlarmThresholds;
        out alarmStatus : AlarmPriority;
    }
    
    action def UpdateDisplay {
        in spO2Reading : OxygenSaturationReading;
        in pulseReading : PulseRateReading;
        in signalQuality : Real;
    }
    
    action def ContinuousPatientMonitoring {
        in alarmLimits : AlarmThresholds;
        out currentSpO2 : OxygenSaturationReading;
        out currentPulse : PulseRateReading;
        
        first start;
        then merge monitoringLoop;
        
        then action emitLight : EmitDualWavelengthLight {
            in redIntensity;
            in infraredIntensity;
            out emittedSignal;
        }
        
        then action detectLight : DetectTransmittedLight {
            in incidentSignal = emitLight.emittedSignal;
            out detectedSignal;
        }
        
        then action filterSignal : FilterAndAmplify {
            in rawSignal = detectLight.detectedSignal;
            out filteredSignal;
        }
        
        then action computeSpO2 : CalculateSpO2 {
            in redAbsorption;
            in infraredAbsorption;
            out oxygenSaturation;
        }
        
        then action computePulse : ExtractPulseRate {
            in plethysmographicWaveform = filterSignal.filteredSignal;
            out heartRate;
        }
        
        then assign currentSpO2 := computeSpO2.oxygenSaturation;
        then assign currentPulse := computePulse.heartRate;
        
        then action checkAlarms : EvaluateAlarmConditions {
            in currentSpO2 = computeSpO2.oxygenSaturation;
            in currentPulse = computePulse.heartRate;
            in limits = alarmLimits;
            out alarmStatus;
        }
        
        then action refreshDisplay : UpdateDisplay {
            in spO2Reading = computeSpO2.oxygenSaturation;
            in pulseReading = computePulse.heartRate;
            in signalQuality;
        }
        
        then decide;
            if checkAlarms.alarmStatus == AlarmPriority::critical then activateAlarm;
            if checkAlarms.alarmStatus == AlarmPriority::warning then activateAlarm;
            else monitoringLoop;
        
        action activateAlarm;
        then monitoringLoop;
    }
    
    part def NellcorMonitor {
        part fingerSensor : OpticalSensor;
        part processor : SignalProcessingUnit;
        part display : DisplayModule;
        part alarmSystem : AlarmSubsystem;
        part power : PowerSupply;
    }
    
    part nellcorPulseOximeter : NellcorMonitor {
        doc /* Nellcor pulse oximeter system for non-invasive continuous monitoring
             of arterial oxygen saturation (SpO2) and pulse rate in clinical settings.
             Uses dual-wavelength optical spectroscopy to measure oxygen saturation
             by analyzing differential absorption of red and infrared light by
             oxygenated and deoxygenated hemoglobin in pulsatile arterial blood. */
        
        perform action monitoring : ContinuousPatientMonitoring {
            in alarmLimits;
            out currentSpO2;
            out currentPulse;
        }
        
        part fingerSensor : OpticalSensor {
            perform monitoring.emitLight;
            perform monitoring.detectLight;
        }
        
        part processor : SignalProcessingUnit {
            perform monitoring.filterSignal;
            perform monitoring.computeSpO2;
            perform monitoring.computePulse;
        }
        
        part display : DisplayModule {
            perform monitoring.refreshDisplay;
        }
        
        part alarmSystem : AlarmSubsystem {
            perform monitoring.checkAlarms;
            perform monitoring.activateAlarm;
        }
        
        part power : PowerSupply;
        
        connection sensorToProcessor 
            connect fingerSensor.sensorPort.detectedLight to processor.rawOpticalSignal;
        
        connection processorToDisplay 
            connect processor.processedSpO2 to display.displayPort.spO2Value;
        
        connection pulseToDisplay 
            connect processor.processedPulse to display.displayPort.pulseValue;
        
        connection qualityToDisplay 
            connect processor.qualityMetric to display.displayPort.quality;
        
        connection processorToAlarm 
            connect processor.processedSpO2 to alarmSystem.alarmPort;
    }
    
    requirement def AccuracyRequirement {
        doc /* The pulse oximeter shall meet specified measurement accuracy standards */
        
        subject monitor : NellcorMonitor;
        
        require constraint spO2AccuracySpec {
            doc /* SpO2 measurement accuracy shall be ±2 digits (1 standard deviation)
                 in the range of 70% to 100% SpO2 for non-motion conditions */
        }
        
        require constraint pulseRateAccuracySpec {
            doc /* Pulse rate accuracy shall be ±3 beats per minute or ±2% (whichever is greater)
                 in the range of 25 to 240 beats per minute */
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The pulse oximeter shall meet patient and operator safety requirements */
        
        subject monitor : NellcorMonitor;
        
        require constraint electricalSafetyCompliance {
            doc /* Device shall comply with IEC 60601-1 and IEC 60601-2-49 
                 electrical safety standards for medical electrical equipment */
        }
        
        require constraint alarmResponseTime {
            doc /* Alarm system shall activate within 10 seconds of detecting
                 a condition that exceeds configured alarm thresholds */
        }
        
        require constraint opticalSafety {
            doc /* Optical emission shall not exceed IEC 60825-1 Class 1 limits
                 for LED safety to prevent retinal hazard */
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* The pulse oximeter shall meet operational performance requirements */
        
        subject monitor : NellcorMonitor;
        
        require constraint updateRate {
            doc /* Display shall update SpO2 and pulse rate values at least once per second */
        }
        
        require constraint signalAcquisitionTime {
            doc /* System shall acquire valid SpO2 and pulse rate readings
                 within 30 seconds of sensor application under normal conditions */
        }
        
        require constraint batteryLife {
            doc /* Device shall operate continuously for at least 8 hours
                 on fully charged battery under typical use conditions */
        }
    }
    
    requirement <'REQ-NELLCOR-001'> primaryMeasurementRequirement : AccuracyRequirement {
        doc /* Primary measurement accuracy requirement for Nellcor pulse oximeter
             ensuring clinical-grade SpO2 and pulse rate monitoring */
        
        assume constraint adequatePerfusion {
            doc /* Patient has adequate peripheral perfusion at sensor site */
        }
        
        assume constraint properSensorPlacement {
            doc /* Sensor is correctly positioned on patient finger, toe, or earlobe
                 with good contact and minimal motion artifact */
        }
        
        assume constraint ambientConditions {
            doc /* Ambient light interference is minimized and operating temperature
                 is within specified range of 10°C to 40°C */
        }
    }
    
    requirement <'REQ-NELLCOR-002'> patientSafetyRequirement : SafetyRequirement {
        doc /* Patient safety and alarm system requirements for continuous monitoring */
    }
    
    requirement <'REQ-NELLCOR-003'> operationalPerformance : PerformanceRequirement {
        doc /* Operational performance requirements for clinical workflow integration */
    }
    
    requirement <'REQ-NELLCOR-004'> primaryFunction {
        doc /* The primary function of the Nellcor pulse oximeter system is to provide
             continuous, non-invasive monitoring of arterial oxygen saturation (SpO2)
             and pulse rate, displaying real-time values and waveforms to clinicians,
             and generating alarms when physiological parameters fall outside
             configured safe ranges, thereby enabling early detection of hypoxemia
             and supporting patient safety in clinical care environments. */
        
        subject monitor : NellcorMonitor;
        
        satisfy primaryFunction by nellcorPulseOximeter;
    }
}
