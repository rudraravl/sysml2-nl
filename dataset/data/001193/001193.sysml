package PiezometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def PorePressureData {
        attribute pressure :> ISQ::pressure;
        attribute depth :> ISQ::length;
        attribute timestamp :> ISQ::time;
        attribute temperature :> ISQ::temperature;
    }

    item def CalibrationData {
        attribute offset :> ISQ::pressure;
        attribute scaleFactor : Real;
        attribute referenceTemperature :> ISQ::temperature;
    }

    port def FluidInterfacePort {
        in item ambientPressure : ISQ::PressureValue;
        in item ambientTemperature : ISQ::TemperatureValue;
    }

    port def DataTransmissionPort {
        out item pressureReading : PorePressureData;
    }

    port def PowerInputPort {
        in item voltage :> ISQ::voltage;
    }

    port def CalibrationInterfacePort {
        in item calibrationInput : CalibrationData;
        out item calibrationStatus : Boolean;
    }

    part def PressureTransducer {
        port fluidInterface : FluidInterfacePort;
        port powerInput : PowerInputPort;

        attribute sensitivity : Real;
        attribute operatingRange :> ISQ::pressure;

        perform action convertPressure {
            in fluidPressure :> ISQ::pressure;
            in temperature :> ISQ::temperature;
            out electricalSignal :> ISQ::voltage;
        }
    }

    part def SignalConditioner {
        port powerInput : PowerInputPort;

        attribute amplificationGain : Real;
        attribute filterCutoffFrequency :> ISQ::frequency;

        perform action amplifyAndFilter {
            in rawSignal :> ISQ::voltage;
            out conditionedSignal :> ISQ::voltage;
        }
    }

    part def AnalogToDigitalConverter {
        port powerInput : PowerInputPort;

        attribute resolution : Integer;
        attribute samplingRate :> ISQ::frequency;

        perform action digitizeSignal {
            in analogSignal :> ISQ::voltage;
            out digitalValue : Real;
        }
    }

    part def Microprocessor {
        port powerInput : PowerInputPort;
        port calibrationInterface : CalibrationInterfacePort;

        attribute calibrationCoefficients : CalibrationData;

        perform action applyCalibration {
            in rawValue : Real;
            in temperature :> ISQ::temperature;
            out calibratedPressure :> ISQ::pressure;
        }

        perform action formatData {
            in pressure :> ISQ::pressure;
            in depth :> ISQ::length;
            in temperature :> ISQ::temperature;
            out formattedData : PorePressureData;
        }
    }

    part def DataStorage {
        port powerInput : PowerInputPort;

        attribute storageCapacity : Integer;
        attribute storedReadings : PorePressureData[*] := ();

        perform action storeReading {
            in reading : PorePressureData;
            out updatedStorage : PorePressureData[*];
        }
    }

    part def CommunicationModule {
        port powerInput : PowerInputPort;
        port dataOutput : DataTransmissionPort;

        attribute transmissionProtocol : String;
        attribute transmissionInterval :> ISQ::time;

        perform action transmitData {
            in dataToTransmit : PorePressureData;
        }
    }

    part def PowerSupply {
        port powerOutput : PowerInputPort;

        attribute batteryCapacity :> ISQ::energy;
        attribute outputVoltage :> ISQ::voltage;

        perform action supplyPower {
            out voltage :> ISQ::voltage;
        }
    }

    action def MeasurePorePressure {
        first start;
        then merge measurementCycle;

        action senseFluidPressure {
            in ambientPressure :> ISQ::pressure;
            in ambientTemperature :> ISQ::temperature;
            out transducerSignal :> ISQ::voltage;
        }

        then action conditionSignal {
            in rawSignal :> ISQ::voltage;
            out processedSignal :> ISQ::voltage;
        }

        then action convertToDigital {
            in analogInput :> ISQ::voltage;
            out digitalOutput : Real;
        }

        then action calibrateReading {
            in digitalValue : Real;
            in temperature :> ISQ::temperature;
            out calibratedPressure :> ISQ::pressure;
        }

        then action packageData {
            in pressure :> ISQ::pressure;
            in depth :> ISQ::length;
            in temperature :> ISQ::temperature;
            out measurement : PorePressureData;
        }

        then action archiveData {
            in measurement : PorePressureData;
        }

        then action transmitReading {
            in measurement : PorePressureData;
        }

        then decide;
            if continuousMonitoring then measurementCycle;
            if calibrationRequired then performCalibration;

        action performCalibration {
            in calibrationParams : CalibrationData;
            out calibrationComplete : Boolean;
        }

        then measurementCycle;

        attribute continuousMonitoring : Boolean;
        attribute calibrationRequired : Boolean;
    }

    action def PowerManagement;
    action def TransmitStoredData;
    action def CalibrationSequence;
    action def ReducePowerConsumption;

    state def PiezometerOperationalStates {
        entry; then Initialization;

        state Initialization;
        then state Standby;

        state Standby {
            entry; then do PowerManagement;
        }

        state ActiveMeasurement {
            entry; then do MeasurePorePressure;
        }

        state DataTransmission {
            entry; then do TransmitStoredData;
        }

        state Calibration {
            entry; then do CalibrationSequence;
        }

        state LowPower {
            entry; then do ReducePowerConsumption;
        }

        transition initComplete first Initialization then Standby;
        transition startMeasure first Standby then ActiveMeasurement;
        transition measureComplete first ActiveMeasurement then DataTransmission;
        transition transmitComplete first DataTransmission then Standby;
        transition calibrationTrigger first Standby then Calibration;
        transition calibrationDone first Calibration then Standby;
        transition lowBattery first Standby then LowPower;
        transition powerRestored first LowPower then Standby;
    }

    part def Piezometer {
        port fluidInterface : FluidInterfacePort;
        port dataOutput : DataTransmissionPort;
        port calibrationPort : CalibrationInterfacePort;

        part transducer : PressureTransducer {
            port :>> fluidInterface;
        }

        part conditioner : SignalConditioner;

        part adc : AnalogToDigitalConverter;

        part processor : Microprocessor {
            port :>> calibrationPort;
        }

        part storage : DataStorage;

        part communicator : CommunicationModule {
            port :>> dataOutput;
        }

        part power : PowerSupply;

        connection fluidToTransducer connect fluidInterface to transducer.fluidInterface;
        connection powerToTransducer connect power.powerOutput to transducer.powerInput;
        connection powerToConditioner connect power.powerOutput to conditioner.powerInput;
        connection powerToADC connect power.powerOutput to adc.powerInput;
        connection powerToProcessor connect power.powerOutput to processor.powerInput;
        connection powerToStorage connect power.powerOutput to storage.powerInput;
        connection powerToCommunicator connect power.powerOutput to communicator.powerInput;
        connection calibrationToProcessor connect calibrationPort to processor.calibrationInterface;
        connection dataToOutput connect communicator.dataOutput to dataOutput;

        perform action continuousMeasurement[*] ordered references MeasurePorePressure;

        state operationalMode : PiezometerOperationalStates;
    }

    part piezometerSystem : Piezometer {
        perform action measurementOperation : MeasurePorePressure;

        part :>> transducer {
            perform measurementOperation.senseFluidPressure;
        }

        part :>> conditioner {
            perform measurementOperation.conditionSignal;
        }

        part :>> adc {
            perform measurementOperation.convertToDigital;
        }

        part :>> processor {
            perform measurementOperation.calibrateReading;
            perform measurementOperation.packageData;
        }

        part :>> storage {
            perform measurementOperation.archiveData;
        }

        part :>> communicator {
            perform measurementOperation.transmitReading;
        }
    }

    requirement def MeasurementAccuracyRequirement {
        doc /* The piezometer shall measure pore water pressure with accuracy within ±0.25% of full scale. */

        require constraint accuracyConstraint {
            attribute measuredValue :> ISQ::pressure;
            attribute trueValue :> ISQ::pressure;
            attribute fullScale :> ISQ::pressure;
            attribute maxError :> ISQ::pressure = fullScale * 0.0025;

            (measuredValue - trueValue) <= maxError and
            (trueValue - measuredValue) <= maxError
        }
    }

    requirement def OperatingRangeRequirement {
        doc /* The piezometer shall operate continuously within specified pressure and temperature ranges. */

        require constraint pressureRangeConstraint {
            attribute operatingPressure :> ISQ::pressure;
            attribute minPressure :> ISQ::pressure = 0.0 [SI::kPa];
            attribute maxPressure :> ISQ::pressure = 3500.0 [SI::kPa];

            operatingPressure >= minPressure and operatingPressure <= maxPressure
        }

        require constraint temperatureRangeConstraint {
            attribute operatingTemperature :> ISQ::temperature;
            attribute minTemperature :> ISQ::temperature = 253.15 [SI::K];
            attribute maxTemperature :> ISQ::temperature = 353.15 [SI::K];

            operatingTemperature >= minTemperature and operatingTemperature <= maxTemperature
        }
    }

    requirement def DataAcquisitionRequirement {
        doc /* The piezometer shall acquire and store pressure readings at configurable intervals. */

        attribute minimumSamplingRate :> ISQ::frequency = 0.0167 [SI::Hz];
        attribute maximumSamplingRate :> ISQ::frequency = 10.0 [SI::Hz];
    }

    requirement def PowerConsumptionRequirement {
        doc /* The piezometer shall operate on battery power for minimum 12 months under normal conditions. */

        attribute maximumAveragePower :> ISQ::power = 0.005 [SI::W];
        attribute minimumBatteryLife :> ISQ::time = 31536000.0 [SI::s];
    }

    requirement piezometerSystemRequirements {
        doc /* The piezometer system shall continuously monitor and record pore water pressure 
               in saturated soil or rock formations to assess groundwater conditions, 
               structural stability, and hydraulic behavior. */

        subject piezometerSystem;

        require measurementAccuracy : MeasurementAccuracyRequirement;
        require operatingRange : OperatingRangeRequirement;
        require dataAcquisition : DataAcquisitionRequirement;
        require powerConsumption : PowerConsumptionRequirement;
    }
}
