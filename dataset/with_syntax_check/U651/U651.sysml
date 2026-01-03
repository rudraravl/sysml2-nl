package DigitalSensorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def SensorIdentifier :> ScalarValues::String;
    
    enum def OperationalMode {
        standby;
        active;
        calibration;
        fault;
    }
    
    enum def SignalQuality {
        excellent;
        good;
        marginal;
        unacceptable;
    }
    
    attribute def AnalogInput {
        attribute voltage : ISQ::VoltageValue;
        attribute current : ISQ::ElectricCurrentValue;
    }
    
    attribute def DigitalOutput {
        attribute bitResolution : ScalarValues::Integer;
        attribute numericValue : ScalarValues::Integer;
        attribute timestamp : Time::TimeInstantValue;
    }
    
    attribute def MeasurementData {
        attribute physicalValue : ScalarValues::Real;
        attribute unit : ScalarValues::String;
        attribute quality : SignalQuality;
        attribute sensorID : SensorIdentifier;
        attribute captureTime : Time::TimeInstantValue;
    }
    
    port def AnalogInputPort {
        in analogSignal : AnalogInput;
    }
    
    port def DigitalDataPort {
        out digitalData : DigitalOutput;
    }
    
    port def MeasurementOutputPort {
        out measurement : MeasurementData;
    }
    
    port def CommandPort {
        in controlSignal : ControlCommand;
        out statusResponse : SystemStatus;
    }
    
    attribute def ControlCommand {
        attribute operation : ScalarValues::String;
        attribute targetValue : ScalarValues::Real;
    }
    
    attribute def SystemStatus {
        attribute mode : OperationalMode;
        attribute healthIndicator : ScalarValues::Real;
    }
    
    item def PhysicalSignal {
        attribute amplitude : ISQ::VoltageValue;
        attribute frequency : ISQ::FrequencyValue;
        attribute noiseLevel : ISQ::VoltageValue;
    }
    
    part def SignalConditioner {
        attribute amplificationGain : ScalarValues::Real;
        attribute filterCutoffFreq : ISQ::FrequencyValue;
        
        port analogIn : AnalogInputPort;
        port conditionedOut {
            out signal : AnalogInput;
        }
        
        action conditionSignal {
            in rawSignal : AnalogInput;
            out conditionedSignal : AnalogInput;
            
            first start;
            then action amplify {
                in input : ISQ::VoltageValue = rawSignal.voltage;
                out amplified : ISQ::VoltageValue;
            }
            then action filter {
                in signal : ISQ::VoltageValue = amplify.amplified;
                out filtered : ISQ::VoltageValue;
            }
            then action outputConditioned {
                in voltage : ISQ::VoltageValue = filter.filtered;
                out result : AnalogInput {
                    :>> voltage = voltage;
                }
            }
            then done;
        }
    }
    
    part def AnalogDigitalConverter {
        attribute resolution : ScalarValues::Integer;
        attribute samplingRate : ISQ::FrequencyValue;
        attribute referenceVoltage : ISQ::VoltageValue;
        
        port analogInput : AnalogInputPort;
        port digitalOutput : DigitalDataPort;
        
        action convertToDigital {
            in analogValue : AnalogInput;
            out digitalValue : DigitalOutput;
            
            first start;
            then action sampleAndHold {
                in voltage : ISQ::VoltageValue = analogValue.voltage;
                out sampledVoltage : ISQ::VoltageValue = voltage;
            }
            then action quantize {
                in voltage : ISQ::VoltageValue = sampleAndHold.sampledVoltage;
                in refVoltage : ISQ::VoltageValue = referenceVoltage;
                in bits : ScalarValues::Integer = resolution;
                out quantizedValue : ScalarValues::Integer;
            }
            then action encode {
                in value : ScalarValues::Integer = quantize.quantizedValue;
                out encoded : DigitalOutput {
                    :>> bitResolution = resolution;
                    :>> numericValue = value;
                }
            }
            then done;
        }
    }
    
    part def DataProcessor {
        attribute scalingFactor : ScalarValues::Real;
        attribute offsetCorrection : ScalarValues::Real;
        attribute validRangeMin : ScalarValues::Real;
        attribute validRangeMax : ScalarValues::Real;
        
        port digitalInput {
            in rawData : DigitalOutput;
        }
        
        port processedOutput : MeasurementOutputPort;
        
        action processData {
            in digitalInput : DigitalOutput;
            out processedMeasurement : MeasurementData;
            
            first start;
            then action scaleValue {
                in rawValue : ScalarValues::Integer = digitalInput.numericValue;
                out scaledValue : ScalarValues::Real;
            }
            then action validateRange {
                in value : ScalarValues::Real = scaleValue.scaledValue;
                out isValid : ScalarValues::Boolean;
                out quality : SignalQuality;
            }
            then action applyCompensation {
                in value : ScalarValues::Real = scaleValue.scaledValue;
                out compensated : ScalarValues::Real;
            }
            then action formatOutput {
                in value : ScalarValues::Real = applyCompensation.compensated;
                in quality : SignalQuality = validateRange.quality;
                out result : MeasurementData {
                    :>> physicalValue = value;
                    :>> quality = quality;
                }
            }
            then done;
        }
    }
    
    part def CommunicationInterface {
        attribute protocol : ScalarValues::String;
        attribute dataRate : ScalarValues::Real;
        
        port dataInput {
            in measurement : MeasurementData;
        }
        
        port networkOutput {
            out transmittedData : MeasurementData;
        }
        
        action transmitData {
            in inputMeasurement : MeasurementData;
            out outputMeasurement : MeasurementData;
            
            first start;
            then action formatForProtocol {
                in data : MeasurementData = inputMeasurement;
                out formatted : MeasurementData;
            }
            then action transmit {
                in data : MeasurementData = formatForProtocol.formatted;
                out transmitted : MeasurementData = data;
            }
            then done;
        }
    }
    
    part def DigitalSensorUnit {
        attribute sensorID : SensorIdentifier;
        attribute operatingMode : OperationalMode;
        attribute measurementInterval : ISQ::DurationValue;
        
        port sensorInput : AnalogInputPort;
        port dataOutput : MeasurementOutputPort;
        port control : CommandPort;
        
        part conditioner : SignalConditioner {
            attribute :>> amplificationGain = 10.0;
            attribute :>> filterCutoffFreq = 100.0 [Hz];
        }
        
        part adc : AnalogDigitalConverter {
            attribute :>> resolution = 24;
            attribute :>> samplingRate = 1000.0 [Hz];
            attribute :>> referenceVoltage = 5.0 [V];
        }
        
        part processor : DataProcessor {
            attribute :>> scalingFactor = 0.001;
            attribute :>> offsetCorrection = 0.0;
            attribute :>> validRangeMin = -100.0;
            attribute :>> validRangeMax = 100.0;
        }
        
        part commInterface : CommunicationInterface {
            attribute :>> protocol = "I2C";
            attribute :>> dataRate = 400000.0;
        }
        
        connection inputToConditioner connect sensorInput to conditioner.analogIn;
        connection conditionerToADC connect conditioner.conditionedOut to adc.analogInput;
        connection adcToProcessor connect adc.digitalOutput to processor.digitalInput;
        connection processorToComm connect processor.processedOutput to commInterface.dataInput;
        connection commToOutput connect commInterface.networkOutput to dataOutput;
        
        state operationalStateMachine {
            entry; then standbyState;
            
            state standbyState {
                entry assign operatingMode = OperationalMode::standby;
            }
            
            transition standby_to_calibration
                first standbyState
                accept cmd via control
                if cmd.operation == "CALIBRATE"
                then calibrationState;
            
            transition standby_to_active
                first standbyState
                accept cmd via control
                if cmd.operation == "START"
                then activeState;
            
            state calibrationState {
                entry assign operatingMode = OperationalMode::calibration;
                do action performCalibration {
                    perform processor.processData;
                }
            }
            
            transition calibration_to_active
                first calibrationState
                if performCalibration.done
                then activeState;
            
            state activeState {
                entry assign operatingMode = OperationalMode::active;
                do action acquireAndProcess {
                    perform conditioner.conditionSignal;
                    perform adc.convertToDigital;
                    perform processor.processData;
                    perform commInterface.transmitData;
                }
            }
            
            transition active_to_standby
                first activeState
                accept cmd via control
                if cmd.operation == "STOP"
                then standbyState;
            
            transition any_to_fault
                first activeState
                accept errorSignal
                then faultState;
            
            state faultState {
                entry assign operatingMode = OperationalMode::fault;
            }
            
            transition fault_to_standby
                first faultState
                accept cmd via control
                if cmd.operation == "RESET"
                then standbyState;
        }
        
        action measurementCycle {
            first start;
            then merge continuousMeasurement;
            then action conditionInput {
                perform conditioner.conditionSignal;
            }
            then action digitize {
                perform adc.convertToDigital;
            }
            then action process {
                perform processor.processData;
            }
            then action transmit {
                perform commInterface.transmitData;
            }
            then action waitInterval;
            then continuousMeasurement;
        }
    }
    
    part def SensorNetwork {
        attribute networkID : ScalarValues::String;
        attribute numberOfSensors : ScalarValues::Integer;
        
        part sensors : DigitalSensorUnit[8] {
            attribute :>> measurementInterval = 100.0 [ms];
        }
        
        part dataCollector {
            port inputs : MeasurementOutputPort[8];
            port aggregatedOutput {
                out collectedData : MeasurementData[0..*];
            }
            
            action collectMeasurements {
                in sensorMeasurements : MeasurementData[8];
                out aggregated : MeasurementData[0..*];
                
                first start;
                then action gatherData {
                    in data : MeasurementData[8] = sensorMeasurements;
                    out gathered : MeasurementData[0..*];
                }
                then action timestampAlign {
                    in data : MeasurementData[0..*] = gatherData.gathered;
                    out aligned : MeasurementData[0..*];
                }
                then action qualityCheck {
                    in data : MeasurementData[0..*] = timestampAlign.aligned;
                    out verified : MeasurementData[0..*];
                }
                then done;
            }
        }
        
        connection sensor0ToCollector connect sensors[0].dataOutput to dataCollector.inputs[0];
        connection sensor1ToCollector connect sensors[1].dataOutput to dataCollector.inputs[1];
        connection sensor2ToCollector connect sensors[2].dataOutput to dataCollector.inputs[2];
        connection sensor3ToCollector connect sensors[3].dataOutput to dataCollector.inputs[3];
        connection sensor4ToCollector connect sensors[4].dataOutput to dataCollector.inputs[4];
        connection sensor5ToCollector connect sensors[5].dataOutput to dataCollector.inputs[5];
        connection sensor6ToCollector connect sensors[6].dataOutput to dataCollector.inputs[6];
        connection sensor7ToCollector connect sensors[7].dataOutput to dataCollector.inputs[7];
    }
    
    requirement <'REQ-SYS-001'> primarySystemFunction {
        doc /* The digital sensor system shall continuously acquire analog physical signals,
             * convert them to high-resolution digital representations, process the data
             * to extract meaningful measurements with quality assessment, and transmit
             * the processed information to downstream monitoring and control systems.
             */
        
        subject sensor : DigitalSensorUnit;
        
        require signalAcquisitionReq;
        require conversionAccuracyReq;
        require dataProcessingReq;
        require communicationReq;
    }
    
    requirement <'REQ-SYS-002'> signalAcquisitionReq {
        doc /* The system shall condition input analog signals through amplification
             * and filtering to prepare them for accurate analog-to-digital conversion.
             */
        
        subject conditioner : SignalConditioner;
        
        assert constraint {
            conditioner.amplificationGain >= 1.0 and
            conditioner.filterCutoffFreq > 0.0 [Hz]
        }
    }
    
    requirement <'REQ-SYS-003'> conversionAccuracyReq {
        doc /* The analog-to-digital converter shall provide minimum 16-bit resolution
             * at a sampling rate of at least 100 Hz to ensure measurement fidelity.
             */
        
        subject adc : AnalogDigitalConverter;
        
        assert constraint {
            adc.resolution >= 16 and
            adc.samplingRate >= 100.0 [Hz]
        }
    }
    
    requirement <'REQ-SYS-004'> dataProcessingReq {
        doc /* The data processor shall apply scaling, offset correction, and range
             * validation to produce calibrated measurements with quality indicators.
             */
        
        subject processor : DataProcessor;
        
        assert constraint {
            processor.validRangeMax > processor.validRangeMin
        }
    }
    
    requirement <'REQ-SYS-005'> communicationReq {
        doc /* The communication interface shall transmit processed measurement data
             * using a standard protocol at sufficient data rate for real-time monitoring.
             */
        
        subject commInterface : CommunicationInterface;
        
        assert constraint {
            commInterface.dataRate >= 100000.0
        }
    }
    
    requirement <'REQ-SYS-006'> measurementIntervalReq {
        doc /* The sensor shall complete a full measurement cycle within the specified
             * measurement interval to maintain continuous monitoring capability.
             */
        
        subject sensor : DigitalSensorUnit;
        
        assert constraint {
            sensor.measurementInterval <= 1000.0 [ms]
        }
    }
    
    part digitalSensorSystem : DigitalSensorUnit {
        :>> sensorID = "DSU-PRIMARY-001";
        :>> measurementInterval = 100.0 [ms];
        :>> operatingMode = OperationalMode::standby;
        
        part :>> conditioner {
            :>> amplificationGain = 12.5;
            :>> filterCutoffFreq = 150.0 [Hz];
        }
        
        part :>> adc {
            :>> resolution = 24;
            :>> samplingRate = 1000.0 [Hz];
            :>> referenceVoltage = 5.0 [V];
        }
        
        part :>> processor {
            :>> scalingFactor = 0.00119;
            :>> offsetCorrection = -0.5;
            :>> validRangeMin = -50.0;
            :>> validRangeMax = 150.0;
        }
        
        part :>> commInterface {
            :>> protocol = "I2C";
            :>> dataRate = 400000.0;
        }
        
        perform action continuousOperation : measurementCycle;
    }
    
    satisfy primarySystemFunction by digitalSensorSystem;
    satisfy signalAcquisitionReq by digitalSensorSystem.conditioner;
    satisfy conversionAccuracyReq by digitalSensorSystem.adc;
    satisfy dataProcessingReq by digitalSensorSystem.processor;
    satisfy communicationReq by digitalSensorSystem.commInterface;
    satisfy measurementIntervalReq by digitalSensorSystem;
}
