package SmartdustEnvironmentalMonitoring {
    private import ScalarValues::*;
    private import ISQ::*;
    private import ISQThermodynamics::*;
    private import ISQMechanics::*;

    import Definitions::*;
    import Components::*;

    package Definitions {
        attribute def WakeSignal;
        attribute def HarvestCompleteSignal;
        attribute def SenseCompleteSignal;
        attribute def ProcessCompleteSignal;
        attribute def TransmitCompleteSignal;
        attribute def AnalyzeTimerSignal;
        attribute def AnalysisCompleteSignal;
        attribute def CollectCompleteSignal;

        attribute def TemperatureValue :> Real {
            doc /* Temperature in degrees Celsius */
        }
        attribute def HumidityValue :> Real {
            doc /* Relative humidity percentage (0-100) */
        }
        attribute def PressureValue :> Real {
            doc /* Atmospheric pressure in hectopascals */
        }
        attribute def LightLevelValue :> Real {
            doc /* Ambient light in lux */
        }
        attribute def BatteryChargeValue :> Real {
            doc /* Battery charge as percentage (0-100) */
        }
        attribute def AverageTemperatureValue :> Real {
            doc /* Average temperature across motes in degrees Celsius */
        }
        attribute def SolarIrradianceValue :> Real {
            doc /* Solar irradiance in watts per square metre */
        }
        attribute def VibrationAmplitudeValue :> Real {
            doc /* Vibration amplitude in metres per second squared */
        }

        attribute def EnvironmentalReading {
            attribute moteId : String;
            attribute temperature : TemperatureValue;
            attribute humidity : HumidityValue;
            attribute pressure : PressureValue;
            attribute lightLevel : LightLevelValue;
            attribute timestamp : String;
            attribute batteryCharge : BatteryChargeValue;
        }

        attribute def DataPacket {
            attribute sourceMoteId : String;
            attribute reading : EnvironmentalReading;
            attribute hopCount : Integer;
        }

        attribute def AlertNotification {
            attribute alertType : String;
            attribute alertValue : TemperatureValue;
            attribute alertThreshold : TemperatureValue;
        }

        port def WirelessPort {
            in item incomingPacket : DataPacket;
            out item outgoingPacket : DataPacket;
        }

        action def HarvestEnergy {
            in harvester : EnergyHarvesterTypeDef;
            out chargeAmount : BatteryChargeValue;
        }

        action def SenseEnvironment {
            out temperature : TemperatureValue;
            out humidity : HumidityValue;
            out pressure : PressureValue;
            out lightLevel : LightLevelValue;
        }

        action def ProcessReading {
            in rawReading : EnvironmentalReading;
            out processedReading : EnvironmentalReading;
        }

        action def TransmitPacket {
            in packet : DataPacket;
            in radio : WirelessPort;
        }

        action def CollectPacket {
            in packet : DataPacket;
            out reading : EnvironmentalReading;
        }

        action def AnalyzeReadings {
            in readings : EnvironmentalReading[*];
            out averageTemperature : AverageTemperatureValue;
            out alert : AlertNotification;
        }

        action def ConservePower;

        part def EnergyHarvesterTypeDef {
            attribute solarIrradiance : SolarIrradianceValue;
            attribute vibrationAmplitude : VibrationAmplitudeValue;
            attribute conversionEfficiency : Real = 0.15;
        }

        state def MoteStates;
        state def BaseStationStates;
    }

    package Components {
        private import Definitions::*;

        part def EnergyHarvester :> EnergyHarvesterTypeDef {
            doc /* Converts ambient solar light and physical vibrations into electrical energy */
        }

        part def Battery {
            doc /* Stores electrical energy for mote operation */
            attribute chargeLevel : BatteryChargeValue;
            attribute maxCapacity : BatteryChargeValue = 100;
            attribute criticalThreshold : BatteryChargeValue = 10;
        }

        part def TemperatureSensor {
            attribute reading : TemperatureValue;
        }

        part def HumiditySensor {
            attribute reading : HumidityValue;
        }

        part def PressureSensor {
            attribute reading : PressureValue;
        }

        part def LightSensor {
            attribute reading : LightLevelValue;
        }

        part def Mote {
            doc /* Smartdust Mote - miniature, self-contained, autonomous sensor node */
            attribute moteId : String;
            attribute currentReading : EnvironmentalReading;
            attribute outgoingPacket : DataPacket;
            attribute isRelay : Boolean = false;
            attribute lowChargeThreshold : BatteryChargeValue = 10;

            port wirelessPort : WirelessPort;

            part temperatureSensor : TemperatureSensor;
            part humiditySensor : HumiditySensor;
            part pressureSensor : PressureSensor;
            part lightSensor : LightSensor;
            part energyHarvester : EnergyHarvester;
            part battery : Battery;

            exhibit state moteStates : MoteStates {
                in operatingMote : Mote = self;
                entry; then sleeping;

                state sleeping {
                    doc /* Low-power sleep state to conserve energy */
                    do action ConservePower;
                }

                transition sleepingToHarvesting
                    first sleeping
                    accept WakeSignal
                    then harvesting;

                state harvesting {
                    doc /* Harvesting energy from ambient solar and vibration sources */
                    do action harvest : HarvestEnergy {
                        in harvester = operatingMote.energyHarvester;
                        out chargeAmount = operatingMote.battery.chargeLevel;
                    }
                }

                transition harvestingToSensing
                    first harvesting
                    accept HarvestCompleteSignal
                    then sensing;

                state sensing {
                    doc /* Taking environmental sensor readings */
                    do action sense : SenseEnvironment {
                        out temperature = operatingMote.temperatureSensor.reading;
                        out humidity = operatingMote.humiditySensor.reading;
                        out pressure = operatingMote.pressureSensor.reading;
                        out lightLevel = operatingMote.lightSensor.reading;
                    }
                }

                transition sensingToProcessing
                    first sensing
                    accept SenseCompleteSignal
                    then processing;

                state processing {
                    doc /* Processing sensor data into a formatted reading */
                    do action process : ProcessReading {
                        in rawReading = operatingMote.currentReading;
                        out processedReading = operatingMote.currentReading;
                    }
                }

                transition processingToTransmitting
                    first processing
                    accept ProcessCompleteSignal
                    if operatingMote.battery.chargeLevel > operatingMote.lowChargeThreshold
                    then transmitting;

                transition processingToSleeping
                    first processing
                    accept ProcessCompleteSignal
                    if operatingMote.battery.chargeLevel <= operatingMote.lowChargeThreshold
                    then sleeping;

                state transmitting {
                    doc /* Transmitting data packet to base station or relay mote via wireless mesh */
                    do action transmit : TransmitPacket {
                        in packet = operatingMote.outgoingPacket;
                        in radio = operatingMote.wirelessPort;
                    }
                }

                transition transmittingToSleeping
                    first transmitting
                    accept TransmitCompleteSignal
                    then sleeping;
            }
        }

        part def BaseStation {
            doc /* Central data aggregator and command center for the smartdust network */
            attribute stationId : String;
            attribute collectedReadings : EnvironmentalReading[*];
            attribute currentReading : EnvironmentalReading;
            attribute currentAlert : AlertNotification;
            attribute averageTemperature : AverageTemperatureValue;
            attribute alertThreshold : TemperatureValue = 50;

            port wirelessPort : WirelessPort;

            exhibit state stationStates : BaseStationStates {
                in station : BaseStation = self;
                entry; then listening;

                state listening {
                    doc /* Continuously listening for data packets from motes in the mesh network */
                }

                transition listeningToCollecting
                    first listening
                    accept DataPacket
                    then collecting;

                state collecting {
                    doc /* Collecting received data packets from motes */
                    do action collect : CollectPacket {
                        in packet = station.wirelessPort.incomingPacket;
                        out reading = station.currentReading;
                    }
                }

                transition collectingToListening
                    first collecting
                    accept CollectCompleteSignal
                    then listening;

                transition collectingToAnalyzing
                    first collecting
                    accept AnalyzeTimerSignal
                    then analyzing;

                state analyzing {
                    doc /* Performing analysis on collected data - calculating average temperature and checking for alert conditions */
                    do action analyze : AnalyzeReadings {
                        in readings = station.collectedReadings;
                        out averageTemperature = station.averageTemperature;
                        out alert = station.currentAlert;
                    }
                }

                transition analyzingToListening
                    first analyzing
                    accept AnalysisCompleteSignal
                    then listening;
            }
        }
    }

    package System {
        private import Definitions::*;
        private import Components::*;

        part smartdustSystem {
            doc /* Smartdust system for large-scale, distributed environmental monitoring */

            part motes : Mote[1..*] {
                doc /* Network of scattered sensor motes forming a wireless mesh */
            }

            part baseStation : BaseStation {
                doc /* Central base station for data aggregation and analysis */
            }

            connection motesToBaseStation connect motes.wirelessPort to baseStation.wirelessPort;
            connection moteMesh connect motes.wirelessPort to motes.wirelessPort;
        }
    }

    package Requirements {
        private import Components::*;
        private import Definitions::*;

        requirement def EnergyAutonomyRequirement {
            doc /* Each mote must operate autonomously using harvested energy from solar and vibration sources */
            doc /* The mote shall harvest ambient solar and vibration energy to maintain battery charge above critical threshold. */
        }

        requirement def LowPowerConservationRequirement {
            doc /* When battery charge falls below critical threshold, mote must forgo transmission to save power */
            doc /* If battery charge is critically low, the mote shall skip transmission and return to sleep. */
        }

        requirement def MeshNetworkingRequirement {
            doc /* Motes must form a wireless mesh network to relay data through intermediate motes to reach base station */
            doc /* The system shall support multi-hop wireless routing so distant motes can relay data to the Base Station. */
        }

        requirement def DataAggregationRequirement {
            doc /* Base station must aggregate data from all motes and calculate average environmental conditions */
            doc /* The Base Station shall collect data packets and compute average temperature across the monitored area. */
        }

        requirement def EnvironmentalMonitoringRequirement {
            doc /* System must monitor temperature, humidity, atmospheric pressure, and ambient light across the monitored area */
            doc /* Each mote shall measure temperature, humidity, pressure, and ambient light levels. */
        }

        requirement energyAutonomy : EnergyAutonomyRequirement;
        requirement lowPowerConservation : LowPowerConservationRequirement;
        requirement meshNetworking : MeshNetworkingRequirement;
        requirement dataAggregation : DataAggregationRequirement;
        requirement environmentalMonitoring : EnvironmentalMonitoringRequirement;
    }
}
