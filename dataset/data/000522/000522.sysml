package VitalcallSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def EmergencyType {
        attribute isMedical : Boolean;
        attribute isFall : Boolean;
        attribute isManual : Boolean;
        attribute severity : Integer;
    }
    
    attribute def LocationData {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute address : String;
    }
    
    attribute def VitalSigns {
        attribute heartRate : FrequencyValue;
        attribute bloodPressure : PressureValue;
        attribute bodyTemperature : TemperatureValue;
    }
    
    attribute def UserProfile {
        attribute userId : String;
        attribute name : String;
        attribute age : Integer;
        attribute medicalConditions : String;
        attribute emergencyContacts : String;
    }
    
    item def EmergencyAlert {
        attribute emergencyType : EmergencyType;
        attribute location : LocationData;
        attribute timestamp : TimeValue;
        attribute userProfile : UserProfile;
        attribute vitalSigns : VitalSigns;
    }
    
    item def DispatchInstruction {
        attribute alertId : String;
        attribute responderType : String;
        attribute priority : Integer;
        attribute targetLocation : LocationData;
        attribute estimatedResponseTime : TimeValue;
    }
    
    item def ResponseStatus {
        attribute isDispatched : Boolean;
        attribute isEnRoute : Boolean;
        attribute isOnScene : Boolean;
        attribute estimatedArrival : TimeValue;
    }
    
    port def AlertInputPort {
        in item alert : EmergencyAlert;
    }
    
    port def MonitoringPort {
        in item vitals : VitalSigns;
        out item status : ResponseStatus;
    }
    
    port def DispatchPort {
        out item command : DispatchInstruction;
        in item confirmation : ResponseStatus;
    }
    
    port def CommunicationPort {
        out item notification : EmergencyAlert;
        in item acknowledgment : Boolean;
    }
    
    part def WearableDevice {
        attribute deviceId : String;
        attribute batteryLevel : Real;
        attribute isActive : Boolean;
        
        port emergencyButton : AlertInputPort;
        port vitalMonitor : MonitoringPort;
        
        perform action detectEmergency;
        perform action monitorVitals;
        perform action transmitAlert;
    }
    
    part def BaseStation {
        attribute stationId : String;
        attribute signalStrength : Real;
        
        port deviceLink : CommunicationPort;
        port centerLink : CommunicationPort;
        
        perform action relayAlert;
        perform action maintainConnection;
    }
    
    part def MonitoringCenter {
        attribute centerId : String;
        attribute operatorCount : Integer;
        attribute capacity : Integer;
        
        port alertReceiver : AlertInputPort;
        port dispatcher : DispatchPort;
        
        perform action processAlert;
        perform action assessSituation;
        perform action coordinateResponse;
    }
    
    part def EmergencyResponder {
        attribute responderId : String;
        attribute responderType : String;
        attribute isAvailable : Boolean;
        attribute currentLocation : LocationData;
        
        port commandReceiver : DispatchPort;
        port statusReporter : CommunicationPort;
        
        perform action receiveDispatch;
        perform action navigateToLocation;
        perform action provideAssistance;
    }
    
    action def DetectEmergency {
        in attribute monitoredVitals : VitalSigns;
        in attribute buttonPressed : Boolean;
        in attribute fallDetected : Boolean;
        out attribute emergencyDetected : Boolean;
        out attribute emergencyType : EmergencyType;
    }
    
    action def CreateAlert {
        in attribute emergencyType : EmergencyType;
        in attribute userProfile : UserProfile;
        in attribute alertLocation : LocationData;
        in attribute vitals : VitalSigns;
        out attribute alert : EmergencyAlert;
    }
    
    action def TransmitAlert {
        in attribute alert : EmergencyAlert;
        in attribute destination : String;
        out attribute transmitted : Boolean;
        out attribute transmissionTime : TimeValue;
    }
    
    action def AssessEmergency {
        in attribute alert : EmergencyAlert;
        out attribute priority : Integer;
        out attribute requiredResponderType : String;
        out attribute estimatedResources : Integer;
    }
    
    action def DispatchResponders {
        in attribute priority : Integer;
        in attribute dispatchLocation : LocationData;
        in attribute responderType : String;
        out attribute dispatchCommand : DispatchInstruction;
        out attribute estimatedResponse : TimeValue;
    }
    
    action def MonitorResponse {
        in attribute dispatchCommand : DispatchInstruction;
        in attribute responderStatus : ResponseStatus;
        out attribute responseComplete : Boolean;
        out attribute actualResponseTime : TimeValue;
    }
    
    state def VitalcallOperationalState {
        entry action initializeSystem;
        
        state Monitoring {
            entry action activateMonitoring;
            do action continuousVitalCheck;
        }
        
        state EmergencyDetected {
            entry action captureEmergencyData;
            do action performValidation;
        }
        
        state AlertTransmitting {
            entry action sendAlertToBase;
            do action awaitBaseAcknowledgment;
        }
        
        state AlertRelayed {
            entry action relayToCenter;
            do action awaitCenterAcknowledgment;
        }
        
        state Assessing {
            entry action analyzeEmergency;
            do action calculatePriority;
        }
        
        state Dispatching {
            entry action selectResponders;
            do action issueDispatchCommands;
        }
        
        state ResponseInProgress {
            entry action trackResponders;
            do action monitorStatus;
        }
        
        state Resolved {
            entry action logIncident;
            do action notifyCompletion;
        }
        
        transition monitoring_to_detected
            first Monitoring
            accept emergencyTrigger : EmergencyAlert
            then EmergencyDetected;
        
        transition detected_to_transmitting
            first EmergencyDetected
            then AlertTransmitting;
        
        transition transmitting_to_relayed
            first AlertTransmitting
            accept baseAck : Boolean
            then AlertRelayed;
        
        transition relayed_to_assessing
            first AlertRelayed
            accept centerAck : Boolean
            then Assessing;
        
        transition assessing_to_dispatching
            first Assessing
            then Dispatching;
        
        transition dispatching_to_responding
            first Dispatching
            accept dispatchConfirmation : ResponseStatus
            then ResponseInProgress;
        
        transition responding_to_resolved
            first ResponseInProgress
            then Resolved;
        
        transition resolved_to_monitoring
            first Resolved
            then Monitoring;
    }
    
    action def HandleEmergencyEvent {
        in attribute device : WearableDevice;
        in attribute user : UserProfile;
        out attribute responseDispatched : Boolean;
        out attribute totalResponseTime : TimeValue;
        
        first start;
        
        then action detect : DetectEmergency {
            in monitoredVitals = device.vitalMonitor.vitals;
            in buttonPressed = true;
            in fallDetected = false;
            out emergencyDetected;
            out emergencyType;
        }
        
        then action createAlert : CreateAlert {
            in emergencyType = detect.emergencyType;
            in userProfile = user;
            out alert;
        }
        
        then action transmitToBase : TransmitAlert {
            in alert = createAlert.alert;
            in destination = "BaseStation";
            out transmitted;
            out transmissionTime;
        }
        
        then action relayToCenter : TransmitAlert {
            in alert = createAlert.alert;
            in destination = "MonitoringCenter";
            out transmitted;
            out transmissionTime;
        }
        
        then action assess : AssessEmergency {
            in alert = createAlert.alert;
            out priority;
            out requiredResponderType;
            out estimatedResources;
        }
        
        then action dispatch : DispatchResponders {
            in priority = assess.priority;
            in dispatchLocation = createAlert.alert.location;
            in responderType = assess.requiredResponderType;
            out dispatchCommand;
            out estimatedResponse;
        }
        
        then action monitor : MonitorResponse {
            in dispatchCommand = dispatch.dispatchCommand;
            out responseComplete;
            out actualResponseTime;
        }
        
        then assign responseDispatched := true;
        then assign totalResponseTime := monitor.actualResponseTime;
        then done;
    }
    
    part def Vitalcall {
        doc /* A personal emergency response system that enables individuals, particularly 
                elderly or at-risk users, to quickly summon help in emergency situations. */
        
        part wearableDevice : WearableDevice {
            attribute deviceId = "VCD-001";
            attribute batteryLevel = 85.0;
            attribute isActive = true;
        }
        
        part baseStation : BaseStation {
            attribute stationId = "BS-001";
            attribute signalStrength = 95.0;
        }
        
        part monitoringCenter : MonitoringCenter {
            attribute centerId = "MC-001";
            attribute operatorCount = 12;
            attribute capacity = 100;
        }
        
        part responders : EmergencyResponder[1..*] {
            attribute responderType = "Paramedic";
            attribute isAvailable = true;
        }
        
        connection deviceToBase connect 
            wearableDevice.emergencyButton to baseStation.deviceLink;
        
        connection baseToCenter connect 
            baseStation.centerLink to monitoringCenter.alertReceiver;
        
        connection centerToResponders connect 
            monitoringCenter.dispatcher to responders.commandReceiver;
        
        perform action handleEmergency : HandleEmergencyEvent[*] ordered;
        perform statemachine systemState : VitalcallOperationalState;
    }
    
    requirement def EmergencyResponseRequirement {
        doc /* The system shall detect emergency situations and dispatch appropriate 
                responders within specified time limits to ensure user safety. */
        
        subject vitalcallSystem : Vitalcall;
        
        require constraint maxAlertTransmissionTime {
            doc /* Alert transmission from device to monitoring center shall complete 
                    within 5 seconds. */
            vitalcallSystem.handleEmergency.transmitToBase.transmissionTime + 
            vitalcallSystem.handleEmergency.relayToCenter.transmissionTime <= 5.0[SI::s]
        }
        
        require constraint maxDispatchTime {
            doc /* Emergency responders shall be dispatched within 60 seconds of 
                    alert reception at monitoring center. */
            vitalcallSystem.handleEmergency.dispatch.estimatedResponse <= 60.0[SI::s]
        }
        
        require constraint deviceReliability {
            doc /* Wearable device shall maintain minimum 80% battery level and 
                    active connection status. */
            vitalcallSystem.wearableDevice.batteryLevel >= 80.0 and 
            vitalcallSystem.wearableDevice.isActive == true
        }
        
        require constraint centerCapacity {
            doc /* Monitoring center shall maintain sufficient operator capacity 
                    to handle concurrent emergency alerts. */
            vitalcallSystem.monitoringCenter.operatorCount >= 10
        }
    }
    
    requirement primaryFunction : EmergencyResponseRequirement {
        doc /* The Vitalcall system provides rapid emergency detection, alert transmission, 
                and coordinated dispatch of emergency responders to assist users in critical 
                situations. The system continuously monitors user vital signs and location, 
                processes emergency alerts through a 24/7 monitoring center, and coordinates 
                multi-agency response to ensure timely assistance. The primary function is to 
                reduce emergency response time and improve outcomes for at-risk individuals 
                by providing immediate access to professional emergency services through a 
                simple, wearable interface. */
    }
}
