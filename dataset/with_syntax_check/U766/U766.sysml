package MagnetometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def MagneticFluxDensityValue :> ISQ::MagneticFluxDensityValue {
        attribute :>> num : Real;
        attribute :>> mRef : ISQ::MagneticFluxDensityUnit;
    }
    
    attribute def SamplingRateValue :> ISQ::FrequencyValue {
        attribute :>> num : Real;
        attribute :>> mRef : ISQ::FrequencyUnit;
    }
    
    attribute def VoltageValue :> ISQ::VoltageValue {
        attribute :>> num : Real;
        attribute :>> mRef : ISQ::VoltageUnit;
    }
    
    attribute def CurrentValue :> ISQ::ElectricCurrentValue {
        attribute :>> num : Real;
        attribute :>> mRef : ISQ::ElectricCurrentUnit;
    }
    
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue {
        attribute :>> num : Real;
        attribute :>> mRef : ISQ::ThermodynamicTemperatureUnit;
    }
    
    enum def OperationalState {
        powerOff;
        initializing;
        idle;
        measuring;
        calibrating;
        fault;
    }
    
    enum def MagneticAxis {
        xAxis;
        yAxis;
        zAxis;
    }
    
    item def MagneticFieldVector {
        attribute xComponent : MagneticFluxDensityValue;
        attribute yComponent : MagneticFluxDensityValue;
        attribute zComponent : MagneticFluxDensityValue;
        attribute magnitude : MagneticFluxDensityValue;
        attribute timestamp : TimeInstantValue;
    }
    
    item def CalibrationData {
        attribute offsetX : MagneticFluxDensityValue;
        attribute offsetY : MagneticFluxDensityValue;
        attribute offsetZ : MagneticFluxDensityValue;
        attribute scaleFactorX : Real;
        attribute scaleFactorY : Real;
        attribute scaleFactorZ : Real;
    }
    
    item def PowerSupply;
    item def DigitalData;
    
    port def PowerInputPort {
        in power : PowerSupply;
    }
    
    port def SensorDataPort {
        out fieldVector : MagneticFieldVector;
    }
    
    port def DigitalOutputPort {
        out data : DigitalData;
    }
    
    port def ControlPort {
        in startMeasurement : Boolean;
        in stopMeasurement : Boolean;
        in calibrateCommand : Boolean;
        out currentState : OperationalState;
    }
    
    part def SensingElement {
        attribute sensitivity : MagneticFluxDensityValue;
        attribute measurementRange : MagneticFluxDensityValue;
        attribute noiseLevel : MagneticFluxDensityValue;
        
        port sensorOutput : SensorDataPort;
        
        action def SenseMagneticField {
            out rawFieldVector : MagneticFieldVector;
        }
    }
    
    part def SignalConditioner {
        attribute amplificationGain : Real;
        attribute filterCutoffFrequency : SamplingRateValue;
        
        action def AmplifySignal {
            in rawSignal : MagneticFieldVector;
            out amplifiedSignal : MagneticFieldVector;
        }
        
        action def FilterNoise {
            in noisySignal : MagneticFieldVector;
            out filteredSignal : MagneticFieldVector;
        }
    }
    
    part def AnalogToDigitalConverter {
        attribute resolution : Integer;
        attribute conversionRate : SamplingRateValue;
        
        action def ConvertSignal {
            in analogSignal : MagneticFieldVector;
            out digitalSignal : MagneticFieldVector;
        }
    }
    
    part def DigitalProcessor {
        attribute processingSpeed : SamplingRateValue;
        attribute memoryCapacity : Integer;
        
        action def ApplyCalibration {
            in rawData : MagneticFieldVector;
            in calibration : CalibrationData;
            out calibratedData : MagneticFieldVector;
        }
        
        action def CalculateMagnitude {
            in fieldVector : MagneticFieldVector;
            out magnitude : MagneticFluxDensityValue;
        }
        
        action def PerformCalibration {
            in samples : MagneticFieldVector[*];
            out calibrationParams : CalibrationData;
        }
    }
    
    part def CommunicationInterface {
        attribute dataRate : SamplingRateValue;
        attribute protocol : String;
        
        port digitalOutput : DigitalOutputPort;
        
        action def TransmitData {
            in processedData : MagneticFieldVector;
            out transmittedData : DigitalData;
        }
    }
    
    part def PowerManagementUnit {
        attribute inputVoltage : VoltageValue;
        attribute outputVoltage : VoltageValue;
        attribute currentDraw : CurrentValue;
        
        port powerInput : PowerInputPort;
        
        action def RegulateVoltage {
            in inputPower : PowerSupply;
            out regulatedPower : PowerSupply;
        }
        
        action def MonitorPower {
            out voltage : VoltageValue;
            out current : CurrentValue;
        }
    }
    
    part def TemperatureSensor {
        attribute operatingTemperature : TemperatureValue;
        
        action def MeasureTemperature {
            out temperature : TemperatureValue;
        }
    }
    
    state def MagnetometerStateMachine {
        entry; then powerOff;
        
        state powerOff;
        
        state initializing {
            entry action initializeSystem;
            do action selfTest;
        }
        
        state idle;
        
        state measuring {
            do action continuousMeasurement {
                first start;
                then merge measureLoop;
                then action sense : SensingElement::SenseMagneticField;
                then action condition : SignalConditioner::AmplifySignal {
                    in rawSignal = sense.rawFieldVector;
                }
                then action filter : SignalConditioner::FilterNoise {
                    in noisySignal = condition.amplifiedSignal;
                }
                then action convert : AnalogToDigitalConverter::ConvertSignal {
                    in analogSignal = filter.filteredSignal;
                }
                then action calibrate : DigitalProcessor::ApplyCalibration {
                    in rawData = convert.digitalSignal;
                }
                then action transmit : CommunicationInterface::TransmitData {
                    in processedData = calibrate.calibratedData;
                }
                then measureLoop;
            }
        }
        
        state calibrating {
            do action calibrationSequence {
                action collectSamples;
                then computeOffsets;
                then storeCalibration;
            }
        }
        
        state fault {
            entry action reportFault;
        }
        
        transition powerOn
            first powerOff
            accept powerCommand
            then initializing;
        
        transition initComplete
            first initializing
            then idle;
        
        transition startMeasure
            first idle
            accept startMeasurement
            if startMeasurement == true
            then measuring;
        
        transition stopMeasure
            first measuring
            accept stopMeasurement
            if stopMeasurement == true
            then idle;
        
        transition beginCalibration
            first idle
            accept calibrateCommand
            if calibrateCommand == true
            then calibrating;
        
        transition calibrationComplete
            first calibrating
            then idle;
        
        transition errorDetected
            first measuring
            accept errorCondition
            then fault;
        
        transition resetFromFault
            first fault
            accept resetCommand
            then initializing;
    }
    
    action def MeasureEarthMagneticField {
        in samplingRate : SamplingRateValue;
        in calibrationData : CalibrationData;
        out magneticFieldMeasurement : MagneticFieldVector;
        
        first start;
        then action acquireRawData {
            out rawVector : MagneticFieldVector;
        }
        then action processData {
            in inputVector : MagneticFieldVector = acquireRawData.rawVector;
            in calibration : CalibrationData = calibrationData;
            out processedVector : MagneticFieldVector;
        }
        then action computeMagnitude {
            in fieldData : MagneticFieldVector = processData.processedVector;
            out finalMeasurement : MagneticFieldVector;
        }
        then action outputMeasurement {
            in measurement : MagneticFieldVector = computeMagnitude.finalMeasurement;
        }
        then done;
    }
    
    part def Magnetometer {
        doc /* A three-axis magnetometer system that measures the Earth's magnetic field 
             * vector and provides calibrated digital output for navigation and orientation 
             * applications. */
        
        attribute operationalState : OperationalState = OperationalState::powerOff;
        attribute currentSamplingRate : SamplingRateValue;
        attribute measurementAccuracy : MagneticFluxDensityValue;
        attribute maxMeasurementRange : MagneticFluxDensityValue;
        attribute storedCalibration : CalibrationData;
        
        part sensingElement : SensingElement {
            attribute :>> sensitivity = 0.1 [SI::uT];
            attribute :>> measurementRange = 1600.0 [SI::uT];
            attribute :>> noiseLevel = 0.05 [SI::uT];
        }
        
        part signalConditioner : SignalConditioner {
            attribute :>> amplificationGain = 100.0;
            attribute :>> filterCutoffFrequency = 200.0 [SI::Hz];
        }
        
        part adc : AnalogToDigitalConverter {
            attribute :>> resolution = 16;
            attribute :>> conversionRate = 100.0 [SI::Hz];
        }
        
        part processor : DigitalProcessor {
            attribute :>> processingSpeed = 1000.0 [SI::Hz];
            attribute :>> memoryCapacity = 2048;
        }
        
        part commInterface : CommunicationInterface {
            attribute :>> dataRate = 400.0 [SI::Hz];
            attribute :>> protocol = "I2C";
        }
        
        part powerMgmt : PowerManagementUnit {
            attribute :>> inputVoltage = 5.0 [SI::V];
            attribute :>> outputVoltage = 3.3 [SI::V];
            attribute :>> currentDraw = 2.5 [SI::mA];
        }
        
        part tempSensor : TemperatureSensor {
            attribute :>> operatingTemperature = 298.15 [SI::K];
        }
        
        port powerPort : PowerInputPort;
        port dataPort : DigitalOutputPort;
        port controlPort : ControlPort;
        
        connection sensorToConditioner connect sensingElement.sensorOutput to signalConditioner;
        connection conditionerToADC connect signalConditioner to adc;
        connection adcToProcessor connect adc to processor;
        connection processorToComm connect processor to commInterface.digitalOutput;
        connection powerToSystem connect powerMgmt.powerInput to powerPort;
        
        perform action measureField : MeasureEarthMagneticField {
            in samplingRate = currentSamplingRate;
            in calibrationData = storedCalibration;
            out magneticFieldMeasurement : MagneticFieldVector;
        }
        
        state behavior : MagnetometerStateMachine;
    }
    
    requirement def <'REQ-MAG-001'> PrimaryFunctionRequirement {
        doc /* The magnetometer system shall continuously measure the three-axis 
             * magnetic field vector of the Earth's magnetic field and provide 
             * calibrated digital output for navigation, orientation, and heading 
             * determination applications. */
        subject magnetometer : Magnetometer;
    }
    
    requirement def <'REQ-MAG-002'> MeasurementAccuracyRequirement {
        doc /* The magnetometer shall measure magnetic flux density with an accuracy 
             * of ±0.5 microtesla or better across the full measurement range. */
        subject magnetometer : Magnetometer;
        
        require constraint accuracyConstraint {
            magnetometer.measurementAccuracy.num <= 0.5
        }
    }
    
    requirement def <'REQ-MAG-003'> MeasurementRangeRequirement {
        doc /* The magnetometer shall support a measurement range of at least 
             * ±1600 microtesla on all three axes. */
        subject magnetometer : Magnetometer;
        
        require constraint rangeConstraint {
            magnetometer.maxMeasurementRange.num >= 1600.0
        }
    }
    
    requirement def <'REQ-MAG-004'> SamplingRateRequirement {
        doc /* The magnetometer shall support configurable sampling rates from 
             * 10 Hz to 100 Hz. */
        subject magnetometer : Magnetometer;
        
        require constraint samplingConstraint {
            magnetometer.currentSamplingRate.num >= 10.0 and 
            magnetometer.currentSamplingRate.num <= 100.0
        }
    }
    
    requirement def <'REQ-MAG-005'> CalibrationCapabilityRequirement {
        doc /* The magnetometer shall support field calibration to compensate for 
             * hard iron and soft iron distortions. */
        subject magnetometer : Magnetometer;
    }
    
    requirement def <'REQ-MAG-006'> PowerConsumptionRequirement {
        doc /* The magnetometer shall operate with a maximum current consumption 
             * of 5 mA during active measurement. */
        subject powerMgmt : PowerManagementUnit;
        
        require constraint powerConstraint {
            powerMgmt.currentDraw.num <= 5.0
        }
    }
    
    requirement def <'REQ-MAG-007'> TemperatureStabilityRequirement {
        doc /* The magnetometer shall maintain measurement accuracy across an 
             * operating temperature range of -40°C to +85°C. */
        subject magnetometer : Magnetometer;
    }
    
    part magnetometerSystem : Magnetometer {
        attribute :>> currentSamplingRate = 50.0 [SI::Hz];
        attribute :>> measurementAccuracy = 0.3 [SI::uT];
        attribute :>> maxMeasurementRange = 1600.0 [SI::uT];
    }
    
    satisfy PrimaryFunctionRequirement by magnetometerSystem;
    satisfy MeasurementAccuracyRequirement by magnetometerSystem;
    satisfy MeasurementRangeRequirement by magnetometerSystem;
    satisfy SamplingRateRequirement by magnetometerSystem;
    satisfy CalibrationCapabilityRequirement by magnetometerSystem;
    satisfy PowerConsumptionRequirement by magnetometerSystem.powerMgmt;
    satisfy TemperatureStabilityRequirement by magnetometerSystem;
}
