package WirelessTempMonitoringSystem {
    import ScalarValues::*;

    // ---- Value Types with Units ----
    value type TemperatureValue :> Real {
        unit 'C';
    }
    value type BatteryLevelValue :> Real {
        unit '%';
    }
    value type NodeIDValue :> Integer;
    value type PacketIDValue :> Integer;
    value type SignalStrengthValue :> Real {
        unit 'dBm';
    }
    value type TimeValue :> Real {
        unit 's';
    }
    value type VoltageValue :> Real {
        unit 'V';
    }
    value type CapacityValue :> Real {
        unit 'mAh';
    }
    value type FrequencyValue :> Real {
        unit 'Hz';
    }
    value type DistanceValue :> Real {
        unit 'm';
    }

    // ---- Item Definitions ----
    item def TemperatureReading {
        attribute value : TemperatureValue;
        attribute timestamp : TimeValue;
        attribute nodeID : NodeIDValue;
    }

    item def BatteryStatus {
        attribute level : BatteryLevelValue;
        attribute nodeID : NodeIDValue;
    }

    item def DataPacket {
        attribute packetID : PacketIDValue;
        attribute nodeID : NodeIDValue;
        attribute temperature : TemperatureValue;
        attribute batteryLevel : BatteryLevelValue;
        attribute timestamp : TimeValue;
    }

    item def AggregatedStats {
        attribute averageTemp : TemperatureValue;
        attribute minTemp : TemperatureValue;
        attribute maxTemp : TemperatureValue;
        attribute sampleCount : Integer;
        attribute periodStart : TimeValue;
        attribute periodEnd : TimeValue;
    }

    // ---- Port Definitions ----
    port def WirelessOutPort {
        out dataPacket : DataPacket;
    }

    port def WirelessInPort {
        in dataPacket : DataPacket;
    }

    port def PowerPort {
        out voltage : VoltageValue;
    }

    port def BatteryLevelPort {
        out level : BatteryLevelValue;
    }

    port def MeasurementPort {
        out reading : TemperatureValue;
    }

    port def DataInPort {
        in packet : DataPacket;
    }

    port def DataOutPort {
        out packet : DataPacket;
    }

    port def StatsOutPort {
        out stats : AggregatedStats;
    }

    // ---- Requirements ----
    requirement def MonitorTemperatureRequirement {
        doc "The system shall monitor environmental temperature using a distributed network of sensor nodes.";
        attribute monitoredArea : String;
    }

    requirement def SensorNodePowerRequirement {
        doc "Each sensor node shall operate on battery power for at least 1 year.";
        attribute minLifetime : TimeValue = 31536000 [s];
    }

    requirement def DataAggregationRequirement {
        doc "The coordinator shall aggregate temperature data and compute average, minimum, and maximum statistics over a set period.";
        attribute aggregationPeriod : TimeValue = 3600 [s];
    }

    requirement def WirelessCommunicationRequirement {
        doc "Sensor nodes shall transmit data packets wirelessly to the coordinator node.";
    }

    requirement def SensorNodeLifecycleRequirement {
        doc "Each sensor node shall cycle through sleeping, sensing, processing, and transmitting states to conserve energy.";
    }

    // ---- Component Part Definitions ----
    part def Thermistor {
        attribute accuracy : TemperatureValue = 0.5 [C];
        attribute operatingRangeMin : TemperatureValue = -40 [C];
        attribute operatingRangeMax : TemperatureValue = 85 [C];
        port measurementOut : MeasurementPort;
        action measureTemperature out reading : TemperatureValue;
    }

    part def Microcontroller {
        attribute clockSpeed : FrequencyValue = 8000000 [Hz];
        port sensorIn {
            in tempReading : TemperatureValue;
        }
        port batteryIn {
            in battLevel : BatteryLevelValue;
        }
        port packetOut : DataOutPort;
        action processData {
            in temp : TemperatureValue;
            in batt : BatteryLevelValue;
            in id : NodeIDValue;
            out packet : DataPacket;
        }
    }

    part def RadioTransceiver {
        attribute frequency : FrequencyValue = 2400000000 [Hz];
        attribute range : DistanceValue = 100 [m];
        attribute txPower : SignalStrengthValue = 0 [dBm];
        port txIn : DataInPort;
        port rfOut : WirelessOutPort;
        action transmit {
            in packet : DataPacket;
        }
    }

    part def CoinCellBattery {
        attribute capacity : CapacityValue = 220 [mAh];
        attribute currentLevel : BatteryLevelValue = 100 [%];
        port powerOut : PowerPort;
        port levelOut : BatteryLevelPort;
        action checkLevel out level : BatteryLevelValue;
    }

    part def RadioReceiver {
        attribute sensitivity : SignalStrengthValue = -90 [dBm];
        attribute frequency : FrequencyValue = 2400000000 [Hz];
        port rfIn : WirelessInPort;
        port dataOut : DataOutPort;
        action receive {
            out packet : DataPacket;
        }
    }

    part def ProcessingUnit {
        attribute clockSpeed : FrequencyValue = 48000000 [Hz];
        port dataIn : DataInPort;
        port statsOut : StatsOutPort;
        action aggregateData {
            in packets : DataPacket[0..*];
            out stats : AggregatedStats;
        }
    }

    part def RechargeableBattery {
        attribute capacity : CapacityValue = 2000 [mAh];
        attribute currentLevel : BatteryLevelValue = 100 [%];
        port powerOut : PowerPort;
        action recharge;
    }

    // ---- Sensor Node ----
    part def SensorNode {
        attribute nodeID : NodeIDValue;
        attribute samplingInterval : TimeValue = 300 [s];
        attribute firmwareVersion : String = "1.0.0";

        part thermistor : Thermistor;
        part microcontroller : Microcontroller;
        part transceiver : RadioTransceiver;
        part battery : CoinCellBattery;

        port wirelessOut : WirelessOutPort;

        connection thermistor.measurementOut to microcontroller.sensorIn;
        connection battery.levelOut to microcontroller.batteryIn;
        connection battery.powerOut to microcontroller;
        connection battery.powerOut to thermistor;
        connection battery.powerOut to transceiver;
        connection microcontroller.packetOut to transceiver.txIn;
        connection transceiver.rfOut to wirelessOut;

        state machine SensorNodeStateMachine {
            state sleeping {
                entry action { /* enter low-power mode */ }
            }
            state sensing {
                do action { thermistor.measureTemperature(); battery.checkLevel(); }
            }
            state processing {
                do action { microcontroller.processData(); }
            }
            state transmitting {
                do action { transceiver.transmit(); }
            }

            transition sleeping -> sensing when samplingInterval elapsed;
            transition sensing -> processing when thermistor.measurementOut.reading available;
            transition processing -> transmitting when microcontroller.packetOut.packet available;
            transition transmitting -> sleeping when transceiver.transmit complete;
        }

        satisfy SensorNodePowerRequirement;
        satisfy SensorNodeLifecycleRequirement;
        satisfy WirelessCommunicationRequirement;
    }

    // ---- Coordinator Node ----
    part def CoordinatorNode {
        attribute aggregationPeriod : TimeValue = 3600 [s];
        attribute firmwareVersion : String = "2.0.0";

        part receiver : RadioReceiver;
        part processor : ProcessingUnit;
        part battery : RechargeableBattery;

        port wirelessIn : WirelessInPort;
        port statsOut : StatsOutPort;

        connection wirelessIn to receiver.rfIn;
        connection receiver.dataOut to processor.dataIn;
        connection battery.powerOut to receiver;
        connection battery.powerOut to processor;
        connection processor.statsOut to statsOut;

        state machine CoordinatorStateMachine {
            state listening {
                do action { receiver.receive(); }
            }
            state aggregating {
                do action { processor.aggregateData(); }
            }
            state reporting {
                do action { /* publish aggregated stats */ }
            }

            transition listening -> aggregating when aggregationPeriod elapsed;
            transition aggregating -> reporting when processor.aggregateData complete;
            transition reporting -> listening when stats published;
        }

        satisfy DataAggregationRequirement;
    }

    // ---- System ----
    part def WirelessTempMonitoringSystem {
        attribute numNodes : Integer = 10;
        attribute monitoredArea : String = "Building Floor 1";

        part coordinator : CoordinatorNode;
        part sensorNodes : SensorNode[1..*];

        connection sensorNodes.wirelessOut to coordinator.wirelessIn;

        satisfy MonitorTemperatureRequirement;
    }
}
