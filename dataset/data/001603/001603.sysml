package TelephoneSwitchboardSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def PhoneNumber;
	attribute def LineIdentifier;
	attribute def ConnectionIdentifier;
	
	item def AudioSignal {
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute frequency : ISQ::FrequencyValue;
	}
	
	item def CallRequest {
		attribute originatingLine : PhoneNumber;
		attribute destinationLine : PhoneNumber;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def ConnectionRecord {
		attribute connectionId : ConnectionIdentifier;
		attribute caller : PhoneNumber;
		attribute receiver : PhoneNumber;
		attribute startTime : ISQ::TimeValue;
		attribute duration : ISQ::TimeValue;
	}
	
	attribute def LineState {
		attribute isIdle : Boolean;
		attribute isRinging : Boolean;
		attribute isConnected : Boolean;
		attribute isOffHook : Boolean;
	}
	
	port def SubscriberLinePort {
		in audioIn : AudioSignal;
		out audioOut : AudioSignal;
		attribute lineNumber : PhoneNumber;
		attribute lineState : LineState;
	}
	
	port def TrunkPort {
		in trunkAudioIn : AudioSignal;
		out trunkAudioOut : AudioSignal;
		attribute trunkId : LineIdentifier;
	}
	
	port def OperatorPort {
		in operatorAudioIn : AudioSignal;
		out operatorAudioOut : AudioSignal;
		in callRequestIn : CallRequest;
		out connectionStatusOut : ConnectionRecord;
	}
	
	part def SubscriberLine {
		attribute phoneNumber : PhoneNumber;
		attribute currentState : LineState {
			attribute isIdle = true;
			attribute isRinging = false;
			attribute isConnected = false;
			attribute isOffHook = false;
		}
		port linePort : SubscriberLinePort;
	}
	
	part def SwitchingMatrix {
		attribute matrixCapacity : Integer;
		attribute activeConnectionCount : Integer;
		port inputPorts : SubscriberLinePort[100];
		port outputPorts : SubscriberLinePort[100];
		
		action def CreateConnection {
			in sourceLineNumber : PhoneNumber;
			in destinationLineNumber : PhoneNumber;
			out connectionId : ConnectionIdentifier;
			out success : Boolean;
		}
		
		action def TerminateConnection {
			in connectionId : ConnectionIdentifier;
			out success : Boolean;
		}
		
		action def RouteAudio {
			in sourcePort : SubscriberLinePort;
			in destinationPort : SubscriberLinePort;
			in audioSignal : AudioSignal;
		}
	}
	
	part def OperatorConsole {
		attribute operatorId : LineIdentifier;
		port operatorInterface : OperatorPort;
		
		action def AnswerIncomingCall {
			in callRequest : CallRequest;
			out acknowledged : Boolean;
		}
		
		action def DetermineDestination {
			in originatingLine : PhoneNumber;
			out destinationLine : PhoneNumber;
			out routingValid : Boolean;
		}
		
		action def InitiateConnection {
			in caller : PhoneNumber;
			in receiver : PhoneNumber;
			out connectionRequested : Boolean;
		}
	}
	
	part def SignalGenerator {
		action def GenerateDialTone {
			out signal : AudioSignal {
				attribute voltage = 48.0;
				attribute frequency = 350.0;
			}
		}
		
		action def GenerateRingingSignal {
			out signal : AudioSignal {
				attribute voltage = 90.0;
				attribute frequency = 20.0;
			}
		}
		
		action def GenerateBusySignal {
			out signal : AudioSignal {
				attribute voltage = 48.0;
				attribute frequency = 480.0;
			}
		}
	}
	
	part def CallRecordingSystem {
		attribute records : ConnectionRecord[*];
		
		action def LogConnection {
			in connectionInfo : ConnectionRecord;
			out logged : Boolean;
		}
		
		action def RetrieveRecord {
			in connectionId : ConnectionIdentifier;
			out record : ConnectionRecord;
		}
	}
	
	action def MonitorLineStatus {
		in lineNumber : PhoneNumber;
		out currentState : LineState;
	}
	
	action def DetectOffHook {
		in lineNumber : PhoneNumber;
		out offHookDetected : Boolean;
	}
	
	action def EstablishPhysicalConnection {
		in callerLine : PhoneNumber;
		in receiverLine : PhoneNumber;
		out connectionEstablished : Boolean;
		out connectionId : ConnectionIdentifier;
	}
	
	action def ReleasePhysicalConnection {
		in connectionId : ConnectionIdentifier;
		out released : Boolean;
	}
	
	action def RouteCall {
		in originatingLine : PhoneNumber;
		out callRouted : Boolean;
		
		first start;
		then merge monitoringLoop;
		
		action detectOffHook : DetectOffHook {
			in lineNumber = originatingLine;
			out offHookDetected;
		}
		
		then decide;
			if detectOffHook.offHookDetected then provideDialTone;
			if !detectOffHook.offHookDetected then monitoringLoop;
		
		action provideDialTone : SignalGenerator::GenerateDialTone {
			out signal;
		}
		
		then action notifyOperator {
			action createRequest {
				out callRequest : CallRequest;
			}
		}
		
		then action operatorAnswers : OperatorConsole::AnswerIncomingCall {
			in callRequest = notifyOperator.createRequest.callRequest;
			out acknowledged;
		}
		
		then action getDestination : OperatorConsole::DetermineDestination {
			in originatingLine = originatingLine;
			out destinationLine;
			out routingValid;
		}
		
		then decide;
			if getDestination.routingValid then checkDestinationAvailable;
			if !getDestination.routingValid then playBusySignal;
		
		action checkDestinationAvailable : MonitorLineStatus {
			in lineNumber = getDestination.destinationLine;
			out currentState;
		}
		
		then decide;
			if checkDestinationAvailable.currentState.isIdle then ringDestination;
			if !checkDestinationAvailable.currentState.isIdle then playBusySignal;
		
		action ringDestination : SignalGenerator::GenerateRingingSignal {
			out signal;
		}
		
		then action establishConnection : EstablishPhysicalConnection {
			in callerLine = originatingLine;
			in receiverLine = getDestination.destinationLine;
			out connectionEstablished;
			out connectionId;
		}
		
		then action maintainConnection {
			action monitorActiveCall : MonitorLineStatus {
				in lineNumber = originatingLine;
				out currentState;
			}
			
			then decide;
				if monitorActiveCall.currentState.isConnected then monitorActiveCall;
				if !monitorActiveCall.currentState.isConnected then releaseConnection;
		}
		
		action releaseConnection : ReleasePhysicalConnection {
			in connectionId = establishConnection.connectionId;
			out released;
		}
		
		then action logCall : CallRecordingSystem::LogConnection {
			in connectionInfo : ConnectionRecord;
			out logged;
		}
		
		then done;
		
		action playBusySignal : SignalGenerator::GenerateBusySignal {
			out signal;
		}
		
		then monitoringLoop;
	}
	
	part def TelephoneSwitchboard {
		doc /*
			The telephone switchboard establishes temporary electrical connections between
			subscriber telephone lines by routing audio signals through a switching matrix
			under operator control, enabling voice communication between remote parties.
		*/
		
		part subscriberLines : SubscriberLine[100];
		
		part switchingMatrix : SwitchingMatrix {
			attribute matrixCapacity = 100;
			attribute activeConnectionCount = 0;
		}
		
		part operatorConsoles : OperatorConsole[5];
		
		part signalGenerator : SignalGenerator;
		
		part recordingSystem : CallRecordingSystem;
		
		port externalTrunks : TrunkPort[10];
		
		connection subscriberToMatrix connect 
			subscriberLines.linePort to switchingMatrix.inputPorts;
		
		connection matrixToSubscriber connect 
			switchingMatrix.outputPorts to subscriberLines.linePort;
		
		perform action routeIncomingCalls[*] ordered {
			in originatingLine : PhoneNumber;
			out callRouted : Boolean;
			
			first start;
			then merge monitoringLoop;
			
			action detectOffHook : DetectOffHook {
				in lineNumber = originatingLine;
				out offHookDetected;
			}
			
			then decide;
				if detectOffHook.offHookDetected then provideDialTone;
				if !detectOffHook.offHookDetected then monitoringLoop;
			
			action provideDialTone : SignalGenerator::GenerateDialTone {
				out signal;
			}
			
			then action notifyOperator {
				action createRequest {
					out callRequest : CallRequest;
				}
			}
			
			then action operatorAnswers : OperatorConsole::AnswerIncomingCall {
				in callRequest = notifyOperator.createRequest.callRequest;
				out acknowledged;
			}
			
			then action getDestination : OperatorConsole::DetermineDestination {
				in originatingLine = originatingLine;
				out destinationLine;
				out routingValid;
			}
			
			then decide;
				if getDestination.routingValid then checkDestinationAvailable;
				if !getDestination.routingValid then playBusySignal;
			
			action checkDestinationAvailable : MonitorLineStatus {
				in lineNumber = getDestination.destinationLine;
				out currentState;
			}
			
			then decide;
				if checkDestinationAvailable.currentState.isIdle then ringDestination;
				if !checkDestinationAvailable.currentState.isIdle then playBusySignal;
			
			action ringDestination : SignalGenerator::GenerateRingingSignal {
				out signal;
			}
			
			then action establishConnection : EstablishPhysicalConnection {
				in callerLine = originatingLine;
				in receiverLine = getDestination.destinationLine;
				out connectionEstablished;
				out connectionId;
			}
			
			then action maintainConnection {
				action monitorActiveCall : MonitorLineStatus {
					in lineNumber = originatingLine;
					out currentState;
				}
				
				then decide;
					if monitorActiveCall.currentState.isConnected then monitorActiveCall;
					if !monitorActiveCall.currentState.isConnected then releaseConnection;
			}
			
			action releaseConnection : ReleasePhysicalConnection {
				in connectionId = establishConnection.connectionId;
				out released;
			}
			
			then action logCall : CallRecordingSystem::LogConnection {
				in connectionInfo : ConnectionRecord;
				out logged;
			}
			
			then done;
			
			action playBusySignal : SignalGenerator::GenerateBusySignal {
				out signal;
			}
			
			then monitoringLoop;
		}
	}
	
	part switchboard : TelephoneSwitchboard;
	
	requirement <'SWB-REQ-001'> primaryFunctionRequirement {
		doc /*
			The telephone switchboard shall establish bidirectional audio connections
			between any two subscriber lines by creating temporary electrical paths
			through the switching matrix under operator supervision.
		*/
		
		subject sb : TelephoneSwitchboard;
		
		require constraint {
			doc /* 
				The switchboard must route audio signals from caller to receiver
				and from receiver to caller simultaneously during active connections.
			*/
		}
	}
	
	requirement <'SWB-REQ-002'> connectionCapacityRequirement {
		doc /*
			The switchboard shall support at least 50 simultaneous active connections
			between subscriber lines without degradation of service quality.
		*/
		
		subject sb : TelephoneSwitchboard;
		
		require constraint {
			sb.switchingMatrix.activeConnectionCount <= 50
		}
	}
	
	requirement <'SWB-REQ-003'> connectionTimeRequirement {
		doc /*
			The switchboard shall establish a complete audio connection between
			caller and receiver within 15 seconds of operator receiving the call request.
		*/
		
		subject sb : TelephoneSwitchboard;
		
		attribute maxConnectionTime : ISQ::TimeValue = 15.0;
	}
	
	requirement <'SWB-REQ-004'> signalIntegrityRequirement {
		doc /*
			The switchboard shall maintain audio signal voltage within ±5% of nominal
			48V for all active connections to ensure clear voice transmission.
		*/
		
		subject sb : TelephoneSwitchboard;
	}
	
	requirement <'SWB-REQ-005'> recordKeepingRequirement {
		doc /*
			The switchboard shall record the originating line, destination line,
			connection time, and duration for every completed call for billing
			and operational analysis purposes.
		*/
		
		subject crs : CallRecordingSystem;
	}
}
