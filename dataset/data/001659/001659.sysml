package HomeRFWirelessSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MACAddress;
	attribute def NetworkID;
	attribute def TimeSlot;
	attribute def EncryptionKey;
	
	value def FrequencyBand {
		attribute lowerBound : FrequencyValue;
		attribute upperBound : FrequencyValue;
	}
	
	attribute def DataRateUnit;
	
	item def VoiceFrame {
		attribute sourceMAC : MACAddress;
		attribute destMAC : MACAddress;
		attribute voicePayload : Real[*];
		attribute timestamp : TimeValue;
	}
	
	item def DataFrame {
		attribute sourceMAC : MACAddress;
		attribute destMAC : MACAddress;
		attribute dataPayload : String;
		attribute priority : Integer;
	}
	
	item def BeaconFrame {
		attribute networkID : NetworkID;
		attribute hopSequence : FrequencyValue[*];
		attribute timeSlotMap : TimeSlot[*];
	}
	
	item def AssociationRequest {
		attribute deviceMAC : MACAddress;
	}
	
	port def RFTransceiverPort {
		out txSignal : PowerValue;
		in rxSignal : PowerValue;
		attribute operatingFreq : FrequencyValue;
		attribute channelBandwidth : FrequencyValue;
	}
	
	port def VoiceInterfacePort {
		in voiceInput : VoiceFrame;
		out voiceOutput : VoiceFrame;
	}
	
	port def DataInterfacePort {
		in dataInput : DataFrame;
		out dataOutput : DataFrame;
	}
	
	port def NetworkControlPort {
		in controlCommand : String;
		out statusReport : String;
	}
	
	part def ControlPoint {
		doc /* Central coordinator managing network access and routing. */
		
		attribute macAddress : MACAddress;
		attribute networkID : NetworkID;
		attribute hopPattern : FrequencyValue[*];
		attribute beaconInterval : TimeValue;
		attribute maxConnectedDevices : Integer = 127;
		
		port rfPort : RFTransceiverPort;
		port voiceGateway : VoiceInterfacePort;
		port dataGateway : DataInterfacePort;
		port controlPort : NetworkControlPort;
		
		part macLayer : MACController;
		part frequencyHopper : FrequencyHoppingController;
		part voiceCodec : VoiceCodec;
		part dataRouter : DataRouter;
		part securityEngine : SecurityEngine;
		part beaconGenerator : BeaconGenerator;
		
		perform action manageNetwork;
	}
	
	part def WirelessDevice {
		doc /* Mobile device connecting to HomeRF network. */
		
		attribute macAddress : MACAddress;
		attribute deviceType : String;
		attribute assignedSlot : TimeSlot;
		attribute powerLevel : PowerValue;
		
		port rfPort : RFTransceiverPort;
		port userVoicePort : VoiceInterfacePort;
		port userDataPort : DataInterfacePort;
		port deviceControl : NetworkControlPort;
		
		part transceiver : RFTransceiver;
		part macClient : MACClient;
		part applicationProcessor : ApplicationProcessor;
		part powerManager : PowerManager;
		
		perform action communicateWithNetwork;
	}
	
	part def MACController {
		attribute connectedDevices : MACAddress[0..127];
		attribute slotAllocation : TimeSlot[*];
		perform action allocateTimeSlots;
		perform action manageAccess;
	}
	
	part def FrequencyHoppingController {
		attribute currentChannel : FrequencyValue;
		attribute hopSequence : FrequencyValue[*];
		attribute hopRate : FrequencyValue;
		perform action performHopping;
	}
	
	part def VoiceCodec {
		perform action encodeVoice;
		perform action decodeVoice;
	}
	
	part def DataRouter {
		perform action routeData;
		perform action prioritizeTraffic;
	}
	
	part def SecurityEngine {
		attribute encryptionEnabled : Boolean;
		attribute securityKey : EncryptionKey;
		perform action encryptFrame;
		perform action decryptFrame;
		perform action authenticate;
	}
	
	part def BeaconGenerator {
		perform action generateBeacon;
		perform action broadcastBeacon;
	}
	
	part def RFTransceiver {
		perform action transmitSignal;
		perform action receiveSignal;
		perform action tuneFrequency;
	}
	
	part def MACClient {
		perform action synchronizeWithBeacon;
		perform action requestSlot;
	}
	
	part def ApplicationProcessor {
		perform action processVoice;
		perform action processData;
	}
	
	part def PowerManager {
		attribute batteryLevel : Real;
		perform action optimizePower;
		perform action enterSleepMode;
	}
	
	action def InitializeNetwork {
		in networkID : NetworkID;
		in hopPattern : FrequencyValue[*];
		out initSuccess : Boolean;
	}
	
	action def AssociateDevice {
		in deviceMAC : MACAddress;
		out assignedSlot : TimeSlot;
		out associationSuccess : Boolean;
	}
	
	action def TransmitVoiceData {
		in voiceFrame : VoiceFrame;
		in destinationMAC : MACAddress;
		out transmitSuccess : Boolean;
	}
	
	action def TransmitDataPacket {
		in dataFrame : DataFrame;
		in destinationMAC : MACAddress;
		out transmitSuccess : Boolean;
	}
	
	action def PerformFrequencyHop {
		in currentFreq : FrequencyValue;
		in hopSequence : FrequencyValue[*];
		out nextFreq : FrequencyValue;
	}
	
	state def DeviceConnectionState {
		entry; then disconnected;
		
		state disconnected {
			doc /* Device not associated with network. */
		}
		
		transition disconnected_to_scanning
			first disconnected
			then scanning;
		
		state scanning {
			entry; then listenForBeacon;
			action listenForBeacon;
			then evaluateBeacon;
			action evaluateBeacon;
		}
		
		transition scanning_to_associating
			first scanning
			then associating;
		
		state associating {
			entry; then sendAssociationRequest;
			action sendAssociationRequest;
			then waitForAssignment;
			action waitForAssignment;
		}
		
		transition associating_to_connected
			first associating
			then connected;
		
		transition associating_to_scanning
			first associating
			then scanning;
		
		state connected {
			doc /* Device actively communicating on network. */
			
			state active {
				state transmitting;
				state receiving;
				state idle;
			}
			
			state powerSave;
		}
		
		transition connected_to_disconnected
			first connected
			then disconnected;
	}
	
	action def ProvideIntegratedWirelessCommunication {
		doc /* Primary system function: simultaneous voice and data over shared RF. */
		
		in voiceTraffic : VoiceFrame[*];
		in dataTraffic : DataFrame[*];
		in hopSequence : FrequencyValue[*];
		in beaconPeriod : TimeValue;
		out deliveredVoice : VoiceFrame[*] := ( );
		out deliveredData : DataFrame[*] := ( );
		
		private attribute currentFrequency : FrequencyValue;
		private attribute activeDevices : MACAddress[*] := ( );
		private attribute slotSchedule : TimeSlot[*] := ( );
		
		first start;
		then action initialize : InitializeNetwork {
			in networkID;
			in hopPattern = hopSequence;
			out initSuccess;
		}
		then merge networkLoop;
		
		loop {
			action broadcastBeacon {
				action generateBeaconFrame {
					out beacon : BeaconFrame;
				}
				then action transmitBeacon {
					in beaconFrame = generateBeaconFrame.beacon;
				}
			}
			then merge trafficHandling;
			
			action handleAssociation {
				accept req : AssociationRequest;
				then action associate : AssociateDevice {
					in deviceMAC = req.deviceMAC;
					out assignedSlot;
					out associationSuccess;
				}
			}
			then trafficHandling;
			
			action processTraffic {
				decide;
					if true then handleVoice;
					if true then handleData;
				
				action handleVoice {
					for vFrame in voiceTraffic {
						action transmitVoice : TransmitVoiceData {
							in voiceFrame = vFrame;
							in destinationMAC = vFrame.destMAC;
							out transmitSuccess;
						}
					}
				}
				
				action handleData {
					for dFrame in dataTraffic {
						action transmitData : TransmitDataPacket {
							in dataFrame = dFrame;
							in destinationMAC = dFrame.destMAC;
							out transmitSuccess;
						}
					}
				}
			}
			then action hopFrequency : PerformFrequencyHop {
				in currentFreq = currentFrequency;
				in hopSequence;
				out nextFreq;
			}
			then assign currentFrequency := hopFrequency.nextFreq;
			then networkLoop;
		}
	}
	
	part def HomeRFNetworkSystem {
		attribute systemNetworkID : NetworkID;
		attribute operatingBand : FrequencyBand;
		attribute numberOfChannels : Integer = 50;
		attribute maxSupportedDevices : Integer = 127;
		attribute nominalDataRate : Real = 1.6;
		attribute peakDataRate : Real = 10.0;
		
		part controlPoint : ControlPoint;
		part devices : WirelessDevice[1..127];
	}
	
	part homeRFNetwork : HomeRFNetworkSystem {
		doc /* 
		 * HomeRF wireless network system providing integrated voice and data
		 * communication services for residential and small office environments
		 * using frequency hopping spread spectrum in the 2.4 GHz ISM band.
		 */
		
		attribute systemNetworkID;
		attribute operatingBand {
			attribute lowerBound = 2400.0;
			attribute upperBound = 2483.5;
		}
		attribute numberOfChannels = 50;
		attribute maxSupportedDevices = 127;
		attribute nominalDataRate = 1.6;
		attribute peakDataRate = 10.0;
		
		part controlPoint : ControlPoint {
			attribute macAddress;
			attribute networkID = homeRFNetwork.systemNetworkID;
			attribute hopPattern;
			attribute beaconInterval = 100.0;
		}
		
		part devices : WirelessDevice[1..127] {
			attribute macAddress;
			attribute deviceType;
		}
		
		connection rfLinks : WirelessConnection
			connect controlPoint.rfPort to devices.rfPort;
		
		perform action primaryOperation : ProvideIntegratedWirelessCommunication {
			in voiceTraffic;
			in dataTraffic;
			in hopSequence = controlPoint.hopPattern;
			in beaconPeriod = controlPoint.beaconInterval;
			out deliveredVoice;
			out deliveredData;
		}
		
		part controlPoint.macLayer {
			perform primaryOperation.handleAssociation;
		}
		
		part controlPoint.frequencyHopper {
			perform primaryOperation.hopFrequency;
		}
		
		part controlPoint.beaconGenerator {
			perform primaryOperation.broadcastBeacon;
		}
		
		part controlPoint.voiceCodec {
			perform primaryOperation.handleVoice;
		}
		
		part controlPoint.dataRouter {
			perform primaryOperation.handleData;
		}
	}
	
	connection def WirelessConnection {
		end controllerEnd : RFTransceiverPort;
		end deviceEnd : RFTransceiverPort[1..*];
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* 
		 * The HomeRF system shall provide simultaneous wireless voice and data
		 * communication services to multiple devices within a home or small office.
		 */
		subject system : HomeRFNetworkSystem;
	}
	
	requirement def FrequencyBandRequirement {
		doc /* The system shall operate in the 2.4 GHz ISM band (2400-2483.5 MHz). */
		subject system : HomeRFNetworkSystem;
		require constraint {
			system.operatingBand.lowerBound == 2400.0 and
			system.operatingBand.upperBound == 2483.5
		}
	}
	
	requirement def DataRateRequirement {
		doc /* The system shall support data rates from 1.6 Mbps to 10 Mbps. */
		subject system : HomeRFNetworkSystem;
		require constraint {
			system.nominalDataRate >= 1.6 and
			system.peakDataRate <= 10.0
		}
	}
	
	requirement def DeviceCapacityRequirement {
		doc /* The system shall support up to 127 simultaneous wireless devices. */
		subject system : HomeRFNetworkSystem;
		require constraint {
			system.maxSupportedDevices == 127
		}
	}
	
	requirement def FrequencyHoppingRequirement {
		doc /* 
		 * The system shall employ frequency hopping spread spectrum (FHSS)
		 * across 50 channels for interference avoidance and security.
		 */
		subject system : HomeRFNetworkSystem;
		require constraint {
			system.numberOfChannels == 50
		}
	}
	
	requirement def VoiceQualityRequirement {
		doc /* The system shall maintain voice quality with latency under 25ms. */
		subject cp : ControlPoint;
	}
	
	requirement def SecurityRequirement {
		doc /* The system shall provide encryption for all transmitted data. */
		subject cp : ControlPoint;
		require constraint {
			cp.securityEngine.encryptionEnabled == true
		}
	}
	
	requirement homeRFSystemRequirements {
		doc /* Top-level requirements for HomeRF wireless communication system. */
		
		require r1 : PrimaryFunctionRequirement;
		require r2 : FrequencyBandRequirement;
		require r3 : DataRateRequirement;
		require r4 : DeviceCapacityRequirement;
		require r5 : FrequencyHoppingRequirement;
		require r6 : VoiceQualityRequirement;
		require r7 : SecurityRequirement;
	}
}
