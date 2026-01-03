package 'AirPollutionSensingUnit' {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;
    private import Time::*;
    private import Quantities::*;
    private import MeasurementReferences::*;

    attribute def ConcentrationValue :> Real;

    attribute def PM2_5_Concentration :> ConcentrationValue;
    attribute def PM10_Concentration :> ConcentrationValue;
    attribute def CO_Concentration :> ConcentrationValue;
    attribute def NO2_Concentration :> ConcentrationValue;
    attribute def O3_Concentration :> ConcentrationValue;
    attribute def SO2_Concentration :> ConcentrationValue;

    attribute def AirQualityIndex :> Real;

    item def AirSample {
        attribute pm2_5: PM2_5_Concentration;
        attribute pm10: PM10_Concentration;
        attribute carbonMonoxide: CO_Concentration;
        attribute nitrogenDioxide: NO2_Concentration;
        attribute ozone: O3_Concentration;
        attribute sulfurDioxide: SO2_Concentration;
        attribute temperature: TemperatureValue;
        attribute relativeHumidity: Real;
        attribute pressure: PressureValue;
        attribute timestamp: TimeInstantValue;
    }

    item def PollutionMeasurement {
        attribute airQualityIndex: AirQualityIndex;
        attribute rawData: AirSample;
        attribute location: String;
        attribute measurementTime: TimeInstantValue;
        attribute isValid: Boolean;
    }

    item def CalibrationData {
        attribute calibrationFactor: Real;
        attribute referenceConcentration: ConcentrationValue;
        attribute calibrationTimestamp: TimeInstantValue;
    }

    port def SensorDataPort {
        out item measurement: PollutionMeasurement;
    }

    port def PowerPort {
        in attribute voltage: Real;
        in attribute current: Real;
    }

    port def CalibrationPort {
        in item calibrationData: CalibrationData;
        out attribute calibrationStatus: Boolean;
    }

    port def AirIntakePort {
        in item airSample: AirSample;
    }

    port def DataReceiverPort {
        in item measurement: PollutionMeasurement;
    }

    connection def DataConnection {
        end source: SensorDataPort[1];
        end sink: DataReceiverPort[1];
    }

    action def SampleAir {
        in item ambientAir: AirSample;
        out item rawSample: AirSample;
    }

    action def FilterNoise {
        in item rawSample: AirSample;
        out item filteredSample: AirSample;
        attribute filterCoefficient: Real = 0.85;
    }

    action def ApplyCalibration {
        in item filteredSample: AirSample;
        in item calibration: CalibrationData;
        out item calibratedSample: AirSample;
    }

    action def ComputeAQI {
        in item sample: AirSample;
        out item aqi: AirQualityIndex;
    }

    action def ValidateMeasurement {
        in item measurement: PollutionMeasurement;
        out item validatedMeasurement: PollutionMeasurement;
        out attribute isValid: Boolean;
    }

    action def TransmitData {
        in item measurement: PollutionMeasurement;
        out item transmittedData: PollutionMeasurement;
    }

    action def PerformMeasurementCycle {
        in item ambientAir: AirSample;
        in item calibration: CalibrationData;
        out item pollutionMeasurement: PollutionMeasurement;

        bind sampleAir.ambientAir = ambientAir;

        action sampleAir: SampleAir {
            in ambientAir;
            out rawSample;
        }

        succession flow from sampleAir.rawSample to filterNoise.rawSample;

        action filterNoise: FilterNoise {
            in rawSample;
            out filteredSample;
        }

        succession flow from filterNoise.filteredSample to applyCalibration.filteredSample;

        action applyCalibration: ApplyCalibration {
            in filteredSample;
            in calibration;
            out calibratedSample;
        }

        succession flow from applyCalibration.calibratedSample to computeAQI.sample;

        action computeAQI: ComputeAQI {
            in sample;
            out aqi;
        }

        succession flow from computeAQI.aqi to assembleMeasurement.aqi;
        succession flow from applyCalibration.calibratedSample to assembleMeasurement.sample;

        action assembleMeasurement {
            in aqi: AirQualityIndex;
            in sample: AirSample;
            out measurement: PollutionMeasurement;
        }

        succession flow from assembleMeasurement.measurement to validateMeasurement.measurement;

        action validateMeasurement: ValidateMeasurement {
            in measurement;
            out validatedMeasurement;
            out isValid;
        }

        bind validateMeasurement.validatedMeasurement = pollutionMeasurement;
    }

    state def SensorOperationalStates {
        entry; then idle;

        state idle;

        transition idle_to_warmup
            first idle
            accept SamplingTrigger
            then warmup;

        state warmup;

        transition warmup_to_measuring
            first warmup
            accept WarmupComplete
            then measuring;

        state measuring {
            entry; then sampling;

            state sampling;
            transition sampling_to_filtering
                first sampling
                accept SamplingComplete
                then filtering;

            state filtering;
            transition filtering_to_calibrating
                first filtering
                accept FilteringComplete
                then calibrating;

            state calibrating;
            transition calibrating_to_computing
                first calibrating
                accept CalibrationComplete
                then computing;

            state computing;
            transition computing_to_validating
                first computing
                accept ComputingComplete
                then validating;

            state validating;
            transition validating_to_transmitting
                first validating
                accept ValidationComplete
                then transmitting;

            state transmitting;
            transition transmitting_done
                first transmitting
                accept TransmissionComplete
                then done;

            exit; then idle;
        }

        transition idle_to_calibration
            first idle
            accept CalibrationRequest
            then calibrationMode;

        state calibrationMode;

        transition calibration_to_idle
            first calibrationMode
            accept CalibrationDone
            then idle;

        transition any_to_error
            first idle
            accept ErrorDetected
            then error;

        state error;

        transition error_to_idle
            first error
            accept ErrorCleared
            then idle;
    }

    part def SensingElement {
        attribute elementType: String;
        attribute sensitivity: Real;
        attribute responseTime: DurationValue;

        port sensingPort {
            in item airSample: AirSample;
            out attribute concentration: ConcentrationValue;
        }
    }

    part def ParticulateMatterSensor :> SensingElement {
        attribute :>> elementType = "Laser Scattering PM Sensor";
        attribute :>> sensitivity = 0.1;
        attribute :>> responseTime = 1.0[s];
        attribute particleSize: LengthValue;
    }

    part def ElectrochemicalGasSensor :> SensingElement {
        attribute :>> elementType = "Electrochemical Cell";
        attribute :>> sensitivity = 0.01;
        attribute :>> responseTime = 30.0[s];
        attribute targetGas: String;
        attribute electrodeType: String;
    }

    part def MetalOxideGasSensor :> SensingElement {
        attribute :>> elementType = "Metal Oxide Semiconductor";
        attribute :>> sensitivity = 0.05;
        attribute :>> responseTime = 60.0[s];
        attribute heatingTemperature: TemperatureValue;
    }

    part def EnvironmentalSensor :> SensingElement {
        attribute :>> elementType = "DHT22";
        attribute :>> sensitivity = 0.1;
        attribute :>> responseTime = 2.0[s];
    }

    part def SignalProcessor {
        attribute processingAlgorithm: String;
        attribute filterType: String;
        attribute cutoffFrequency: FrequencyValue;

        perform action processSignal: FilterNoise;
    }

    part def DataAcquisitionModule {
        attribute samplingRate: FrequencyValue;
        attribute resolution: Real;
        attribute adcBits: Real;

        perform action acquireData: SampleAir;
    }

    part def CommunicationModule {
        attribute protocol: String;
        attribute baudRate: Real;
        attribute transmissionPower: PowerValue;

        port commPort: SensorDataPort;

        perform action transmit: TransmitData;
    }

    part def PowerManagementUnit {
        attribute inputVoltage: Real;
        attribute outputVoltage: Real;
        attribute maxCurrent: Real;
        attribute efficiency: Real;

        port powerOut: PowerPort;
    }

    part def CalibrationModule {
        attribute calibrationInterval: DurationValue;
        attribute lastCalibrationTime: TimeInstantValue;
        attribute calibrationAccuracy: Real;

        port calibrationPort: CalibrationPort;

        perform action calibrate: ApplyCalibration;
    }

    part def AirPollutionSensor {
        attribute sensorID: String;
        attribute deploymentLocation: String;
        attribute sensorStatus: String;
        attribute isOperational: Boolean;
        attribute isCalibrated: Boolean;

        port dataOutput: SensorDataPort;
        port powerInput: PowerPort;
        port calibrationInterface: CalibrationPort;
        port airIntake: AirIntakePort;

        part pm2_5Sensor: ParticulateMatterSensor[1] {
            attribute :>> particleSize = 2.5e-6[m];
        }

        part pm10Sensor: ParticulateMatterSensor[1] {
            attribute :>> particleSize = 10.0e-6[m];
        }

        part coSensor: ElectrochemicalGasSensor[1] {
            attribute :>> targetGas = "CO";
            attribute :>> electrodeType = "Platinum";
        }

        part no2Sensor: ElectrochemicalGasSensor[1] {
            attribute :>> targetGas = "NO2";
            attribute :>> electrodeType = "Gold";
        }

        part o3Sensor: ElectrochemicalGasSensor[1] {
            attribute :>> targetGas = "O3";
            attribute :>> electrodeType = "Silver";
        }

        part so2Sensor: MetalOxideGasSensor[1] {
            attribute :>> targetGas = "SO2";
            attribute :>> heatingTemperature = 573.15[K];
        }

        part environmentalSensor: EnvironmentalSensor[1];

        part dataAcquisition: DataAcquisitionModule[1] {
            attribute :>> samplingRate = 1.0[Hz];
            attribute :>> resolution = 16.0;
            attribute :>> adcBits = 16.0;
        }

        part signalProcessor: SignalProcessor[1] {
            attribute :>> processingAlgorithm = "Kalman Filter";
            attribute :>> filterType = "Low Pass";
            attribute :>> cutoffFrequency = 0.1[Hz];
        }

        part commModule: CommunicationModule[1] {
            attribute :>> protocol = "LoRaWAN";
            attribute :>> baudRate = 115200.0;
            attribute :>> transmissionPower = 0.02[W];
        }

        part powerManagement: PowerManagementUnit[1] {
            attribute :>> inputVoltage = 12.0;
            attribute :>> outputVoltage = 5.0;
            attribute :>> maxCurrent = 2.0;
            attribute :>> efficiency = 0.85;
        }

        part calibrationModule: CalibrationModule[1] {
            attribute :>> calibrationInterval = 2592000.0[s];
            attribute :>> calibrationAccuracy = 0.95;
        }

        connect powerManagement.powerOut to powerInput;
        connect commModule.commPort to dataOutput;
        connect calibrationModule.calibrationPort to calibrationInterface;

        perform action measurePollution: PerformMeasurementCycle;

        exhibit state operationalState: SensorOperationalStates;
    }

    part def Enclosure {
        attribute material: String;
        attribute weatherproofRating: String;
        attribute dimensions: LengthValue[3];
        attribute weight: MassValue;
        attribute color: String;
    }

    part def MountingBracket {
        attribute material: String;
        attribute mountingType: String;
        attribute loadCapacity: MassValue;
    }

    part def AirIntakeFilter {
        attribute filterType: String;
        attribute filterEfficiency: Real;
        attribute replacementInterval: DurationValue;
    }

    part def SensingUnit {
        part sensor: AirPollutionSensor[1];
        part enclosure: Enclosure[1];
        part mountingBracket: MountingBracket[1];
        part intakeFilter: AirIntakeFilter[1];

        connect sensor.airIntake to intakeFilter;
        connect sensor to enclosure;
        connect enclosure to mountingBracket;
    }

    requirement def MeasurementAccuracyRequirement {
        doc /* The sensor shall measure pollutant concentrations with specified accuracy */

        subject sensor: AirPollutionSensor;

        require constraint {
            sensor.pm2_5Sensor.sensitivity <= 1.0
        }

        require constraint {
            sensor.coSensor.sensitivity <= 0.05
        }

        require constraint {
            sensor.no2Sensor.sensitivity <= 0.05
        }
    }

    requirement def ResponseTimeRequirement {
        doc /* The sensor shall provide readings within specified response time */

        subject sensor: AirPollutionSensor;

        require constraint {
            sensor.pm2_5Sensor.responseTime <= 5.0[s]
        }

        require constraint {
            sensor.coSensor.responseTime <= 60.0[s]
        }

        require constraint {
            sensor.o3Sensor.responseTime <= 60.0[s]
        }
    }

    requirement def DataAcquisitionRequirement {
        doc /* The sensor shall acquire data at regular intervals with sufficient resolution */

        subject unit: SensingUnit;

        require constraint {
            unit.sensor.dataAcquisition.samplingRate >= 0.1[Hz]
        }

        require constraint {
            unit.sensor.dataAcquisition.resolution >= 12.0
        }
    }

    requirement def OperationalReliabilityRequirement {
        doc /* The sensor shall operate continuously and maintain calibration */

        subject sensor: AirPollutionSensor;

        require constraint {
            sensor.isOperational == true
        }

        require constraint {
            sensor.isCalibrated == true
        }

        require constraint {
            sensor.calibrationModule.calibrationAccuracy >= 0.90
        }
    }

    requirement def PowerConsumptionRequirement {
        doc /* The sensor shall operate within specified power limits */

        subject sensor: AirPollutionSensor;

        require constraint {
            sensor.powerManagement.maxCurrent <= 3.0
        }

        require constraint {
            sensor.powerManagement.efficiency >= 0.80
        }
    }

    requirement def EnvironmentalProtectionRequirement {
        doc /* The sensing unit shall be protected against environmental conditions */

        subject unit: SensingUnit;

        require constraint {
            unit.enclosure.weatherproofRating == "IP65"
        }
    }

    part sensingUnit: SensingUnit {
        part :>> sensor {
            attribute :>> sensorID = "APS-2024-001";
            attribute :>> deploymentLocation = "Urban Monitoring Station Alpha";
            attribute :>> sensorStatus = "Operational";
            attribute :>> isOperational = true;
            attribute :>> isCalibrated = true;
        }

        part :>> enclosure {
            attribute :>> material = "UV-resistant ABS plastic";
            attribute :>> weatherproofRating = "IP65";
            attribute :>> dimensions = (250.0[mm], 180.0[mm], 120.0[mm]);
            attribute :>> weight = 1.5[kg];
            attribute :>> color = "White";
        }

        part :>> mountingBracket {
            attribute :>> material = "Stainless steel 316";
            attribute :>> mountingType = "Pole mount with U-bolts";
            attribute :>> loadCapacity = 5.0[kg];
        }

        part :>> intakeFilter {
            attribute :>> filterType = "HEPA H13";
            attribute :>> filterEfficiency = 0.995;
            attribute :>> replacementInterval = 7776000.0[s];
        }

        satisfy measurementAccuracy: MeasurementAccuracyRequirement {
            subject actualSensor = sensor;
        }

        satisfy responseTime: ResponseTimeRequirement {
            subject actualSensor = sensor;
        }

        satisfy dataAcquisition: DataAcquisitionRequirement {
            subject actualUnit = sensingUnit;
        }

        satisfy operationalReliability: OperationalReliabilityRequirement {
            subject actualSensor = sensor;
        }

        satisfy powerConsumption: PowerConsumptionRequirement {
            subject actualSensor = sensor;
        }

        satisfy environmentalProtection: EnvironmentalProtectionRequirement {
            subject actualUnit = sensingUnit;
        }
    }
}
