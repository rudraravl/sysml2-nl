package 'Integrated Circuit Piezoelectric Sensing Unit' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def PressureValue :> QuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : PressureUnit;
    }

    attribute def VoltageValue :> QuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : VoltageUnit;
    }

    attribute def ChargeValue :> QuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : ChargeUnit;
    }

    attribute def FrequencyValue :> QuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : FrequencyUnit;
    }

    attribute def PressureUnit :> MeasurementUnit;
    attribute def VoltageUnit :> MeasurementUnit;
    attribute def ChargeUnit :> MeasurementUnit;
    attribute def FrequencyUnit :> MeasurementUnit;

    attribute def SensorCalibration {
        attribute sensitivityCoefficient : Real;
        attribute offsetValue : Real;
        attribute calibrationDate : String;
        attribute isValid : Boolean;
    }

    attribute def SensorStatus {
        attribute operationalState : String;
        attribute faultCode : Integer;
        attribute temperature : Real;
        attribute lastMeasurementTime : String;
    }

    item def MechanicalStimulus {
        attribute appliedPressure : Real;
        attribute frequency : Real;
        attribute duration : Real;
    }

    item def ElectricalCharge {
        attribute magnitude : Real;
        attribute polarity : String;
    }

    item def AnalogSignal {
        attribute voltage : Real;
        attribute bandwidth : Real;
    }

    item def DigitalData {
        attribute value : Integer;
        attribute resolution : Integer;
        attribute timestamp : String;
    }

    item def PressureMeasurement {
        attribute pressure : Real;
        attribute uncertainty : Real;
        attribute quality : String;
    }

    port def MechanicalInputPort {
        in stimulus : MechanicalStimulus;
    }

    port def ChargeOutputPort {
        out charge : ElectricalCharge;
    }

    port def AnalogSignalPort {
        inout signal : AnalogSignal;
    }

    port def DigitalDataPort {
        out data : DigitalData;
    }

    port def MeasurementOutputPort {
        out measurement : PressureMeasurement;
    }

    port def PowerSupplyPort {
        in supplyVoltage : Real;
        in current : Real;
    }

    port def ControlPort {
        in calibrateCommand : Boolean;
        in resetCommand : Boolean;
        out statusResponse : SensorStatus;
    }

    part def PiezoelectricCrystal {
        attribute material : String;
        attribute thickness : Real;
        attribute area : Real;
        attribute piezoelectricConstant : Real;

        port mechanicalInput : ~MechanicalInputPort;
        port chargeOutput : ChargeOutputPort;

        action generateCharge {
            in stimulus : MechanicalStimulus;
            out charge : ElectricalCharge;
        }
    }

    part def ChargeAmplifier {
        attribute gain : Real;
        attribute inputImpedance : Real;
        attribute noiseLevel : Real;

        port chargeInput : ~ChargeOutputPort;
        port voltageOutput : AnalogSignalPort;
        port power : ~PowerSupplyPort;

        action amplifyCharge {
            in charge : ElectricalCharge;
            out voltage : AnalogSignal;
        }
    }

    part def SignalFilter {
        attribute filterType : String;
        attribute cutoffFrequency : Real;
        attribute order : Integer;

        port analogInput : ~AnalogSignalPort;
        port analogOutput : AnalogSignalPort;

        action filterSignal {
            in rawSignal : AnalogSignal;
            out filteredSignal : AnalogSignal;
        }
    }

    part def ADConverter {
        attribute resolution : Integer;
        attribute samplingRate : Real;
        attribute referenceVoltage : Real;
        attribute conversionTime : Real;

        port analogInput : ~AnalogSignalPort;
        port digitalOutput : DigitalDataPort;
        port power : ~PowerSupplyPort;

        action convertToDigital {
            in analogValue : AnalogSignal;
            out digitalValue : DigitalData;
        }
    }

    part def SignalProcessor {
        attribute processorType : String;
        attribute clockSpeed : Real;
        attribute memorySize : Integer;

        port digitalInput : ~DigitalDataPort;
        port measurementOutput : MeasurementOutputPort;
        port controlInterface : ControlPort;
        port power : ~PowerSupplyPort;

        attribute calibration : SensorCalibration;
        attribute status : SensorStatus;

        action processSignal {
            in digitalData : DigitalData;
            out measurement : PressureMeasurement;

            action applyCalibration {
                in rawValue : Integer;
                out calibratedValue : Real;
            }

            then action convertToEngineering {
                in scaledValue : Real;
                out pressureValue : Real;
            }

            then action validateMeasurement {
                in pressure : Real;
                out validatedMeasurement : PressureMeasurement;
            }

            flow from applyCalibration.calibratedValue to convertToEngineering.scaledValue;
            flow from convertToEngineering.pressureValue to validateMeasurement.pressure;
        }

        action performCalibration {
            in calibrationData : SensorCalibration;
            out calibrationStatus : Boolean;
        }

        action performSelfTest {
            out testResult : Boolean;
            out diagnosticCode : Integer;
        }
    }

    part def IntegratedCircuitPiezoelectricSensor {
        attribute sensorID : String;
        attribute packageType : String;
        attribute operatingTempMin : Real;
        attribute operatingTempMax : Real;
        attribute maxPressureRating : Real;

        part crystal : PiezoelectricCrystal[1] {
            attribute :>> material = "Lead Zirconate Titanate";
            attribute :>> thickness = 0.5;
            attribute :>> area = 25.0;
            attribute :>> piezoelectricConstant = 374.0;
        }

        part chargeAmp : ChargeAmplifier[1] {
            attribute :>> gain = 100.0;
            attribute :>> inputImpedance = 1.0e12;
            attribute :>> noiseLevel = 0.001;
        }

        part signalFilter : SignalFilter[1] {
            attribute :>> filterType = "Low-pass Butterworth";
            attribute :>> cutoffFrequency = 10000.0;
            attribute :>> order = 4;
        }

        part adc : ADConverter[1] {
            attribute :>> resolution = 24;
            attribute :>> samplingRate = 100000.0;
            attribute :>> referenceVoltage = 5.0;
            attribute :>> conversionTime = 0.00001;
        }

        part processor : SignalProcessor[1] {
            attribute :>> processorType = "ARM Cortex-M4";
            attribute :>> clockSpeed = 168000000.0;
            attribute :>> memorySize = 524288;
        }

        port mechanicalInterface : ~MechanicalInputPort;
        port dataInterface : MeasurementOutputPort;
        port controlInterface : ControlPort;
        port powerInterface : ~PowerSupplyPort;

        connect mechanicalInterface to crystal.mechanicalInput;
        connect crystal.chargeOutput to chargeAmp.chargeInput;
        connect chargeAmp.voltageOutput to signalFilter.analogInput;
        connect signalFilter.analogOutput to adc.analogInput;
        connect adc.digitalOutput to processor.digitalInput;
        connect processor.measurementOutput to dataInterface;
        connect processor.controlInterface to controlInterface;
        connect chargeAmp.power to powerInterface;
        connect adc.power to powerInterface;
        connect processor.power to powerInterface;
    }

    state def SensorOperatingStates {
        entry; then powerUp;

        state powerUp {
            entry action initializeHardware;
            do action performPowerOnSelfTest;
        }

        transition powerUp_to_initialization
            first powerUp
            then initialization;

        state initialization {
            entry action loadCalibrationData;
            do action configureParameters;
        }

        transition initialization_to_ready
            first initialization
            then ready;

        state ready;

        transition ready_to_measuring
            first ready
            accept measurementRequest
            then measuring;

        state measuring {
            state acquiring {
                do action acquireData;
            }

            state processing {
                do action processData;
            }

            state outputting {
                do action transmitMeasurement;
            }

            transition acquiring_to_processing
                first acquiring
                then processing;

            transition processing_to_outputting
                first processing
                then outputting;
        }

        transition measuring_to_ready
            first measuring
            then ready;

        transition ready_to_calibrating
            first ready
            accept calibrateCommand
            then calibrating;

        state calibrating {
            entry action startCalibration;
            do action executeCalibrationSequence;
        }

        transition calibrating_to_ready
            first calibrating
            then ready;

        transition any_to_fault
            first ready
            accept faultDetected
            then fault;

        state fault {
            entry action logFault;
            do action runDiagnostics;
        }

        transition fault_to_ready
            first fault
            accept resetCommand
            then ready;

        transition any_to_shutdown
            first ready
            accept shutdownCommand
            then shutdown;

        state shutdown {
            entry action saveState;
            do action powerDown;
        }
    }

    action def MeasurePressure {
        in stimulus : MechanicalStimulus;
        out measurement : PressureMeasurement;

        bind generateCharge.stimulus = stimulus;

        action generateCharge : PiezoelectricCrystal::generateCharge {
            in stimulus;
            out charge;
        }

        then action amplifyCharge : ChargeAmplifier::amplifyCharge {
            in charge;
            out voltage;
        }

        flow from generateCharge.charge to amplifyCharge.charge;

        then action filterSignal : SignalFilter::filterSignal {
            in rawSignal;
            out filteredSignal;
        }

        flow from amplifyCharge.voltage to filterSignal.rawSignal;

        then action convertToDigital : ADConverter::convertToDigital {
            in analogValue;
            out digitalValue;
        }

        flow from filterSignal.filteredSignal to convertToDigital.analogValue;

        then action processSignal : SignalProcessor::processSignal {
            in digitalData;
            out measurement;
        }

        flow from convertToDigital.digitalValue to processSignal.digitalData;

        bind measurement = processSignal.measurement;
    }

    part def SensingUnit {
        attribute unitSerialNumber : String;
        attribute manufacturingDate : String;
        attribute firmwareVersion : String;

        part icpSensor : IntegratedCircuitPiezoelectricSensor[1] {
            attribute :>> sensorID = "ICP-2024-001";
            attribute :>> packageType = "Hermetically Sealed TO-5";
            attribute :>> operatingTempMin = -55.0;
            attribute :>> operatingTempMax = 125.0;
            attribute :>> maxPressureRating = 10000000.0;
        }

        port pressureInput : ~MechanicalInputPort;
        port measurementOutput : MeasurementOutputPort;
        port controlInput : ControlPort;
        port powerSupply : ~PowerSupplyPort;

        connect pressureInput to icpSensor.mechanicalInterface;
        connect icpSensor.dataInterface to measurementOutput;
        connect icpSensor.controlInterface to controlInput;
        connect icpSensor.powerInterface to powerSupply;

        perform action measurementOperation : MeasurePressure;

        exhibit state operationalBehavior : SensorOperatingStates;
    }

    requirement def SensingUnitRequirements {
        subject unit : SensingUnit;

        require sensorTechnology {
            doc /* The sensing unit shall use an integrated circuit piezoelectric sensor for pressure measurement. */
            assume unit.icpSensor.crystal.material == "Lead Zirconate Titanate";
        }

        require measurementRange {
            doc /* The sensing unit shall measure pressure from 0 to 10 MPa. */
            assume unit.icpSensor.maxPressureRating >= 10000000.0;
        }

        require measurementAccuracy {
            doc /* The sensing unit shall provide pressure measurements with accuracy better than 0.5% of full scale. */
        }

        require responseTime {
            doc /* The sensing unit shall respond to pressure changes within 100 microseconds. */
            assume unit.icpSensor.adc.conversionTime <= 0.0001;
        }

        require resolution {
            doc /* The sensing unit shall provide measurement resolution of at least 24 bits. */
            assume unit.icpSensor.adc.resolution >= 24;
        }

        require operatingTemperature {
            doc /* The sensing unit shall operate over temperature range of -55°C to +125°C. */
        }

        require powerSupply {
            doc /* The sensing unit shall operate on 5V DC supply with current consumption less than 100 mA. */
        }

        require calibration {
            doc /* The sensing unit shall support field calibration and store calibration data. */
        }

        require selfTest {
            doc /* The sensing unit shall perform power-on self-test and continuous diagnostics. */
        }
    }

    part sensingUnitInstance : SensingUnit {
        attribute :>> unitSerialNumber = "SU-ICP-20240101-001";
        attribute :>> manufacturingDate = "2024-01-01";
        attribute :>> firmwareVersion = "v2.3.1";

        part :>> icpSensor {
            part :>> processor {
                attribute :>> calibration {
                    attribute :>> sensitivityCoefficient = 10.0;
                    attribute :>> offsetValue = 0.0;
                    attribute :>> calibrationDate = "2024-01-01";
                    attribute :>> isValid = true;
                }
                attribute :>> status {
                    attribute :>> operationalState = "Ready";
                    attribute :>> faultCode = 0;
                    attribute :>> temperature = 25.0;
                    attribute :>> lastMeasurementTime = "2024-01-01T00:00:00Z";
                }
            }
        }
    }

    requirement systemRequirements : SensingUnitRequirements {
        subject testUnit :>> unit = sensingUnitInstance;
    }

    verification def AccuracyTest {
        subject unitUnderTest : SensingUnit;

        in testPressure : Real;
        out measuredPressure : Real;
        out error : Real;

        action applyTestPressure {
            in pressure : Real;
            out stimulus : MechanicalStimulus;
        }

        then action performMeasurement : MeasurePressure {
            in stimulus;
            out measurement;
        }

        then action calculateError {
            in expected : Real;
            in actual : Real;
            out errorPercent : Real;
        }

        assert constraint accuracyCheck {
            error <= 0.5
        }
    }

    verification sensingUnitVerification {
        subject unitUnderTest : SensingUnit = sensingUnitInstance;

        objective verifySensorTechnology {
            verify systemRequirements.sensorTechnology;
        }

        objective verifyMeasurementRange {
            verify systemRequirements.measurementRange;
        }

        objective verifyAccuracy {
            verify systemRequirements.measurementAccuracy;
        }

        objective verifyResponseTime {
            verify systemRequirements.responseTime;
        }

        objective verifyResolution {
            verify systemRequirements.resolution;
        }
    }
}
