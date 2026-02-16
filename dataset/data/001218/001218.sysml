package 'Radar Tracker System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def TargetID;
	attribute def TrackQuality;
	attribute def ScanMode;
	
	item def RadarPulse {
		attribute frequency : FrequencyValue;
		attribute power : PowerValue;
		attribute pulseWidth : TimeValue;
		attribute transmitTime : TimeValue;
	}
	
	item def EchoReturn {
		attribute range : LengthValue;
		attribute azimuth : PlaneAngleValue;
		attribute elevation : PlaneAngleValue;
		attribute dopplerShift : FrequencyValue;
		attribute signalStrength : PowerValue;
		attribute receiveTime : TimeValue;
	}
	
	item def Position3D {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}
	
	item def Velocity3D {
		attribute vx : SpeedValue;
		attribute vy : SpeedValue;
		attribute vz : SpeedValue;
	}
	
	item def TrackFile {
		attribute id : TargetID;
		attribute position : Position3D;
		attribute velocity : Velocity3D;
		attribute quality : TrackQuality;
		attribute lastUpdate : TimeValue;
		attribute confidence : Real;
	}
	
	item def SteeringCommand {
		attribute azimuth : PlaneAngleValue;
		attribute elevation : PlaneAngleValue;
		attribute scanRate : AngularVelocityValue;
	}
	
	port def RFTransmitPort {
		out transmitPulse : RadarPulse;
	}
	
	port def RFReceivePort {
		in receivedEcho : EchoReturn;
	}
	
	port def TrackDataPort {
		out tracks : TrackFile[*];
	}
	
	port def AntennaControlPort {
		out steeringCmd : SteeringCommand;
		in currentPosition : Position3D;
	}
	
	part def AntennaAssembly {
		port rfTx : RFTransmitPort;
		port rfRx : RFReceivePort;
		port control : AntennaControlPort;
		
		attribute currentAzimuth : PlaneAngleValue;
		attribute currentElevation : PlaneAngleValue;
		attribute beamWidth : PlaneAngleValue;
	}
	
	part def Transmitter {
		port pulseOut : RFTransmitPort;
		
		attribute peakPower : PowerValue;
		attribute operatingFrequency : FrequencyValue;
		attribute pulseRepetitionFrequency : FrequencyValue;
	}
	
	part def Receiver {
		port echoIn : RFReceivePort;
		
		attribute sensitivity : PowerValue;
		attribute noiseFigure : Real;
		attribute bandwidth : FrequencyValue;
	}
	
	part def SignalProcessor {
		attribute detectionThreshold : PowerValue;
		attribute clusteringRadius : LengthValue;
		
		action def FilterClutter {
			in rawEchoes : EchoReturn[*];
			out filteredEchoes : EchoReturn[*];
		}
		
		action def DetectTargets {
			in filteredEchoes : EchoReturn[*];
			out detections : EchoReturn[*];
		}
	}
	
	part def TrackManager {
		attribute maxTracks : Integer;
		attribute trackMemory : TimeValue;
		attribute associationGate : LengthValue;
		
		action def InitiateTrack {
			in detection : EchoReturn;
			out newTrack : TrackFile;
		}
		
		action def UpdateTrack {
			in existingTrack : TrackFile;
			in detection : EchoReturn;
			out updatedTrack : TrackFile;
		}
		
		action def PredictTrack {
			in track : TrackFile;
			in deltaTime : TimeValue;
			out predictedTrack : TrackFile;
		}
		
		action def CorrelateDetections {
			in predictions : TrackFile[*];
			in detections : EchoReturn[*];
			out correlatedTracks : TrackFile[*];
			out uncorrelatedDetections : EchoReturn[*];
		}
		
		action def PruneTracks {
			in tracks : TrackFile[*];
			in currentTime : TimeValue;
			out activeTracks : TrackFile[*];
		}
	}
	
	part def RadarTrackerSystem {
		port trackOutput : TrackDataPort;
		
		part antenna : AntennaAssembly;
		part transmitter : Transmitter;
		part receiver : Receiver;
		part signalProcessor : SignalProcessor;
		part trackManager : TrackManager;
		
		connect transmitter.pulseOut to antenna.rfTx;
		connect antenna.rfRx to receiver.echoIn;
		
		perform action primaryOperation : ContinuousTrackingOperation;
	}
	
	action def TransmitRadarPulse {
		out pulse : RadarPulse;
	}
	
	action def ReceiveEchoes {
		in timeWindow : TimeValue;
		out rawEchoes : EchoReturn[*];
	}
	
	action def ContinuousTrackingOperation {
		out trackData : TrackFile[*];
		
		private attribute activeTrackFile : TrackFile[*] := ( );
		private attribute currentTime : TimeValue;
		
		first start;
		then merge trackingLoop;
		
		action initializeRadar {
			action powerUpTransmitter;
			then action calibrateReceiver;
			then action positionAntenna;
		}
		
		then trackingLoop;
		
		action trackingCycle {
			action transmitPulse : TransmitRadarPulse {
				out pulse : RadarPulse;
			}
			
			then action waitForEchoes {
				in maxRange : LengthValue;
				out echoWindow : TimeValue;
			}
			
			then action collectEchoes : ReceiveEchoes {
				in timeWindow = waitForEchoes.echoWindow;
				out rawEchoes : EchoReturn[*];
			}
			
			then action processSignals {
				in echoes = collectEchoes.rawEchoes;
				
				action filterClutter {
					in rawEchoes = echoes;
					out filtered : EchoReturn[*];
				}
				
				then action detectTargets {
					in filtered = filterClutter.filtered;
					out detections : EchoReturn[*];
				}
			}
			
			then action manageTracking {
				in detections = processSignals.detectTargets.detections;
				in existingTracks = activeTrackFile;
				
				action predictAllTracks {
					in tracks = existingTracks;
					in deltaT : TimeValue;
					out predictions : TrackFile[*];
				}
				
				then action correlate {
					in predicted = predictAllTracks.predictions;
					in newDetections = detections;
					out associated : TrackFile[*];
					out unassociated : EchoReturn[*];
				}
				
				then decide;
					if correlate.associated->size() > 0 then updateTracks;
					if correlate.unassociated->size() > 0 then initiateTracks;
				
				action updateTracks {
					in associatedTracks = correlate.associated;
					out updated : TrackFile[*];
				}
				
				action initiateTracks {
					in unassociatedDetections = correlate.unassociated;
					out newTracks : TrackFile[*];
				}
				
				then merge consolidateTracks;
				
				action consolidateTracks {
					in updatedTracks : TrackFile[*];
					in newTracks : TrackFile[*];
					out combined : TrackFile[*];
				}
				
				then action pruneTracks {
					in allTracks = consolidateTracks.combined;
					in time = currentTime;
					out activeTracks : TrackFile[*];
				}
			}
			
			then assign activeTrackFile := manageTracking.pruneTracks.activeTracks;
			
			then action steerAntenna {
				in tracks = activeTrackFile;
				out command : SteeringCommand;
			}
			
			then action outputTracks {
				in tracks = activeTrackFile;
				out publishedTracks : TrackFile[*];
			}
			
			then assign trackData := outputTracks.publishedTracks;
		}
		
		then trackingLoop;
	}
	
	state def RadarOperationalStates {
		entry; then idle;
		
		state idle {
			entry assign mode := 'Standby';
		}
		
		state searching {
			entry assign mode := 'Search';
			do action wideScan;
		}
		
		state tracking {
			entry assign mode := 'Track';
			do action focusedScan;
		}
		
		state multiTarget {
			entry assign mode := 'MultiTrack';
			do action interleavedScan;
		}
		
		transition idleToSearch
			first idle
			accept powerOn
			then searching;
		
		transition searchToTrack
			first searching
			accept targetDetected
			if detectionCount >= 1
			then tracking;
		
		transition trackToMulti
			first tracking
			accept additionalTarget
			if trackCount > 1
			then multiTarget;
		
		transition multiToTrack
			first multiTarget
			accept trackLost
			if trackCount == 1
			then tracking;
		
		transition trackToSearch
			first tracking
			accept allTracksLost
			if trackCount == 0
			then searching;
		
		transition anyToIdle
			first searching, tracking, multiTarget
			accept powerOff
			then idle;
		
		attribute mode : ScanMode;
		attribute detectionCount : Integer;
		attribute trackCount : Integer;
	}
	
	requirement def SystemRequirement;
	
	requirement <'RT-SYS-001'> primaryTrackingRequirement : SystemRequirement {
		doc /* The Radar Tracker System shall continuously detect and track multiple targets 
		       in three-dimensional space by transmitting electromagnetic pulses, receiving 
		       reflected echoes, processing returns to identify targets, correlating detections 
		       with existing tracks, and maintaining accurate position and velocity estimates 
		       for each tracked target throughout its observable trajectory. */
		
		subject radarSystem : RadarTrackerSystem;
		
		require constraint detectionCapability {
			doc /* The system shall detect targets within operational range and sensitivity limits. */
		}
		
		require constraint trackInitiation {
			doc /* The system shall initiate new tracks for unassociated detections meeting quality criteria. */
		}
		
		require constraint trackMaintenance {
			doc /* The system shall update existing tracks with correlated detections using prediction and filtering. */
		}
		
		require constraint multiTargetHandling {
			doc /* The system shall simultaneously maintain tracks for multiple independent targets. */
		}
	}
	
	requirement <'RT-SYS-002'> performanceRequirement : SystemRequirement {
		doc /* The Radar Tracker System shall maintain track accuracy and update rate 
		       sufficient for operational effectiveness under specified conditions. */
		
		assume constraint environmentalConditions {
			doc /* System operates within specified temperature, humidity, and electromagnetic environment. */
		}
		
		assume constraint targetCharacteristics {
			doc /* Targets have minimum radar cross-section and velocity within system design parameters. */
		}
		
		require primaryTrackingRequirement;
		
		require constraint updateRate {
			doc /* Track updates shall occur at minimum specified frequency to ensure continuity. */
		}
		
		require constraint positionAccuracy {
			doc /* Track position estimates shall maintain accuracy within specified error bounds. */
		}
		
		require constraint velocityAccuracy {
			doc /* Track velocity estimates shall maintain accuracy within specified error bounds. */
		}
	}
	
	requirement <'RT-SYS-003'> reliabilityRequirement : SystemRequirement {
		doc /* The Radar Tracker System shall operate reliably with minimal track loss 
		       and false track initiation under normal operating conditions. */
		
		require constraint trackContinuity {
			doc /* The system shall maintain track continuity through temporary signal loss or interference. */
		}
		
		require constraint falseTrackRate {
			doc /* The system shall limit false track initiation rate to acceptable levels. */
		}
		
		require constraint trackDropRate {
			doc /* The system shall limit premature track termination rate to acceptable levels. */
		}
	}
}
