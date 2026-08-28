package Vitalcall {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types ----
    value def HeartRateValue :> Real { unit 'bpm'; }
    value def SystolicPressure :> Real { unit 'mmHg'; }
    value def DiastolicPressure :> Real { unit 'mmHg'; }
    value def BodyTemperature :> Real { unit 'degC'; }
    value def Latitude :> Real { unit 'deg'; }
    value def Longitude :> Real { unit 'deg'; }
    value def BatteryLevel :> Real { unit 'percent'; }
    value def SignalStrength :> Real { unit 'dBm'; }
    value def ResponseTime :> Real { unit 'min'; }

    // ---- Enumerations ----
    enum def EmergencyType {
        literal ManualButton;
        literal FallDetected;
        literal VitalSignAnomaly;
        literal UserDistress;
    }

    enum def AlertSeverity {
        literal Low;
        literal Medium;
        literal High;
        literal Critical;
    }

    enum def ResponderType {
        literal Paramedic;
        literal EMT;
        literal Police;
        literal Firefighter;
        literal FamilyContact;
    }

    enum def ResponderStatus {
        literal Available;
        literal Dispatched;
        literal EnRoute;
        literal OnScene;
        literal Transporting;
        literal Completed;
        literal OffDuty;
    }

    enum def DeviceState {
        literal Idle;
        literal Monitoring;
        literal EmergencyActive;
        literal LowBattery;
        literal Charging;
    }

    // ---- Item Definitions ----
    item def Location {
        attribute latitude : Latitude;
        attribute longitude : Longitude;
        attribute timestamp : DateTime;
    }

    item def VitalSigns {
        attribute heartRate : HeartRateValue;
        attribute systolic : SystolicPressure;
        attribute diastolic : DiastolicPressure;
        attribute temperature : BodyTemperature;
        attribute measuredAt : DateTime;
    }

    item def MedicalProfile {
        attribute userId : String;
        attribute fullName : String;
        attribute age : Integer;
        attribute bloodType : String;
        attribute preexistingConditions : String[0..*];
        attribute allergies : String[0..*];
        attribute medications : String[0..*];
        attribute emergencyContacts : String[0..*];
        attribute primaryPhysician : String;
    }

    item def EmergencyAlert {
        attribute alertId : String;
        attribute emergencyType : EmergencyType;
        attribute severity : AlertSeverity;
        attribute location : Location;
        attribute vitalSigns : VitalSigns;
        attribute medicalProfile : MedicalProfile;
        attribute timestamp : DateTime;
        attribute deviceSerial : String;
    }

    item def DispatchInstruction {
        attribute instructionId : String;
        attribute alertId : String;
        attribute responderType : ResponderType;
        attribute destination : Location;
        attribute emergencyType : EmergencyType;
        attribute medicalProfile : MedicalProfile;
        attribute priority : AlertSeverity;
        attribute issuedAt : DateTime;
    }

    item def ResponderUpdate {
        attribute instructionId : String;
        attribute responderId : String;
        attribute status : ResponderStatus;
        attribute currentLocation : Location;
        attribute eta : ResponseTime;
        attribute note : String;
        attribute timestamp : DateTime;
    }

    item def Acknowledgement {
        attribute alertId : String;
        attribute receivedAt : DateTime;
        attribute operatorId : String;
    }

    // ---- Port Definitions ----
    port def AlertOutPort {
        out alert : EmergencyAlert;
    }

    port def AlertInPort {
        in alert : EmergencyAlert;
    }

    port def DispatchOutPort {
        out instruction : DispatchInstruction;
    }

    port def DispatchInPort {
        in instruction : DispatchInstruction;
    }

    port def UpdateOutPort {
        out update : ResponderUpdate;
    }

    port def UpdateInPort {
        in update : ResponderUpdate;
    }

    port def AckOutPort {
        out ack : Acknowledgement;
    }

    port def AckInPort {
        in ack : Acknowledgement;
    }

    // ---- Requirements ----
    requirement def VitalcallRequirement {
        subject system : VitalcallSystem;
        doc /* The Vitalcall system shall provide rapid assistance to users in emergencies. */
    }

    requirement def RapidResponseRequirement :> VitalcallRequirement {
        doc /* The system shall detect emergencies and initiate response within 30 seconds. */
        attribute maxDetectionTime : ResponseTime = 0.5;
    }

    requirement def VitalMonitoringRequirement :> VitalcallRequirement {
        doc /* The wearable device shall continuously monitor heart rate, blood pressure, and body temperature. */
    }

    requirement def ManualAlertRequirement :> VitalcallRequirement {
        doc /* The user shall be able to manually trigger an emergency alert via a button press. */
    }

    requirement def FallDetectionRequirement :> VitalcallRequirement {
        doc /* The wearable device shall automatically detect falls and generate an alert. */
    }

    requirement def AlertContentRequirement :> VitalcallRequirement {
        doc /* Alerts shall include emergency type, location, medical profile, and current vital signs. */
    }

    requirement def RelayRequirement :> VitalcallRequirement {
        doc /* The base station shall relay alerts from the wearable device to the monitoring center. */
    }

    requirement def OperatorAssessmentRequirement :> VitalcallRequirement {
        doc /* Monitoring center operators shall assess alert severity and determine response. */
    }

    requirement def DispatchRequirement :> VitalcallRequirement {
        doc /* The monitoring center shall dispatch the nearest available responder with full incident details. */
    }

    requirement def TrackingRequirement :> VitalcallRequirement {
        doc /* The system shall track responder status from dispatch through incident resolution. */
    }

    requirement def AvailabilityRequirement :> VitalcallRequirement {
        doc /* The monitoring center shall be staffed 24/7. */
    }

    // ---- Part Definitions ----
    part def VitalcallSystem {
        requirement satisfaction RapidResponseRequirement by self;
        requirement satisfaction AvailabilityRequirement by self;

        part user : User;
        part wearable : WearableDevice {
            requirement satisfaction VitalMonitoringRequirement by self;
            requirement satisfaction ManualAlertRequirement by self;
            requirement satisfaction FallDetectionRequirement by self;
            requirement satisfaction AlertContentRequirement by self;

            port alertOut : AlertOutPort;
            port ackIn : AckInPort;

            attribute serialNumber : String;
            attribute battery : BatteryLevel;
            attribute firmwareVersion : String;

            part sensors : SensorSuite {
                part heartRateSensor : HeartRateSensor;
                part bloodPressureSensor : BloodPressureSensor;
                part temperatureSensor : TemperatureSensor;
                part accelerometer : Accelerometer;
            }

            part gps : GPSReceiver;
            part profileStore : ProfileStorage;
            part button : EmergencyButton;
            part transmitter : RadioTransmitter;

            state def WearableStateMachine {
                entry; then Idle;
                state Idle;
                transition Idle to Monitoring
                    when battery > 10.0;
                state Monitoring {
                    entry { sensors.heartRateSensor.sample(); sensors.bloodPressureSensor.sample(); sensors.temperatureSensor.sample(); }
                    do { continuouslyMonitor(); }
                }
                transition Monitoring to EmergencyActive
                    when button.pressed or sensors.accelerometer.fallDetected or vitalAnomalyDetected;
                state EmergencyActive {
                    entry { generateAlert(); alertOut.alert.send(); }
                    do { awaitAcknowledgement(); }
                }
                transition EmergencyActive to Monitoring
                    when ackIn.ack.received;
                transition Monitoring to LowBattery
                    when battery <= 10.0;
                state LowBattery {
                    entry { emitLowBatteryWarning(); }
                }
                transition LowBattery to Charging
                    when onCharger;
                state Charging;
                transition Charging to Idle
                    when battery >= 95.0;
            }

            state machine : WearableStateMachine;

            action generateAlert :> Action {
                out alert : EmergencyAlert;
            }
            action continuouslyMonitor :> Action;
            action awaitAcknowledgement :> Action;
            action emitLowBatteryWarning :> Action;
        }

        part baseStation : BaseStation {
            requirement satisfaction RelayRequirement by self;

            port alertIn : AlertInPort;
            port alertOut : AlertOutPort;
            port ackIn : AckInPort;
            port ackOut : AckOutPort;

            attribute stationId : String;
            attribute homeLocation : Location;
            attribute connected : Boolean;

            state def BaseStationStateMachine {
                entry; then Listening;
                state Listening {
                    do { listenForAlerts(); }
                }
                transition Listening to Relaying
                    when alertIn.alert.received;
                state Relaying {
                    entry { forwardAlert(); alertOut.alert.send(); }
                }
                transition Relaying to Listening
                    when ackIn.ack.received;
            }

            state machine : BaseStationStateMachine;

            action listenForAlerts :> Action;
            action forwardAlert :> Action;
        }

        part monitoringCenter : MonitoringCenter {
            requirement satisfaction OperatorAssessmentRequirement by self;
            requirement satisfaction DispatchRequirement by self;
            requirement satisfaction TrackingRequirement by self;

            port alertIn : AlertInPort;
            port ackOut : AckOutPort;
            port dispatchOut : DispatchOutPort;
            port updateIn : UpdateInPort;

            attribute centerId : String;
            attribute staffed : Boolean = true;
            attribute activeIncidents : Integer;

            part operators : Operator[*] {
                attribute operatorId : String;
                attribute onDuty : Boolean;
            }

            part dispatcher : Dispatcher;
            part incidentLog : IncidentLog;

            state def MonitoringCenterStateMachine {
                entry; then Ready;
                state Ready {
                    do { awaitAlert(); }
                }
                transition Ready to Processing
                    when alertIn.alert.received;
                state Processing {
                    entry { acknowledgeAlert(); ackOut.ack.send(); assessSeverity(); }
                    do { determineResponse(); }
                }
                transition Processing to Dispatching
                    when responseDetermined;
                state Dispatching {
                    entry { selectResponder(); dispatchOut.instruction.send(); }
                }
                transition Dispatching to Tracking
                    when dispatchOut.instruction.sent;
                state Tracking {
                    do { trackResponders(); }
                }
                transition Tracking to Ready
                    when incidentResolved;
            }

            state machine : MonitoringCenterStateMachine;

            action awaitAlert :> Action;
            action acknowledgeAlert :> Action;
            action assessSeverity :> Action;
            action determineResponse :> Action;
            action selectResponder :> Action;
            action trackResponders :> Action;
        }

        part responders : EmergencyResponder[*] {
            requirement satisfaction DispatchRequirement by self;

            port dispatchIn : DispatchInPort;
            port updateOut : UpdateOutPort;

            attribute responderId : String;
            attribute responderType : ResponderType;
            attribute status : ResponderStatus = Available;
            attribute homeBase : Location;

            state def ResponderStateMachine {
                entry; then Available;
                state Available {
                    do { awaitDispatch(); }
                }
                transition Available to EnRoute
                    when dispatchIn.instruction.received;
                state EnRoute {
                    entry { acknowledgeDispatch(); updateOut.update.send(); }
                    do { navigateToScene(); }
                }
                transition EnRoute to OnScene
                    when arrivedAtScene;
                state OnScene {
                    entry { updateOut.update.send(); }
                    do { provideAssistance(); }
                }
                transition OnScene to Transporting
                    when transportRequired;
                state Transporting {
                    do { transportPatient(); }
                }
                transition Transporting to Completed
                    when careTransferred;
                state Completed {
                    entry { updateOut.update.send(); }
                }
                transition Completed to Available
                    when cleared;
            }

            state machine : ResponderStateMachine;

            action awaitDispatch :> Action;
            action acknowledgeDispatch :> Action;
            action navigateToScene :> Action;
            action provideAssistance :> Action;
            action transportPatient :> Action;
        }

        // ---- Connections ----
        connection wearable.alertOut to baseStation.alertIn;
        connection baseStation.alertOut to monitoringCenter.alertIn;
        connection monitoringCenter.ackOut to baseStation.ackIn;
        connection baseStation.ackOut to wearable.ackIn;
        connection monitoringCenter.dispatchOut to responders.dispatchIn;
        connection responders.updateOut to monitoringCenter.updateIn;
    }

    // ---- Supporting Part Definitions ----
    part def User {
        attribute userId : String;
        attribute name : String;
        attribute age : Integer;
        attribute medicalProfile : MedicalProfile;
        attribute currentLocation : Location;
    }

    part def WearableDevice {
        attribute serialNumber : String;
    }

    part def BaseStation;

    part def MonitoringCenter;

    part def EmergencyResponder;

    part def SensorSuite;
    part def HeartRateSensor {
        action sample :> Action;
    }
    part def BloodPressureSensor {
        action sample :> Action;
    }
    part def TemperatureSensor {
        action sample :> Action;
    }
    part def Accelerometer {
        attribute fallDetected : Boolean;
    }
    part def GPSReceiver;
    part def ProfileStorage {
        attribute storedProfile : MedicalProfile;
    }
    part def EmergencyButton {
        attribute pressed : Boolean;
    }
    part def RadioTransmitter;

    part def Operator;
    part def Dispatcher;
    part def IncidentLog {
        attribute entries : EmergencyAlert[0..*];
    }

    action def Action;
}
