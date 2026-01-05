package 'Vivint Smart Home Security System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def SecurityMode {
		attribute modeType : String;
	}
	
	attribute def AlarmState {
		attribute active : Boolean;
		attribute severity : Integer;
	}
	
	attribute def SensorStatus {
		attribute triggered : Boolean;
		attribute batteryLevel : Real;
		attribute signalStrength : Real;
	}
	
	attribute def UserCredentials {
		attribute userId : String;
		attribute pinCode : Integer;
		attribute accessLevel : Integer;
	}
	
	item def PowerSupply {
		attribute voltage : ISQ::VoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
		attribute frequency : ISQ::FrequencyValue;
	}
	
	item def WirelessData {
		attribute frequency : ISQ::FrequencyValue;
		attribute bandwidth : Real;
		attribute protocol : String;
	}
	
	item def VideoStream {
		attribute resolution : String;
		attribute frameRate : Real;
		attribute bitrate : Real;
	}
	
	port def PowerPort {
		in item power : PowerSupply;
	}
	
	port def WirelessPort {
		in item signal : WirelessData;
		out item signal : WirelessData;
	}
	
	port def SensorDataPort {
		out status : SensorStatus;
	}
	
	port def ControlCommandPort {
		in credentials : UserCredentials;
		in mode : SecurityMode;
		out state : AlarmState;
	}
	
	port def VideoPort {
		out stream : VideoStream;
	}
	
	port def NotificationPort {
		out alert : String;
	}
	
	part def ContactSensor {
		attribute sensorId : String;
		attribute location : String;
		port dataOut : SensorDataPort;
		port wireless : WirelessPort;
		
		attribute currentStatus : SensorStatus {
			attribute triggered = false;
			attribute batteryLevel = 100.0;
			attribute signalStrength = 95.0;
		}
		
		perform action monitorContact {
			out status : SensorStatus;
		}
	}
	
	part def MotionSensor {
		attribute sensorId : String;
		attribute location : String;
		attribute detectionRange : ISQ::LengthValue;
		attribute sensitivity : Real;
		port dataOut : SensorDataPort;
		port wireless : WirelessPort;
		
		attribute currentStatus : SensorStatus {
			attribute triggered = false;
			attribute batteryLevel = 100.0;
			attribute signalStrength = 92.0;
		}
		
		perform action detectMotion {
			out status : SensorStatus;
		}
	}
	
	part def SmartCamera {
		attribute cameraId : String;
		attribute location : String;
		attribute hasNightVision : Boolean;
		attribute hasAudioRecording : Boolean;
		port videoOut : VideoPort;
		port wireless : WirelessPort;
		port powerIn : PowerPort;
		
		perform action captureVideo {
			out stream : VideoStream;
		}
		
		perform action detectPerson {
			out personDetected : Boolean;
		}
	}
	
	part def SmartDoorbell {
		attribute hasCamera : Boolean;
		attribute hasTwoWayAudio : Boolean;
		port videoOut : VideoPort;
		port dataOut : SensorDataPort;
		port wireless : WirelessPort;
		port powerIn : PowerPort;
		
		perform action detectVisitor {
			out visitorPresent : Boolean;
		}
		
		perform action streamVideo {
			out stream : VideoStream;
		}
	}
	
	part def SmartLock {
		attribute lockId : String;
		attribute isLocked : Boolean;
		attribute autoLockEnabled : Boolean;
		port controlIn : ControlCommandPort;
		port wireless : WirelessPort;
		port powerIn : PowerPort;
		
		perform action lockUnlock {
			in credentials : UserCredentials;
			out lockState : Boolean;
		}
	}
	
	part def ControlPanel {
		attribute panelId : String;
		attribute hasTouchscreen : Boolean;
		attribute hasKeypad : Boolean;
		port controlInterface : ControlCommandPort;
		port wireless : WirelessPort;
		port powerIn : PowerPort;
		
		perform action processUserCommand {
			in credentials : UserCredentials;
			in mode : SecurityMode;
			out commandValid : Boolean;
		}
		
		perform action displayStatus {
			in state : AlarmState;
		}
	}
	
	part def CentralHub {
		attribute hubId : String;
		attribute hasBackupBattery : Boolean;
		attribute backupDuration : ISQ::TimeValue;
		port controlPort : ControlCommandPort;
		port wireless : WirelessPort;
		port powerIn : PowerPort;
		port notificationOut : NotificationPort;
		
		attribute systemMode : SecurityMode {
			attribute modeType = "Disarmed";
		}
		
		attribute alarmStatus : AlarmState {
			attribute active = false;
			attribute severity = 0;
		}
		
		perform action coordinateSystem;
		perform action processAlerts;
		perform action manageCommunications;
	}
	
	part def Siren {
		attribute sirenId : String;
		attribute volumeLevel : Real;
		attribute hasStrobe : Boolean;
		port controlIn : ControlCommandPort;
		port powerIn : PowerPort;
		
		perform action soundAlarm {
			in alarmActive : Boolean;
			in severity : Integer;
		}
	}
	
	part def CloudService {
		attribute serviceUrl : String;
		attribute isConnected : Boolean;
		attribute storageCapacity : Real;
		port wireless : WirelessPort;
		port notificationOut : NotificationPort;
		
		perform action storeEventData {
			in eventType : String;
			in eventData : String;
		}
		
		perform action sendMobileNotification {
			in alertMessage : String;
			out notificationSent : Boolean;
		}
		
		perform action processRemoteCommands {
			in credentials : UserCredentials;
			in command : SecurityMode;
			out commandExecuted : Boolean;
		}
		
		perform action provideVideoStorage {
			in stream : VideoStream;
		}
	}
	
	action def MonitorAllSensors {
		in contactStatuses : SensorStatus[*];
		in motionStatuses : SensorStatus[*];
		out threatDetected : Boolean;
		out triggeredLocation : String;
	}
	
	action def EvaluateThreatLevel {
		in sensorStatus : SensorStatus;
		in currentMode : SecurityMode;
		in sensorLocation : String;
		out isValidThreat : Boolean;
		out threatLevel : Integer;
	}
	
	action def ActivateSecurityResponse {
		in threatLevel : Integer;
		in location : String;
		out sirenActivated : Boolean;
		out notificationSent : Boolean;
		out videoRecordingStarted : Boolean;
	}
	
	action def ProcessUserAuthentication {
		in credentials : UserCredentials;
		out authenticated : Boolean;
		out accessGranted : Boolean;
	}
	
	action def ChangeSecurityMode {
		in credentials : UserCredentials;
		in requestedMode : SecurityMode;
		in currentMode : SecurityMode;
		out newMode : SecurityMode;
		out modeChanged : Boolean;
	}
	
	action def SendAlert {
		in alertType : String;
		in alertDetails : String;
		in priority : Integer;
		out alertMessage : String;
	}
	
	part vivintSmartHome : VivintSmartHomeSystem;
	
	part def VivintSmartHomeSystem {
		doc /*
			The Vivint Smart Home Security System is a comprehensive residential 
			security and automation platform that integrates multiple sensors, 
			cameras, smart locks, and control devices to provide continuous 
			monitoring, threat detection, and automated response capabilities 
			for protecting homes and families.
		*/
		
		part hub : CentralHub;
		
		part mainPanel : ControlPanel {
			attribute hasTouchscreen = true;
			attribute hasKeypad = true;
		}
		
		part frontDoorContact : ContactSensor {
			attribute location = "Front Door";
		}
		
		part backDoorContact : ContactSensor {
			attribute location = "Back Door";
		}
		
		part garageDoorContact : ContactSensor {
			attribute location = "Garage Door";
		}
		
		part windowContacts : ContactSensor[8];
		
		part livingRoomMotion : MotionSensor {
			attribute location = "Living Room";
		}
		
		part hallwayMotion : MotionSensor {
			attribute location = "Hallway";
		}
		
		part basementMotion : MotionSensor {
			attribute location = "Basement";
		}
		
		part frontDoorCamera : SmartCamera {
			attribute location = "Front Entrance";
			attribute hasNightVision = true;
			attribute hasAudioRecording = true;
		}
		
		part backyardCamera : SmartCamera {
			attribute location = "Backyard";
			attribute hasNightVision = true;
			attribute hasAudioRecording = false;
		}
		
		part doorbell : SmartDoorbell {
			attribute hasCamera = true;
			attribute hasTwoWayAudio = true;
		}
		
		part frontDoorLock : SmartLock {
			attribute autoLockEnabled = true;
		}
		
		part backDoorLock : SmartLock {
			attribute autoLockEnabled = true;
		}
		
		part garageLock : SmartLock {
			attribute autoLockEnabled = false;
		}
		
		part indoorSiren : Siren {
			attribute volumeLevel = 110.0;
			attribute hasStrobe = true;
		}
		
		part outdoorSiren : Siren {
			attribute volumeLevel = 120.0;
			attribute hasStrobe = true;
		}
		
		part cloud : CloudService {
			attribute storageCapacity = 1000.0;
			attribute isConnected = true;
		}
		
		connection wirelessMesh connect
			hub.wireless to mainPanel.wireless,
			hub.wireless to frontDoorContact.wireless,
			hub.wireless to backDoorContact.wireless,
			hub.wireless to garageDoorContact.wireless,
			hub.wireless to windowContacts.wireless,
			hub.wireless to livingRoomMotion.wireless,
			hub.wireless to hallwayMotion.wireless,
			hub.wireless to basementMotion.wireless,
			hub.wireless to frontDoorCamera.wireless,
			hub.wireless to backyardCamera.wireless,
			hub.wireless to doorbell.wireless,
			hub.wireless to frontDoorLock.wireless,
			hub.wireless to backDoorLock.wireless,
			hub.wireless to garageLock.wireless,
			hub.wireless to cloud.wireless;
		
		perform action secureAndProtect {
			doc /*
				Primary operational behavior that continuously monitors all sensors,
				evaluates threats, manages security modes, and coordinates automated
				responses to protect the home.
			*/
			
			first start;
			then merge continuousMonitoring;
			
			action continuousMonitoring {
				action gatherSensorData : MonitorAllSensors {
					in contactStatuses : SensorStatus[*];
					in motionStatuses : SensorStatus[*];
					out threatDetected : Boolean;
					out triggeredLocation : String;
				}
				
				then decide;
					if gatherSensorData.threatDetected then assessThreat;
					else continuousMonitoring;
				
				action assessThreat : EvaluateThreatLevel {
					in sensorStatus : SensorStatus;
					in currentMode = hub.systemMode;
					in sensorLocation = gatherSensorData.triggeredLocation;
					out isValidThreat : Boolean;
					out threatLevel : Integer;
				}
				
				then decide;
					if assessThreat.isValidThreat then respondToThreat;
					else continuousMonitoring;
				
				action respondToThreat {
					first action activateResponse : ActivateSecurityResponse {
						in threatLevel = assessThreat.threatLevel;
						in location = gatherSensorData.triggeredLocation;
						out sirenActivated : Boolean;
						out notificationSent : Boolean;
						out videoRecordingStarted : Boolean;
					}
					
					then action soundSirens {
						assign indoorSiren.volumeLevel := 110.0;
						assign outdoorSiren.volumeLevel := 120.0;
					}
					
					then action startRecording {
						perform frontDoorCamera.captureVideo;
						perform backyardCamera.captureVideo;
						perform doorbell.streamVideo;
					}
					
					then action notifyUsers : SendAlert {
						in alertType = "INTRUSION_DETECTED";
						in alertDetails = gatherSensorData.triggeredLocation;
						in priority = assessThreat.threatLevel;
						out alertMessage : String;
					}
					
					then action cloudNotify {
						perform cloud.sendMobileNotification {
							in alertMessage = notifyUsers.alertMessage;
						}
					}
					
					then action storeEvent {
						perform cloud.storeEventData {
							in eventType = "ALARM";
							in eventData = notifyUsers.alertMessage;
						}
					}
					
					then continuousMonitoring;
				}
			}
			
			accept userCommand : UserCredentials;
			
			then action authenticate : ProcessUserAuthentication {
				in credentials = userCommand;
				out authenticated : Boolean;
				out accessGranted : Boolean;
			}
			
			then decide;
				if authenticate.authenticated then processCommand;
				else continuousMonitoring;
			
			accept modeRequest : SecurityMode;
			
			action processCommand : ChangeSecurityMode {
				in credentials = userCommand;
				in requestedMode = modeRequest;
				in currentMode = hub.systemMode;
				out newMode : SecurityMode;
				out modeChanged : Boolean;
			}
			
			then assign hub.systemMode := processCommand.newMode;
			
			then continuousMonitoring;
		}
	}
	
	requirement def SystemRequirements {
		doc /* Top-level requirements for Vivint Smart Home Security System */
		
		requirement <'REQ-VIV-001'> continuousProtection {
			doc /*
				The system shall provide continuous 24/7 monitoring of all 
				connected sensors and devices to detect security threats.
			*/
			subject vivintSmartHome : VivintSmartHomeSystem;
		}
		
		requirement <'REQ-VIV-002'> rapidThreatDetection {
			doc /*
				The system shall detect and evaluate security threats within 
				2 seconds of sensor activation.
			*/
			subject vivintSmartHome : VivintSmartHomeSystem;
		}
		
		requirement <'REQ-VIV-003'> automatedResponse {
			doc /*
				Upon confirmed threat detection, the system shall automatically 
				activate sirens, begin video recording, and send notifications 
				within 3 seconds.
			*/
			subject vivintSmartHome : VivintSmartHomeSystem;
		}
		
		requirement <'REQ-VIV-004'> multiDeviceIntegration {
			doc /*
				The system shall integrate and coordinate at least 20 different 
				devices including sensors, cameras, locks, and control panels.
			*/
			subject vivintSmartHome : VivintSmartHomeSystem;
		}
		
		requirement <'REQ-VIV-005'> wirelessReliability {
			doc /*
				All wireless communications shall maintain 99.5% uptime with 
				automatic mesh network healing and cellular backup.
			*/
			subject vivintSmartHome : VivintSmartHomeSystem;
		}
		
		requirement <'REQ-VIV-006'> powerBackup {
			doc /*
				The central hub shall operate on battery backup for minimum 
				24 hours during AC power outage.
			*/
			subject hub : CentralHub;
		}
		
		requirement <'REQ-VIV-007'> remoteAccess {
			doc /*
				Users shall be able to monitor, control, and receive alerts 
				from the system remotely through cloud connectivity.
			*/
			subject cloud : CloudService;
		}
		
		requirement <'REQ-VIV-008'> videoStorage {
			doc /*
				The system shall store video recordings in the cloud for 
				minimum 30 days with encrypted transmission and storage.
			*/
			subject cloud : CloudService;
		}
		
		requirement <'REQ-VIV-009'> smartAutomation {
			doc /*
				The system shall support automated actions such as auto-locking 
				doors, adjusting cameras, and mode changes based on user patterns.
			*/
			subject vivintSmartHome : VivintSmartHomeSystem;
		}
		
		requirement <'REQ-VIV-010'> userAuthentication {
			doc /*
				All system control commands shall require multi-factor 
				authentication with role-based access control.
			*/
			subject vivintSmartHome : VivintSmartHomeSystem;
		}
	}
	
	requirement primaryMission {
		doc /*
			The Vivint Smart Home Security System shall provide comprehensive 
			residential protection by continuously monitoring entry points and 
			interior spaces through integrated sensors and cameras, intelligently 
			detecting and evaluating security threats, automatically responding 
			with sirens and notifications, enabling remote monitoring and control 
			through cloud connectivity, and integrating smart home automation 
			features to enhance safety, convenience, and peace of mind for 
			homeowners and their families.
		*/
		
		require SystemRequirements::continuousProtection;
		require SystemRequirements::rapidThreatDetection;
		require SystemRequirements::automatedResponse;
		require SystemRequirements::multiDeviceIntegration;
		require SystemRequirements::wirelessReliability;
		require SystemRequirements::powerBackup;
		require SystemRequirements::remoteAccess;
		require SystemRequirements::videoStorage;
		require SystemRequirements::smartAutomation;
		require SystemRequirements::userAuthentication;
	}
}
