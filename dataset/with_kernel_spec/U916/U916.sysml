package TideGaugeSystem {
    private import ISQ::*;
    private import ScalarValues::*;

    item def AlarmStatus {
        attribute isFloodRisk : Boolean;
        attribute isLowWaterRisk : Boolean;
    }

    item def TidePrediction {
        attribute nextHighTideTime : TimeValue;
        attribute nextHighTideLevel : LengthValue;
        attribute nextLowTideTime : TimeValue;
        attribute nextLowTideLevel : LengthValue;
    }

    item def DataPacket {
        attribute timestamp : TimeValue;
        attribute waterLevel : LengthValue;
        attribute trendRate : SpeedValue;
        attribute prediction : TidePrediction;
        attribute alarmStatus : AlarmStatus;
    }

    port def PressureOutputPort {
        out pressure : PressureValue;
    }

    port def TemperatureOutputPort {
        out temperature : TemperatureValue;
    }

    port def PressureInputPort {
        in pressure : PressureValue;
    }

    port def TemperatureInputPort {
        in temperature : TemperatureValue;
    }

    port def ProcessedDataOutputPort {
        out waterLevel : LengthValue;
        out trendRate : SpeedValue;
        out prediction : TidePrediction;
        out alarmStatus : AlarmStatus;
    }

    port def ProcessedDataInputPort {
        in waterLevel : LengthValue;
        in trendRate : SpeedValue;
        in prediction : TidePrediction;
        in alarmStatus : AlarmStatus;
    }

    port def TelemetryOutputPort {
        out packet : DataPacket;
    }

    port def TelemetryInputPort {
        in packet : DataPacket;
    }

    port def PowerOutputPort {
        out voltage : ElectricPotentialValue;
        out current : ElectricCurrentValue;
    }

    port def PowerInputPort {
        in voltage : ElectricPotentialValue;
        in current : ElectricCurrentValue;
    }

    action def MeasurePressure {
        out pressure : PressureValue;
    }

    action def MeasureTemperature {
        out temperature : TemperatureValue;
    }

    action def ConvertPressureToLevel {
        in pressure : PressureValue;
        in temperature : TemperatureValue;
        out waterLevel : LengthValue;
    }

    action def CalculateTrend {
        in waterLevelHistory : LengthValue[*];
        out trendRate : SpeedValue;
    }

    action def PredictTides {
        in waterLevelHistory : LengthValue[*];
        out prediction : TidePrediction;
    }

    action def CheckAlarms {
        in currentLevel : LengthValue;
        in currentRate : SpeedValue;
        in floodThreshold : LengthValue;
        in lowWaterThreshold : LengthValue;
        out alarmStatus : AlarmStatus;
    }

    action def TransmitData {
        in packet : DataPacket;
        out success : Boolean;
    }

    action def ManagePower {
        in batteryCharge : EnergyValue;
        in solarInput : PowerValue;
        out outputVoltage : ElectricPotentialValue;
    }

    state def DataAcquisitionStates {
        state Idle;
        state Sampling;
        state Analyzing;
        state Transmitting;

        transition first Idle -> Sampling;
        transition Sampling -> Analyzing;
        transition Analyzing -> Transmitting;
        transition Transmitting -> Idle;
    }

    state def TelemetryStates {
        state Idle;
        state Transmitting;

        transition first Idle -> Transmitting;
        transition Transmitting -> Idle;
    }

    part def PressureTransducer {
        attribute maxPressure : PressureValue;
        attribute accuracy : LengthValue = 0.01 [m];
        port pressureOut : PressureOutputPort;
        perform action measurePressure : MeasurePressure;
    }

    part def TemperatureSensor {
        attribute maxTemperature : TemperatureValue;
        port temperatureOut : TemperatureOutputPort;
        perform action measureTemperature : MeasureTemperature;
    }

    part def SensorPackage {
        part pressureTransducer : PressureTransducer;
        part temperatureSensor : TemperatureSensor;
        port pressureOut : PressureOutputPort;
        port temperatureOut : TemperatureOutputPort;
        port powerIn : PowerInputPort;

        connect pressureTransducer.pressureOut to pressureOut;
        connect temperatureSensor.temperatureOut to temperatureOut;
    }

    part def DataAcquisitionUnit {
        attribute samplingFrequency : FrequencyValue = 1.0 [Hz];
        attribute floodThreshold : LengthValue;
        attribute lowWaterThreshold : LengthValue;
        attribute waterLevelBuffer : LengthValue[*] ordered;

        port pressureIn : PressureInputPort;
        port temperatureIn : TemperatureInputPort;
        port processedDataOut : ProcessedDataOutputPort;
        port powerIn : PowerInputPort;

        perform action convertPressureToLevel : ConvertPressureToLevel;
        perform action calculateTrend : CalculateTrend;
        perform action predictTides : PredictTides;
        perform action checkAlarms : CheckAlarms;

        exhibit state acquisitionStates : DataAcquisitionStates;
    }

    part def TelemetrySystem {
        attribute transmissionInterval : TimeValue = 300 [s];
        port dataIn : ProcessedDataInputPort;
        port transmitOut : TelemetryOutputPort;
        port powerIn : PowerInputPort;

        perform action transmitData : TransmitData;

        exhibit state telemetryStates : TelemetryStates;
    }

    part def Battery {
        attribute capacity : EnergyValue;
        attribute currentCharge : EnergyValue;
    }

    part def SolarPanel {
        attribute maxPower : PowerValue;
    }

    part def PowerManagementUnit {
        part battery : Battery;
        part solarPanel : SolarPanel;
        port powerOut : PowerOutputPort;

        perform action managePower : ManagePower;
    }

    part def MountingStructure {
        attribute material : String = "Marine-Grade Stainless Steel";
        attribute maxDepthRating : LengthValue = 50 [m];
        attribute corrosionResistant : Boolean = true;
    }

    part def RemoteMonitoringStation {
        port dataReceivePort : TelemetryInputPort;
    }

    part def TideGaugeSystem {
        part sensorPackage : SensorPackage;
        part dataAcquisitionUnit : DataAcquisitionUnit;
        part telemetrySystem : TelemetrySystem;
        part powerManagementUnit : PowerManagementUnit;
        part mountingStructure : MountingStructure;

        connect sensorPackage.pressureOut to dataAcquisitionUnit.pressureIn;
        connect sensorPackage.temperatureOut to dataAcquisitionUnit.temperatureIn;
        connect dataAcquisitionUnit.processedDataOut to telemetrySystem.dataIn;
        connect powerManagementUnit.powerOut to sensorPackage.powerIn;
        connect powerManagementUnit.powerOut to dataAcquisitionUnit.powerIn;
        connect powerManagementUnit.powerOut to telemetrySystem.powerIn;
    }

    requirement <TGS-001> measurementAccuracyRequirement {
        doc /* The system shall measure water level with an accuracy of plus or minus 1 cm. */
        subject tideGaugeSystem : TideGaugeSystem;
        attribute requiredAccuracy : LengthValue = 0.01 [m];
    }

    requirement <TGS-002> samplingRateRequirement {
        doc /* The system shall sample sensor data at a minimum frequency of 1 Hz. */
        subject dataAcquisitionUnit : DataAcquisitionUnit;
        attribute minSamplingRate : FrequencyValue = 1.0 [Hz];
    }

    requirement <TGS-003> transmissionIntervalRequirement {
        doc /* The system shall transmit processed data to the remote station every 5 minutes. */
        subject telemetrySystem : TelemetrySystem;
        attribute maxTransmissionInterval : TimeValue = 300 [s];
    }

    requirement <TGS-004> powerAutonomyRequirement {
        doc /* The system shall operate autonomously for at least 30 days without solar input. */
        subject powerManagementUnit : PowerManagementUnit;
        attribute minAutonomy : TimeValue = 30 [d];
    }

    requirement <TGS-005> depthRatingRequirement {
        doc /* The mounting structure shall withstand installation at depths up to 50 meters. */
        subject mountingStructure : MountingStructure;
        attribute requiredDepthRating : LengthValue = 50 [m];
    }

    requirement <TGS-006> alarmConfigurabilityRequirement {
        doc /* The system shall support configurable alarm thresholds for flood and low water conditions. */
        subject dataAcquisitionUnit : DataAcquisitionUnit;
        attribute configurableThresholds : Boolean = true;
    }
}
