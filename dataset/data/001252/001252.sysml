package SmartdustSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def NodeID :> String;
    attribute def SensorData :> Real;
    attribute def Timestamp :> Real;

    item def EnvironmentalReading {
        attribute temperature : ThermodynamicTemperatureValue;
        attribute humidity : Real;
        attribute pressure : PressureValue;
        attribute lightLevel : LuminousIntensityValue;
        attribute timestamp : TimeValue;
        attribute nodeID : NodeID;
    }

    item def NetworkPacket {
        attribute sourceID : NodeID;
        attribute destinationID : NodeID;
        attribute payload : EnvironmentalReading;
        attribute hopCount : Integer;
    }

    item def AggregatedData {
        attribute readings : EnvironmentalReading[*];
        attribute averageTemperature : ThermodynamicTemperatureValue;
        attribute coverageArea : AreaValue;
    }

    port def SensorPort {
        out reading : EnvironmentalReading;
    }

    port def WirelessPort {
        in rxPacket : NetworkPacket;
        out txPacket : NetworkPacket;
    }

    port def PowerPort {
        in harvestedEnergy : EnergyValue;
        out consumedPower : PowerValue;
    }

    action def SenseEnvironment {
        in ambientTemp : ThermodynamicTemperatureValue;
        in ambientHumidity : Real;
        in ambientPressure : PressureValue;
        in ambientLight : LuminousIntensityValue;
        out reading : EnvironmentalReading;
    }

    action def HarvestEnergy {
        in solarIntensity : LuminousIntensityValue;
        in vibrationLevel : AccelerationValue;
        out energy : EnergyValue;
    }

    action def TransmitData {
        in packet : NetworkPacket;
        in powerLevel : PowerValue;
    }

    action def ReceiveData {
        in packet : NetworkPacket;
        out processedData : EnvironmentalReading;
    }

    action def RoutePacket {
        in incomingPacket : NetworkPacket;
        in routingTable : NodeID[*];
        out nextHop : NodeID;
    }

    part def EnergyHarvester {
        port powerOut : PowerPort;
        attribute currentOutput : PowerValue;
        
        perform action harvest : HarvestEnergy {
            in solarIntensity;
            in vibrationLevel;
            out energy;
        }
    }

    part def BatteryStorage {
        attribute capacity : EnergyValue;
        attribute currentCharge : EnergyValue;
        attribute chargeLevel : Real;
        
        action def StoreEnergy {
            in energy : EnergyValue;
        }
        
        action def SupplyPower {
            in demand : PowerValue;
            out power : PowerValue;
        }
    }

    part def MicroSensor {
        port sensorOut : SensorPort;
        attribute sensorID : NodeID;
        attribute accuracy : Real;
        
        perform action sense : SenseEnvironment {
            in ambientTemp;
            in ambientHumidity;
            in ambientPressure;
            in ambientLight;
            out reading;
        }
    }

    part def MicroController {
        attribute processingPower : FrequencyValue;
        attribute memorySize : Real;
        
        action def ProcessSensorData {
            in rawReading : EnvironmentalReading;
            out processedReading : EnvironmentalReading;
        }
        
        action def ManageRouting {
            in packet : NetworkPacket;
            out route : NodeID;
        }
    }

    part def RadioTransceiver {
        port commPort : WirelessPort;
        attribute frequency : FrequencyValue;
        attribute transmitPower : PowerValue;
        attribute range : LengthValue;
        
        perform action transmit : TransmitData {
            in packet;
            in powerLevel;
        }
        
        perform action receive : ReceiveData {
            in packet;
            out processedData;
        }
    }

    part def SmartdustMote {
        attribute moteID : NodeID;
        attribute position : LengthValue[3];
        attribute operationalStatus : Boolean;
        
        port sensorPort : SensorPort;
        port wirelessPort : WirelessPort;
        port powerPort : PowerPort;
        
        part sensor : MicroSensor;
        part controller : MicroController;
        part radio : RadioTransceiver;
        part harvester : EnergyHarvester;
        part battery : BatteryStorage;
        
        connect sensor.sensorOut to sensorPort;
        connect radio.commPort to wirelessPort;
        connect harvester.powerOut to powerPort;
        
        state def MoteLifecycle {
            entry; then Initializing;
            
            state Initializing;
            then Sleeping;
            
            state Sleeping {
                entry assign battery.chargeLevel := battery.currentCharge / battery.capacity;
            }
            then Harvesting;
            
            state Harvesting;
            then Sensing;
            
            state Sensing;
            then Processing;
            
            state Processing;
            then Transmitting;
            
            state Transmitting;
            then Receiving;
            
            state Receiving;
            then Sleeping;
        }
        
        perform action operateMote {
            first start;
            then merge continuousOperation;
            
            action harvestPower : HarvestEnergy {
                in solarIntensity;
                in vibrationLevel;
                out energy;
            }
            then action storePower : BatteryStorage::StoreEnergy {
                in energy = harvestPower.energy;
            }
            
            then action acquireData : SenseEnvironment {
                in ambientTemp;
                in ambientHumidity;
                in ambientPressure;
                in ambientLight;
                out reading;
            }
            
            then action processData : controller.ProcessSensorData {
                in rawReading = acquireData.reading;
                out processedReading;
            }
            
            then decide;
                if battery.chargeLevel > 0.2 then transmitReading;
                if battery.chargeLevel <= 0.2 then enterLowPower;
            
            action transmitReading : TransmitData {
                in packet;
                in powerLevel = radio.transmitPower;
            }
            then continuousOperation;
            
            action enterLowPower;
            then continuousOperation;
        }
    }

    part def BaseStation {
        attribute stationID : NodeID;
        attribute location : LengthValue[3];
        
        port wirelessPort : WirelessPort;
        port dataOutput : flow out AggregatedData;
        
        part radio : RadioTransceiver;
        attribute collectedReadings : EnvironmentalReading[*];
        
        connect radio.commPort to wirelessPort;
        
        action def AggregateData {
            in readings : EnvironmentalReading[*];
            out aggregated : AggregatedData;
            
            private attribute sum : ThermodynamicTemperatureValue;
            private attribute count : Integer := 0;
            
            for reading in readings {
                then assign sum := sum + reading.temperature;
                then assign count := count + 1;
            }
            
            then assign aggregated.readings := readings;
            then assign aggregated.averageTemperature := sum / count;
        }
        
        perform action collectAndAggregate {
            first start;
            then merge collectLoop;
            
            action receivePacket : ReceiveData {
                in packet;
                out processedData;
            }
            
            then action storeReading {
                assign collectedReadings := collectedReadings->including(receivePacket.processedData);
            }
            
            then decide;
                if collectedReadings->size() >= 100 then aggregate;
                if collectedReadings->size() < 100 then collectLoop;
            
            action aggregate : AggregateData {
                in readings = collectedReadings;
                out aggregated;
            }
            then done;
        }
    }

    part def SmartdustNetwork {
        attribute networkID : NodeID;
        attribute deploymentArea : AreaValue;
        attribute nodeCount : Integer;
        
        part motes : SmartdustMote[100];
        part baseStation : BaseStation;
        
        connect motes.wirelessPort to baseStation.wirelessPort;
        
        perform action monitorEnvironment {
            first start;
            
            action deployNetwork {
                doc /* Deploy smartdust motes across target area */
            }
            
            then action establishMesh {
                doc /* Configure mesh network topology and routing */
            }
            
            then merge collectData;
            
            action gatherSensorData {
                doc /* Motes sense environment and transmit data */
            }
            
            then action aggregateAtBase : BaseStation::AggregateData {
                in readings;
                out aggregated;
            }
            
            then action analyzeData {
                in data = aggregateAtBase.aggregated;
                out analysis : Real;
            }
            
            then decide;
                if analysis > 0.75 then triggerAlert;
                if analysis <= 0.75 then collectData;
            
            action triggerAlert {
                doc /* Generate alert based on environmental conditions */
            }
            then done;
        }
    }

    requirement def SmartdustRequirements {
        doc /* Requirements for smartdust system operation */
        
        requirement <'SR-1'> moteSize {
            doc /* Each smartdust mote shall have dimensions less than 1 cubic millimeter */
            subject mote : SmartdustMote;
        }
        
        requirement <'SR-2'> energyAutonomy {
            doc /* Each mote shall operate autonomously using harvested energy for minimum 1 year */
            subject mote : SmartdustMote;
        }
        
        requirement <'SR-3'> sensingAccuracy {
            doc /* Temperature sensing accuracy shall be within +/- 0.5 degrees Celsius */
            subject sensor : MicroSensor;
        }
        
        requirement <'SR-4'> communicationRange {
            doc /* Each mote shall communicate wirelessly within 10 meter range */
            subject radio : RadioTransceiver;
        }
        
        requirement <'SR-5'> networkScalability {
            doc /* The network shall support minimum 100 nodes with mesh topology */
            subject network : SmartdustNetwork;
        }
        
        requirement <'SR-6'> dataLatency {
            doc /* Data aggregation shall occur within 60 seconds of sensing */
            subject baseStation : BaseStation;
        }
    }

    requirement smartdustMission {
        doc /* 
            The smartdust system shall provide distributed environmental monitoring
            by deploying a network of miniature wireless sensor nodes that autonomously
            sense, process, and communicate environmental data to a central base station
            for real-time aggregation and analysis.
        */
        
        assume constraint energyAvailable {
            doc /* Sufficient ambient energy available for harvesting */
        }
        
        assume constraint deploymentArea {
            doc /* Target area accessible for mote deployment */
        }
        
        require SmartdustRequirements::moteSize;
        require SmartdustRequirements::energyAutonomy;
        require SmartdustRequirements::sensingAccuracy;
        require SmartdustRequirements::communicationRange;
        require SmartdustRequirements::networkScalability;
        require SmartdustRequirements::dataLatency;
    }
}
