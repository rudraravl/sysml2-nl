package AugustSmartLock {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types =====
    def LengthUnit :> Real { unit 'mm'; }
    def VoltageUnit :> Real { unit 'V'; }
    def PercentUnit :> Real { unit '%'; }
    def TimeUnit :> Real { unit 's'; }
    def DistanceUnit :> Real { unit 'm'; }
    def CurrentUnit :> Real { unit 'A'; }
    def TorqueUnit :> Real { unit 'N*m'; }
    def FrequencyUnit :> Real { unit 'Hz'; }
    
    value def BatteryVoltage :> VoltageUnit;
    value def BatteryLevel :> PercentUnit;
    value def BoltStroke :> LengthUnit;
    value def MotorCurrent :> CurrentUnit;
    value def MotorTorque :> TorqueUnit;
    value def ProximityDistance :> DistanceUnit;
    value def Timeout :> TimeUnit;
    value def SignalStrength :> PercentUnit;
    
    // ===== Enumerations =====
    enum def LockState {
        value locked;
        value unlocked;
        value locking;
        value unlocking;
        value jammed;
    }
    
    enum def DoorState {
        value open;
        value closed;
        value ajar;
    }
    
    enum def BoltPosition {
        value fullyExtended;
        value fullyRetracted;
        value partial;
    }
    
    enum def AccessMethod {
        value mobileApp;
        value geoFencing;
        value voiceAssistant;
        value keypad;
    }
    
    enum def AuthResult {
        value authorized;
        value denied;
        value unknown;
    }
    
    enum def CommandKind {
        value lock;
        value unlock;
        value status;
        value queryLog;
    }
    
    enum def AlertKind {
        value lowBattery;
        value jamDetected;
        value doorAjar;
        value tamper;
    }
    
    // ===== Item Definitions =====
    item def Command {
        attribute kind : CommandKind;
        attribute source : AccessMethod;
        attribute userId : String;
        attribute timestamp : String;
    }
    
    item def AuthRequest {
        attribute userId : String;
        attribute credentialHash : String;
        attribute method : AccessMethod;
    }
    
    item def AuthResponse {
        attribute result : AuthResult;
        attribute userId : String;
        attribute validUntil : String;
    }
    
    item def BoltDriveSignal {
        attribute direction : CommandKind;
        attribute duration : TimeUnit;
    }
    
    item def MotorFeedback {
        attribute current : MotorCurrent;
        attribute torque : MotorTorque;
        attribute stalled : Boolean;
    }
    
    item def BoltSensorReading {
        attribute position : BoltPosition;
        attribute timestamp : String;
    }
    
    item def DoorSensorReading {
        attribute state : DoorState;
        attribute timestamp : String;
    }
    
    item def ActivityEntry {
        attribute event : String;
        attribute method : AccessMethod;
        attribute result : AuthResult;
        attribute timestamp : String;
        attribute detail : String;
    }
    
    item def Alert {
        attribute kind : AlertKind;
        attribute message : String;
        attribute timestamp : String;
        attribute severity : Integer;
    }
    
    item def BatteryStatus {
        attribute level : BatteryLevel;
        attribute voltage : BatteryVoltage;
        attribute estimatedRemaining : TimeUnit;
    }
    
    item def ProximityEvent {
        attribute distance : ProximityDistance;
        attribute userId : String;
        attribute timestamp : String;
    }
    
    item def WifiFrame {
        attribute ssid : String;
        attribute rssi : SignalStrength;
        attribute payload : String;
    }
    
    item def BluetoothFrame {
        attribute rssi : SignalStrength;
        attribute payload : String;
    }
    
    item def VoiceCommand {
        attribute phrase : String;
        attribute userId : String;
        attribute timestamp : String;
    }
    
    // ===== Port Definitions =====
    port def BluetoothPort {
        out bluetoothTx : BluetoothFrame;
        in bluetoothRx : BluetoothFrame;
    }
    
    port def WifiPort {
        out wifiTx : WifiFrame;
        in wifiRx : WifiFrame;
    }
    
    port def MotorDrivePort {
        out driveSignal : BoltDriveSignal;
        in feedback : MotorFeedback;
    }
    
    port def BoltSensorPort {
        in reading : BoltSensorReading;
    }
    
    port def DoorSensorPort {
        in reading : DoorSensorReading;
    }
    
    port def PowerPort {
        out voltage : BatteryVoltage;
        out status : BatteryStatus;
    }
    
    port def CommandPort {
        in command : Command;
        out response : String;
    }
    
    port def AlertPort {
        out alert : Alert;
    }
    
    port def ActivityLogPort {
        out entry : ActivityEntry;
    }
    
    port def ProximityPort {
        in event : ProximityEvent;
    }
    
    port def VoicePort {
        in command : VoiceCommand;
    }
    
    // ===== Parts =====
    part def BatteryPack {
        port powerOut : PowerPort;
        attribute nominalVoltage : BatteryVoltage = 6.0;
        attribute currentLevel : BatteryLevel = 100;
        attribute lowThreshold : BatteryLevel = 20;
        attribute criticalThreshold : BatteryLevel = 5;
        
        action monitorBattery {
            in level : BatteryLevel;
            return alertNeeded : Boolean;
        }
    }
    
    part def BluetoothModule {
        port btPort : BluetoothPort;
        port commandOut : CommandPort;
        attribute pairingEnabled : Boolean = true;
        attribute maxRange : ProximityDistance = 30.0;
        
        action receiveBluetooth {
            in frame : BluetoothFrame;
            return command : Command;
        }
        
        action sendBluetooth {
            in frame : BluetoothFrame;
        }
    }
    
    part def WifiModule {
        port wifiPort : WifiPort;
        port commandOut : CommandPort;
        port alertOut : AlertPort;
        attribute connected : Boolean = false;
        attribute ssid : String;
        attribute reconnectInterval : Timeout = 30.0;
        
        action receiveWifi {
            in frame : WifiFrame;
            return command : Command;
        }
        
        action sendWifi {
            in frame : WifiFrame;
        }
    }
    
    part def DeadboltAssembly {
        port motorPort : MotorDrivePort;
        port boltSensorOut : BoltSensorPort;
        attribute stroke : BoltStroke = 25.0;
        attribute maxTorque : MotorTorque = 3.0;
        attribute stallCurrent : MotorCurrent = 1.5;
        attribute position : BoltPosition = BoltPosition::fullyExtended;
        
        part motor {
            attribute running : Boolean = false;
            attribute direction : CommandKind;
        }
        
        action driveBolt {
            in signal : BoltDriveSignal;
            return feedback : MotorFeedback;
        }
        
        action readPosition {
            return reading : BoltSensorReading;
        }
    }
    
    part def BoltPositionSensor {
        port sensorOut : BoltSensorPort;
        attribute samplingInterval : Timeout = 0.5;
        
        action sample {
            return reading : BoltSensorReading;
        }
    }
    
    part def DoorPositionSensor {
        port sensorOut : DoorSensorPort;
        attribute samplingInterval : Timeout = 1.0;
        
        action sample {
            return reading : DoorSensorReading;
        }
    }
    
    part def ActivityLog {
        port logIn : ActivityLogPort;
        attribute maxEntries : Integer = 500;
        attribute entries : ActivityEntry[*] ordered;
        
        action record {
            in entry : ActivityEntry;
        }
        
        action retrieve {
            in count : Integer;
            return result : ActivityEntry[*];
        }
    }
    
    part def Authenticator {
        port authIn : CommandPort;
        port authOut : CommandPort;
        attribute authorizedUsers : String[*];
        attribute failedAttempts : Integer = 0;
        attribute maxFailedAttempts : Integer = 5;
        attribute lockoutDuration : Timeout = 60.0;
        
        action authenticate {
            in request : AuthRequest;
            return response : AuthResponse;
        }
    }
    
    part def SmartController {
        port commandIn : CommandPort;
        port authOut : CommandPort;
        port motorControl : MotorDrivePort;
        port boltFeedback : BoltSensorPort;
        port doorFeedback : DoorSensorPort;
        port powerIn : PowerPort;
        port alertOut : AlertPort;
        port logOut : ActivityLogPort;
        port proximityIn : ProximityPort;
        port voiceIn : VoicePort;
        
        attribute currentState : LockState = LockState::locked;
        attribute autoLockDelay : Timeout = 30.0;
        attribute autoUnlockEnabled : Boolean = true;
        attribute geoFenceRadius : ProximityDistance = 5.0;
        attribute obstructionThreshold : MotorCurrent = 1.2;
        
        part authenticator : Authenticator;
        part activityLog : ActivityLog;
        
        action processCommand {
            in cmd : Command;
            out result : String;
        }
        
        action evaluateAutoLock {
            in door : DoorState;
            in bolt : BoltPosition;
            return trigger : Boolean;
        }
        
        action evaluateGeoFence {
            in proximity : ProximityEvent;
            return shouldUnlock : Boolean;
        }
        
        action raiseAlert {
            in kind : AlertKind;
            in message : String;
        }
        
        // State machine describing lock behavior
        state machine LockStateMachine {
            state Locked {
                entry action {
                    // Ensure bolt is extended
                }
                transition Locked -> Unlocking
                    when { commandIn.command?.kind == CommandKind::unlock }
                    guard { authenticator.authenticate(AuthRequest{userId = commandIn.command?.userId, credentialHash = "", method = commandIn.command?.source}).result == AuthResult::authorized }
                    action {
                        logOut.entry << ActivityEntry{event = "unlock requested", method = commandIn.command?.source, result = AuthResult::authorized, timestamp = commandIn.command?.timestamp, detail = "Authorized unlock"};
                    }
                transition Locked -> Jammed
                    when { motorControl.feedback?.stalled == true }
                    action {
                        alertOut.alert << Alert{kind = AlertKind::jamDetected, message = "Bolt jammed during locking", timestamp = "", severity = 2};
                    }
            }
            
            state Unlocked {
                entry action {
                    // Bolt retracted
                }
                transition Unlocked -> Locking
                    when { commandIn.command?.kind == CommandKind::lock }
                    action {
                        logOut.entry << ActivityEntry{event = "lock requested", method = commandIn.command?.source, result = AuthResult::authorized, timestamp = commandIn.command?.timestamp, detail = "Authorized lock"};
                    }
                transition Unlocked -> Locking
                    when { evaluateAutoLock(doorFeedback.reading?.state, boltFeedback.reading?.position) }
                    guard { doorFeedback.reading?.state == DoorState::closed }
                    action {
                        logOut.entry << ActivityEntry{event = "auto-lock triggered", method = AccessMethod::mobileApp, result = AuthResult::authorized, timestamp = "", detail = "Door closed, auto-locking"};
                    }
            }
            
            state Locking {
                entry action {
                    motorControl.driveSignal << BoltDriveSignal{direction = CommandKind::lock, duration = 4.0};
                }
                transition Locking -> Locked
                    when { boltFeedback.reading?.position == BoltPosition::fullyExtended }
                    action {
                        logOut.entry << ActivityEntry{event = "bolt extended", method = AccessMethod::mobileApp, result = AuthResult::authorized, timestamp = "", detail = "Lock complete"};
                    }
                transition Locking -> Jammed
                    when { motorControl.feedback?.stalled == true }
                    action {
                        alertOut.alert << Alert{kind = AlertKind::jamDetected, message = "Obstruction while locking", timestamp = "", severity = 2};
                    }
            }
            
            state Unlocking {
                entry action {
                    motorControl.driveSignal << BoltDriveSignal{direction = CommandKind::unlock, duration = 4.0};
                }
                transition Unlocking -> Unlocked
                    when { boltFeedback.reading?.position == BoltPosition::fullyRetracted }
                    action {
                        logOut.entry << ActivityEntry{event = "bolt retracted", method = AccessMethod::mobileApp, result = AuthResult::authorized, timestamp = "", detail = "Unlock complete"};
                    }
                transition Unlocking -> Jammed
                    when { motorControl.feedback?.stalled == true }
                    action {
                        alertOut.alert << Alert{kind = AlertKind::jamDetected, message = "Obstruction while unlocking", timestamp = "", severity = 2};
                    }
            }
            
            state Jammed {
                entry action {
                    alertOut.alert << Alert{kind = AlertKind::jamDetected, message = "Deadbolt jammed", timestamp = "", severity = 3};
                }
                transition Jammed -> Locked
                    when { commandIn.command?.kind == CommandKind::lock && boltFeedback.reading?.position == BoltPosition::fullyExtended }
                transition Jammed -> Unlocked
                    when { commandIn.command?.kind == CommandKind::unlock && boltFeedback.reading?.position == BoltPosition::fullyRetracted }
                transition Jammed -> Locking
                    when { commandIn.command?.kind == CommandKind::lock && boltFeedback.reading?.position != BoltPosition::fullyExtended }
                transition Jammed -> Unlocking
                    when { commandIn.command?.kind == CommandKind::unlock && boltFeedback.reading?.position != BoltPosition::fullyRetracted }
            }
        }
    }
    
    part def AugustSmartLockSystem {
        part battery : BatteryPack;
        part controller : SmartController;
        part bluetooth : BluetoothModule;
        part wifi : WifiModule;
        part deadbolt : DeadboltAssembly;
        part boltSensor : BoltPositionSensor;
        part doorSensor : DoorPositionSensor;
        
        port externalBluetooth : BluetoothPort;
        port externalWifi : WifiPort;
        port externalAlert : AlertPort;
        port externalProximity : ProximityPort;
        port externalVoice : VoicePort;
        
        connection battery.powerOut to controller.powerIn;
        connection bluetooth.commandOut to controller.commandIn;
        connection wifi.commandOut to controller.commandIn;
        connection controller.motorControl to deadbolt.motorPort;
        connection boltSensor.sensorOut to controller.boltFeedback;
        connection doorSensor.sensorOut to controller.doorFeedback;
        connection deadbolt.boltSensorOut to boltSensor.sensorOut;
        connection bluetooth.btPort to externalBluetooth;
        connection wifi.wifiPort to externalWifi;
        connection controller.alertOut to externalAlert;
        connection externalProximity to controller.proximityIn;
        connection externalVoice to controller.voiceIn;
        connection controller.logOut to controller.activityLog.logIn;
    }
    
    // ===== Requirements =====
    requirement def SecureAccessRequirement {
        doc "The system shall authenticate all lock and unlock requests before executing them."
        attribute maxFailedAttempts : Integer = 5;
        subject lock : AugustSmartLockSystem;
        objective {
            lock.controller.authenticator.authenticate(AuthRequest{userId = "", credentialHash = "", method = AccessMethod::mobileApp}).result == AuthResult::authorized
        }
    }
    
    requirement def KeylessOperationRequirement {
        doc "The system shall provide keyless locking and unlocking via mobile app, geo-fencing, and voice assistant."
        subject lock : AugustSmartLockSystem;
        attribute supportedMethods : AccessMethod[*] = {AccessMethod::mobileApp, AccessMethod::geoFencing, AccessMethod::voiceAssistant};
    }
    
    requirement def DeadboltControlRequirement {
        doc "The controller shall drive the motor to extend or retract the deadbolt within 4 seconds."
        subject lock : AugustSmartLockSystem;
        attribute maxActuationTime : Timeout = 4.0;
    }
    
    requirement def JamDetectionRequirement {
        doc "The system shall detect deadbolt obstruction and enter a jammed state, alerting the user."
        subject lock : AugustSmartLockSystem;
        attribute stallCurrentThreshold : MotorCurrent = 1.2;
    }
    
    requirement def AutoLockRequirement {
        doc "The system shall auto-lock only when the door is confirmed closed."
        subject lock : AugustSmartLockSystem;
        attribute autoLockDelay : Timeout = 30.0;
    }
    
    requirement def BatteryMonitoringRequirement {
        doc "The system shall monitor battery level and alert the user when below 20%."
        subject lock : AugustSmartLockSystem;
        attribute lowBatteryThreshold : BatteryLevel = 20;
    }
    
    requirement def ActivityLoggingRequirement {
        doc "The system shall record all lock, unlock, and failed authentication events in an activity log."
        subject lock : AugustSmartLockSystem;
        attribute minLogCapacity : Integer = 500;
    }
    
    requirement def WirelessConnectivityRequirement {
        doc "The system shall communicate via Bluetooth for short-range and Wi-Fi for remote access."
        subject lock : AugustSmartLockSystem;
        attribute bluetoothRange : ProximityDistance = 30.0;
    }
    
    requirement def DoorPositionSensingRequirement {
        doc "The system shall detect whether the door is open, closed, or ajar."
        subject lock : AugustSmartLockSystem;
    }
    
    requirement def GeoFenceAutoUnlockRequirement {
        doc "The system shall automatically unlock when an authorized user is within the geo-fence radius."
        subject lock : AugustSmartLockSystem;
        attribute geoFenceRadius : ProximityDistance = 5.0;
    }
    
    // ===== Satisfaction =====
    satisfaction SecureAccessRequirement {
        subject lock : AugustSmartLockSystem = AugustSmartLockSystem;
    }
    satisfaction KeylessOperationRequirement {
        subject lock : AugustSmartLockSystem = AugustSmartLockSystem;
    }
    satisfaction DeadboltControlRequirement {
        subject lock : AugustSmartLockSystem = AugustSmartLockSystem;
    }
    satisfaction JamDetectionRequirement {
        subject lock : AugustSmartLockSystem = AugustSmartLockSystem;
    }
    satisfaction AutoLockRequirement {
        subject lock : AugustSmartLockSystem = AugustSmartLockSystem;
    }
    satisfaction BatteryMonitoringRequirement {
        subject lock : AugustSmartLockSystem = AugustSmartLockSystem;
    }
    satisfaction ActivityLoggingRequirement {
        subject lock : AugustSmartLockSystem = AugustSmartLockSystem;
    }
    satisfaction WirelessConnectivityRequirement {
        subject lock : AugustSmartLockSystem = AugustSmartLockSystem;
    }
    satisfaction DoorPositionSensingRequirement {
        subject lock : AugustSmartLockSystem = AugustSmartLockSystem;
    }
    satisfaction GeoFenceAutoUnlockRequirement {
        subject lock : AugustSmartLockSystem = AugustSmartLockSystem;
    }
}
