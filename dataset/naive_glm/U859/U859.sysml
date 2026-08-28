package SNOTEL {

    import ScalarValues::*;

    package ValueTypes {
        value type MassDensityValue :> Real { :>> unit 'kg/m^2'; }
        value type LengthValue :> Real { :>> unit 'm'; }
        value type TemperatureValue :> Real { :>> unit 'degC'; }
        value type VoltageValue :> Real { :>> unit 'V'; }
        value type PercentValue :> Real { :>> unit '%'; }
        value type FrequencyValue :> Real { :>> unit 'Hz'; }
        value type DurationValue :> Real { :>> unit 's'; }
        value type PowerValue :> Real { :>> unit 'W'; }
        value type EnergyValue :> Real { :>> unit 'J'; }
        value type IrradianceValue :> Real { :>> unit 'W/m^2'; }
    }

    package Items {
        item def SnowWaterEquivalent {
            attribute value : MassDensityValue;
            attribute timestamp : String;
        }
        item def SnowDepthData {
            attribute value : LengthValue;
            attribute timestamp : String;
        }
        item def AirTemperatureData {
            attribute value : TemperatureValue;
            attribute timestamp : String;
        }
        item def PrecipitationData {
            attribute value : LengthValue;
            attribute timestamp : String;
            attribute period : DurationValue;
        }
        item def SoilTemperatureData {
            attribute value : TemperatureValue;
            attribute timestamp : String;
            attribute depth : LengthValue;
        }
        item def SoilMoistureData {
            attribute value : PercentValue;
            attribute timestamp : String;
            attribute depth : LengthValue;
        }
        item def DataPacket {
            attribute stationId : String;
            attribute timestamp : String;
            attribute snowWaterEquivalent : MassDensityValue;
            attribute snowDepth : LengthValue;
            attribute airTemperature : TemperatureValue;
            attribute precipitationAccumulation : LengthValue;
            attribute soilTemperature : TemperatureValue;
            attribute soilMoisture : PercentValue;
            attribute batteryCharge : PercentValue;
        }
        item def ElectricalPower {
            attribute voltage : VoltageValue;
            attribute availablePower : PowerValue;
        }
        item def TransmissionAck {
            attribute success : Boolean;
            attribute retryCount : Integer;
        }
        item def SatelliteCommand {
            attribute frequency : FrequencyValue;
            attribute channel : String;
        }
    }

    abstract part def Sensor {
        attribute samplingInterval : DurationValue;
        attribute lastReadingTime : String;
        port out dataOut;
        action def sample {
            out timestamp : String;
        }
        perform sample;
    }

    part def SnowPillow :> Sensor {
        :>> samplingInterval = 3600;
        :>> dataOut : Items::SnowWaterEquivalent;
        attribute calibrationFactor : Real = 1.0;
        attribute pillowArea : Real = 3.0;
        private attribute rawPressure : Real;
        action measurePressure {
            out pressure : Real;
        }
        action computeSWE {
            in pressure : Real;
            in calibrationFactor : Real;
            out swe : MassDensityValue;
        }
        perform measurePressure then computeSWE;
    }

    part def UltrasonicDepthSensor :> Sensor {
        :>> samplingInterval = 3600;
        :>> dataOut : Items::SnowDepthData;
        attribute mountingHeight : LengthValue = 2.5;
        private attribute rawDistance : LengthValue;
        action emitPulse {
            out echoTime : DurationValue;
        }
        action computeDistance {
            in echoTime : DurationValue;
            out distance : LengthValue;
        }
        action computeDepth {
            in distance : LengthValue;
            in mountingHeight : LengthValue;
            out depth : LengthValue;
        }
        perform emitPulse then computeDistance then computeDepth;
    }

    part def AirTemperatureSensor :> Sensor {
        :>> samplingInterval = 1800;
        :>> dataOut : Items::AirTemperatureData;
        attribute rangeMin : TemperatureValue = -40;
        attribute rangeMax : TemperatureValue = 60;
        attribute accuracy : TemperatureValue = 0.5;
        action measureResistance {
            out resistance : Real;
        }
        action convertToTemperature {
            in resistance : Real;
            out temperature : TemperatureValue;
        }
        perform measureResistance then convertToTemperature;
    }

    part def PrecipitationGauge :> Sensor {
        :>> samplingInterval = 3600;
        :>> dataOut : Items::PrecipitationData;
        attribute tippingBucketResolution : LengthValue = 0.0001;
        attribute catchDiameter : LengthValue = 0.2;
        private attribute tipCount : Integer = 0;
        private attribute accumulation : LengthValue = 0;
        action detectTip {
            out tipSignal : Boolean;
        }
        action incrementCount {
            in tipSignal : Boolean;
            out count : Integer;
        }
        action computeAccumulation {
            in count : Integer;
            in resolution : LengthValue;
            out accumulation : LengthValue;
        }
        perform detectTip then incrementCount then computeAccumulation;
    }

    part def SoilTemperatureSensor :> Sensor {
        :>> samplingInterval = 3600;
        :>> dataOut : Items::SoilTemperatureData;
        attribute burialDepth : LengthValue = 0.1;
        attribute accuracy : TemperatureValue = 0.3;
        action measureTemperature {
            out temperature : TemperatureValue;
        }
        perform measureTemperature;
    }

    part def SoilMoistureSensor :> Sensor {
        :>> samplingInterval = 3600;
        :>> dataOut : Items::SoilMoistureData;
        attribute burialDepth : LengthValue = 0.1;
        attribute measurementRange : PercentValue = 100;
        action measureDielectric {
            out dielectric : Real;
        }
        action convertToMoisture {
            in dielectric : Real;
            out moisture : PercentValue;
        }
        perform measureDielectric then convertToMoisture;
    }

    part def DataLogger {
        port in sweIn : Items::SnowWaterEquivalent;
        port in depthIn : Items::SnowDepthData;
        port in airTempIn : Items::AirTemperatureData;
        port in precipIn : Items::PrecipitationData;
        port in soilTempIn : Items::SoilTemperatureData;
        port in soilMoistureIn : Items::SoilMoistureData;
        port in batteryStatusIn : PercentValue;
        port in ackIn : Items::TransmissionAck;
        port out packetOut : Items::DataPacket;
        port out transmitCommandOut : Boolean;
        port in powerIn : Items::ElectricalPower;

        attribute stationId : String = "SNOTEL-001";
        attribute loggingInterval : DurationValue = 3600;
        attribute transmissionInterval : DurationValue = 14400;
        attribute maxRetries : Integer = 3;
        private attribute currentPacket : Items::DataPacket;
        private attribute retryCount : Integer = 0;
        private attribute lastTransmissionTime : String;
        private attribute timeSinceTransmission : DurationValue = 0;

        action def collectReadings {
            in swe : MassDensityValue;
            in depth : LengthValue;
            in airTemp : TemperatureValue;
            in precip : LengthValue;
            in soilTemp : TemperatureValue;
            in soilMoisture : PercentValue;
            in batteryCharge : PercentValue;
            out packet : Items::DataPacket;
        }
        action def formatPacket {
            in swe : MassDensityValue;
            in depth : LengthValue;
            in airTemp : TemperatureValue;
            in precip : LengthValue;
            in soilTemp : TemperatureValue;
            in soilMoisture : PercentValue;
            in batteryCharge : PercentValue;
            in stationId : String;
            out packet : Items::DataPacket;
        }
        action def scheduleTransmission {
            in timeSince : DurationValue;
            in interval : DurationValue;
            out transmit : Boolean;
        }
        action def handleAck {
            in ack : Items::TransmissionAck;
            in maxRetries : Integer;
            out retry : Boolean;
            out reset : Boolean;
        }

        state loggerBehavior {
            entry;
            state Collecting {
                entry : collectReadings;
            }
            state Formatting {
                entry : formatPacket;
            }
            state Waiting {
                attribute timeSinceLastTransmission : DurationValue;
            }
            state Transmitting;
            state RetryWait {
                attribute backoffTime : DurationValue = 30;
            }
            transition Collecting -> Formatting when Collecting.done;
            transition Formatting -> Waiting when Formatting.done;
            transition Waiting -> Transmitting when Waiting.timeSinceLastTransmission >= transmissionInterval;
            transition Transmitting -> Waiting when ackIn.success == true;
            transition Transmitting -> RetryWait when ackIn.success == false && retryCount < maxRetries;
            transition RetryWait -> Transmitting when RetryWait.backoffTimeElapsed;
            transition Transmitting -> Waiting when ackIn.success == false && retryCount >= maxRetries;
        }
    }

    part def SatelliteTransmitter {
        port in packetIn : Items::DataPacket;
        port in commandIn : Boolean;
        port out ackOut : Items::TransmissionAck;
        port in powerIn : Items::ElectricalPower;

        attribute satelliteSystem : String = "GOES";
        attribute transmitFrequency : FrequencyValue = 1.7e9;
        attribute channel : String = "GOES-East";
        attribute maxRetries : Integer = 3;
        attribute transmitDuration : DurationValue = 5;
        private attribute retryCount : Integer = 0;
        private attribute lastAck : Boolean;

        action def encodePacket {
            in packet : Items::DataPacket;
            out encoded : String;
        }
        action def transmit {
            in encoded : String;
            in frequency : FrequencyValue;
            in channel : String;
            out signalSent : Boolean;
        }
        action def waitForAck {
            in timeout : DurationValue;
            out ack : Items::TransmissionAck;
        }

        state transmitterBehavior {
            state Idle;
            state Encoding {
                entry : encodePacket;
            }
            state Transmitting {
                entry : transmit;
            }
            state WaitingAck {
                entry : waitForAck;
            }
            transition Idle -> Encoding when commandIn == true;
            transition Encoding -> Transmitting when Encoding.done;
            transition Transmitting -> WaitingAck when Transmitting.done;
            transition WaitingAck -> Idle when ackOut.success == true;
            transition WaitingAck -> Encoding when ackOut.success == false && retryCount < maxRetries;
            transition WaitingAck -> Idle when ackOut.success == false && retryCount >= maxRetries;
        }
    }

    part def SolarPanel {
        port out powerOut : Items::ElectricalPower;
        attribute ratedPower : PowerValue = 10;
        attribute area : Real = 0.5;
        attribute efficiency : Real = 0.18;
        private attribute currentOutput : PowerValue = 0;
        action generatePower {
            in irradiance : IrradianceValue;
            in area : Real;
            in efficiency : Real;
            out power : Items::ElectricalPower;
        }
        perform generatePower;
    }

    part def Battery {
        port in chargeIn : Items::ElectricalPower;
        port out powerOut : Items::ElectricalPower;
        port out chargeStatusOut : PercentValue;
        attribute capacity : EnergyValue = 360000;
        attribute currentCharge : PercentValue = 100;
        attribute minChargeThreshold : PercentValue = 20;
        attribute nominalVoltage : VoltageValue = 12;
        private attribute chargeRate : PowerValue = 0;
        action charge {
            in power : Items::ElectricalPower;
            out newCharge : PercentValue;
        }
        action discharge {
            in demand : PowerValue;
            out power : Items::ElectricalPower;
            out newCharge : PercentValue;
        }
        action monitorCharge {
            out charge : PercentValue;
        }
        perform monitorCharge;
    }

    part def PowerController {
        port in solarIn : Items::ElectricalPower;
        port in batteryIn : Items::ElectricalPower;
        port in batteryChargeIn : PercentValue;
        port out loggerPowerOut : Items::ElectricalPower;
        port out transmitterPowerOut : Items::ElectricalPower;
        port out batteryChargeOut : Items::ElectricalPower;
        port out chargeStatusOut : PercentValue;

        attribute loggerVoltage : VoltageValue = 12;
        attribute transmitterVoltage : VoltageValue = 12;
        attribute loggerPowerDemand : PowerValue = 1;
        attribute transmitterPowerDemand : PowerValue = 5;
        attribute chargeThreshold : PercentValue = 95;

        action regulatePower {
            in solar : Items::ElectricalPower;
            in battery : Items::ElectricalPower;
            in batteryCharge : PercentValue;
            in loggerDemand : PowerValue;
            in transmitterDemand : PowerValue;
            out toLogger : Items::ElectricalPower;
            out toTransmitter : Items::ElectricalPower;
            out toBattery : Items::ElectricalPower;
        }
        action prioritizeLoads {
            in available : PowerValue;
            out loggerAllocation : PowerValue;
            out transmitterAllocation : PowerValue;
            out batteryAllocation : PowerValue;
        }

        state powerManagement {
            state SolarPowered {
                attribute solarAvailable : Boolean = true;
            }
            state BatteryPowered;
            state ChargingBattery {
                attribute batteryFull : Boolean = false;
            }
            state LowBattery;
            transition SolarPowered -> BatteryPowered when solarIn.availablePower < loggerPowerDemand;
            transition BatteryPowered -> SolarPowered when solarIn.availablePower >= loggerPowerDemand;
            transition SolarPowered -> ChargingBattery when batteryChargeIn < chargeThreshold && solarIn.availablePower > loggerPowerDemand;
            transition ChargingBattery -> SolarPowered when batteryChargeIn >= chargeThreshold;
            transition BatteryPowered -> LowBattery when batteryChargeIn < Battery.minChargeThreshold;
            transition LowBattery -> SolarPowered when solarIn.availablePower > 0;
        }
    }

    part def SNOTELStation {
        attribute stationId : String = "SNOTEL-001";
        attribute location : String;
        attribute elevation : LengthValue;
        attribute deploymentDate : String;

        part snowPillow : SnowPillow;
        part ultrasonicDepthSensor : UltrasonicDepthSensor;
        part airTemperatureSensor : AirTemperatureSensor;
        part precipitationGauge : PrecipitationGauge;
        part soilTemperatureSensor : SoilTemperatureSensor;
        part soilMoistureSensor : SoilMoistureSensor;
        part dataLogger : DataLogger;
        part satelliteTransmitter : SatelliteTransmitter;
        part solarPanel : SolarPanel;
        part battery : Battery;
        part powerController : PowerController;

        connection snowPillow.dataOut to dataLogger.sweIn;
        connection ultrasonicDepthSensor.dataOut to dataLogger.depthIn;
        connection airTemperatureSensor.dataOut to dataLogger.airTempIn;
        connection precipitationGauge.dataOut to dataLogger.precipIn;
        connection soilTemperatureSensor.dataOut to dataLogger.soilTempIn;
        connection soilMoistureSensor.dataOut to dataLogger.soilMoistureIn;
        connection dataLogger.packetOut to satelliteTransmitter.packetIn;
        connection dataLogger.transmitCommandOut to satelliteTransmitter.commandIn;
        connection satelliteTransmitter.ackOut to dataLogger.ackIn;
        connection solarPanel.powerOut to powerController.solarIn;
        connection battery.powerOut to powerController.batteryIn;
        connection battery.chargeStatusOut to powerController.batteryChargeIn;
        connection powerController.loggerPowerOut to dataLogger.powerIn;
        connection powerController.transmitterPowerOut to satelliteTransmitter.powerIn;
        connection powerController.batteryChargeOut to battery.chargeIn;
        connection powerController.chargeStatusOut to dataLogger.batteryStatusIn;

        state stationOperation {
            state Initializing {
                attribute initializationComplete : Boolean = false;
            }
            state Measuring;
            state Aggregating;
            state Transmitting;
            state Idle;
            transition Initializing -> Measuring when Initializing.initializationComplete == true;
            transition Measuring -> Aggregating when allSensorsRead == true;
            transition Aggregating -> Transmitting when transmissionScheduled == true;
            transition Transmitting -> Idle when transmissionComplete == true;
            transition Idle -> Measuring when measurementIntervalElapsed == true;
        }
    }

    package Requirements {
        requirement def EnvironmentalMonitoringRequirement {
            subject station : SNOTELStation;
            require station to continuously measure snowpack, weather, and soil conditions;
        }
        requirement def SnowWaterEquivalentRequirement {
            subject pillow : SnowPillow;
            attribute accuracy : MassDensityValue = 2.5;
            require pillow to measure snow water equivalent within accuracy;
        }
        requirement def SnowDepthRequirement {
            subject sensor : UltrasonicDepthSensor;
            attribute accuracy : LengthValue = 0.025;
            require sensor to measure snow depth within accuracy;
        }
        requirement def AirTemperatureRequirement {
            subject sensor : AirTemperatureSensor;
            attribute accuracy : TemperatureValue = 0.5;
            attribute rangeMin : TemperatureValue = -40;
            attribute rangeMax : TemperatureValue = 60;
            require sensor to measure air temperature within accuracy across rangeMin to rangeMax;
        }
        requirement def PrecipitationRequirement {
            subject gauge : PrecipitationGauge;
            attribute resolution : LengthValue = 0.0001;
            require gauge to measure accumulated precipitation with resolution;
        }
        requirement def SoilMeasurementRequirement {
            subject station : SNOTELStation;
            attribute depth : LengthValue = 0.1;
            require station to measure soil temperature and soil moisture at depth;
        }
        requirement def DataLoggingRequirement {
            subject logger : DataLogger;
            attribute interval : DurationValue = 3600;
            require logger to collect, timestamp, and format readings into standardized data packets at interval;
        }
        requirement def TransmissionRequirement {
            subject transmitter : SatelliteTransmitter;
            attribute interval : DurationValue = 14400;
            attribute maxRetries : Integer = 3;
            require transmitter to broadcast data packets via GOES satellite at interval;
            require transmitter to retry failed transmissions up to maxRetries times;
        }
        requirement def PowerAutonomyRequirement {
            subject station : SNOTELStation;
            attribute minOperationDuration : DurationValue = 2592000;
            require station to operate autonomously for minOperationDuration without external power;
            require station to maintain battery charge above 20 percent during night and poor weather;
        }
        requirement def ReliabilityRequirement {
            subject station : SNOTELStation;
            require station to retry failed transmissions ensuring high data reliability;
        }

        requirement monitoringReq : EnvironmentalMonitoringRequirement;
        requirement sweReq : SnowWaterEquivalentRequirement;
        requirement depthReq : SnowDepthRequirement;
        requirement airTempReq : AirTemperatureRequirement;
        requirement precipReq : PrecipitationRequirement;
        requirement soilReq : SoilMeasurementRequirement;
        requirement loggingReq : DataLoggingRequirement;
        requirement transmitReq : TransmissionRequirement;
        requirement powerReq : PowerAutonomyRequirement;
        requirement reliabilityReq : ReliabilityRequirement;
    }
}
