package SNOTELStationModel {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def SnowWaterEquivalentValue :> Real;
    attribute def SnowDepthValue :> Real;
    attribute def AirTemperatureValue :> Real;
    attribute def PrecipitationValue :> Real;
    attribute def SoilTemperatureValue :> Real;
    attribute def SoilMoistureValue :> Real;
    attribute def BatteryChargeValue :> Real;
    attribute def PowerValue :> Real;

    item def DataPacket {
        attribute snowWaterEquivalent : SnowWaterEquivalentValue;
        attribute snowDepth : SnowDepthValue;
        attribute airTemperature : AirTemperatureValue;
        attribute precipitation : PrecipitationValue;
        attribute soilTemperature : SoilTemperatureValue;
        attribute soilMoisture : SoilMoistureValue;
        attribute timestamp : String;
    }

    action def MeasureSnowWaterEquivalent { out value : SnowWaterEquivalentValue; }
    action def MeasureSnowDepth { out value : SnowDepthValue; }
    action def MeasureAirTemperature { out value : AirTemperatureValue; }
    action def MeasurePrecipitation { out value : PrecipitationValue; }
    action def MeasureSoilTemperature { out value : SoilTemperatureValue; }
    action def MeasureSoilMoisture { out value : SoilMoistureValue; }

    action def GetTimestamp { out timestamp : String; }

    action def AggregateData {
        in snowWE : SnowWaterEquivalentValue;
        in snowDepth : SnowDepthValue;
        in airTemp : AirTemperatureValue;
        in precip : PrecipitationValue;
        in soilTemp : SoilTemperatureValue;
        in soilMoist : SoilMoistureValue;
        in timestamp : String;
        out packet : DataPacket;
    }

    action def TransmitData {
        in packet : DataPacket;
        out success : Boolean;
    }

    action def Delay {
        in duration : Real;
    }

    action def ManagePower {
        in solarPower : PowerValue;
        inout batteryCharge : BatteryChargeValue;
        out dataLoggerPower : PowerValue;
        out transmitterPower : PowerValue;
    }

    action def GeneratePower {
        out power : PowerValue;
    }

    action def MeasureAndTransmit {
        first start;
        then merge measureCycle;
        then action getTS : GetTimestamp {
            out timestamp : String;
        }
        then action aggregateData : AggregateData {
            in timestamp = getTS.timestamp;
            out packet : DataPacket;
        }
        then merge transmitAttempt;
        then action transmitData : TransmitData {
            in packet = aggregateData.packet;
            out success : Boolean;
        }
        then decide;
            if transmitData.success then done;
            if !transmitData.success then waitAndRetry;
        action waitAndRetry : Delay {
            in duration = 300.0;
        }
        then transmitAttempt;
    }

    part def SNOTELStation {
        part snowPillow {
            port dataOut { out attribute swe : SnowWaterEquivalentValue; }
            perform action measure : MeasureSnowWaterEquivalent {
                out value : SnowWaterEquivalentValue;
            }
        }

        part ultrasonicDepthSensor {
            port dataOut { out attribute depth : SnowDepthValue; }
            perform action measure : MeasureSnowDepth {
                out value : SnowDepthValue;
            }
        }

        part airTemperatureSensor {
            port dataOut { out attribute temp : AirTemperatureValue; }
            perform action measure : MeasureAirTemperature {
                out value : AirTemperatureValue;
            }
        }

        part precipitationGauge {
            port dataOut { out attribute precip : PrecipitationValue; }
            perform action measure : MeasurePrecipitation {
                out value : PrecipitationValue;
            }
        }

        part soilTemperatureSensor {
            port dataOut { out attribute soilTemp : SoilTemperatureValue; }
            perform action measure : MeasureSoilTemperature {
                out value : SoilTemperatureValue;
            }
        }

        part soilMoistureSensor {
            port dataOut { out attribute moisture : SoilMoistureValue; }
            perform action measure : MeasureSoilMoisture {
                out value : SoilMoistureValue;
            }
        }

        part dataLogger {
            port sweIn { in attribute swe : SnowWaterEquivalentValue; }
            port depthIn { in attribute depth : SnowDepthValue; }
            port tempIn { in attribute temp : AirTemperatureValue; }
            port precipIn { in attribute precip : PrecipitationValue; }
            port soilTempIn { in attribute soilTemp : SoilTemperatureValue; }
            port moistureIn { in attribute moisture : SoilMoistureValue; }
            port dataOut { out attribute packet : DataPacket; }
            port powerIn { in attribute pwr : PowerValue; }

            perform action logData : AggregateData {
                in snowWE = sweIn.swe;
                in snowDepth = depthIn.depth;
                in airTemp = tempIn.temp;
                in precip = precipIn.precip;
                in soilTemp = soilTempIn.soilTemp;
                in soilMoist = moistureIn.moisture;
                in timestamp = "auto";
                out packet : DataPacket;
            }
        }

        part satelliteTransmitter {
            port dataIn { in attribute packet : DataPacket; }
            port powerIn { in attribute pwr : PowerValue; }
            port successOut { out attribute success : Boolean; }
            perform action broadcast : TransmitData {
                in packet = dataIn.packet;
                out success : Boolean;
            }
        }

        part solarPanel {
            port powerOut { out attribute pwr : PowerValue; }
            perform action generate : GeneratePower {
                out power : PowerValue;
            }
        }

        part battery {
            port chargeIn { in attribute pwr : PowerValue; }
            port powerOut { out attribute pwr : PowerValue; }
            attribute charge : BatteryChargeValue;
        }

        part powerController {
            port solarIn { in attribute pwr : PowerValue; }
            port batteryIn { in attribute pwr : PowerValue; }
            port batteryChargeOut { out attribute pwr : PowerValue; }
            port loggerOut { out attribute pwr : PowerValue; }
            port transmitterOut { out attribute pwr : PowerValue; }
            perform action manage : ManagePower {
                in solarPower = solarIn.pwr;
                out dataLoggerPower = loggerOut.pwr;
                out transmitterPower = transmitterOut.pwr;
            }
        }

        connect snowPillow.dataOut to dataLogger.sweIn;
        connect ultrasonicDepthSensor.dataOut to dataLogger.depthIn;
        connect airTemperatureSensor.dataOut to dataLogger.tempIn;
        connect precipitationGauge.dataOut to dataLogger.precipIn;
        connect soilTemperatureSensor.dataOut to dataLogger.soilTempIn;
        connect soilMoistureSensor.dataOut to dataLogger.moistureIn;
        connect dataLogger.dataOut to satelliteTransmitter.dataIn;

        connect solarPanel.powerOut to powerController.solarIn;
        connect battery.powerOut to powerController.batteryIn;
        connect powerController.batteryChargeOut to battery.chargeIn;
        connect powerController.loggerOut to dataLogger.powerIn;
        connect powerController.transmitterOut to satelliteTransmitter.powerIn;

        perform action stationOperation : MeasureAndTransmit;
    }

    requirement def ContinuousMonitoringRequirement {
        text "The SNOTEL station shall continuously measure snowpack, weather, and soil conditions to support water supply forecasting, flood prediction, and climate research.";
    }

    requirement def DataReliabilityRequirement {
        text "The SNOTEL station shall retry failed transmissions to ensure high data reliability from remote outposts.";
    }

    requirement def AutonomousPowerRequirement {
        text "The SNOTEL station shall operate autonomously using solar power with battery backup for continuous operation during night and poor weather conditions.";
    }

    part snotelStation : SNOTELStation {
        satisfy ContinuousMonitoringRequirement by stationOperation;
        satisfy DataReliabilityRequirement by stationOperation;
        satisfy AutonomousPowerRequirement by powerController.manage;
    }
}
