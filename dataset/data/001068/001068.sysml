package GeigerCounterSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def CountsPerMinute :> Real;
    attribute def DoseRateValue :> Real;
    attribute def VoltageLevel :> Real;
    attribute def PulseCount :> Integer;
    
    enum def SafetyLevel {
        background;
        elevated;
        warning;
        danger;
    }
    
    item def IonizingParticle {
        attribute energyLevel : EnergyValue;
        attribute particleType : String;
    }
    
    item def ElectricalPulse {
        attribute amplitude : VoltageLevel;
        attribute duration : DurationValue;
    }
    
    attribute def MeasurementReading {
        attribute cpm : CountsPerMinute;
        attribute doseRate : DoseRateValue;
        attribute timestamp : TimeValue;
    }
    
    port def RadiationInputPort {
        in particle : IonizingParticle;
    }
    
    port def PulseOutputPort {
        out pulse : ElectricalPulse;
    }
    
    port def PulseInputPort {
        in pulse : ElectricalPulse;
    }
    
    port def DataOutputPort {
        out reading : MeasurementReading;
    }
    
    port def DataInputPort {
        in reading : MeasurementReading;
    }
    
    port def AlarmTriggerPort {
        out alarmSignal : Boolean;
    }
    
    port def PowerOutputPort {
        out voltage : VoltageLevel;
    }
    
    part def HighVoltageSupply {
        attribute inputVoltage : VoltageLevel = 9.0 [V];
        attribute outputVoltage : VoltageLevel = 450.0 [V];
        
        port hvOut : PowerOutputPort;
        
        action generateHighVoltage {
            in inputV : VoltageLevel;
            out outputV : VoltageLevel;
        }
    }
    
    part def GeigerMullerTube {
        attribute operatingVoltage : VoltageLevel = 450.0 [V];
        attribute tubeLength : LengthValue = 95.0 [mm];
        attribute fillGas : String = "Neon-Halogen";
        attribute deadTime : DurationValue = 100.0e-6 [s];
        
        port radiationIn : RadiationInputPort;
        port pulseOut : PulseOutputPort;
        
        action detectIonization {
            in particle : IonizingParticle;
            out pulse : ElectricalPulse;
            out ionizationEvent : Boolean;
        }
    }
    
    part def PulseProcessingUnit {
        attribute pulseCount : PulseCount = 0;
        attribute measurementInterval : DurationValue = 60.0 [s];
        attribute currentCPM : CountsPerMinute = 0.0;
        attribute conversionFactor : Real = 0.0057;
        
        port pulseIn : PulseInputPort;
        port dataOut : DataOutputPort;
        
        action countPulses {
            in pulse : ElectricalPulse;
            inout count : PulseCount;
            out cpm : CountsPerMinute;
        }
        
        action calculateDoseRate {
            in cpm : CountsPerMinute;
            in factor : Real;
            out doseRate : DoseRateValue;
        }
    }
    
    part def AudioIndicator {
        attribute clickEnabled : Boolean = true;
        attribute clickVolume : Real = 0.75;
        
        port pulseIn : PulseInputPort;
        
        action produceClick {
            in trigger : ElectricalPulse;
        }
    }
    
    part def VisualDisplay {
        attribute displayBrightness : Real = 0.8;
        attribute displayUnits : String = "CPM";
        attribute backlightActive : Boolean = true;
        
        port dataIn : DataInputPort;
        
        action updateDisplay {
            in reading : MeasurementReading;
            in safetyLevel : SafetyLevel;
        }
    }
    
    part def AlarmUnit {
        attribute alarmThreshold : CountsPerMinute = 120.0;
        attribute alarmActive : Boolean = false;
        attribute alarmType : String = "Audible";
        
        port dataIn : DataInputPort;
        port alarmOut : AlarmTriggerPort;
        
        action evaluateThreshold {
            in reading : MeasurementReading;
            in threshold : CountsPerMinute;
            out alarmState : Boolean;
        }
        
        action activateAlarm {
            in trigger : Boolean;
        }
    }
    
    part def GeigerCounter {
        attribute systemStatus : String = "Operational";
        attribute batteryLevel : Real = 100.0;
        attribute currentSafetyLevel : SafetyLevel = SafetyLevel::background;
        attribute currentReading : CountsPerMinute = 0.0;
        
        port environmentalRadiation : RadiationInputPort;
        
        part powerSupply : HighVoltageSupply {
            attribute :>> inputVoltage = 9.0 [V];
            attribute :>> outputVoltage = 450.0 [V];
        }
        
        part detectorTube : GeigerMullerTube {
            attribute :>> operatingVoltage = 450.0 [V];
            attribute :>> tubeLength = 95.0 [mm];
            attribute :>> fillGas = "Neon-Halogen";
            attribute :>> deadTime = 100.0e-6 [s];
        }
        
        part processor : PulseProcessingUnit {
            attribute :>> pulseCount = 0;
            attribute :>> measurementInterval = 60.0 [s];
            attribute :>> currentCPM = 0.0;
            attribute :>> conversionFactor = 0.0057;
        }
        
        part speaker : AudioIndicator {
            attribute :>> clickEnabled = true;
            attribute :>> clickVolume = 0.75;
        }
        
        part display : VisualDisplay {
            attribute :>> displayBrightness = 0.8;
            attribute :>> displayUnits = "CPM";
            attribute :>> backlightActive = true;
        }
        
        part alarm : AlarmUnit {
            attribute :>> alarmThreshold = 120.0;
            attribute :>> alarmActive = false;
            attribute :>> alarmType = "Audible";
        }
        
        connection radiationDetection connect environmentalRadiation to detectorTube.radiationIn;
        connection pulseToProcessor connect detectorTube.pulseOut to processor.pulseIn;
        connection pulseToAudio connect detectorTube.pulseOut to speaker.pulseIn;
        connection dataToDisplay connect processor.dataOut to display.dataIn;
        connection dataToAlarm connect processor.dataOut to alarm.dataIn;
        
        perform action monitorRadiation {
            first start;
            then merge continuousMonitoring;
            
            action initializeTube {
                in voltage = powerSupply.outputVoltage;
            }
            then action detectParticle {
                in particle : IonizingParticle;
                out pulse : ElectricalPulse;
                out detected : Boolean;
            }
            then action processPulse {
                in pulse = detectParticle.pulse;
                out cpmValue : CountsPerMinute;
                out doseValue : DoseRateValue;
            }
            then action assessRadiationLevel {
                in cpm = processPulse.cpmValue;
                out safetyLevel : SafetyLevel;
            }
            then decide;
                if assessRadiationLevel.safetyLevel == SafetyLevel::background then normalOperation;
                if assessRadiationLevel.safetyLevel == SafetyLevel::elevated then elevatedOperation;
                if assessRadiationLevel.safetyLevel == SafetyLevel::warning then warningOperation;
                if assessRadiationLevel.safetyLevel == SafetyLevel::danger then dangerOperation;
            
            action normalOperation {
                in reading = processPulse.cpmValue;
            }
            then continuousMonitoring;
            
            action elevatedOperation {
                in reading = processPulse.cpmValue;
            }
            then continuousMonitoring;
            
            action warningOperation {
                in reading = processPulse.cpmValue;
            }
            then triggerWarningAlarm;
            then continuousMonitoring;
            
            action dangerOperation {
                in reading = processPulse.cpmValue;
            }
            then triggerDangerAlarm;
            then continuousMonitoring;
            
            action triggerWarningAlarm;
            action triggerDangerAlarm;
        }
        
        exhibit state monitoringBehavior {
            entry; then idle;
            
            state idle;
            accept at when detectorTube.pulseOut.pulse
                then detecting;
            
            state detecting;
            accept after processor.measurementInterval
                then evaluating;
            
            state evaluating;
            if currentReading < 50.0 then backgroundLevel;
            if currentReading >= 50.0 and currentReading < 100.0 then elevatedLevel;
            if currentReading >= 100.0 and currentReading < 200.0 then warningLevel;
            if currentReading >= 200.0 then dangerLevel;
            
            state backgroundLevel;
            then idle;
            
            state elevatedLevel;
            then idle;
            
            state warningLevel;
            then idle;
            
            state dangerLevel;
            then idle;
        }
    }
    
    requirement <'REQ-GC-100'> detectIonizingRadiation {
        doc /* The Geiger counter system shall detect ionizing radiation
             * by measuring ionization events in the Geiger-Muller tube
             * and converting them to a counts per minute measurement.
             */
        subject geigerCounter : GeigerCounter;
        
        require <'REQ-GC-101'> operatingVoltageRequirement {
            doc /* The Geiger-Muller tube shall operate at a voltage
                 * sufficient to enable gas ionization detection.
                 */
            subject tube :>> geigerCounter.detectorTube;
            assert constraint {
                tube.operatingVoltage >= 400.0 [V] and tube.operatingVoltage <= 500.0 [V]
            }
        }
        
        require <'REQ-GC-102'> pulseCountingAccuracy {
            doc /* The pulse processing unit shall accurately count
                 * detection events over the measurement interval.
                 */
            subject processingUnit :>> geigerCounter.processor;
            assert constraint {
                processingUnit.measurementInterval == 60.0 [s]
            }
        }
    }
    
    requirement <'REQ-GC-200'> provideContinuousFeedback {
        doc /* The Geiger counter shall provide continuous real-time
             * feedback to the user through audible and visual indicators
             * based on the measured radiation level.
             */
        subject geigerCounter : GeigerCounter;
        
        require <'REQ-GC-201'> audibleClickFeedback {
            doc /* The system shall produce an audible click for each
                 * detected ionization event.
                 */
            subject audioIndicator :>> geigerCounter.speaker;
            assert constraint {
                audioIndicator.clickEnabled == true
            }
        }
        
        require <'REQ-GC-202'> visualDisplayFeedback {
            doc /* The system shall display the current radiation level
                 * in counts per minute on the visual display.
                 */
            subject visualDisplay :>> geigerCounter.display;
            assert constraint {
                visualDisplay.displayUnits == "CPM"
            }
        }
    }
    
    requirement <'REQ-GC-300'> activateSafetyAlarm {
        doc /* The Geiger counter shall activate a safety alarm when
             * radiation levels exceed the defined safe threshold.
             */
        subject geigerCounter : GeigerCounter;
        
        require <'REQ-GC-301'> alarmThresholdSetting {
            doc /* The alarm shall activate when radiation exceeds
                 * 120 counts per minute.
                 */
            subject alarmSystem :>> geigerCounter.alarm;
            assert constraint {
                alarmSystem.alarmThreshold == 120.0
            }
        }
    }
    
    part geigerCounterSystem : GeigerCounter;
    
    satisfy detectIonizingRadiation by geigerCounterSystem;
    satisfy provideContinuousFeedback by geigerCounterSystem;
    satisfy activateSafetyAlarm by geigerCounterSystem;
}
