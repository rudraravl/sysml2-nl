package SSMIS {
    import ScalarValues::*;
    import SI::*;

    // ── Value Types ──────────────────────────────────────────────
    attribute def BrightnessTemperature :> Real { unit 'K'; }
    attribute def FrequencyValue :> Real { unit 'GHz'; }
    attribute def SwathWidthValue :> Real { unit 'km'; }
    attribute def DataRateValue :> Real { unit 'Mbps'; }
    attribute def WindSpeedValue :> Real { unit 'm/s'; }
    attribute def HumidityValue :> Real { unit '%'; }
    attribute def PowerValue :> Real { unit 'W'; }
    attribute def ScanAngleValue :> Real { unit 'deg'; }
    attribute def RotationRateValue :> Real { unit 'rpm'; }
    attribute def TemperatureValue :> Real { unit 'K'; }
    attribute def ConcentrationValue :> Real { unit '%'; }
    attribute def PrecipitationIntensityValue :> Real { unit 'mm/h'; }
    attribute def AltitudeValue :> Real { unit 'km'; }

    // ── Enumerations ──────────────────────────────────────────────
    enum def PrecipitationType {
        none;
        lightRain;
        moderateRain;
        heavyRain;
        snow;
    }

    enum def OperatingMode {
        standby;
        calibration;
        activeImaging;
        dataTransmission;
    }

    enum def GroundCommandType {
        enterStandby;
        beginCalibration;
        beginImaging;
        beginTransmission;
    }

    // ── Item Definitions ─────────────────────────────────────────
    item def MicrowaveRadiation;

    item def RawBrightnessTemperatureData {
        attribute channelBrightnessTemps : BrightnessTemperature[24];
        attribute channelFrequencies : FrequencyValue[24];
        attribute timestamp : String;
    }

    item def AtmosphericTemperatureProfile {
        attribute altitudes : AltitudeValue[*];
        attribute temperatures : TemperatureValue[*];
    }

    item def AtmosphericHumidityProfile {
        attribute altitudes : AltitudeValue[*];
        attribute humidities : HumidityValue[*];
    }

    item def OceanSurfaceWindData {
        attribute windSpeed : WindSpeedValue;
    }

    item def SeaIceConcentrationData {
        attribute concentration : ConcentrationValue;
    }

    item def PrecipitationData {
        attribute precipType : PrecipitationType;
        attribute intensity : PrecipitationIntensityValue;
    }

    item def ProcessedEnvironmentalData {
        attribute temperatureProfile : AtmosphericTemperatureProfile;
        attribute humidityProfile : AtmosphericHumidityProfile;
        attribute oceanWind : OceanSurfaceWindData;
        attribute seaIce : SeaIceConcentrationData;
        attribute precipitation : PrecipitationData;
    }

    item def DownlinkPacket {
        attribute products : ProcessedEnvironmentalData[*];
        attribute timestamp : String;
    }

    item def GroundCommand {
        attribute commandType : GroundCommandType;
    }

    item def CalibrationCycle {
        attribute hotReference : TemperatureValue;
        attribute coldReference : TemperatureValue;
    }

    item def ElectricalPower {
        attribute powerLevel : PowerValue;
    }

    item def ThermalSetpoint {
        attribute targetTemperature : TemperatureValue;
    }

    // ── Port Definitions ─────────────────────────────────────────
    port def MicrowaveOutputPort {
        out MicrowaveRadiation radiation;
    }
    port def MicrowaveInputPort {
        in MicrowaveRadiation radiation;
    }
    port def RawDataOutputPort {
        out RawBrightnessTemperatureData data;
    }
    port def RawDataInputPort {
        in RawBrightnessTemperatureData data;
    }
    port def ProcessedDataOutputPort {
        out ProcessedEnvironmentalData data;
    }
    port def ProcessedDataInputPort {
        in ProcessedEnvironmentalData data;
    }
    port def DownlinkOutputPort {
        out DownlinkPacket data;
    }
    port def CommandInputPort {
        in GroundCommand command;
    }
    port def CalibrationOutputPort {
        out CalibrationCycle calibration;
    }
    port def CalibrationInputPort {
        in CalibrationCycle calibration;
    }
    port def PowerOutputPort {
        out ElectricalPower power;
    }
    port def PowerInputPort {
        in ElectricalPower power;
    }
    port def ThermalOutputPort {
        out ThermalSetpoint setpoint;
    }
    port def ThermalInputPort {
        in ThermalSetpoint setpoint;
    }

    // ── Action Definitions ───────────────────────────────────────
    action def PerformScan;
    action def MeasureBrightnessTemperature;
    action def ProcessRawData;
    action def TransmitToGround;
    action def PerformCalibration;
    action def GeneratePower;
    action def StoreAndDischarge;
    action def DistributePower;
    action def MaintainTemperature;

    // ── Part Definitions ─────────────────────────────────────────
    part def ConicalScanningAntenna {
        attribute rotationRate : RotationRateValue = 18.0;
        attribute scanAngle : ScanAngleValue = 40.0;
        attribute swathWidth : SwathWidthValue = 1707.0;

        port microwaveOut : MicrowaveOutputPort;
        port powerIn : PowerInputPort;
        port thermalIn : ThermalInputPort;

        perform performScan : PerformScan;
    }

    part def MultichannelRadiometer {
        attribute numChannels : Integer = 24;
        attribute channelFrequencies : FrequencyValue[24];

        port microwaveIn : MicrowaveInputPort;
        port calibrationIn : CalibrationInputPort;
        port rawDataOut : RawDataOutputPort;
        port powerIn : PowerInputPort;
        port thermalIn : ThermalInputPort;

        perform measureBrightnessTemperature : MeasureBrightnessTemperature;
    }

    part def OnboardSignalProcessor {
        attribute numAlgorithms : Integer = 5;

        port rawDataIn : RawDataInputPort;
        port processedDataOut : ProcessedDataOutputPort;
        port powerIn : PowerInputPort;
        port thermalIn : ThermalInputPort;

        perform processRawData : ProcessRawData;
    }

    part def DataTransmitter {
        attribute downlinkRate : DataRateValue = 12.0;

        port dataIn : ProcessedDataInputPort;
        port rfDownlink : DownlinkOutputPort;
        port powerIn : PowerInputPort;
        port thermalIn : ThermalInputPort;

        perform transmitToGround : TransmitToGround;
    }

    part def CalibrationSubsystem {
        attribute hotReferenceTemp : TemperatureValue = 300.0;
        attribute coldReferenceTemp : TemperatureValue = 2.73;

        port calibrationOut : CalibrationOutputPort;
        port powerIn : PowerInputPort;
        port thermalIn : ThermalInputPort;

        perform performCalibration : PerformCalibration;
    }

    part def SolarArray {
        attribute outputPower : PowerValue = 250.0;

        port powerOut : PowerOutputPort;

        perform generatePower : GeneratePower;
    }

    part def Battery {
        attribute capacity : PowerValue = 100.0;
        attribute chargeLevel : PowerValue = 80.0;

        port powerOut : PowerOutputPort;
        port powerIn : PowerInputPort;

        perform storeAndDischarge : StoreAndDischarge;
    }

    part def PowerManagementUnit {
        attribute totalDistributedPower : PowerValue = 200.0;

        port solarIn : PowerInputPort;
        port batteryIn : PowerInputPort;
        port powerToAntenna : PowerOutputPort;
        port powerToRadiometer : PowerOutputPort;
        port powerToProcessor : PowerOutputPort;
        port powerToTransmitter : PowerOutputPort;
        port powerToCalibration : PowerOutputPort;
        port powerToThermal : PowerOutputPort;

        perform distributePower : DistributePower;
    }

    part def ThermalControlSystem {
        attribute operatingTempMin : TemperatureValue = 253.15;
        attribute operatingTempMax : TemperatureValue = 313.15;

        port thermalToAntenna : ThermalOutputPort;
        port thermalToRadiometer : ThermalOutputPort;
        port thermalToProcessor : ThermalOutputPort;
        port thermalToTransmitter : ThermalOutputPort;
        port thermalToCalibration : ThermalOutputPort;
        port powerIn : PowerInputPort;

        perform maintainTemperature : MaintainTemperature;
    }

    // ── Top-Level SSMIS Assembly ──────────────────────────────────
    part def SSMIS {
        attribute currentMode : OperatingMode = OperatingMode::standby;

        port commandIn : CommandInputPort;
        port downlinkOut : DownlinkOutputPort;

        part antenna : ConicalScanningAntenna;
        part radiometer : MultichannelRadiometer;
        part processor : OnboardSignalProcessor;
        part transmitter : DataTransmitter;
        part calibration : CalibrationSubsystem;
        part solarArray : SolarArray;
        part battery : Battery;
        part powerManagement : PowerManagementUnit;
        part thermalControl : ThermalControlSystem;

        // Signal and data flow
        connect antenna.microwaveOut to radiometer.microwaveIn;
        connect radiometer.rawDataOut to processor.rawDataIn;
        connect processor.processedDataOut to transmitter.dataIn;
        connect transmitter.rfDownlink to downlinkOut;
        connect calibration.calibrationOut to radiometer.calibrationIn;

        // Power distribution
        connect solarArray.powerOut to powerManagement.solarIn;
        connect battery.powerOut to powerManagement.batteryIn;
        connect powerManagement.powerToAntenna to antenna.powerIn;
        connect powerManagement.powerToRadiometer to radiometer.powerIn;
        connect powerManagement.powerToProcessor to processor.powerIn;
        connect powerManagement.powerToTransmitter to transmitter.powerIn;
        connect powerManagement.powerToCalibration to calibration.powerIn;
        connect powerManagement.powerToThermal to thermalControl.powerIn;

        // Thermal control distribution
        connect thermalControl.thermalToAntenna to antenna.thermalIn;
        connect thermalControl.thermalToRadiometer to radiometer.thermalIn;
        connect thermalControl.thermalToProcessor to processor.thermalIn;
        connect thermalControl.thermalToTransmitter to transmitter.thermalIn;
        connect thermalControl.thermalToCalibration to calibration.thermalIn;

        // ── State Machine ────────────────────────────────────────
        state operatingStates {
            state standby;
            state calibration;
            state activeImaging;
            state dataTransmission;

            transition from standby to calibration
                when [commandIn.command.commandType == GroundCommandType::beginCalibration];
            transition from standby to activeImaging
                when [commandIn.command.commandType == GroundCommandType::beginImaging];
            transition from calibration to activeImaging
                when [commandIn.command.commandType == GroundCommandType::beginImaging];
            transition from calibration to standby
                when [commandIn.command.commandType == GroundCommandType::enterStandby];
            transition from activeImaging to dataTransmission
                when [commandIn.command.commandType == GroundCommandType::beginTransmission];
            transition from activeImaging to standby
                when [commandIn.command.commandType == GroundCommandType::enterStandby];
            transition from activeImaging to calibration
                when [commandIn.command.commandType == GroundCommandType::beginCalibration];
            transition from dataTransmission to standby
                when [commandIn.command.commandType == GroundCommandType::enterStandby];
            transition from dataTransmission to activeImaging
                when [commandIn.command.commandType == GroundCommandType::beginImaging];
        }
    }

    // ── Requirements ─────────────────────────────────────────────
    requirement def SSMISOverallRequirement {
        doc 'The SSMIS shall provide continuous, all-weather environmental monitoring of the Earth using passive microwave measurements.';
        subject ssmis : SSMIS;
    }

    requirement def MultichannelRadiometerRequirement {
        doc 'The radiometer shall detect microwave energy across 24 frequency channels.';
        subject radiometer : MultichannelRadiometer;
        assert radiometer.numChannels == 24;
    }

    requirement def SwathCoverageRequirement {
        doc 'The conical scanning antenna shall observe a 1707 km swath of the Earth surface.';
        subject antenna : ConicalScanningAntenna;
        assert antenna.swathWidth == 1707.0;
    }

    requirement def DataProcessingRequirement {
        doc 'The onboard signal processor shall convert raw brightness temperature measurements into environmental data products including atmospheric temperature and humidity profiles, ocean surface wind speed, sea ice concentration, and precipitation type and intensity.';
        subject processor : OnboardSignalProcessor;
    }

    requirement def DataTransmissionRequirement {
        doc 'The data transmitter shall relay processed environmental data at a high data rate to ground stations.';
        subject transmitter : DataTransmitter;
        assert transmitter.downlinkRate >= 10.0;
    }

    requirement def CalibrationRequirement {
        doc 'The calibration subsystem shall use on-board hot and cold temperature references to calibrate the radiometer.';
        subject calibration : CalibrationSubsystem;
        assert calibration.hotReferenceTemp > calibration.coldReferenceTemp;
    }

    requirement def PowerManagementRequirement {
        doc 'The power management unit shall draw energy from solar arrays and store it in batteries.';
        subject powerManagement : PowerManagementUnit;
        subject solarArray : SolarArray;
        subject battery : Battery;
    }

    requirement def ThermalControlRequirement {
        doc 'The thermal control system shall maintain all components within their optimal operating temperature range.';
        subject thermalControl : ThermalControlSystem;
        assert thermalControl.operatingTempMin < thermalControl.operatingTempMax;
    }

    requirement def OperatingModesRequirement {
        doc 'The SSMIS shall operate in standby, calibration, active imaging, and data transmission modes, transitioning based on ground control commands.';
        subject ssmis : SSMIS;
    }
}
