package Pyranometer {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value def Voltage :> Real { unit 'V'; }
    value def Irradiance :> Real { unit 'W/m^2'; }
    value def Temperature :> Real { unit 'degC'; }
    value def CalibrationFactor :> Real { unit 'V/(W/m^2)'; }
    value def DigitalCount :> Integer;
    value def Frequency :> Real { unit 'Hz'; }
    value def Power :> Real { unit 'W'; }
    value def Duration :> Real { unit 's'; }

    // ===== Item Types =====
    item def SolarRadiation {
        attribute irradiance : Irradiance;
    }
    item def ElectricalSignal {
        attribute voltage : Voltage;
    }
    item def ConditionedSignal {
        attribute voltage : Voltage;
    }
    item def DigitalData {
        attribute rawValue : DigitalCount;
        attribute irradiance : Irradiance;
        attribute temperature : Temperature;
    }
    item def MeasurementRecord {
        attribute timestamp : String;
        attribute irradiance : Irradiance;
        attribute temperature : Temperature;
    }
    item def PowerSupply {
        attribute voltage : Voltage;
        attribute power : Power;
    }

    // ===== Signal Definitions for State Machine Events =====
    item def PowerOnSignal;
    item def MaintenanceRequestedSignal;
    item def MaintenanceCompleteSignal;
    item def ShutdownRequestedSignal;

    // ===== Port Definitions =====
    port def RadiationPort {
        out item radiation : SolarRadiation;
    }
    port def VoltagePort {
        out item signal : ElectricalSignal;
    }
    port def ConditionedSignalPort {
        out item signal : ConditionedSignal;
    }
    port def DigitalDataPort {
        out item data : DigitalData;
    }
    port def MeasurementPort {
        out item record : MeasurementRecord;
    }
    port def PowerPort {
        out item supply : PowerSupply;
    }
    port def TempDataPort {
        out item temp : Temperature;
    }

    // ===== Interface Definitions =====
    interface def RadiationInterface {
        end supplier : RadiationPort;
        end consumer : ~RadiationPort;
    }
    interface def VoltageInterface {
        end supplier : VoltagePort;
        end consumer : ~VoltagePort;
    }
    interface def ConditionedSignalInterface {
        end supplier : ConditionedSignalPort;
        end consumer : ~ConditionedSignalPort;
    }
    interface def DigitalDataInterface {
        end supplier : DigitalDataPort;
        end consumer : ~DigitalDataPort;
    }
    interface def MeasurementInterface {
        end supplier : MeasurementPort;
        end consumer : ~MeasurementPort;
    }
    interface def PowerInterface {
        end supplier : PowerPort;
        end consumer : ~PowerPort;
    }
    interface def TempDataInterface {
        end supplier : TempDataPort;
        end consumer : ~TempDataPort;
    }

    // ===== Action Definitions =====
    action runSelfTest {
        out item status : String;
    }
    action achieveThermalStability {
        in item duration : Duration;
    }
    action loadCalibrationData {
        out item calibrationFactor : CalibrationFactor;
    }
    action continuousMeasurement {
        out item record : MeasurementRecord;
    }
    action performServicing {
        out item status : String;
    }

    // ===== Part Definitions =====

    part def GlassDome {
        attribute transmittance : Real = 0.95;
        attribute spectralRangeMin : Real = 300;
        attribute spectralRangeMax : Real = 2800;
        port radiationIn : ~RadiationPort;
        port radiationOut : RadiationPort;

        action transmitRadiation {
            in item incoming : SolarRadiation;
            out item transmitted : SolarRadiation;
        }
    }

    part def ThermopileSensor {
        attribute sensitivity : CalibrationFactor = 0.00001;
        port radiationIn : ~RadiationPort;
        port voltageOut : VoltagePort;
        port tempIn : ~TempDataPort;
        port powerIn : ~PowerPort;

        action convertRadiationToVoltage {
            in item radiation : SolarRadiation;
            in item temp : Temperature;
            out item voltage : ElectricalSignal;
        }
    }

    part def TemperatureSensor {
        attribute accuracy : Temperature = 0.5;
        attribute range : Temperature = 40;
        port tempOut : TempDataPort;
        port powerIn : ~PowerPort;

        action measureTemperature {
            out item temp : Temperature;
        }
    }

    part def SignalConditioner {
        attribute gain : Real = 100;
        attribute filterCutoff : Frequency = 1;
        port voltageIn : ~VoltagePort;
        port signalOut : ConditionedSignalPort;
        port powerIn : ~PowerPort;

        action amplifyAndFilter {
            in item input : ElectricalSignal;
            out item output : ConditionedSignal;
        }
    }

    part def DataAcquisitionUnit {
        attribute adcResolution : DigitalCount = 16;
        attribute calibrationFactor : CalibrationFactor = 0.00001;
        port signalIn : ~ConditionedSignalPort;
        port tempIn : ~TempDataPort;
        port dataOut : DigitalDataPort;
        port measurementOut : MeasurementPort;
        port powerIn : ~PowerPort;

        action convertAnalogToDigital {
            in item signal : ConditionedSignal;
            out item digitalValue : DigitalCount;
        }

        action applyCalibration {
            in item digitalValue : DigitalCount;
            in item temp : Temperature;
            out item data : DigitalData;
        }

        action calculateIrradiance {
            in item data : DigitalData;
            out item record : MeasurementRecord;
        }
    }

    part def DataStorageModule {
        attribute capacity : Integer = 1000000;
        attribute storedRecords : Integer = 0;
        port dataIn : ~DigitalDataPort;
        port dataOut : DigitalDataPort;
        port powerIn : ~PowerPort;

        action storeRecord {
            in item data : DigitalData;
        }

        action retrieveRecords {
            out item data : DigitalData;
        }
    }

    part def CommunicationInterface {
        attribute protocol : String = "RS-485";
        attribute baudRate : Integer = 9600;
        port measurementIn : ~MeasurementPort;
        port externalOut : MeasurementPort;
        port powerIn : ~PowerPort;

        action transmitData {
            in item record : MeasurementRecord;
            out item transmitted : MeasurementRecord;
        }
    }

    part def PowerManagementUnit {
        attribute inputVoltage : Voltage = 12;
        attribute outputVoltage5V : Voltage = 5;
        attribute outputVoltage3V3 : Voltage = 3.3;
        port powerIn : ~PowerPort;
        port powerOutThermopile : PowerPort;
        port powerOutTempSensor : PowerPort;
        port powerOutSignalCond : PowerPort;
        port powerOutDAQ : PowerPort;
        port powerOutStorage : PowerPort;
        port powerOutComm : PowerPort;

        action distributePower {
            in item input : PowerSupply;
            out item supply5V : PowerSupply;
            out item supply3V3 : PowerSupply;
        }
    }

    // ===== State Machine =====
    state def PyranometerStates {
        entry; then Off;

        state Off;

        transition from Off to SelfTest
            accept PowerOnSignal;

        state SelfTest {
            do runSelfTest;
        }

        transition from SelfTest to WarmUp;

        state WarmUp {
            attribute warmUpDuration : Duration = 60;
            do achieveThermalStability;
        }

        transition from WarmUp to LoadCalibration;

        state LoadCalibration {
            do loadCalibrationData;
        }

        transition from LoadCalibration to Measuring;

        state Measuring {
            do continuousMeasurement;
        }

        transition from Measuring to Maintenance
            accept MaintenanceRequestedSignal;

        transition from Maintenance to Measuring
            accept MaintenanceCompleteSignal;

        state Maintenance {
            do performServicing;
        }

        transition from Measuring to Off
            accept ShutdownRequestedSignal;

        transition from Maintenance to Off
            accept ShutdownRequestedSignal;
    }

    // ===== Main Pyranometer Instrument =====
    part def PyranometerInstrument {
        port externalRadiation : ~RadiationPort;
        port externalComm : MeasurementPort;
        port externalPower : ~PowerPort;

        part dome : GlassDome;
        part thermopile : ThermopileSensor;
        part tempSensor : TemperatureSensor;
        part signalCond : SignalConditioner;
        part daqUnit : DataAcquisitionUnit;
        part storage : DataStorageModule;
        part comm : CommunicationInterface;
        part powerUnit : PowerManagementUnit;

        exhibit PyranometerStates;

        // Radiation path: external -> dome -> thermopile
        connect externalRadiation to dome.radiationIn;
        interface : RadiationInterface connect dome.radiationOut to thermopile.radiationIn;

        // Voltage signal path: thermopile -> signal conditioner
        interface : VoltageInterface connect thermopile.voltageOut to signalCond.voltageIn;

        // Conditioned signal path: signal conditioner -> DAQ
        interface : ConditionedSignalInterface connect signalCond.signalOut to daqUnit.signalIn;

        // Temperature data path: temp sensor -> thermopile and DAQ
        interface : TempDataInterface connect tempSensor.tempOut to thermopile.tempIn;
        interface : TempDataInterface connect tempSensor.tempOut to daqUnit.tempIn;

        // Digital data path: DAQ -> storage
        interface : DigitalDataInterface connect daqUnit.dataOut to storage.dataIn;

        // Measurement path: DAQ -> comm -> external
        interface : MeasurementInterface connect daqUnit.measurementOut to comm.measurementIn;
        connect comm.externalOut to externalComm;

        // Power distribution: external -> power unit -> all components
        connect externalPower to powerUnit.powerIn;
        interface : PowerInterface connect powerUnit.powerOutThermopile to thermopile.powerIn;
        interface : PowerInterface connect powerUnit.powerOutTempSensor to tempSensor.powerIn;
        interface : PowerInterface connect powerUnit.powerOutSignalCond to signalCond.powerIn;
        interface : PowerInterface connect powerUnit.powerOutDAQ to daqUnit.powerIn;
        interface : PowerInterface connect powerUnit.powerOutStorage to storage.powerIn;
        interface : PowerInterface connect powerUnit.powerOutComm to comm.powerIn;
    }

    // ===== Requirements =====
    package Requirements {
        requirement def MeasurementAccuracyRequirement {
            doc /* The pyranometer shall measure solar irradiance with an accuracy of at least 5 W/m^2. */
            attribute requiredAccuracy : Irradiance = 5;
            subject instrument : PyranometerInstrument;
        }

        requirement def SpectralRangeRequirement {
            doc /* The glass dome shall transmit solar radiation in the 300-2800 nm spectral range. */
            attribute minWavelength : Real = 300;
            attribute maxWavelength : Real = 2800;
            subject dome : GlassDome;
        }

        requirement def TemperatureCompensationRequirement {
            doc /* The system shall compensate for temperature-related variations using an internal temperature sensor. */
            subject instrument : PyranometerInstrument;
        }

        requirement def DataStorageRequirement {
            doc /* The instrument shall store at least 1,000,000 measurement records onboard. */
            attribute minCapacity : Integer = 1000000;
            subject storage : DataStorageModule;
        }

        requirement def CommunicationRequirement {
            doc /* The instrument shall provide live readings via a communication interface. */
            subject comm : CommunicationInterface;
        }

        requirement def PowerManagementRequirement {
            doc /* The power management unit shall distribute correct voltage to all electronic components. */
            subject powerUnit : PowerManagementUnit;
        }

        requirement def OperationalLifecycleRequirement {
            doc /* The pyranometer shall follow the lifecycle: power-on self-test, warm-up, calibration load, continuous measurement, maintenance, and shutdown. */
            subject instrument : PyranometerInstrument;
        }

        requirement def ThermopileSensitivityRequirement {
            doc /* The thermopile sensor shall produce a voltage proportional to incident solar irradiance. */
            attribute minSensitivity : CalibrationFactor = 0.000005;
            subject thermopile : ThermopileSensor;
        }

        requirement def SignalConditioningRequirement {
            doc /* The signal conditioner shall amplify and filter the thermopile voltage signal. */
            attribute minGain : Real = 50;
            subject signalCond : SignalConditioner;
        }

        requirement def WarmUpRequirement {
            doc /* The pyranometer shall enter a warm-up period to achieve thermal stability before measurement. */
            attribute maxWarmUpDuration : Duration = 120;
            subject instrument : PyranometerInstrument;
        }
    }

    // ===== Requirement Satisfaction =====
    satisfaction MeasurementAccuracyRequirement by PyranometerInstrument;
    satisfaction SpectralRangeRequirement by GlassDome;
    satisfaction TemperatureCompensationRequirement by PyranometerInstrument;
    satisfaction DataStorageRequirement by DataStorageModule;
    satisfaction CommunicationRequirement by CommunicationInterface;
    satisfaction PowerManagementRequirement by PowerManagementUnit;
    satisfaction OperationalLifecycleRequirement by PyranometerInstrument;
    satisfaction ThermopileSensitivityRequirement by ThermopileSensor;
    satisfaction SignalConditioningRequirement by SignalConditioner;
    satisfaction WarmUpRequirement by PyranometerInstrument;
}
