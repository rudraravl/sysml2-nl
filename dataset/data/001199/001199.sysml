package PositionSensitiveDeviceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Position2D {
        attribute x : LengthValue;
        attribute y : LengthValue;
    }
    
    attribute def PhotocurrentPair {
        attribute currentA : ElectricCurrentValue;
        attribute currentB : ElectricCurrentValue;
    }
    
    attribute def AnalogVoltages {
        attribute vx : ElectricPotentialValue;
        attribute vy : ElectricPotentialValue;
    }
    
    item def LightBeam {
        attribute wavelength : LengthValue;
        attribute power : PowerValue;
        attribute spotSize : LengthValue;
    }
    
    item def PositionData {
        attribute position : Position2D;
        attribute timestamp : TimeValue;
        attribute confidence : Real;
    }
    
    item def SampleTrigger;
    item def TemperatureChange;
    
    port def OpticalInputPort {
        in lightBeam : LightBeam;
    }
    
    port def AnalogSignalPort {
        out voltages : AnalogVoltages;
    }
    
    port def DigitalOutputPort {
        out positionData : PositionData;
    }
    
    port def ControlPort {
        in biasVoltage : ElectricPotentialValue;
        in gainSetting : Real;
    }
    
    part def PhotodetectorArray {
        attribute activeLength : LengthValue;
        attribute activeWidth : LengthValue;
        attribute responsivity : Real;
        
        port opticalInput : OpticalInputPort;
        port analogOutput : AnalogSignalPort;
        
        perform action generatePhotocurrents {
            in incident : LightBeam;
            in length : LengthValue;
            out currents : PhotocurrentPair;
            
            first start;
            then action computeCurrents {
                out ia : ElectricCurrentValue;
                out ib : ElectricCurrentValue;
            }
            then assign currents.currentA := computeCurrents.ia;
            then assign currents.currentB := computeCurrents.ib;
            then done;
        }
    }
    
    part def TransimpedanceAmplifier {
        attribute feedbackResistance : Real;
        attribute bandwidth : FrequencyValue;
        
        port currentInput : ~AnalogSignalPort;
        port voltageOutput : AnalogSignalPort;
        
        perform action convertCurrentToVoltage {
            in inputCurrents : PhotocurrentPair;
            in resistance : Real;
            out outputVoltages : AnalogVoltages;
            
            first start;
            then done;
        }
    }
    
    part def AnalogToDigitalConverter {
        attribute resolution : Real;
        attribute samplingRate : FrequencyValue;
        attribute referenceVoltage : ElectricPotentialValue;
        
        port analogInput : ~AnalogSignalPort;
        port digitalOutput : DigitalOutputPort;
        
        state adcStateMachine {
            entry; then idle;
            
            state idle;
            transition idle_to_sampling
                first idle
                accept at SampleTrigger
                then sampling;
            
            state sampling {
                entry; then acquireSignal;
                
                action acquireSignal {
                    in voltages : AnalogVoltages;
                    out digitalValues : Real[2];
                }
                then converting;
            }
            
            state converting {
                entry; then performConversion;
                
                action performConversion {
                    in digitalValues : Real[2];
                    out convertedData : Real[2];
                }
                then done;
            }
            
            transition converting_to_idle
                first converting
                then idle;
        }
    }
    
    part def PositionCalculator {
        attribute calibrationMatrix : Real[2][2];
        attribute offsetCorrection : Position2D;
        
        port dataInput : ~DigitalOutputPort;
        port positionOutput : DigitalOutputPort;
        
        perform action computePosition {
            in voltageX : ElectricPotentialValue;
            in voltageY : ElectricPotentialValue;
            in sensorLength : LengthValue;
            in sensorWidth : LengthValue;
            out calculatedPosition : PositionData;
            
            first start;
            then action calculateCoordinates {
                out xCoord : LengthValue;
                out yCoord : LengthValue;
            }
            then assign calculatedPosition.position.x := calculateCoordinates.xCoord;
            then assign calculatedPosition.position.y := calculateCoordinates.yCoord;
            then action assessQuality {
                in vx : ElectricPotentialValue;
                in vy : ElectricPotentialValue;
                out qualityScore : Real;
            }
            then assign calculatedPosition.confidence := assessQuality.qualityScore;
            then done;
        }
    }
    
    part def BiasController {
        attribute nominalBias : ElectricPotentialValue;
        attribute temperatureCoefficient : Real;
        
        port controlOutput : ~ControlPort;
        
        state biasStateMachine {
            entry; then initializing;
            
            state initializing {
                entry; then setBias;
                
                action setBias {
                    out biasValue : ElectricPotentialValue;
                }
                then operational;
            }
            
            state operational;
            
            state adjusting {
                entry; then compensateTemperature;
                
                action compensateTemperature {
                    in currentTemp : TemperatureValue;
                    out adjustedBias : ElectricPotentialValue;
                }
                then operational;
            }
            
            transition operational_to_adjusting
                first operational
                accept at TemperatureChange
                then adjusting;
        }
    }
    
    part def PositionSensitiveDevice {
        attribute operatingWavelength : LengthValue;
        attribute maxDetectionRate : FrequencyValue;
        attribute positionAccuracy : LengthValue;
        
        part detector : PhotodetectorArray {
            attribute :>> activeLength = 10.0 [mm];
            attribute :>> activeWidth = 10.0 [mm];
            attribute :>> responsivity = 0.6;
        }
        
        part amplifier : TransimpedanceAmplifier {
            attribute :>> feedbackResistance = 10000.0;
            attribute :>> bandwidth = 100000.0 [Hz];
        }
        
        part adc : AnalogToDigitalConverter {
            attribute :>> resolution = 16.0;
            attribute :>> samplingRate = 10000.0 [Hz];
            attribute :>> referenceVoltage = 5.0 [V];
        }
        
        part calculator : PositionCalculator;
        
        part biasControl : BiasController {
            attribute :>> nominalBias = 12.0 [V];
            attribute :>> temperatureCoefficient = 0.002;
        }
        
        port opticalInput : OpticalInputPort;
        port positionOutput : DigitalOutputPort;
        port systemControl : ControlPort;
        
        connection detectorToAmplifier connect 
            detector.analogOutput to amplifier.currentInput;
        
        connection amplifierToADC connect 
            amplifier.voltageOutput to adc.analogInput;
        
        connection adcToCalculator connect 
            adc.digitalOutput to calculator.dataInput;
        
        connection calculatorToOutput connect 
            calculator.positionOutput to positionOutput;
        
        connection biasToDetector connect 
            biasControl.controlOutput to systemControl;
        
        connection inputToDetector connect 
            opticalInput to detector.opticalInput;
        
        perform action measureBeamPosition {
            first start;
            then merge continuousMeasurement;
            
            action detectLight references detector.generatePhotocurrents;
            then action amplifySignal references amplifier.convertCurrentToVoltage;
            then action digitizeSignal {
                perform adc.adcStateMachine;
            }
            then action calculatePosition references calculator.computePosition {
                in sensorLength = detector.activeLength;
                in sensorWidth = detector.activeWidth;
            }
            then continuousMeasurement;
        }
    }
    
    requirement def <'PSD-REQ-001'> PositionAccuracyRequirement {
        doc /* The position sensitive device shall determine the centroid position 
                of an incident light beam with accuracy better than 50 micrometers 
                across the entire active area. */
        
        subject device : PositionSensitiveDevice;
        
        require constraint {
            device.positionAccuracy <= 0.05 [mm]
        }
    }
    
    requirement def <'PSD-REQ-002'> ResponseTimeRequirement {
        doc /* The system shall provide position measurements at a rate of at least 
                1 kHz to enable real-time beam tracking and alignment applications. */
        
        subject device : PositionSensitiveDevice;
        
        require constraint {
            device.maxDetectionRate >= 1000.0 [Hz]
        }
    }
    
    requirement def <'PSD-REQ-003'> LinearityRequirement {
        doc /* The position measurement shall exhibit linearity better than 1% 
                across 90% of the active sensing area. */
        
        subject device : PositionSensitiveDevice;
    }
    
    requirement def <'PSD-REQ-004'> WavelengthRangeRequirement {
        doc /* The device shall operate effectively for incident light wavelengths 
                between 400 nm and 1100 nm, covering visible and near-infrared spectrum. */
        
        subject device : PositionSensitiveDevice;
        
        require constraint {
            device.operatingWavelength >= 400.0 [nm] and 
            device.operatingWavelength <= 1100.0 [nm]
        }
    }
    
    requirement <'PSD-MISSION'> beamPositionDetectionMission {
        doc /* The position sensitive device system shall continuously detect and 
                report the two-dimensional position of incident light beams with high 
                accuracy and speed, enabling applications in laser beam alignment, 
                optical tracking, precision manufacturing quality control, and 
                scientific instrumentation where real-time spatial monitoring of 
                light sources is critical. */
        
        assume constraint environmentalConditions {
            doc /* The device operates in controlled laboratory conditions with 
                    ambient temperature between 15°C and 30°C and minimal 
                    electromagnetic interference. */
        }
        
        require posAccReq : PositionAccuracyRequirement;
        require respTimeReq : ResponseTimeRequirement;
        require linReq : LinearityRequirement;
        require waveReq : WavelengthRangeRequirement;
    }
    
    part psdSystem : PositionSensitiveDevice {
        attribute :>> operatingWavelength = 632.8 [nm];
        attribute :>> maxDetectionRate = 10000.0 [Hz];
        attribute :>> positionAccuracy = 0.025 [mm];
        
        satisfy beamPositionDetectionMission by psdSystem;
    }
}
