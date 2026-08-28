package SSMIS_Model {
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        private import ScalarValues::Real;
        private import ScalarValues::Integer;
        private import ISQ::*;

        alias TemperatureValue for ISQ::TemperatureValue;
        alias PowerValue for ISQ::PowerValue;
        alias FrequencyValue for ISQ::FrequencyValue;
        alias AngleValue for ScalarValues::Real;
        alias LengthValue for ISQ::LengthValue;

        item def MicrowaveRadiation {
            attribute frequency : FrequencyValue;
            attribute intensity : Real;
        }

        enum def CalibrationReferenceKind {
            hot;
            cold;
        }

        item def CalibrationReference {
            attribute temperature : TemperatureValue;
            attribute referenceType : CalibrationReferenceKind;
        }

        item def RawRadiometerData {
            attribute channelIndex : Integer;
            attribute brightnessTemperature : TemperatureValue;
            attribute scanAngle : AngleValue;
        }

        enum def DataProductKind {
            atmosphericTemperatureProfile;
            atmosphericHumidityProfile;
            oceanSurfaceWindSpeed;
            seaIceConcentration;
            precipitationType;
            precipitationIntensity;
        }

        item def EnvironmentalDataProduct {
            attribute productType : DataProductKind;
            attribute dataValue : Real;
        }

        item def ElectricalPower {
            attribute power : PowerValue;
        }

        item def TemperatureReading {
            attribute temperature : TemperatureValue;
        }

        item def HeaterCommand {
            attribute heaterLevel : Real;
        }

        item def TransmittedSignal {
            attribute dataRate : Real;
            attribute carrierFrequency : FrequencyValue;
        }

        item def GroundCommand;
        item def StandbyCommand :> GroundCommand;
        item def CalibrateCommand :> GroundCommand;
        item def ActiveImagingCommand :> GroundCommand;
        item def DataTransmissionCommand :> GroundCommand;
        item def ShutdownCommand :> GroundCommand;

        port def MicrowaveRadiationPort { out item radiation : MicrowaveRadiation; }
        port def RawRadiometerDataPort { out item rawData : RawRadiometerData; }
        port def CalibrationReferencePort { out item reference : CalibrationReference; }
        port def EnvironmentalDataProductPort { out item dataProduct : EnvironmentalDataProduct; }
        port def PowerPort { out item power : ElectricalPower; }
        port def TemperaturePort { out item temperature : TemperatureReading; }
        port def HeaterCommandPort { out item command : HeaterCommand; }
        port def CommandPort { out item command : GroundCommand; }
        port def TransmittedSignalPort { out item signal : TransmittedSignal; }

        action def ScanAntenna {
            out radiation : MicrowaveRadiation;
        }

        action def MeasureRadiometricData {
            in radiation : MicrowaveRadiation;
            in hotReference : CalibrationReference;
            in coldReference : CalibrationReference;
            out rawData : RawRadiometerData;
        }

        action def ProcessRadiometerData {
            in rawData : RawRadiometerData;
            out dataProducts : EnvironmentalDataProduct;
        }

        action def TransmitDataProducts {
            in dataProducts : EnvironmentalDataProduct;
            out transmittedSignal : TransmittedSignal;
        }

        action def ProvideCalibrationReferences {
            out hotReference : CalibrationReference;
            out coldReference : CalibrationReference;
        }

        action def RegulateTemperature {
            in currentTemperature : TemperatureReading;
            out heaterCommand : HeaterCommand;
        }

        part def SolarArray {
            port outputPort : PowerPort;
        }

        part def Battery {
            port chargePort : ~PowerPort;
            port dischargePort : PowerPort;
        }

        part def PowerManagementUnit {
            port busPowerOutPort : PowerPort;
            part solarArray : SolarArray;
            part battery : Battery;
            flow solarArray.outputPort.power to battery.chargePort.power;
            flow battery.dischargePort.power to busPowerOutPort.power;
        }

        part def ThermalHeater {
            port heaterCommandInPort : ~HeaterCommandPort;
            port powerInPort : ~PowerPort;
        }

        part def ThermalControlSystem {
            port temperatureInPort : ~TemperaturePort;
            port heaterCommandOutPort : HeaterCommandPort;
            perform action regulate : RegulateTemperature {
                in currentTemperature = temperatureInPort.temperature;
                out heaterCommand = heaterCommandOutPort.command;
            }
        }

        part def ConicalScanningAntenna {
            attribute swathWidth : LengthValue = 1707.0 [km];
            attribute scanRate : AngleValue;
            port radiationOutPort : MicrowaveRadiationPort;
            port powerInPort : ~PowerPort;
            port temperatureOutPort : TemperaturePort;
            perform action scan : ScanAntenna {
                out radiation = radiationOutPort.radiation;
            }
        }

        part def MicrowaveRadiometer {
            attribute channelCount : Integer = 24;
            port radiationInPort : ~MicrowaveRadiationPort;
            port hotReferenceInPort : ~CalibrationReferencePort;
            port coldReferenceInPort : ~CalibrationReferencePort;
            port rawDataOutPort : RawRadiometerDataPort;
            port powerInPort : ~PowerPort;
            port temperatureOutPort : TemperaturePort;
            perform action measure : MeasureRadiometricData {
                in radiation = radiationInPort.radiation;
                in hotReference = hotReferenceInPort.reference;
                in coldReference = coldReferenceInPort.reference;
                out rawData = rawDataOutPort.rawData;
            }
        }

        part def SignalProcessor {
            port rawDataInPort : ~RawRadiometerDataPort;
            port dataProductOutPort : EnvironmentalDataProductPort;
            port powerInPort : ~PowerPort;
            port temperatureOutPort : TemperaturePort;
            perform action processData : ProcessRadiometerData {
                in rawData = rawDataInPort.rawData;
                out dataProducts = dataProductOutPort.dataProduct;
            }
        }

        part def DataTransmitter {
            port dataProductInPort : ~EnvironmentalDataProductPort;
            port transmittedOutPort : TransmittedSignalPort;
            port powerInPort : ~PowerPort;
            port temperatureOutPort : TemperaturePort;
            perform action transmit : TransmitDataProducts {
                in dataProducts = dataProductInPort.dataProduct;
                out transmittedSignal = transmittedOutPort.signal;
            }
        }

        part def CalibrationSubsystem {
            port hotReferenceOutPort : CalibrationReferencePort;
            port coldReferenceOutPort : CalibrationReferencePort;
            port powerInPort : ~PowerPort;
            perform action provideReferences : ProvideCalibrationReferences {
                out hotReference = hotReferenceOutPort.reference;
                out coldReference = coldReferenceOutPort.reference;
            }
        }

        part def GroundStation {
            port commandOutPort : CommandPort;
            port dataInPort : ~TransmittedSignalPort;
        }

        part def SSMISInstrument {
            port groundCommandPort : ~CommandPort;
            port dataDownlinkPort : TransmittedSignalPort;

            part antenna : ConicalScanningAntenna;
            part radiometer : MicrowaveRadiometer;
            part signalProcessor : SignalProcessor;
            part dataTransmitter : DataTransmitter;
            part calibrationSubsystem : CalibrationSubsystem;
            part powerManagementUnit : PowerManagementUnit;
            part thermalControlSystem : ThermalControlSystem;
            part thermalHeater : ThermalHeater;

            flow antenna.radiationOutPort.radiation to radiometer.radiationInPort.radiation;
            flow calibrationSubsystem.hotReferenceOutPort.reference to radiometer.hotReferenceInPort.reference;
            flow calibrationSubsystem.coldReferenceOutPort.reference to radiometer.coldReferenceInPort.reference;
            flow radiometer.rawDataOutPort.rawData to signalProcessor.rawDataInPort.rawData;
            flow signalProcessor.dataProductOutPort.dataProduct to dataTransmitter.dataProductInPort.dataProduct;
            flow dataTransmitter.transmittedOutPort.signal to dataDownlinkPort.signal;
            flow powerManagementUnit.busPowerOutPort.power to antenna.powerInPort.power;
            flow powerManagementUnit.busPowerOutPort.power to radiometer.powerInPort.power;
            flow powerManagementUnit.busPowerOutPort.power to signalProcessor.powerInPort.power;
            flow powerManagementUnit.busPowerOutPort.power to dataTransmitter.powerInPort.power;
            flow powerManagementUnit.busPowerOutPort.power to calibrationSubsystem.powerInPort.power;
            flow powerManagementUnit.busPowerOutPort.power to thermalHeater.powerInPort.power;
            flow radiometer.temperatureOutPort.temperature to thermalControlSystem.temperatureInPort.temperature;
            flow thermalControlSystem.heaterCommandOutPort.command to thermalHeater.heaterCommandInPort.command;

            state operatingModes {
                entry; then standby;
                state standby;
                transition standby_to_calibration
                    first standby
                    accept calibrateCommand : CalibrateCommand
                    then calibration;
                transition standby_to_activeImaging
                    first standby
                    accept activeImagingCommand : ActiveImagingCommand
                    then activeImaging;
                state calibration;
                transition calibration_to_activeImaging
                    first calibration
                    accept activeImagingCommand : ActiveImagingCommand
                    then activeImaging;
                transition calibration_to_standby
                    first calibration
                    accept standbyCommand : StandbyCommand
                    then standby;
                state activeImaging;
                transition activeImaging_to_dataTransmission
                    first activeImaging
                    accept dataTransmissionCommand : DataTransmissionCommand
                    then dataTransmission;
                transition activeImaging_to_standby
                    first activeImaging
                    accept standbyCommand : StandbyCommand
                    then standby;
                state dataTransmission;
                transition dataTransmission_to_standby
                    first dataTransmission
                    accept standbyCommand : StandbyCommand
                    then standby;
            }
        }
    }

    package Usages {
        public import Definitions::*;
        part context {
            part ssmis : SSMISInstrument;
            part groundStation : GroundStation;
            flow groundStation.commandOutPort.command to ssmis.groundCommandPort.command;
            flow ssmis.dataDownlinkPort.signal to groundStation.dataInPort.signal;
        }
    }

    package Requirements {
        requirement 'SSMIS-REQ-001' {
            doc "The SSMIS shall passively measure natural microwave radiation emitted and scattered by the Earth across 24 frequency channels.";
        }
        requirement 'SSMIS-REQ-002' {
            doc "The SSMIS shall provide a swath width of 1707 km during conical scanning.";
        }
        requirement 'SSMIS-REQ-003' {
            doc "The SSMIS shall produce environmental data products including atmospheric temperature and humidity profiles, ocean surface wind speed, sea ice concentration, and precipitation type and intensity.";
        }
        requirement 'SSMIS-REQ-004' {
            doc "The SSMIS shall perform on-board calibration using hot and cold temperature references.";
        }
        requirement 'SSMIS-REQ-005' {
            doc "The SSMIS shall operate in standby, calibration, active imaging, and data transmission modes.";
        }
        requirement 'SSMIS-REQ-006' {
            doc "The SSMIS shall maintain all components within their optimal operating temperature range using a thermal control system.";
        }
        requirement 'SSMIS-REQ-007' {
            doc "The SSMIS shall be powered by solar arrays with battery storage managed by a power management unit.";
        }
    }
}
