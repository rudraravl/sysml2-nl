package MagneticFieldSensorSystem {
    import ScalarValues::*;
    import SI::*;
    
    // ===== Value Types with Units =====
    
    value type MagneticFluxDensityValue :> Real {
        :>> unit = T;
    }
    
    value type VoltageValue :> Real {
        :>> unit = V;
    }
    
    value type CurrentValue :> Real {
        :>> unit = A;
    }
    
    value type ResistanceValue :> Real {
        :>> unit = Ohm;
    }
    
    value type TemperatureValue :> Real {
        :>> unit = K;
    }
    
    value type FrequencyValue :> Real {
        :>> unit = Hz;
    }
    
    value type DigitalCount :> Integer {
        :>> min = 0;
        :>> max = 65535;
    }
    
    // ===== Item Definitions =====
    
    item def MagneticField {
        attribute fluxDensity : MagneticFluxDensityValue;
        attribute direction : Real;
    }
    
    item def AnalogSignal {
        attribute voltage : VoltageValue;
        attribute noiseLevel : VoltageValue;
        attribute bandwidth : FrequencyValue;
    }
    
    item def CompensatedSignal {
        attribute voltage : VoltageValue;
        attribute temperature : TemperatureValue;
        attribute correctionFactor : Real;
    }
    
    item def DigitalData {
        attribute rawCount : DigitalCount;
        attribute temperatureCount : DigitalCount;
        attribute timestamp : Integer;
    }
    
    item def CalibrationData {
        attribute slope : Real;
        attribute offset : MagneticFluxDensityValue;
        attribute temperatureCoefficient : Real;
        attribute linearizationCoefficients : Real[0..*];
    }
    
    // ===== Port Definitions =====
    
    port def MagneticFieldPort {
        in field : MagneticField;
    }
    
    port def BiasPowerOutPort {
        out voltage : VoltageValue;
        out current : CurrentValue;
    }
    
    port def BiasPowerInPort {
        in voltage : VoltageValue;
        in current : CurrentValue;
    }
    
    port def AnalogOutPort {
        out signal : AnalogSignal;
    }
    
    port def AnalogInPort {
        in signal : AnalogSignal;
    }
    
    port def CompensatedOutPort {
        out signal : CompensatedSignal;
    }
    
    port def CompensatedInPort {
        in signal : CompensatedSignal;
    }
    
    port def DigitalOutPort {
        out data : DigitalData;
    }
    
    port def DigitalInPort {
        in data : DigitalData;
    }
    
    port def TemperatureOutPort {
        out temperature : TemperatureValue;
    }
    
    port def TemperatureInPort {
        in temperature : TemperatureValue;
    }
    
    port def FieldStrengthOutPort {
        out fieldStrength : MagneticFluxDensityValue;
        out valid : Boolean;
    }
    
    // ===== Connection Definitions =====
    
    connection def BiasPowerConnection {
        end source : BiasPowerOutPort;
        end target : BiasPowerInPort;
    }
    
    connection def AnalogSignalConnection {
        end source : AnalogOutPort;
        end target : AnalogInPort;
    }
    
    connection def CompensatedSignalConnection {
        end source : CompensatedOutPort;
        end target : CompensatedInPort;
    }
    
    connection def DigitalDataConnection {
        end source : DigitalOutPort;
        end target : DigitalInPort;
    }
    
    connection def TemperatureConnection {
        end source : TemperatureOutPort;
        end target : TemperatureInPort;
    }
    
    // ===== Component Part Definitions =====
    
    part def MagnetoresistiveElement {
        port magFieldIn : MagneticFieldPort;
        port biasIn : BiasPowerInPort;
        port signalOut : AnalogOutPort;
        
        attribute nominalResistance : ResistanceValue = 5000 [Ohm];
        attribute sensitivity : Real = 0.01;
        attribute maxFieldRange : MagneticFluxDensityValue = 10 [T];
        attribute minFieldRange : MagneticFluxDensityValue = 0 [T];
        attribute currentFluxDensity : MagneticFluxDensityValue;
        attribute currentResistance : ResistanceValue;
        attribute temperatureDependence : Real = 0.003;
        
        action computeResistance {
            in fluxDensity : MagneticFluxDensityValue;
            in temperature : TemperatureValue;
            out resistance : ResistanceValue;
        }
        
        action generateOutputVoltage {
            in resistance : ResistanceValue;
            in biasCurrent : CurrentValue;
            out voltage : VoltageValue;
        }
        
        action senseField {
            in field : MagneticFluxDensityValue;
            in biasVoltage : VoltageValue;
            in biasCurrent : CurrentValue;
            out outputSignal : AnalogSignal;
        }
    }
    
    part def BiasingCircuit {
        port powerIn : BiasPowerInPort;
        port biasOut : BiasPowerOutPort;
        
        attribute regulatedVoltage : VoltageValue = 5.0 [V];
        attribute regulatedCurrent : CurrentValue = 0.001 [A];
        attribute voltageStability : Real = 0.01;
        attribute temperatureDrift : Real = 0.00005;
        attribute ripple : VoltageValue = 0.0001 [V];
        
        action regulateVoltage {
            in inputVoltage : VoltageValue;
            out regulatedOut : VoltageValue;
        }
        
        action regulateCurrent {
            in inputCurrent : CurrentValue;
            out regulatedOut : CurrentValue;
        }
        
        action provideStableBias {
            out voltage : VoltageValue;
            out current : CurrentValue;
        }
    }
    
    part def TemperatureSensor {
        port tempOut : TemperatureOutPort;
        
        attribute accuracy : TemperatureValue = 0.1 [K];
        attribute minRange : TemperatureValue = 218.15 [K];
        attribute maxRange : TemperatureValue = 423.15 [K];
        attribute responseTime : Real = 0.1;
        
        action measureTemperature {
            out temperature : TemperatureValue;
        }
    }
    
    part def SignalConditioner {
        port analogIn : AnalogInPort;
        port conditionedOut : AnalogOutPort;
        
        attribute gain : Real = 100.0;
        attribute cutoffFrequency : FrequencyValue = 10000 [Hz];
        attribute inputNoiseFloor : VoltageValue = 0.00001 [V];
        attribute commonModeRejection : Real = 80.0;
        attribute offsetVoltage : VoltageValue = 0 [V];
        
        action amplifySignal {
            in inputSignal : AnalogSignal;
            out amplifiedSignal : AnalogSignal;
        }
        
        action filterNoise {
            in inputSignal : AnalogSignal;
            out filteredSignal : AnalogSignal;
        }
        
        action removeOffset {
            in inputSignal : AnalogSignal;
            out correctedSignal : AnalogSignal;
        }
    }
    
    part def TemperatureCompensator {
        port signalIn : AnalogInPort;
        port tempIn : TemperatureInPort;
        port compensatedOut : CompensatedOutPort;
        
        attribute temperatureCoefficient : Real = 0.002;
        attribute referenceTemperature : TemperatureValue = 293.15 [K];
        attribute compensationAccuracy : Real = 0.0001;
        
        action calculateCorrectionFactor {
            in currentTemp : TemperatureValue;
            out factor : Real;
        }
        
        action applyCompensation {
            in signal : AnalogSignal;
            in temperature : TemperatureValue;
            out compensatedSignal : CompensatedSignal;
        }
    }
    
    part def AnalogToDigitalConverter {
        port analogIn : CompensatedInPort;
        port digitalOut : DigitalOutPort;
        
        attribute resolution : Integer = 16;
        attribute sampleRate : FrequencyValue = 100000 [Hz];
        attribute referenceVoltage : VoltageValue = 5.0 [V];
        attribute conversionTime : Real = 0.00001;
        attribute lsbVoltage : VoltageValue = 0.0000762 [V];
        
        action sample {
            in signal : CompensatedSignal;
            out sampledVoltage : VoltageValue;
        }
        
        action quantize {
            in voltage : VoltageValue;
            out count : DigitalCount;
        }
        
        action convert {
            in signal : CompensatedSignal;
            out data : DigitalData;
        }
    }
    
    part def DataProcessor {
        port digitalIn : DigitalInPort;
        port dataOut : FieldStrengthOutPort;
        
        attribute calibrationData : CalibrationData;
        attribute processingLatency : Real = 0.0001;
        attribute outputRate : FrequencyValue = 1000 [Hz];
        
        action linearizeResponse {
            in data : DigitalData;
            in coefficients : Real[0..*];
            out linearizedData : DigitalData;
        }
        
        action applyCalibration {
            in data : DigitalData;
            in calibration : CalibrationData;
            out fieldStrength : MagneticFluxDensityValue;
        }
        
        action calculateFieldStrength {
            in data : DigitalData;
            out fieldStrength : MagneticFluxDensityValue;
            out valid : Boolean;
        }
        
        action validateOutput {
            in fieldStrength : MagneticFluxDensityValue;
            out valid : Boolean;
        }
    }
    
    // ===== System Assembly =====
    
    part def MagneticFieldSensorSystem {
        port fieldInput : MagneticFieldPort;
        port dataOutput : FieldStrengthOutPort;
        port powerInput : BiasPowerInPort;
        
        part magnetoresistiveElement : MagnetoresistiveElement;
        part biasingCircuit : BiasingCircuit;
        part temperatureSensor : TemperatureSensor;
        part signalConditioner : SignalConditioner;
        part temperatureCompensator : TemperatureCompensator;
        part adc : AnalogToDigitalConverter;
        part dataProcessor : DataProcessor;
        
        // Connections
        connection powerToBias : BiasPowerConnection from powerInput to biasingCircuit.powerIn;
        connection biasToMR : BiasPowerConnection from biasingCircuit.biasOut to magnetoresistiveElement.biasIn;
        connection fieldToMR from fieldInput to magnetoresistiveElement.magFieldIn;
        connection mrToConditioner : AnalogSignalConnection from magnetoresistiveElement.signalOut to signalConditioner.analogIn;
        connection tempToCompensator : TemperatureConnection from temperatureSensor.tempOut to temperatureCompensator.tempIn;
        connection conditionerToCompensator : AnalogSignalConnection from signalConditioner.conditionedOut to temperatureCompensator.signalIn;
        connection compensatorToADC : CompensatedSignalConnection from temperatureCompensator.compensatedOut to adc.analogIn;
        connection adcToProcessor : DigitalDataConnection from adc.digitalOut to dataProcessor.digitalIn;
        connection processorToOutput from dataProcessor.dataOut to dataOutput;
        
        // System attributes for state machine
        attribute powerOnRequested : Boolean = false;
        attribute selfTestPassed : Boolean = false;
        attribute calibrationComplete : Boolean = false;
        attribute measurementRequested : Boolean = false;
        attribute powerOffRequested : Boolean = false;
        attribute systemInitialized : Boolean = false;
        attribute systemReady : Boolean = false;
        
        // Actions for lifecycle
        action runSelfTest {
            out pass : Boolean;
        }
        
        action runCalibration {
            out complete : Boolean;
        }
        
        action takeMeasurement {
            in field : MagneticField;
            out fieldStrength : MagneticFluxDensityValue;
        }
        
        action processData {
            in data : DigitalData;
            out fieldStrength : MagneticFluxDensityValue;
        }
        
        action outputResult {
            in fieldStrength : MagneticFluxDensityValue;
        }
        
        // State machine for lifecycle
        state sensorLifecycle {
            entry state initial;
            
            state poweredOff {
                entry action {
                    selfTestPassed = false;
                    calibrationComplete = false;
                    systemInitialized = false;
                    systemReady = false;
                }
            }
            
            state initializing {
                entry perform runSelfTest;
            }
            
            state calibrating {
                entry perform runCalibration;
            }
            
            state ready {
                entry action {
                    systemReady = true;
                }
            }
            
            state measuring {
                entry perform takeMeasurement;
            }
            
            state processing {
                entry perform processData;
            }
            
            state outputting {
                entry perform outputResult;
            }
            
            transition startFromInitial from initial to poweredOff;
            transition powerOnInit from poweredOff to initializing when powerOnRequested;
            transition selfTestDone from initializing to calibrating when selfTestPassed;
            transition calibrationDone from calibrating to ready when calibrationComplete;
            transition beginMeasurement from ready to measuring when measurementRequested;
            transition measurementComplete from measuring to processing;
            transition processingComplete from processing to outputting;
            transition outputComplete from outputting to ready;
            transition shutDown from (ready | measuring | processing | outputting) to poweredOff when powerOffRequested;
        }
    }
    
    // ===== Requirements =====
    
    requirement def SensorSystemRequirement {
        doc /* Base requirement definition for the magnetic field sensor system. */;
    }
    
    requirement detectMagneticField : SensorSystemRequirement {
        doc /* The system shall detect and accurately measure magnetic field strength using a magnetoresistive element whose electrical resistance changes in the presence of a magnetic field. */;
    }
    
    requirement biasStabilityReq : SensorSystemRequirement {
        doc /* The biasing circuit shall provide stable voltage and current to the magnetoresistive element to ensure consistent operation across the specified temperature range. */;
    }
    
    requirement signalConditioningReq : SensorSystemRequirement {
        doc /* The signal conditioner shall amplify the weak signal from the magnetoresistive element and filter out unwanted electrical noise to produce a stronger and cleaner signal. */;
    }
    
    requirement temperatureCompensationReq : SensorSystemRequirement {
        doc /* The temperature compensator shall adjust the reading to correct for resistance variations caused by changes in ambient temperature. */;
    }
    
    requirement analogToDigitalConversionReq : SensorSystemRequirement {
        doc /* The analog-to-digital converter shall translate the cleaned, amplified, and temperature-corrected analog signal into a digital format. */;
    }
    
    requirement dataProcessingReq : SensorSystemRequirement {
        doc /* The data processor shall apply calibration data to linearize the response and calculate the final magnetic field strength, making the result available through a data output port. */;
    }
    
    requirement lifecycleReq : SensorSystemRequirement {
        doc /* The system shall operate through a defined lifecycle: power-on initialization and self-test, followed by a calibration routine, then active measurement cycles where it continuously measures the field, processes the data, and outputs the results before returning to a ready state for the next measurement. */;
    }
    
    requirement measurementRangeReq : SensorSystemRequirement {
        doc /* The system shall measure magnetic fields from 0 to 10 Tesla with a minimum ADC resolution of 16 bits. */;
    }
    
    requirement measurementAccuracyReq : SensorSystemRequirement {
        doc /* The system shall achieve measurement accuracy of at least 0.1 percent of full-scale reading over the operating temperature range of -55 to 150 degrees Celsius. */;
    }
    
    requirement responseTimeReq : SensorSystemRequirement {
        doc /* The system shall complete a full measurement cycle, from field detection to data output, within 1 millisecond. */;
    }
    
    requirement selfTestReq : SensorSystemRequirement {
        doc /* The system shall perform an initialization and self-test sequence upon power-on, verifying the integrity of all subsystems before entering operational mode. */;
    }
}
