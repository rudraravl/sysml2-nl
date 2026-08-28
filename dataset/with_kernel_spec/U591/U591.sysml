package AirPollutionSensingUnit {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Time::*;

    attribute def MassConcentrationValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def HumidityValue :> Real;
    attribute def PressureValue :> Real;
    attribute def AQIValue :> Integer;
    attribute def VoltageValue :> Real;

    attribute def StartCycle;
    attribute def WarmUpComplete;
    attribute def MeasurementComplete;
    attribute def ErrorDetected;
    attribute def ResetSignal;

    item def AirSample;
    item def RawData {
        attribute pm25 : MassConcentrationValue;
        attribute pm10 : MassConcentrationValue;
        attribute co : MassConcentrationValue;
        attribute no2 : MassConcentrationValue;
        attribute o3 : MassConcentrationValue;
        attribute so2 : MassConcentrationValue;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute pressure : PressureValue;
    }
    item def CleanedData {
        attribute pm25 : MassConcentrationValue;
        attribute pm10 : MassConcentrationValue;
        attribute co : MassConcentrationValue;
        attribute no2 : MassConcentrationValue;
        attribute o3 : MassConcentrationValue;
        attribute so2 : MassConcentrationValue;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute pressure : PressureValue;
    }
    item def CalibratedData {
        attribute pm25 : MassConcentrationValue;
        attribute pm10 : MassConcentrationValue;
        attribute co : MassConcentrationValue;
        attribute no2 : MassConcentrationValue;
        attribute o3 : MassConcentrationValue;
        attribute so2 : MassConcentrationValue;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute pressure : PressureValue;
    }
    item def CalibrationFactors {
        attribute factorPM25 : Real;
        attribute factorPM10 : Real;
        attribute factorCO : Real;
        attribute factorNO2 : Real;
        attribute factorO3 : Real;
        attribute factorSO2 : Real;
    }
    item def MeasurementPackage {
        attribute aqi : AQIValue;
        attribute pm25 : MassConcentrationValue;
        attribute pm10 : MassConcentrationValue;
        attribute co : MassConcentrationValue;
        attribute no2 : MassConcentrationValue;
        attribute o3 : MassConcentrationValue;
        attribute so2 : MassConcentrationValue;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute pressure : PressureValue;
        attribute timestamp : Time::DateTime;
    }

    port def AirInPort {
        in item air : AirSample;
    }
    port def AirOutPort {
        out item air : AirSample;
    }
    port def PowerInPort {
        in attribute voltage : VoltageValue;
    }
    port def PowerOutPort {
        out attribute voltage : VoltageValue;
    }
    port def DataOutPort {
        out item data : RawData;
    }
    port def DataInPort {
        in item data : RawData;
    }
    port def PackageOutPort {
        out item pkg : MeasurementPackage;
    }
    port def PackageInPort {
        in item pkg : MeasurementPackage;
    }
    port def WirelessDataPort {
        out item packet : MeasurementPackage;
    }

    action def WarmUp;
    action def AcquireRawData {
        out item raw : RawData;
    }
    action def FilterNoise {
        in item raw : RawData;
        out item cleaned : CleanedData;
    }
    action def ApplyCalibration {
        in item cleaned : CleanedData;
        in item factors : CalibrationFactors;
        out item calibrated : CalibratedData;
    }
    action def CalculateAQI {
        in item calibrated : CalibratedData;
        out attribute aqi : AQIValue;
    }
    action def ValidateMeasurement {
        in item calibrated : CalibratedData;
        in attribute aqi : AQIValue;
        out item pkg : MeasurementPackage;
    }
    action def TransmitData {
        in item pkg : MeasurementPackage;
    }

    action def MeasurementCycle {
        action acquireRawData : AcquireRawData;
        action filterNoise : FilterNoise;
        action applyCalibration : ApplyCalibration;
        action calculateAQI : CalculateAQI;
        action validateMeasurement : ValidateMeasurement;
        action transmitData : TransmitData;
        flow acquireRawData.raw to filterNoise.raw;
        flow filterNoise.cleaned to applyCalibration.cleaned;
        flow applyCalibration.calibrated to calculateAQI.calibrated;
        flow applyCalibration.calibrated to validateMeasurement.calibrated;
        flow calculateAQI.aqi to validateMeasurement.aqi;
        flow validateMeasurement.pkg to transmitData.pkg;
    }

    state def OperationalStates;

    part def Enclosure {
        attribute material : String = "UV-resistant plastic";
        attribute weatherproof : Boolean = true;
    }
    part def MountingBracket {
        attribute material : String = "Stainless steel";
    }
    part def HEPAFilter {
        attribute replaceable : Boolean = true;
        port airIn : AirInPort;
        port airOut : AirOutPort;
    }
    part def PM25Sensor {
        attribute technology : String = "Laser-based";
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;
    }
    part def PM10Sensor {
        attribute technology : String = "Laser-based";
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;
    }
    part def COSensor {
        attribute technology : String = "Electrochemical";
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;
    }
    part def NO2Sensor {
        attribute technology : String = "Electrochemical";
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;
    }
    part def O3Sensor {
        attribute technology : String = "Electrochemical";
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;
    }
    part def SO2Sensor {
        attribute technology : String = "Metal-oxide";
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;
    }
    part def TemperatureSensor {
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;
    }
    part def HumiditySensor {
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;
    }
    part def PressureSensor {
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;
    }
    part def SensorArray {
        port airIn : AirInPort;
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;
        part pm25Sensor : PM25Sensor;
        part pm10Sensor : PM10Sensor;
        part coSensor : COSensor;
        part no2Sensor : NO2Sensor;
        part o3Sensor : O3Sensor;
        part so2Sensor : SO2Sensor;
        part tempSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part pressureSensor : PressureSensor;
    }
    part def SignalProcessor {
        port dataIn : DataInPort;
        port packageOut : PackageOutPort;
        port powerIn : PowerInPort;
        ref item calibrationFactors : CalibrationFactors;
    }
    part def PowerManagementUnit {
        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;
    }
    part def LoRaWANTransmitter {
        attribute protocol : String = "LoRaWAN";
        port packageIn : PackageInPort;
        port wirelessOut : WirelessDataPort;
        port powerIn : PowerInPort;
    }

    part def AirPollutionSensingSystem {
        part enclosure : Enclosure;
        part bracket : MountingBracket;
        part hepaFilter : HEPAFilter;
        part sensorArray : SensorArray;
        part signalProcessor : SignalProcessor;
        part powerUnit : PowerManagementUnit;
        part transmitter : LoRaWANTransmitter;

        port airIntake : AirInPort;
        port powerInput : PowerInPort;
        port wirelessDataOut : WirelessDataPort;

        action warmUp : WarmUp;
        action measurementCycle : MeasurementCycle;

        exhibit state operationalStates : OperationalStates {
            entry; then idle;
            state idle;
            transition 'idle-warmingUp'
                first idle
                accept StartCycle
                then warmingUp;
            state warmingUp {
                entry warmUp;
            }
            transition 'warmingUp-measuring'
                first warmingUp
                accept WarmUpComplete
                then measuring;
            state measuring {
                do measurementCycle;
            }
            transition 'measuring-idle'
                first measuring
                accept MeasurementComplete
                then idle;
            transition 'measuring-errorHandling'
                first measuring
                accept ErrorDetected
                then errorHandling;
            state errorHandling;
            transition 'errorHandling-idle'
                first errorHandling
                accept ResetSignal
                then idle;
        }

        connect airIntake to hepaFilter.airIn;
        connect hepaFilter.airOut to sensorArray.airIn;
        connect sensorArray.dataOut to signalProcessor.dataIn;
        connect signalProcessor.packageOut to transmitter.packageIn;
        connect transmitter.wirelessOut to wirelessDataOut;
        connect powerInput to powerUnit.powerIn;
        connect powerUnit.powerOut to sensorArray.powerIn;
        connect powerUnit.powerOut to signalProcessor.powerIn;
        connect powerUnit.powerOut to transmitter.powerIn;
    }

    requirement def EnclosureRequirement {
        subject enclosure : Enclosure;
        doc /* The enclosure shall be durable, weatherproof, and UV-resistant plastic. */
    }
    requirement def MountingRequirement {
        subject bracket : MountingBracket;
        doc /* The unit shall be mountable on a pole using a stainless steel bracket. */
    }
    requirement def AirFilteringRequirement {
        subject hepaFilter : HEPAFilter;
        doc /* The system shall draw ambient air through a replaceable HEPA filter before measurement. */
    }
    requirement def PollutantMeasurementRequirement {
        subject sensorArray : SensorArray;
        doc /* The system shall measure PM2.5, PM10, CO, NO2, O3, and SO2 using laser-based, electrochemical, and metal-oxide sensors. */
    }
    requirement def EnvironmentalMeasurementRequirement {
        subject sensorArray : SensorArray;
        doc /* The system shall measure temperature, humidity, and atmospheric pressure. */
    }
    requirement def MeasurementCycleRequirement {
        subject sensingSystem : AirPollutionSensingSystem;
        doc /* The system shall perform a measurement cycle including raw data acquisition, noise filtering, calibration, AQI calculation, and validation before transmission. */
    }
    requirement def WirelessTransmissionRequirement {
        subject transmitter : LoRaWANTransmitter;
        doc /* The system shall transmit validated measurement packages via LoRaWAN protocol. */
    }
    requirement def PowerManagementRequirement {
        subject powerUnit : PowerManagementUnit;
        doc /* A dedicated power management unit shall regulate incoming voltage for all internal components. */
    }
    requirement def OperationalStatesRequirement {
        subject sensingSystem : AirPollutionSensingSystem;
        doc /* The system shall manage operational states including idle, warming up, measuring, and error handling. */
    }

    part sensingUnit : AirPollutionSensingSystem;

    requirement enclosureReq : EnclosureRequirement {
        subject = sensingUnit.enclosure;
    }
    requirement mountingReq : MountingRequirement {
        subject = sensingUnit.bracket;
    }
    requirement filteringReq : AirFilteringRequirement {
        subject = sensingUnit.hepaFilter;
    }
    requirement pollutantReq : PollutantMeasurementRequirement {
        subject = sensingUnit.sensorArray;
    }
    requirement environmentalReq : EnvironmentalMeasurementRequirement {
        subject = sensingUnit.sensorArray;
    }
    requirement cycleReq : MeasurementCycleRequirement {
        subject = sensingUnit;
    }
    requirement wirelessReq : WirelessTransmissionRequirement {
        subject = sensingUnit.transmitter;
    }
    requirement powerReq : PowerManagementRequirement {
        subject = sensingUnit.powerUnit;
    }
    requirement statesReq : OperationalStatesRequirement {
        subject = sensingUnit;
    }
}
