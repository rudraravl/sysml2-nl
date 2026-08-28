package SICD {
    import ScalarValues::*;
    
    // ---- Value types with units ----
    attribute def Voltage :> Real { unit 'V'; }
    attribute def Energy :> Real { unit 'J'; }
    attribute def HeartRate :> Real { unit 'bpm'; }
    attribute def Current :> Real { unit 'A'; }
    attribute def Duration :> Real { unit 's'; }
    attribute def Impedance :> Real { unit 'ohm'; }
    attribute def Frequency :> Real { unit 'Hz'; }
    
    // ---- Item types ----
    item def CardiacSignal {
        attribute amplitude : Voltage;
        attribute dominantFrequency : Frequency;
        attribute timestamp : Duration;
    }
    
    item def ProcessedSignal {
        attribute amplitude : Voltage;
        attribute estimatedRate : HeartRate;
        attribute noiseFloor : Voltage;
        attribute snr : Real;
    }
    
    item def DetectionResult {
        attribute rhythmType : String;
        attribute confidence : Real;
        attribute detectedRate : HeartRate;
        attribute isLifeThreatening : Boolean;
    }
    
    item def TherapyDecision {
        attribute therapyRequired : Boolean;
        attribute programmedEnergy : Energy;
        attribute shockIndex : Integer;
    }
    
    item def ShockPulse {
        attribute energy : Energy;
        attribute peakVoltage : Voltage;
        attribute pulseDuration : Duration;
        attribute waveform : String;
    }
    
    item def PowerFlow {
        attribute current : Current;
        attribute voltage : Voltage;
    }
    
    // ---- Port definitions ----
    port def CardiacSignalPort {
        out signal : CardiacSignal;
    }
    
    port def ProcessedSignalPort {
        out signal : ProcessedSignal;
    }
    
    port def DetectionResultPort {
        out result : DetectionResult;
    }
    
    port def DecisionPort {
        out decision : TherapyDecision;
    }
    
    port def ChargePort {
        out charge : ShockPulse;
    }
    
    port def ShockDeliveryPort {
        out pulse : ShockPulse;
    }
    
    port def PowerPort {
        out power : PowerFlow;
    }
    
    port def CommandPort {
        out trigger : Boolean;
    }
    
    // ---- Component part definitions ----
    part def SensingElectrode {
        port cardiacOut : CardiacSignalPort;
        attribute electrodePosition : String = "parasternal";
        attribute sensingGain : Real = 1.0;
        
        action def SenseCardiacActivity {
            in raw : CardiacSignal;
            out sensed : CardiacSignal;
            perform {
                sensed.amplitude = raw.amplitude * sensingGain;
            }
        }
    }
    
    part def SignalProcessingUnit {
        port signalIn : ~CardiacSignalPort;
        port processedOut : ProcessedSignalPort;
        attribute amplifierGain : Real = 100.0;
        attribute filterBandwidth : Frequency = 40.0;
        attribute noiseFloor : Voltage = 0.05;
        
        action def ProcessSignal {
            in raw : CardiacSignal;
            out processed : ProcessedSignal;
            perform {
                processed.amplitude = raw.amplitude * amplifierGain;
                processed.noiseFloor = noiseFloor;
                processed.snr = processed.amplitude / noiseFloor;
            }
        }
    }
    
    part def ArrhythmiaDetectionUnit {
        port processedIn : ~ProcessedSignalPort;
        port resultOut : DetectionResultPort;
        attribute vfRateThreshold : HeartRate = 200.0;
        attribute vtRateThreshold : HeartRate = 150.0;
        attribute detectionWindow : Duration = 3.0;
        attribute confidenceThreshold : Real = 0.7;
        
        action def DetectArrhythmia {
            in signal : ProcessedSignal;
            out result : DetectionResult;
            perform {
                if signal.estimatedRate >= vfRateThreshold {
                    result.rhythmType = "VentricularFibrillation";
                    result.isLifeThreatening = true;
                } else if signal.estimatedRate >= vtRateThreshold {
                    result.rhythmType = "VentricularTachycardia";
                    result.isLifeThreatening = true;
                } else {
                    result.rhythmType = "NormalSinusRhythm";
                    result.isLifeThreatening = false;
                }
                result.detectedRate = signal.estimatedRate;
                result.confidence = signal.snr / (signal.snr + 1.0);
            }
        }
    }
    
    part def TherapyDecisionUnit {
        port resultIn : ~DetectionResultPort;
        port decisionOut : DecisionPort;
        attribute programmedEnergy : Energy = 80.0;
        attribute maxShocks : Integer = 5;
        attribute currentShockCount : Integer = 0;
        
        action def DecideTherapy {
            in result : DetectionResult;
            out decision : TherapyDecision;
            perform {
                if result.isLifeThreatening and result.confidence >= 0.7 and currentShockCount < maxShocks {
                    decision.therapyRequired = true;
                    decision.programmedEnergy = programmedEnergy;
                    decision.shockIndex = currentShockCount + 1;
                } else {
                    decision.therapyRequired = false;
                    decision.programmedEnergy = 0.0;
                    decision.shockIndex = currentShockCount;
                }
            }
        }
    }
    
    part def ControlProcessor {
        port decisionIn : ~DecisionPort;
        port chargeCommand : CommandPort;
        port deliverCommand : CommandPort;
        port resetCommand : CommandPort;
        attribute therapyTimeout : Duration = 30.0;
        attribute reconfirmationTime : Duration = 2.0;
        
        action def CoordinateTherapy {
            in decision : TherapyDecision;
            out chargeTrigger : Boolean;
            out deliverTrigger : Boolean;
            perform {
                chargeTrigger = decision.therapyRequired;
                deliverTrigger = false;
            }
        }
    }
    
    part def BatteryPack {
        port powerOut : PowerPort;
        attribute capacity : Energy = 1000.0;
        attribute nominalVoltage : Voltage = 3.2;
        attribute remainingCapacity : Energy = 1000.0;
        attribute maxOutputCurrent : Current = 2.0;
    }
    
    part def HighVoltageCapacitor {
        port powerIn : ~PowerPort;
        port chargeOut : ChargePort;
        attribute maxEnergy : Energy = 80.0;
        attribute chargeTime : Duration = 10.0;
        attribute currentCharge : Energy = 0.0;
        attribute chargeEfficiency : Real = 0.85;
        
        action def ChargeCapacitor {
            in power : PowerFlow;
            out chargeReady : Boolean;
            perform {
                currentCharge = maxEnergy;
                chargeReady = (currentCharge >= maxEnergy);
            }
        }
    }
    
    part def DefibrillationElectrode {
        port shockIn : ~ChargePort;
        port shockDelivery : ShockDeliveryPort;
        attribute electrodeImpedance : Impedance = 50.0;
        attribute electrodePosition : String = "left-lateral";
        
        action def DeliverShock {
            in charge : ShockPulse;
            out pulse : ShockPulse;
            perform {
                pulse.energy = charge.energy;
                pulse.peakVoltage = charge.peakVoltage;
                pulse.pulseDuration = charge.pulseDuration;
                pulse.waveform = "biphasic";
            }
        }
    }
    
    part def Patient {
        port cardiacActivity : CardiacSignalPort;
        port therapyIn : ~ShockDeliveryPort;
        attribute heartRate : HeartRate = 72.0;
        attribute transthoracicImpedance : Impedance = 70.0;
    }
    
    // ---- Top-level S-ICD system ----
    part def SICDDevice {
        port sensingInterface : ~CardiacSignalPort;
        port therapyInterface : ShockDeliveryPort;
        
        part sensingElectrode : SensingElectrode {
            port cardiacOut : CardiacSignalPort;
        }
        part signalProcessing : SignalProcessingUnit {
            port signalIn : ~CardiacSignalPort;
            port processedOut : ProcessedSignalPort;
        }
        part arrhythmiaDetection : ArrhythmiaDetectionUnit {
            port processedIn : ~ProcessedSignalPort;
            port resultOut : DetectionResultPort;
        }
        part therapyDecision : TherapyDecisionUnit {
            port resultIn : ~DetectionResultPort;
            port decisionOut : DecisionPort;
        }
        part controlProcessor : ControlProcessor {
            port decisionIn : ~DecisionPort;
            port chargeCommand : CommandPort;
            port deliverCommand : CommandPort;
        }
        part battery : BatteryPack {
            port powerOut : PowerPort;
        }
        part capacitor : HighVoltageCapacitor {
            port powerIn : ~PowerPort;
            port chargeOut : ChargePort;
        }
        part defibElectrode : DefibrillationElectrode {
            port shockIn : ~ChargePort;
            port shockDelivery : ShockDeliveryPort;
        }
        
        // ---- Internal connections ----
        flow connection sensingToProcessing
            connect sensingElectrode.cardiacOut to signalProcessing.signalIn;
        
        flow connection processingToDetection
            connect signalProcessing.processedOut to arrhythmiaDetection.processedIn;
        
        flow connection detectionToDecision
            connect arrhythmiaDetection.resultOut to therapyDecision.resultIn;
        
        flow connection decisionToControl
            connect therapyDecision.decisionOut to controlProcessor.decisionIn;
        
        connection controlToCapacitor
            connect controlProcessor.chargeCommand to capacitor.powerIn;
        
        flow connection batteryToCapacitor
            connect battery.powerOut to capacitor.powerIn;
        
        flow connection capacitorToDefib
            connect capacitor.chargeOut to defibElectrode.shockIn;
        
        // ---- External interface connections ----
        flow connection patientToSensing
            connect sensingInterface to sensingElectrode.cardiacOut;
        
        flow connection defibToPatient
            connect defibElectrode.shockDelivery to therapyInterface;
        
        // ---- Device-level state machine ----
        attribute arrhythmiaDetected : Boolean = false;
        attribute confirmedArrhythmia : Boolean = false;
        attribute falseAlarm : Boolean = false;
        attribute capacitorReady : Boolean = false;
        attribute chargeFailure : Boolean = false;
        attribute shockDelivered : Boolean = false;
        attribute rhythmRestored : Boolean = false;
        attribute arrhythmiaPersists : Boolean = false;
        
        state def DeviceLifecycle {
            entry; then Monitoring;
            
            state Monitoring {
                entry action doMonitor {
                    "Continuously acquire and process cardiac signal.";
                }
                on arrhythmiaDetected then Detection;
            }
            
            state Detection {
                entry action doDetect {
                    "Analyze rate and rhythm; confirm life-threatening arrhythmia.";
                }
                on confirmedArrhythmia then Charging;
                on falseAlarm then Monitoring;
            }
            
            state Charging {
                entry action doCharge {
                    "Energize high-voltage capacitor to programmed energy.";
                }
                on capacitorReady then TherapyDelivery;
                on chargeFailure then Monitoring;
            }
            
            state TherapyDelivery {
                entry action doDeliver {
                    "Deliver biphasic shock through defibrillation electrode.";
                }
                on shockDelivered then PostShockAssessment;
            }
            
            state PostShockAssessment {
                entry action doAssess {
                    "Verify restoration of normal rhythm.";
                }
                on rhythmRestored then Monitoring;
                on arrhythmiaPersists then Detection;
            }
        }
        
        part behavior : DeviceLifecycle;
    }
    
    // ---- Requirements ----
    requirement def SICDRequirement {
        subject device : SICDDevice;
        objective : "Protect patient at risk of sudden cardiac death by automatic detection and therapy.";
    }
    
    requirement ContinuousMonitoringRequirement :> SICDRequirement {
        attribute samplingRate : Frequency = 250.0;
        require device.sensingElectrode shall continuously monitor cardiac activity at >= samplingRate;
    }
    
    requirement SignalQualityRequirement :> SICDRequirement {
        attribute minSNR : Real = 5.0;
        require device.signalProcessing shall produce ProcessedSignal with snr >= minSNR;
    }
    
    requirement DetectionAccuracyRequirement :> SICDRequirement {
        attribute minSensitivity : Real = 0.98;
        attribute maxFalsePositiveRate : Real = 0.01;
        require device.arrhythmiaDetection shall detect ventricular fibrillation with sensitivity >= minSensitivity;
    }
    
    requirement TherapyLatencyRequirement :> SICDRequirement {
        attribute maxTherapyTime : Duration = 30.0;
        require device shall deliver therapy within maxTherapyTime of confirmed arrhythmia detection;
    }
    
    requirement ShockEnergyRequirement :> SICDRequirement {
        attribute maxEnergy : Energy = 80.0;
        attribute minEnergy : Energy = 10.0;
        require device.defibElectrode shall deliver ShockPulse with energy between minEnergy and maxEnergy;
    }
    
    requirement SafetyRequirement :> SICDRequirement {
        require device shall not deliver therapy during normal sinus rhythm;
    }
    
    requirement BatteryLifeRequirement :> SICDRequirement {
        attribute minServiceLife : Duration = 252288000.0; // 8 years in seconds
        require device.battery shall provide capacity sufficient for minServiceLife of operation;
    }
    
    // ---- System instantiation ----
    part sicdSystem : SICDDevice {
        part patient : Patient {
            port cardiacActivity : CardiacSignalPort;
            port therapyIn : ~ShockDeliveryPort;
        }
        
        flow connection patientSignalToSICD
            connect patient.cardiacActivity to sicdSystem.sensingInterface;
        
        flow connection sicdTherapyToPatient
            connect sicdSystem.therapyInterface to patient.therapyIn;
    }
}
