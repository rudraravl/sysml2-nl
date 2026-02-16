package 'Wireless Sensing Unit System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	comment about WirelessSensingUnit
	/* This model describes a wireless sensing unit system that measures environmental
	 * temperature using a distributed wireless sensor network. The system consists of
	 * multiple sensor nodes that measure temperature and transmit data wirelessly to
	 * a central coordinator node for aggregation and processing. */
	
	attribute def NodeIdentifier :> String;
	attribute def PacketSequence :> Integer;
	attribute def TimestampValue :> Real;
	
	item def SensorMeasurement {
		attribute temperature : TemperatureValue;
		attribute timestamp : TimestampValue;
		attribute nodeId : NodeIdentifier;
		attribute batteryLevel : Real;
	}
	
	item def WirelessDataPacket {
		attribute sourceNode : NodeIdentifier;
		attribute destinationNode : NodeIdentifier;
		attribute sequenceNumber : PacketSequence;
		attribute payload : SensorMeasurement;
		attribute signalStrength : Real;
	}
	
	item def AggregatedMeasurements {
		attribute averageTemperature : TemperatureValue;
		attribute minimumTemperature : TemperatureValue;
		attribute maximumTemperature : TemperatureValue;
		attribute sampleCount : Integer;
		attribute measurementPeriod : TimeValue;
	}
	
	port def SensorOutputPort {
		out measurement : SensorMeasurement;
	}
	
	port def WirelessTransmitPort {
		out packet : WirelessDataPacket;
		attribute transmitPower : Real;
		attribute frequency : FrequencyValue;
	}
	
	port def WirelessReceivePort {
		in packet : WirelessDataPacket;
		attribute receiveSensitivity : Real;
		attribute frequency : FrequencyValue;
	}
	
	port def DataAggregationPort {
		in measurements : SensorMeasurement[*];
		out aggregated : AggregatedMeasurements;
	}
	
	connection def WirelessCommunicationLink {
		end transmitter : WirelessTransmitPort[1];
		end receiver : WirelessReceivePort[1];
	}
	
	action def MeasureTemperature {
		in ambientCondition : TemperatureValue;
		out measurement : TemperatureValue;
	}
	
	action def CreateMeasurementRecord {
		in temperature : TemperatureValue;
		in nodeIdentifier : NodeIdentifier;
		in batteryStatus : Real;
		out record : SensorMeasurement;
	}
	
	action def EncapsulateInPacket {
		in measurement : SensorMeasurement;
		in source : NodeIdentifier;
		in destination : NodeIdentifier;
		in sequence : PacketSequence;
		out packet : WirelessDataPacket;
	}
	
	action def TransmitPacket {
		in packet : WirelessDataPacket;
		out transmissionSuccess : Boolean;
	}
	
	action def ReceivePacket {
		in packet : WirelessDataPacket;
		out extractedMeasurement : SensorMeasurement;
	}
	
	action def AggregateMeasurements {
		in measurementStream : SensorMeasurement[*];
		out aggregatedData : AggregatedMeasurements;
	}
	
	action def SensorNodeCycle {
		in nodeId : NodeIdentifier;
		in coordinatorId : NodeIdentifier;
		in currentBattery : Real;
		in sequenceNum : PacketSequence;
		out transmittedPacket : WirelessDataPacket;
		
		action measure : MeasureTemperature {
			in ambientCondition;
			out measurement;
		}
		
		then succession flow from measure.measurement to createRecord.temperature;
		
		action createRecord : CreateMeasurementRecord {
			in temperature;
			in nodeIdentifier = nodeId;
			in batteryStatus = currentBattery;
			out record;
		}
		
		then succession flow from createRecord.record to encapsulate.measurement;
		
		action encapsulate : EncapsulateInPacket {
			in measurement;
			in source = nodeId;
			in destination = coordinatorId;
			in sequence = sequenceNum;
			out packet;
		}
		
		then succession flow from encapsulate.packet to transmit.packet;
		
		action transmit : TransmitPacket {
			in packet;
			out transmissionSuccess;
		}
		
		bind transmit.packet = transmittedPacket;
	}
	
	state def SensorNodeOperationalStates {
		entry; then initialization;
		
		state initialization;
		
		transition init_to_idle
			first initialization
			then idle;
		
		state idle;
		
		transition idle_to_sensing
			first idle
			accept MeasurementTrigger
			then sensing;
		
		state sensing;
		
		transition sensing_to_processing
			first sensing
			then processing;
		
		state processing;
		
		transition processing_to_transmitting
			first processing
			then transmitting;
		
		state transmitting;
		
		transition transmitting_to_idle
			first transmitting
			if TransmissionComplete
			then idle;
		
		transition transmitting_to_error
			first transmitting
			if TransmissionFailed
			then error;
		
		state error;
		
		transition error_to_idle
			first error
			accept RetryTrigger
			then idle;
		
		transition idle_to_sleep
			first idle
			accept LowBatteryDetected
			then sleep;
		
		state sleep;
	}
	
	state def CoordinatorStates {
		entry; then ready;
		
		state ready;
		
		transition ready_to_receiving
			first ready
			accept PacketArrival
			then receiving;
		
		state receiving;
		
		transition receiving_to_aggregating
			first receiving
			then aggregating;
		
		state aggregating;
		
		transition aggregating_to_ready
			first aggregating
			then ready;
	}
	
	part def TemperatureSensorElement {
		attribute sensorType : String;
		attribute measurementRange : TemperatureValue[2];
		attribute accuracy : Real;
		attribute responseTime : TimeValue;
		port output : SensorOutputPort;
	}
	
	part def MicrocontrollerUnit {
		attribute processorSpeed : FrequencyValue;
		attribute ramSize : Integer;
		attribute flashSize : Integer;
		perform action dataProcessing : CreateMeasurementRecord;
	}
	
	part def RadioTransceiver {
		attribute operatingFrequency : FrequencyValue;
		attribute maxTransmitPower : Real;
		attribute receiveSensitivity : Real;
		attribute dataRate : Real;
		attribute communicationRange : LengthValue;
		port txPort : WirelessTransmitPort;
		port rxPort : WirelessReceivePort;
	}
	
	part def PowerSupply {
		attribute batteryType : String;
		attribute nominalVoltage : Real;
		attribute capacity : Real;
		attribute currentLevel : Real;
	}
	
	part def SensorNode {
		attribute nodeIdentifier : NodeIdentifier;
		attribute measurementInterval : TimeValue;
		attribute packetCounter : PacketSequence;
		
		part temperatureSensor : TemperatureSensorElement[1] {
			attribute :>> sensorType = "NTC Thermistor";
			attribute :>> measurementRange = (233.15[K], 373.15[K]);
			attribute :>> accuracy = 0.5;
			attribute :>> responseTime = 2.0[s];
		}
		
		part mcu : MicrocontrollerUnit[1] {
			attribute :>> processorSpeed = 16.0[MHz];
			attribute :>> ramSize = 2048;
			attribute :>> flashSize = 32768;
		}
		
		part radio : RadioTransceiver[1] {
			attribute :>> operatingFrequency = 2400.0[MHz];
			attribute :>> maxTransmitPower = 20.0;
			attribute :>> receiveSensitivity = -95.0;
			attribute :>> dataRate = 250000.0;
			attribute :>> communicationRange = 100.0[m];
		}
		
		part battery : PowerSupply[1] {
			attribute :>> batteryType = "Lithium CR2032";
			attribute :>> nominalVoltage = 3.0;
			attribute :>> capacity = 220.0;
			attribute :>> currentLevel = 220.0;
		}
		
		exhibit state operationalState : SensorNodeOperationalStates;
		perform action nodeCycle : SensorNodeCycle;
	}
	
	part def CoordinatorNode {
		attribute coordinatorId : NodeIdentifier;
		attribute maxSensorNodes : Integer;
		attribute aggregationWindowSize : Integer;
		
		part receiverRadio : RadioTransceiver[1] {
			attribute :>> operatingFrequency = 2400.0[MHz];
			attribute :>> maxTransmitPower = 20.0;
			attribute :>> receiveSensitivity = -100.0;
			attribute :>> dataRate = 250000.0;
			attribute :>> communicationRange = 150.0[m];
		}
		
		part processingUnit : MicrocontrollerUnit[1] {
			attribute :>> processorSpeed = 48.0[MHz];
			attribute :>> ramSize = 8192;
			attribute :>> flashSize = 131072;
		}
		
		part powerModule : PowerSupply[1] {
			attribute :>> batteryType = "Rechargeable Li-Ion";
			attribute :>> nominalVoltage = 3.7;
			attribute :>> capacity = 2600.0;
			attribute :>> currentLevel = 2600.0;
		}
		
		port aggregationPort : DataAggregationPort;
		
		exhibit state coordinatorState : CoordinatorStates;
		perform action receiveAndAggregate : AggregateMeasurements;
	}
	
	part def WirelessSensingUnit {
		satisfy systemRequirements;
	}
	
	part wirelessSensingSystem : WirelessSensingUnit {
		
		part sensorNodes : SensorNode[6] {
			attribute :>> nodeIdentifier = ("SN_001", "SN_002", "SN_003", "SN_004", "SN_005", "SN_006");
			attribute :>> measurementInterval = 60.0[s];
			attribute :>> packetCounter = 0;
		}
		
		part coordinator : CoordinatorNode[1] {
			attribute :>> coordinatorId = "COORD_MAIN";
			attribute :>> maxSensorNodes = 10;
			attribute :>> aggregationWindowSize = 100;
		}
		
		connection wirelessLinks : WirelessCommunicationLink[6]
			connect transmitter references sensorNodes.radio.txPort
			to receiver references coordinator.receiverRadio.rxPort;
	}
	
	requirement def MeasurementRequirements {
		doc /* The wireless sensing unit shall measure temperature with specified
		 * accuracy and reliability across the sensor network. */
		
		requirement temperatureAccuracy {
			doc /* Temperature measurements shall be accurate within 0.5 Kelvin. */
			subject sensor : TemperatureSensorElement;
			require constraint { sensor.accuracy <= 0.5 }
		}
		
		requirement measurementRange {
			doc /* Sensors shall measure temperature from -40°C to 100°C. */
			subject sensor : TemperatureSensorElement;
			require constraint {
				sensor.measurementRange[0] <= 233.15[K] and
				sensor.measurementRange[1] >= 373.15[K]
			}
		}
		
		requirement wirelessCommunicationRange {
			doc /* Wireless communication range shall be at least 100 meters. */
			subject radio : RadioTransceiver;
			require constraint { radio.communicationRange >= 100.0[m] }
		}
		
		requirement networkCapacity {
			doc /* Coordinator shall support at least 6 sensor nodes. */
			subject coord : CoordinatorNode;
			require constraint { coord.maxSensorNodes >= 6 }
		}
		
		requirement batteryLifetime {
			doc /* Sensor nodes shall operate for at least 6 months on battery. */
			subject node : SensorNode;
			require constraint { node.battery.capacity >= 200.0 }
		}
		
		requirement dataReliability {
			doc /* Packet transmission success rate shall exceed 95%. */
			subject link : WirelessCommunicationLink;
		}
	}
	
	requirement systemRequirements : MeasurementRequirements {
		subject wirelessSensingSystem;
	}
}
