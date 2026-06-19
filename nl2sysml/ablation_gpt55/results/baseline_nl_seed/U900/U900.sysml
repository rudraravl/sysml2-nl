package SunSensorSensingUnitModel {

    attribute def Angle_deg {
        attribute value : Real;
        attribute unit : String = "deg";
    }

    attribute def Irradiance_W_per_m2 {
        attribute value : Real;
        attribute unit : String = "W/m^2";
    }

    attribute def Voltage_V {
        attribute value : Real;
        attribute unit : String = "V";
    }

    attribute def Current_mA {
        attribute value : Real;
        attribute unit : String = "mA";
    }

    attribute def Power_W {
        attribute value : Real;
        attribute unit : String = "W";
    }

    attribute def Temperature_degC {
        attribute value : Real;
        attribute unit : String = "degC";
    }

    attribute def Time_s {
        attribute value : Real;
        attribute unit : String = "s";
    }

    attribute def DigitalCount {
        attribute value : Real;
        attribute unit : String = "count";
    }

    attribute def Percent {
        attribute value : Real;
        attribute unit : String = "%";
    }

    item def Sunlight {
        attribute irradiance : Irradiance_W_per_m2;
        attribute incidenceAzimuth : Angle_deg;
        attribute incidenceElevation : Angle_deg;
        attribute spectrumName : String;
    }

    item def ElectricalPower {
        attribute voltage : Voltage_V;
        attribute currentLimit : Current_mA;
        attribute availablePower : Power_W;
    }

    item def RegulatedElectricalPower :> ElectricalPower {
        attribute regulationAccuracy : Percent;
    }

    item def RawPhotodiodeSignals {
        attribute quadrantA : Voltage_V;
        attribute quadrantB : Voltage_V;
        attribute quadrantC : Voltage_V;
        attribute quadrantD : Voltage_V;
        attribute commonMode : Voltage_V;
    }

    item def FilteredPhotodiodeSignals {
        attribute quadrantA : Voltage_V;
        attribute quadrantB : Voltage_V;
        attribute quadrantC : Voltage_V;
        attribute quadrantD : Voltage_V;
        attribute noiseRms : Voltage_V;
    }

    item def DigitalPhotodiodeSamples {
        attribute quadrantA : DigitalCount;
        attribute quadrantB : DigitalCount;
        attribute quadrantC : DigitalCount;
        attribute quadrantD : DigitalCount;
        attribute sampleTime : Time_s;
    }

    item def TemperatureReading {
        attribute sensorTemperature : Temperature_degC;
        attribute electronicsTemperature : Temperature_degC;
    }

    item def SensingCommand {
        attribute enableMeasurement : Boolean;
        attribute requestCalibration : Boolean;
        attribute samplePeriod : Time_s;
    }

    item def SunVectorMeasurement {
        attribute azimuth : Angle_deg;
        attribute elevation : Angle_deg;
        attribute azimuthError : Angle_deg;
        attribute elevationError : Angle_deg;
        attribute irradianceEstimate : Irradiance_W_per_m2;
        attribute validity : Boolean;
        attribute measurementTime : Time_s;
    }

    item def SensorHealthStatus {
        attribute powered : Boolean;
        attribute initialized : Boolean;
        attribute saturated : Boolean;
        attribute sunInFieldOfView : Boolean;
        attribute faultPresent : Boolean;
        attribute temperature : Temperature_degC;
    }

    item def PowerOnCommand;
    item def PowerOffCommand;
    item def StartMeasurementCommand;
    item def StopMeasurementCommand;
    item def CalibrationCommand;
    item def FaultDetectedEvent;
    item def FaultClearedEvent;

    port def SunlightInputPort {
        in item light : Sunlight;
    }

    port def SunlightOutputPort {
        out item light : Sunlight;
    }

    port def OpticalInputPort {
        in item light : Sunlight;
    }

    port def OpticalOutputPort {
        out item light : Sunlight;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def RegulatedPowerOutputPort {
        out item power : RegulatedElectricalPower;
    }

    port def RegulatedPowerInputPort {
        in item power : RegulatedElectricalPower;
    }

    port def RawSignalOutputPort {
        out item signals : RawPhotodiodeSignals;
    }

    port def RawSignalInputPort {
        in item signals : RawPhotodiodeSignals;
    }

    port def FilteredSignalOutputPort {
        out item signals : FilteredPhotodiodeSignals;
    }

    port def FilteredSignalInputPort {
        in item signals : FilteredPhotodiodeSignals;
    }

    port def DigitalSampleOutputPort {
        out item samples : DigitalPhotodiodeSamples;
    }

    port def DigitalSampleInputPort {
        in item samples : DigitalPhotodiodeSamples;
    }

    port def TemperatureOutputPort {
        out item temperature : TemperatureReading;
    }

    port def TemperatureInputPort {
        in item temperature : TemperatureReading;
    }

    port def CommandInputPort {
        in item command : SensingCommand;
    }

    port def CommandOutputPort {
        out item command : SensingCommand;
    }

    port def MeasurementOutputPort {
        out item measurement : SunVectorMeasurement;
    }

    port def MeasurementInputPort {
        in item measurement : SunVectorMeasurement;
    }

    port def HealthOutputPort {
        out item status : SensorHealthStatus;
    }

    port def HealthInputPort {
        in item status : SensorHealthStatus;
    }

    part def SunBaffle {
        port lightIn : OpticalInputPort;
        port lightOut : OpticalOutputPort;

        attribute strayLightRejection : Percent {
            :>> value = 98.0;
            :>> unit = "%";
        }

        attribute clearFieldOfView : Angle_deg {
            :>> value = 120.0;
            :>> unit = "deg";
        }
    }

    part def PrecisionAperture {
        port lightIn : OpticalInputPort;
        port lightOut : OpticalOutputPort;

        attribute apertureDiameter : Real;
        attribute apertureDiameterUnit : String = "mm";

        attribute angularMaskHalfAngle : Angle_deg {
            :>> value = 60.0;
            :>> unit = "deg";
        }
    }

    part def OpticalFilter {
        port lightIn : OpticalInputPort;
        port lightOut : OpticalOutputPort;

        attribute visibleBandTransmission : Percent {
            :>> value = 85.0;
            :>> unit = "%";
        }

        attribute infraredRejection : Percent {
            :>> value = 95.0;
            :>> unit = "%";
        }
    }

    part def QuadrantPhotodiodeArray {
        port lightIn : OpticalInputPort;
        port signalOut : RawSignalOutputPort;
        port powerIn : RegulatedPowerInputPort;

        attribute responsivity : Real;
        attribute responsivityUnit : String = "A/W";

        attribute saturationIrradiance : Irradiance_W_per_m2 {
            :>> value = 1500.0;
            :>> unit = "W/m^2";
        }

        attribute measuredQuantity : String = "Sun incidence direction relative to sensor frame";
    }

    part def SunSensorOpticalHead {
        port lightIn : SunlightInputPort;
        port powerIn : RegulatedPowerInputPort;
        port signalOut : RawSignalOutputPort;

        part baffle : SunBaffle;
        part aperture : PrecisionAperture;
        part filter : OpticalFilter;
        part detector : QuadrantPhotodiodeArray;

        attribute fieldOfView : Angle_deg {
            :>> value = 120.0;
            :>> unit = "deg";
        }

        attribute sensingPrinciple : String = "quadrant photodiode Sun sensor";

        connect lightIn to baffle.lightIn;
        connect baffle.lightOut to aperture.lightIn;
        connect aperture.lightOut to filter.lightIn;
        connect filter.lightOut to detector.lightIn;
        connect powerIn to detector.powerIn;
        connect detector.signalOut to signalOut;
    }

    part def AnalogFrontEnd {
        port signalIn : RawSignalInputPort;
        port signalOut : FilteredSignalOutputPort;
        port powerIn : RegulatedPowerInputPort;

        attribute transimpedanceGain : Real;
        attribute transimpedanceGainUnit : String = "V/A";

        attribute lowPassCutoffFrequency : Real;
        attribute lowPassCutoffFrequencyUnit : String = "Hz";

        attribute inputNoise : Voltage_V {
            :>> value = 0.002;
            :>> unit = "V";
        }
    }

    part def AnalogToDigitalConverter {
        port signalIn : FilteredSignalInputPort;
        port samplesOut : DigitalSampleOutputPort;
        port powerIn : RegulatedPowerInputPort;

        attribute resolutionBits : Real;
        attribute samplingPeriod : Time_s {
            :>> value = 0.05;
            :>> unit = "s";
        }

        attribute referenceVoltage : Voltage_V {
            :>> value = 3.3;
            :>> unit = "V";
        }
    }

    part def PowerRegulator {
        port powerIn : PowerInputPort;
        port powerOut : RegulatedPowerOutputPort;

        attribute outputVoltage : Voltage_V {
            :>> value = 3.3;
            :>> unit = "V";
        }

        attribute maximumOutputCurrent : Current_mA {
            :>> value = 250.0;
            :>> unit = "mA";
        }

        attribute conversionEfficiency : Percent {
            :>> value = 88.0;
            :>> unit = "%";
        }
    }

    part def ThermalMonitor {
        port powerIn : RegulatedPowerInputPort;
        port temperatureOut : TemperatureOutputPort;

        attribute lowOperatingTemperature : Temperature_degC {
            :>> value = -40.0;
            :>> unit = "degC";
        }

        attribute highOperatingTemperature : Temperature_degC {
            :>> value = 85.0;
            :>> unit = "degC";
        }
    }

    part def MeasurementProcessor {
        port commandIn : CommandInputPort;
        port samplesIn : DigitalSampleInputPort;
        port temperatureIn : TemperatureInputPort;
        port powerIn : RegulatedPowerInputPort;
        port measurementOut : MeasurementOutputPort;
        port healthOut : HealthOutputPort;

        attribute algorithmName : String = "normalized quadrant centroid Sun vector estimator";

        attribute maximumAzimuthError : Angle_deg {
            :>> value = 0.5;
            :>> unit = "deg";
        }

        attribute maximumElevationError : Angle_deg {
            :>> value = 0.5;
            :>> unit = "deg";
        }

        attribute maximumLatency : Time_s {
            :>> value = 0.10;
            :>> unit = "s";
        }

        attribute minimumValidIrradiance : Irradiance_W_per_m2 {
            :>> value = 100.0;
            :>> unit = "W/m^2";
        }

        attribute maximumValidIrradiance : Irradiance_W_per_m2 {
            :>> value = 1400.0;
            :>> unit = "W/m^2";
        }
    }

    action def RegulateInputPower {
        in item inputPower : ElectricalPower;
        out item regulatedPower : RegulatedElectricalPower;
    }

    action def SenseSunlightWithQuadrantPhotodiodes {
        in item light : Sunlight;
        in item regulatedPower : RegulatedElectricalPower;
        out item rawSignals : RawPhotodiodeSignals;
    }

    action def FilterPhotodiodeSignals {
        in item rawSignals : RawPhotodiodeSignals;
        out item filteredSignals : FilteredPhotodiodeSignals;
    }

    action def DigitizeFilteredSignals {
        in item filteredSignals : FilteredPhotodiodeSignals;
        out item samples : DigitalPhotodiodeSamples;
    }

    action def EstimateSunVector {
        in item samples : DigitalPhotodiodeSamples;
        in item temperature : TemperatureReading;
        in item command : SensingCommand;
        out item measurement : SunVectorMeasurement;
        out item status : SensorHealthStatus;
    }

    action def AcquireSunDirectionMeasurement {
        in item inputPower : ElectricalPower;
        in item incidentSunlight : Sunlight;
        in item command : SensingCommand;
        in item temperature : TemperatureReading;
        out item measurement : SunVectorMeasurement;
        out item status : SensorHealthStatus;

        action regulate : RegulateInputPower;
        action sense : SenseSunlightWithQuadrantPhotodiodes;
        action filter : FilterPhotodiodeSignals;
        action digitize : DigitizeFilteredSignals;
        action estimate : EstimateSunVector;

        flow inputPower to regulate.inputPower;
        flow regulate.regulatedPower to sense.regulatedPower;
        flow incidentSunlight to sense.light;
        flow sense.rawSignals to filter.rawSignals;
        flow filter.filteredSignals to digitize.filteredSignals;
        flow digitize.samples to estimate.samples;
        flow temperature to estimate.temperature;
        flow command to estimate.command;
        flow estimate.measurement to measurement;
        flow estimate.status to status;
    }

    state def SunSensingUnitOperationalStates {
        state Off;
        state Initializing;
        state Standby;
        state Measuring;
        state Calibrating;
        state Faulted;

        transition initialState first Off;
        transition powerOn first Off accept PowerOnCommand then Initializing;
        transition initializationComplete first Initializing then Standby;
        transition startMeasuring first Standby accept StartMeasurementCommand then Measuring;
        transition stopMeasuring first Measuring accept StopMeasurementCommand then Standby;
        transition startCalibration first Standby accept CalibrationCommand then Calibrating;
        transition finishCalibration first Calibrating then Standby;
        transition measuringFault first Measuring accept FaultDetectedEvent then Faulted;
        transition standbyFault first Standby accept FaultDetectedEvent then Faulted;
        transition clearFault first Faulted accept FaultClearedEvent then Standby;
        transition powerOffFromStandby first Standby accept PowerOffCommand then Off;
        transition powerOffFromFault first Faulted accept PowerOffCommand then Off;
    }

    part def SunSensingUnit {
        port sunlightIn : SunlightInputPort;
        port powerIn : PowerInputPort;
        port commandIn : CommandInputPort;
        port measurementOut : MeasurementOutputPort;
        port healthOut : HealthOutputPort;

        part powerRegulator : PowerRegulator;
        part opticalHead : SunSensorOpticalHead;
        part analogFrontEnd : AnalogFrontEnd;
        part adc : AnalogToDigitalConverter;
        part processor : MeasurementProcessor;
        part thermalMonitor : ThermalMonitor;

        attribute measuredQuantity : String = "Sun direction vector expressed as azimuth and elevation relative to the sensor frame";

        attribute sensorTechnology : String = "Sun sensor using a baffled optical aperture, visible filter, and quadrant photodiode array";

        attribute fieldOfView : Angle_deg {
            :>> value = 120.0;
            :>> unit = "deg";
        }

        attribute maximumAzimuthError : Angle_deg {
            :>> value = 0.5;
            :>> unit = "deg";
        }

        attribute maximumElevationError : Angle_deg {
            :>> value = 0.5;
            :>> unit = "deg";
        }

        attribute measurementUpdatePeriod : Time_s {
            :>> value = 0.10;
            :>> unit = "s";
        }

        attribute minimumOperatingIrradiance : Irradiance_W_per_m2 {
            :>> value = 100.0;
            :>> unit = "W/m^2";
        }

        attribute maximumOperatingIrradiance : Irradiance_W_per_m2 {
            :>> value = 1400.0;
            :>> unit = "W/m^2";
        }

        attribute maximumPowerConsumption : Power_W {
            :>> value = 0.75;
            :>> unit = "W";
        }

        perform action measurementBehavior : AcquireSunDirectionMeasurement;

        exhibit state operationalStates : SunSensingUnitOperationalStates;

        connect powerIn to powerRegulator.powerIn;
        connect powerRegulator.powerOut to opticalHead.powerIn;
        connect powerRegulator.powerOut to analogFrontEnd.powerIn;
        connect powerRegulator.powerOut to adc.powerIn;
        connect powerRegulator.powerOut to processor.powerIn;
        connect powerRegulator.powerOut to thermalMonitor.powerIn;
        connect sunlightIn to opticalHead.lightIn;
        connect opticalHead.signalOut to analogFrontEnd.signalIn;
        connect analogFrontEnd.signalOut to adc.signalIn;
        connect adc.samplesOut to processor.samplesIn;
        connect thermalMonitor.temperatureOut to processor.temperatureIn;
        connect commandIn to processor.commandIn;
        connect processor.measurementOut to measurementOut;
        connect processor.healthOut to healthOut;
    }

    part def SolarEnvironment {
        port sunlightOut : SunlightOutputPort;

        attribute nominalSolarIrradiance : Irradiance_W_per_m2 {
            :>> value = 1361.0;
            :>> unit = "W/m^2";
        }
    }

    part def SpacecraftPowerBus {
        port powerOut : PowerInputPort;

        attribute busVoltage : Voltage_V {
            :>> value = 28.0;
            :>> unit = "V";
        }

        attribute availableCurrent : Current_mA {
            :>> value = 500.0;
            :>> unit = "mA";
        }
    }

    part def FlightComputer {
        port commandOut : CommandOutputPort;
        port measurementIn : MeasurementInputPort;
        port healthIn : HealthInputPort;

        attribute requiredAttitudeUpdatePeriod : Time_s {
            :>> value = 0.20;
            :>> unit = "s";
        }
    }

    part def SunSensingMissionContext {
        part environment : SolarEnvironment;
        part spacecraftPower : SpacecraftPowerBus;
        part flightComputer : FlightComputer;
        part sensingUnit : SunSensingUnit;

        connect environment.sunlightOut to sensingUnit.sunlightIn;
        connect spacecraftPower.powerOut to sensingUnit.powerIn;
        connect flightComputer.commandOut to sensingUnit.commandIn;
        connect sensingUnit.measurementOut to flightComputer.measurementIn;
        connect sensingUnit.healthOut to flightComputer.healthIn;
    }

    requirement def MeasureRelevantQuantityUsingSunSensorRequirement {
        subject unit : SunSensingUnit;

        require constraint {
            unit.measuredQuantity == "Sun direction vector expressed as azimuth and elevation relative to the sensor frame"
        }

        require constraint {
            unit.sensorTechnology == "Sun sensor using a baffled optical aperture, visible filter, and quadrant photodiode array"
        }
    }

    requirement def SunDirectionAccuracyRequirement {
        subject unit : SunSensingUnit;

        require constraint {
            unit.maximumAzimuthError.value <= 0.5
        }

        require constraint {
            unit.maximumElevationError.value <= 0.5
        }
    }

    requirement def SunSensorFieldOfViewRequirement {
        subject unit : SunSensingUnit;

        require constraint {
            unit.fieldOfView.value >= 120.0
        }
    }

    requirement def SunSensorIrradianceRangeRequirement {
        subject unit : SunSensingUnit;

        require constraint {
            unit.minimumOperatingIrradiance.value <= 100.0
        }

        require constraint {
            unit.maximumOperatingIrradiance.value >= 1400.0
        }
    }

    requirement def SunSensorMeasurementRateRequirement {
        subject unit : SunSensingUnit;

        require constraint {
            unit.measurementUpdatePeriod.value <= 0.10
        }
    }

    requirement def SunSensorPowerRequirement {
        subject unit : SunSensingUnit;

        require constraint {
            unit.maximumPowerConsumption.value <= 0.75
        }
    }

    requirement def SunSensingUnitRequirements {
        subject unit : SunSensingUnit;

        require requirement measureRelevantQuantity : MeasureRelevantQuantityUsingSunSensorRequirement {
            subject unit = unit;
        }

        require requirement accuracy : SunDirectionAccuracyRequirement {
            subject unit = unit;
        }

        require requirement fieldOfView : SunSensorFieldOfViewRequirement {
            subject unit = unit;
        }

        require requirement irradianceRange : SunSensorIrradianceRangeRequirement {
            subject unit = unit;
        }

        require requirement measurementRate : SunSensorMeasurementRateRequirement {
            subject unit = unit;
        }

        require requirement power : SunSensorPowerRequirement {
            subject unit = unit;
        }
    }

    part missionContext : SunSensingMissionContext;

    requirement allocatedRequirements : SunSensingUnitRequirements {
        subject unit = missionContext.sensingUnit;
    }
}
