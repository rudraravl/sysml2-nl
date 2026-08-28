package Vitalcall {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::s;
	private import SI::min;
	private import Time::TimeInstantValue;

	package Definitions {
		enum def EmergencyType {
			manual;
			fall;
			cardiac;
			respiratory;
			other;
		}

		enum def SeverityLevel {
			low;
			moderate;
			high;
			critical;
		}

		enum def ResponderType {
			paramedic;
			emt;
			police;
			fire;
		}

		enum def ResponderStatusKind {
			idle;
			dispatched;
			enRoute;
			arrived;
			resolved;
		}

		item def ContactInfo {
			attribute name : String;
			attribute phoneNumber : String;
			attribute relationship : String;
		}

		item def MedicalProfile {
			attribute userId : String;
			attribute age : Integer;
			attribute bloodType : String;
			attribute preExistingConditions : String[0..*];
			attribute allergies : String[0..*];
			attribute medications : String[0..*];
			item emergencyContacts : ContactInfo[0..*];
		}

		item def LocationData {
			attribute latitude : Real;
			attribute longitude : Real;
			attribute address : String;
		}

		item def VitalSigns {
			attribute heartRate : FrequencyValue;
			attribute systolicBP : PressureValue;
			attribute diastolicBP : PressureValue;
			attribute bodyTemperature : TemperatureValue;
			attribute oxygenSaturation : Real;
		}

		item def EmergencyAlert {
			attribute alertId : String;
			attribute emergencyType : EmergencyType;
			item location : LocationData;
			item medicalProfile : MedicalProfile;
			item vitalSigns : VitalSigns;
			attribute timestamp : TimeInstantValue;
		}

		item def DispatchInstruction {
			attribute dispatchId : String;
			item alert : EmergencyAlert;
			attribute responderType : ResponderType;
			attribute severity : SeverityLevel;
			attribute dispatchTime : TimeInstantValue;
		}

		item def ResponderStatusUpdate {
			attribute responderId : String;
			attribute status : ResponderStatusKind;
			attribute timestamp : TimeInstantValue;
			attribute estimatedArrival : DurationValue;
		}

		attribute def EmergencyButtonPressed;
		attribute def DeviceAlertSignal;
		attribute def RelayedAlertSignal;
		attribute def AlertAcknowledged;
		attribute def DispatchReceivedSignal;
		attribute def ResponderEnRouteSignal;
		attribute def ResponderArrivedSignal;
		attribute def IncidentResolvedSignal;

		port def AlertOutPort {
			out alert : EmergencyAlert;
		}

		port def AlertInPort {
			in alert : EmergencyAlert;
		}

		port def DispatchOutPort {
			out dispatch : DispatchInstruction;
		}

		port def DispatchInPort {
			in dispatch : DispatchInstruction;
		}

		port def StatusOutPort {
			out statusUpdate : ResponderStatusUpdate;
		}

		port def StatusInPort {
			in statusUpdate : ResponderStatusUpdate;
		}

		action def MonitorVitalSigns {
			out vitalSigns : VitalSigns;
		}

		action def DetectFall {
			out fallDetected : Boolean;
		}

		action def GenerateAlert {
			in emergencyType : EmergencyType;
			in vitalSigns : VitalSigns;
			in location : LocationData;
			in medicalProfile : MedicalProfile;
			out alert : EmergencyAlert;
		}

		action def RelayAlert {
			in alert : EmergencyAlert;
			out relayedAlert : EmergencyAlert;
		}

		action def AssessSeverity {
			in alert : EmergencyAlert;
			out severity : SeverityLevel;
		}

		action def SelectResponder {
			in severity : SeverityLevel;
			in responderType : ResponderType;
			out responderId : String;
		}

		action def CreateDispatch {
			in alert : EmergencyAlert;
			in severity : SeverityLevel;
			in responderId : String;
			out dispatch : DispatchInstruction;
		}

		action def TrackResponder {
			in statusUpdate : ResponderStatusUpdate;
		}

		part def WearableDevice {
			attribute userId : String;
			item medicalProfile : MedicalProfile;
			item currentLocation : LocationData;
			attribute maxHeartRate : FrequencyValue;
			attribute minHeartRate : FrequencyValue;
			attribute maxBodyTemp : TemperatureValue;
			attribute fallDetectionEnabled : Boolean;
			port alertPort : AlertOutPort;
		}

		part def BaseStation {
			port alertInPort : AlertInPort;
			port alertOutPort : AlertOutPort;
		}

		part def MonitoringCenter {
			attribute centerId : String;
			port alertInPort : AlertInPort;
			port dispatchOutPort : DispatchOutPort;
			port statusInPort : StatusInPort;
		}

		part def EmergencyResponder {
			attribute responderId : String;
			attribute responderType : ResponderType;
			attribute available : Boolean;
			item currentLocation : LocationData;
			port dispatchInPort : DispatchInPort;
			port statusOutPort : StatusOutPort;
		}

		part def VitalcallSystem {
			part wearableDevice : WearableDevice;
			part baseStation : BaseStation;
			part monitoringCenter : MonitoringCenter;
			part responders : EmergencyResponder[0..*];
			connection alertRelay1 connect wearableDevice.alertPort to baseStation.alertInPort;
			connection alertRelay2 connect baseStation.alertOutPort to monitoringCenter.alertInPort;
			connection dispatchChannel connect monitoringCenter.dispatchOutPort to responders.dispatchInPort;
			connection statusChannel connect responders.statusOutPort to monitoringCenter.statusInPort;
		}

		requirement def EmergencyDetectionReq {
			doc /* The wearable device shall detect and report emergencies within 5 seconds of occurrence. */
			subject device : WearableDevice;
			attribute detectionTime : DurationValue;
			constraint { detectionTime <= 5 [s] }
		}

		requirement def AlertTransmissionReq {
			doc /* The alert shall be transmitted from the wearable device to the monitoring center within 10 seconds. */
			subject system : VitalcallSystem;
			attribute transmissionTime : DurationValue;
			constraint { transmissionTime <= 10 [s] }
		}

		requirement def ResponseTimeReq {
			doc /* An emergency responder shall arrive at the scene within 15 minutes of dispatch. */
			subject responder : EmergencyResponder;
			attribute responseTime : DurationValue;
			constraint { responseTime <= 15 [min] }
		}

		requirement def ContinuousMonitoringReq {
			doc /* The wearable device shall continuously monitor vital signs and update them at least every 30 seconds. */
			subject device : WearableDevice;
			attribute updateInterval : DurationValue;
			constraint { updateInterval <= 30 [s] }
		}

		requirement def RichAlertDataReq {
			doc /* Each emergency alert shall include emergency type, user location, medical profile, and current vital signs. */
			subject alert : EmergencyAlert;
			constraint { alert.emergencyType != null }
			constraint { alert.location != null }
			constraint { alert.medicalProfile != null }
			constraint { alert.vitalSigns != null }
		}

		requirement def DispatchNearestResponderReq {
			doc /* The monitoring center shall dispatch the nearest available responder with location, emergency nature, and profile. */
			subject center : MonitoringCenter;
		}
	}

	package Usages {
		private import Definitions::*;

		action 'monitor vital signs' : MonitorVitalSigns;
		action 'detect fall' : DetectFall;
		action 'generate alert' : GenerateAlert;
		action 'relay alert' : RelayAlert;
		action 'assess severity' : AssessSeverity;
		action 'select responder' : SelectResponder;
		action 'create dispatch' : CreateDispatch;
		action 'track responder' : TrackResponder;

		part vitalcall : VitalcallSystem {
			:>> wearableDevice {
				state 'device states' parallel {
					state 'operational states' {
						entry; then monitoring;
						state monitoring {
							do 'detect fall';
						}
						accept EmergencyButtonPressed
							do send new DeviceAlertSignal() to baseStation
							then alertGenerated;
						accept when 'detect fall'.fallDetected
							do send new DeviceAlertSignal() to baseStation
							then alertGenerated;
						state alertGenerated;
						accept AlertAcknowledged
							then monitoring;
					}

					state 'health monitoring states' {
						entry; then normalHealth;
						state normalHealth {
							do 'monitor vital signs';
						}
						accept when 'monitor vital signs'.vitalSigns.heartRate > maxHeartRate
							do send new DeviceAlertSignal() to baseStation
							then healthAlert;
						accept when 'monitor vital signs'.vitalSigns.heartRate < minHeartRate
							do send new DeviceAlertSignal() to baseStation
							then healthAlert;
						accept when 'monitor vital signs'.vitalSigns.bodyTemperature > maxBodyTemp
							do send new DeviceAlertSignal() to baseStation
							then healthAlert;
						state healthAlert;
						accept AlertAcknowledged
							then normalHealth;
					}
				}
			}

			:>> baseStation {
				state 'base station states' {
					entry; then idle;
					state idle;
					accept DeviceAlertSignal
						do 'relay alert'
						then relaying;
					state relaying {
						entry send new RelayedAlertSignal() to monitoringCenter;
					}
					accept AlertAcknowledged
						do send new AlertAcknowledged() to wearableDevice
						then idle;
				}
			}

			:>> monitoringCenter {
				state 'monitoring states' {
					entry; then idle;
					state idle;
					accept RelayedAlertSignal
						do send new AlertAcknowledged() to baseStation
						then assessing;
					state assessing {
						do 'assess severity';
					}
					accept after 2 [s]
						do 'select responder'
						then dispatching;
					state dispatching {
						do 'create dispatch';
					}
					accept after 1 [s]
						do send new DispatchReceivedSignal() to responders
						then tracking;
					state tracking {
						entry; then responderDispatched;
						do 'track responder';
						state responderDispatched;
						accept ResponderEnRouteSignal
							then responderEnRoute;
						state responderEnRoute;
						accept ResponderArrivedSignal
							then responderArrived;
						state responderArrived;
					}
					accept IncidentResolvedSignal
						then idle;
				}
			}

			:>> responders {
				state 'responder states' {
					entry; then idle;
					state idle;
					accept DispatchReceivedSignal
						then dispatched;
					state dispatched;
					accept after 2 [min]
						do send new ResponderEnRouteSignal() to monitoringCenter
						then enRoute;
					state enRoute;
					accept after 10 [min]
						do send new ResponderArrivedSignal() to monitoringCenter
						then arrived;
					state arrived;
					accept after 20 [min]
						do send new IncidentResolvedSignal() to monitoringCenter
						then idle;
				}
			}
		}

		requirement edReq : EmergencyDetectionReq {
			:>> detectionTime = 5 [s];
		}
		requirement atReq : AlertTransmissionReq {
			:>> transmissionTime = 10 [s];
		}
		requirement rtReq : ResponseTimeReq {
			:>> responseTime = 15 [min];
		}
		requirement cmReq : ContinuousMonitoringReq {
			:>> updateInterval = 30 [s];
		}
		requirement radReq : RichAlertDataReq;
		requirement dnrReq : DispatchNearestResponderReq;

		satisfy edReq by vitalcall.wearableDevice;
		satisfy cmReq by vitalcall.wearableDevice;
		satisfy atReq by vitalcall;
		satisfy rtReq by vitalcall.responders;
		satisfy radReq by vitalcall.wearableDevice;
		satisfy dnrReq by vitalcall.monitoringCenter;
	}
}
