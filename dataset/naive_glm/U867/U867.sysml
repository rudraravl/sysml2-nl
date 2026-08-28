package SeismometerSystem {

	import ScalarValues::*;
	import ISQ::*;

	// ---------- Value Types ----------
	
	value type MassValue :> Real {
		:>> unit = MassUnit[kg];
	}
	
	value type VoltageValue :> Real {
		:>> unit = PotentialDifferenceUnit[V];
	}
	
	value type FrequencyValue :> Real {
		:>> unit = FrequencyUnit[Hz];
	}
	
	value type DataRateValue :> Real {
		:>> unit = DataRateUnit[bit/s];
	}
	
	value type StorageCapacityValue :> Real {
		:>> unit = DataSizeUnit[GB];
	}
	
	value type DurationValue :> Real {
		:>> unit = TimeUnit[s];
	}
	
	value type AccelerationValue :> Real {
		:>> unit = AccelerationUnit[m/s^2];
	}
	
	value type PowerValue :> Real {
		:>> unit = PowerUnit[W];
	}
	
	value type CurrentValue :> Real {
		:>> unit = ElectricCurrentUnit[A];
	}
	
	// ---------- Item Types ----------
	
	item def GroundMotion {
		attribute amplitude : AccelerationValue;
		attribute frequency : FrequencyValue;
	}
	
	item def AnalogSignal {
		attribute voltage : VoltageValue;
		attribute noiseFloor : VoltageValue;
	}
	
	item def DigitalSample {
		attribute timestamp : DurationValue;
		attribute value : Real;
		attribute sampleRate : FrequencyValue;
	}
	
	item def SeismicEventData {
		attribute eventId : String;
		attribute startTime : DurationValue;
		attribute duration : DurationValue;
		attribute peakAmplitude : AccelerationValue;
		attribute samples : DigitalSample[0..*];
	}
	
	item def PowerFlow {
		attribute voltage : VoltageValue;
		attribute current : CurrentValue;
	}
	
	// ---------- Port Definitions ----------
	
	port def GroundMotionPort {
		out groundMotion : GroundMotion;
	}
	
	port def AnalogSignalPort {
		out signal : AnalogSignal;
	}
	
	port def DigitalDataPort {
		out data : DigitalSample;
	}
	
	port def EventDataPort {
		out eventData : SeismicEventData;
	}
	
	port def PowerPort {
		out power : PowerFlow;
	}
	
	port def CommandPort {
		in command : String;
	}
	
	port def StatusPort {
		out status : String;
	}
	
	// ---------- Requirements ----------
	
	requirement def SeismometerFunctionalRequirement {
		doc /*
		 * The seismometer system shall continuously detect, measure, and analyze
		 * ground motion, then record and transmit data on significant seismic events.
		 */
	}
	
	requirement def DetectionRequirement :> SeismometerFunctionalRequirement {
		doc /*
		 * The system shall detect ground motion using an internal inertial mass
		 * and convert it into an analog electrical signal.
		 */
	}
	
	requirement def AmplificationRequirement :> SeismometerFunctionalRequirement {
		doc /*
		 * The system shall amplify the raw analog signal without introducing
		 * significant noise.
		 */
	}
	
	requirement def SamplingRequirement :> SeismometerFunctionalRequirement {
		doc /*
		 * The ADC shall sample the amplified signal at a high frequency and
		 * produce a digital data stream.
		 */
	}
	
	requirement def ProcessingRequirement :> SeismometerFunctionalRequirement {
		doc /*
		 * The signal processor shall continuously analyze digital data to
		 * distinguish background noise from genuine seismic events.
		 */
	}
	
	requirement def StorageRequirement :> SeismometerFunctionalRequirement {
		doc /*
		 * The data storage unit shall hold at least 30 days of recorded
		 * seismic event information.
		 */
	}
	
	requirement def TransmissionRequirement :> SeismometerFunctionalRequirement {
		doc /*
		 * The communication interface shall transmit event data over a network
		 * to a central monitoring station.
		 */
	}
	
	requirement def PowerRequirement :> SeismometerFunctionalRequirement {
		doc /*
		 * The power supply unit shall manage electrical needs for all internal
		 * components.
		 */
	}
	
	requirement def OperationalModesRequirement :> SeismometerFunctionalRequirement {
		doc /*
		 * The seismometer shall operate in standby, active, recording,
		 * transmitting, and fault modes.
		 */
	}
	
	// ---------- Part Definitions ----------
	
	part def TransducerAssembly {
		port groundMotionPort : GroundMotionPort;
		port analogOutPort : AnalogSignalPort;
		port powerInPort : PowerPort;
		
		attribute inertialMass : MassValue = 0.5 [kg];
		attribute sensitivity : VoltageValue = 10.0 [V/(m/s^2)];
		
		requirement detectionReq : DetectionRequirement;
		
		action def SenseGroundMotion {
			in groundMotion : GroundMotion;
			out analogSignal : AnalogSignal;
		}
		
		private action senseAction : SenseGroundMotion;
	}
	
	part def Amplifier {
		port analogInPort : AnalogSignalPort;
		port analogOutPort : AnalogSignalPort;
		port powerInPort : PowerPort;
		
		attribute gain : Real = 1000.0;
		attribute inputNoiseFloor : VoltageValue = 1.0e-9 [V];
		attribute outputNoiseFloor : VoltageValue = 1.0e-6 [V];
		
		requirement amplificationReq : AmplificationRequirement;
		
		action def AmplifySignal {
			in inputSignal : AnalogSignal;
			out outputSignal : AnalogSignal;
		}
		
		private action amplifyAction : AmplifySignal;
	}
	
	part def AnalogToDigitalConverter {
		port analogInPort : AnalogSignalPort;
		port digitalOutPort : DigitalDataPort;
		port powerInPort : PowerPort;
		
		attribute sampleRate : FrequencyValue = 1000.0 [Hz];
		attribute resolutionBits : Integer = 24;
		attribute inputRange : VoltageValue = 10.0 [V];
		
		requirement samplingReq : SamplingRequirement;
		
		action def ConvertSignal {
			in inputSignal : AnalogSignal;
			out digitalSample : DigitalSample;
		}
		
		private action convertAction : ConvertSignal;
	}
	
	part def SignalProcessor {
		port digitalInPort : DigitalDataPort;
		port eventDataOutPort : EventDataPort;
		port powerInPort : PowerPort;
		port commandPort : CommandPort;
		port statusPort : StatusPort;
		
		attribute processingFrequency : FrequencyValue = 500.0 [MHz];
		attribute detectionThreshold : AccelerationValue = 0.001 [m/s^2];
		attribute noiseProfile : Real;
		
		requirement processingReq : ProcessingRequirement;
		
		action def AnalyzeData {
			in digitalSample : DigitalSample;
			out detectedEvent : SeismicEventData;
		}
		
		action def ClassifyEvent {
			in digitalSample : DigitalSample;
			out eventType : String;
		}
		
		private action analyzeAction : AnalyzeData;
		private action classifyAction : ClassifyEvent;
	}
	
	part def DataStorageUnit {
		port eventDataInPort : EventDataPort;
		port eventDataOutPort : EventDataPort;
		port powerInPort : PowerPort;
		port commandPort : CommandPort;
		port statusPort : StatusPort;
		
		attribute capacity : StorageCapacityValue = 500.0 [GB];
		attribute retentionPeriod : DurationValue = 2592000.0 [s]; // 30 days
		attribute usedSpace : StorageCapacityValue;
		
		requirement storageReq : StorageRequirement;
		
		action def StoreEvent {
			in eventData : SeismicEventData;
		}
		
		action def RetrieveEvent {
			out eventData : SeismicEventData;
		}
		
		private action storeAction : StoreEvent;
		private action retrieveAction : RetrieveEvent;
	}
	
	part def CommunicationInterface {
		port eventDataInPort : EventDataPort;
		port powerInPort : PowerPort;
		port commandPort : CommandPort;
		port statusPort : StatusPort;
		
		attribute networkAddress : String;
		attribute dataRate : DataRateValue = 100.0e6 [bit/s];
		attribute protocol : String = "TCP/IP";
		
		requirement transmissionReq : TransmissionRequirement;
		
		action def TransmitEvent {
			in eventData : SeismicEventData;
		}
		
		private action transmitAction : TransmitEvent;
	}
	
	part def PowerSupplyUnit {
		port powerOutPort : PowerPort;
		port commandPort : CommandPort;
		port statusPort : StatusPort;
		
		attribute outputVoltage : VoltageValue = 12.0 [V];
		attribute maxCurrent : CurrentValue = 5.0 [A];
		attribute maxPower : PowerValue = 60.0 [W];
		attribute batteryBackup : PowerValue = 20.0 [W];
		
		requirement powerReq : PowerRequirement;
		
		action def DistributePower {
			out powerFlow : PowerFlow;
		}
		
		private action distributeAction : DistributePower;
	}
	
	part def CentralMonitoringStation {
		port eventDataInPort : EventDataPort;
		
		attribute stationId : String;
		attribute location : String;
		
		action def ReceiveEvent {
			in eventData : SeismicEventData;
		}
		
		private action receiveAction : ReceiveEvent;
	}
	
	// ---------- Top-Level Seismometer System ----------
	
	part def SeismometerSystem {
		port externalGroundMotionPort : GroundMotionPort;
		port externalCommandPort : CommandPort;
		port externalStatusPort : StatusPort;
		port externalNetworkPort : EventDataPort;
		
		requirement functionalReq : SeismometerFunctionalRequirement;
		requirement modesReq : OperationalModesRequirement;
		
		part transducerAssembly : TransducerAssembly {
			port groundMotionPort : GroundMotionPort;
			port analogOutPort : AnalogSignalPort;
			port powerInPort : PowerPort;
		}
		
		part amplifier : Amplifier {
			port analogInPort : AnalogSignalPort;
			port analogOutPort : AnalogSignalPort;
			port powerInPort : PowerPort;
		}
		
		part adc : AnalogToDigitalConverter {
			port analogInPort : AnalogSignalPort;
			port digitalOutPort : DigitalDataPort;
			port powerInPort : PowerPort;
		}
		
		part signalProcessor : SignalProcessor {
			port digitalInPort : DigitalDataPort;
			port eventDataOutPort : EventDataPort;
			port powerInPort : PowerPort;
			port commandPort : CommandPort;
			port statusPort : StatusPort;
		}
		
		part dataStorage : DataStorageUnit {
			port eventDataInPort : EventDataPort;
			port eventDataOutPort : EventDataPort;
			port powerInPort : PowerPort;
			port commandPort : CommandPort;
			port statusPort : StatusPort;
		}
		
		part communicationInterface : CommunicationInterface {
			port eventDataInPort : EventDataPort;
			port powerInPort : PowerPort;
			port commandPort : CommandPort;
			port statusPort : StatusPort;
		}
		
		part powerSupply : PowerSupplyUnit {
			port powerOutPort : PowerPort;
			port commandPort : CommandPort;
			port statusPort : StatusPort;
		}
		
		part monitoringStation : CentralMonitoringStation {
			port eventDataInPort : EventDataPort;
		}
		
		// ---------- Connections ----------
		
		connection groundMotionConn connect externalGroundMotionPort to transducerAssembly.groundMotionPort;
		
		connection analogSignalConn1 connect transducerAssembly.analogOutPort to amplifier.analogInPort;
		
		connection analogSignalConn2 connect amplifier.analogOutPort to adc.analogInPort;
		
		connection digitalDataConn connect adc.digitalOutPort to signalProcessor.digitalInPort;
		
		connection eventDataConn1 connect signalProcessor.eventDataOutPort to dataStorage.eventDataInPort;
		
		connection eventDataConn2 connect dataStorage.eventDataOutPort to communicationInterface.eventDataInPort;
		
		connection networkConn connect communicationInterface.eventDataInPort to monitoringStation.eventDataInPort;
		
		connection powerConn1 connect powerSupply.powerOutPort to transducerAssembly.powerInPort;
		connection powerConn2 connect powerSupply.powerOutPort to amplifier.powerInPort;
		connection powerConn3 connect powerSupply.powerOutPort to adc.powerInPort;
		connection powerConn4 connect powerSupply.powerOutPort to signalProcessor.powerInPort;
		connection powerConn5 connect powerSupply.powerOutPort to dataStorage.powerInPort;
		connection powerConn6 connect powerSupply.powerOutPort to communicationInterface.powerInPort;
		
		connection commandConn1 connect externalCommandPort to signalProcessor.commandPort;
		connection commandConn2 connect externalCommandPort to dataStorage.commandPort;
		connection commandConn3 connect externalCommandPort to communicationInterface.commandPort;
		connection commandConn4 connect externalCommandPort to powerSupply.commandPort;
		
		connection statusConn1 connect signalProcessor.statusPort to externalStatusPort;
		connection statusConn2 connect dataStorage.statusPort to externalStatusPort;
		connection statusConn3 connect communicationInterface.statusPort to externalStatusPort;
		connection statusConn4 connect powerSupply.statusPort to externalStatusPort;
		
		// ---------- State Machine ----------
		
		enum def SeismometerMode {
			enum standby;
			enum active;
			enum recording;
			enum transmitting;
			enum fault;
		}
		
		state def SeismometerStateMachine {
			entry action initialEntry {
				// Initialize all subsystems
			}
			
			state standby {
				entry action enterStandby {
					// Power on minimal subsystems, await activation command
				}
				do action standbyAction {
					// Monitor for activation command
				}
				exit action exitStandby {
					// Prepare subsystems for active mode
				}
			}
			
			state active {
				entry action enterActive {
					// Enable transducer, amplifier, ADC, and signal processor
				}
				do action activeAction {
					// Continuously sample and analyze ground motion
				}
				exit action exitActive {
					// Transition to recording or standby
				}
			}
			
			state recording {
				entry action enterRecording {
					// Begin storing event data to data storage unit
				}
				do action recordingAction {
					// Record seismic event data until event concludes
				}
				exit action exitRecording {
					// Finalize and close event record
				}
			}
			
			state transmitting {
				entry action enterTransmitting {
					// Activate communication interface
				}
				do action transmittingAction {
					// Transmit event data to central monitoring station
				}
				exit action exitTransmitting {
					// Confirm successful transmission
				}
			}
			
			state fault {
				entry action enterFault {
					// Log fault, disable non-essential subsystems
				}
				do action faultAction {
					// Await reset command
				}
				exit action exitFault {
					// Run self-diagnostics and reinitialize
				}
			}
			
			trans initial standby;
			trans standby active if (commandPort.command == "activate");
			trans active standby if (commandPort.command == "deactivate");
			trans active recording if (signalProcessor.eventDataOutPort.eventData != null);
			trans recording transmitting if (dataStorage.storeAction.done);
			trans transmitting active if (communicationInterface.transmitAction.done);
			trans active fault if (statusPort.status == "error");
			trans standby fault if (statusPort.status == "error");
			trans recording fault if (statusPort.status == "error");
			trans transmitting fault if (statusPort.status == "error");
			trans fault standby if (commandPort.command == "reset");
		}
		
		private state machine seismometerStateMachine : SeismometerStateMachine;
	}
	
}
