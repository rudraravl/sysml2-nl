package AugustHomeSmartLockSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def BatteryPercentage :> Real;
    attribute def LockPosition :> Real;
    attribute def SignalStrength :> Real;

    enum def LockState {
        locked;
        unlocked;
        locking;
        unlocking;
        jammed;
    }

    enum def AccessMethod {
        mobileApp;
        keypad;
        autoUnlock;
        physicalKey;
        voiceAssistant;
    }

    enum def DoorPosition {
        open;
        closed;
        ajar;
    }

    item def UnlockRequest {
        attribute method : AccessMethod;
        attribute userId : String;
        attribute timestamp : String;
    }

    item def LockRequest {
        attribute method : AccessMethod;
        attribute userId : String;
        attribute timestamp : String;
    }

    item def StatusReport {
        attribute lockState : LockState;
        attribute batteryLevel : BatteryPercentage;
        attribute doorPosition : DoorPosition;
        attribute timestamp : String;
    }

    item def AccessCredential {
        attribute userId : String;
        attribute authToken : String;
        attribute validUntil : String;
    }

    item def ActivityLog {
        attribute eventType : String;
        attribute userId : String;
        attribute timestamp : String;
        attribute successful : Boolean;
    }

    port def WirelessCommunicationPort {
        in item unlockCmd : UnlockRequest;
        in item lockCmd : LockRequest;
        out item status : StatusReport;
        out item activityLog : ActivityLog;
    }

    port def MotorControlPort {
        out attribute torqueCommand : ISQ::torque;
        in attribute positionFeedback : LockPosition;
    }

    port def SensorDataPort {
        in attribute doorState : DoorPosition;
        in attribute boltPosition : LockPosition;
        in attribute batteryVoltage : ISQ::voltage;
    }

    port def PowerSupplyPort {
        out attribute voltage : ISQ::voltage;
        out attribute current : ISQ::electricCurrent;
    }

    part def SmartLockController {
        port wireless : WirelessCommunicationPort;
        port motorControl : MotorControlPort;
        port sensorInput : SensorDataPort;
        port power : PowerSupplyPort;

        attribute currentState : LockState;
        attribute authorizedUsers : String[*];
        attribute eventHistory : ActivityLog[*];
        attribute batteryStatus : BatteryPercentage;

        perform action manageLockControl;
    }

    part def ElectronicDeadbolt {
        port control : MotorControlPort;
        port powerIn : PowerSupplyPort;

        attribute boltExtension : LockPosition;
        attribute motorTorque : ISQ::torque;

        perform action actuateBolt;
    }

    part def BatteryPack {
        port powerOutput : PowerSupplyPort;

        attribute capacity : ISQ::energy;
        attribute voltage : ISQ::voltage;
        attribute remainingCharge : BatteryPercentage;
    }

    part def BluetoothModule {
        port communication : WirelessCommunicationPort;

        attribute connectionActive : Boolean;
        attribute pairedDevices : String[*];
        attribute signalStrength : SignalStrength;
    }

    part def WiFiModule {
        port communication : WirelessCommunicationPort;

        attribute networkSSID : String;
        attribute ipAddress : String;
        attribute connected : Boolean;
    }

    part def DoorPositionSensor {
        port sensorOutput : SensorDataPort;

        attribute detectedPosition : DoorPosition;
        attribute lastChangeTime : String;
    }

    part def BoltPositionSensor {
        port sensorOutput : SensorDataPort;

        attribute measuredPosition : LockPosition;
        attribute calibrated : Boolean;
    }

    part def MobileApplication {
        attribute installedVersion : String;
        attribute userAccount : String;

        event occurrence unlockButtonPressed;
        event occurrence lockButtonPressed;
        event occurrence statusCheckRequested;
    }

    part def HomeOwner {
        attribute name : String;
        attribute accessLevel : String;

        event occurrence arrivingHome;
        event occurrence leavingHome;
        event occurrence grantingGuestAccess;
    }

    action def AuthenticateAccess {
        in credential : AccessCredential;
        in authorizedList : String[*];
        out isAuthorized : Boolean;
        out accessGranted : Boolean;

        first start;
        then assign isAuthorized := false;
        then assign accessGranted := isAuthorized;
        then done;
    }

    action def CheckProximity {
        in userLocation : ISQ::length;
        in lockLocation : ISQ::length;
        in threshold : ISQ::length;
        out withinRange : Boolean;

        first start;
        then assign withinRange := false;
        then done;
    }

    action def ExecuteLockAction {
        in commandType : String;
        in currentPosition : LockPosition;
        out targetPosition : LockPosition;
        out motorTorque : ISQ::torque;
        out newState : LockState;

        first start;
        then decide;
            if commandType == "lock" then lockSequence;
            if commandType == "unlock" then unlockSequence;

        action lockSequence {
            assign targetPosition := 100.0;
            assign motorTorque := 0.5[N*m];
            assign newState := LockState::locked;
        }

        action unlockSequence {
            assign targetPosition := 0.0;
            assign motorTorque := -0.5[N*m];
            assign newState := LockState::unlocked;
        }

        then done;
    }

    action def RecordActivity {
        in eventType : String;
        in userId : String;
        in timestamp : String;
        in success : Boolean;
        out logEntry : ActivityLog;

        first start;
        then assign logEntry.eventType := eventType;
        then assign logEntry.userId := userId;
        then assign logEntry.timestamp := timestamp;
        then assign logEntry.successful := success;
        then done;
    }

    action def MonitorBatteryHealth {
        in currentVoltage : ISQ::voltage;
        in nominalVoltage : ISQ::voltage;
        out percentageRemaining : BatteryPercentage;
        out lowBatteryAlert : Boolean;

        first start;
        then assign percentageRemaining := 85.0;
        then decide;
            if percentageRemaining < 15.0 then assign lowBatteryAlert := true;
            else assign lowBatteryAlert := false;
        then done;
    }

    state machine def LockControlStateMachine {
        initial state Idle;

        state Idle {
            entry action monitorSensors {
                out batteryLevel : BatteryPercentage;
                out doorStatus : DoorPosition;
                out boltStatus : LockPosition;
            }
        }

        state Locked {
            entry action reportLocked {
                out statusMsg : StatusReport;
            }
        }

        state Unlocked {
            entry action reportUnlocked {
                out statusMsg : StatusReport;
            }
        }

        state Locking {
            entry action engageBolt : ExecuteLockAction {
                in commandType = "lock";
                out targetPosition;
                out motorTorque;
                out newState;
            }
        }

        state Unlocking {
            entry action retractBolt : ExecuteLockAction {
                in commandType = "unlock";
                out targetPosition;
                out motorTorque;
                out newState;
            }
        }

        state Authenticating {
            entry action verifyUser : AuthenticateAccess {
                out isAuthorized;
                out accessGranted;
            }
        }

        state Jammed {
            entry action alertJam {
                out errorMsg : StatusReport;
            }
        }

        transition from Idle to Authenticating
            when unlockRequestReceived;

        transition from Authenticating to Unlocking
            when accessApproved;

        transition from Authenticating to Idle
            when accessDenied;

        transition from Unlocking to Unlocked
            when boltRetracted;

        transition from Unlocking to Jammed
            when mechanicalFailure;

        transition from Unlocked to Locking
            when lockRequestReceived;

        transition from Locking to Locked
            when boltEngaged;

        transition from Locking to Jammed
            when mechanicalFailure;

        transition from Locked to Idle
            when statusCheck;

        transition from Unlocked to Idle
            when statusCheck;

        transition from Jammed to Idle
            when manualReset;
    }

    part augustSmartLock : SmartLockController {
        perform action controlLock;

        part controller : SmartLockController {
            exhibit state machine lockControl : LockControlStateMachine;
        }

        part deadbolt : ElectronicDeadbolt {
            perform actuateBolt;
        }

        part battery : BatteryPack {
            attribute capacity = 3000.0[mA*h];
            attribute voltage = 6.0[V];
            attribute remainingCharge = 85.0;
        }

        part bluetooth : BluetoothModule {
            attribute connectionActive = true;
        }

        part wifi : WiFiModule {
            attribute connected = true;
        }

        part doorSensor : DoorPositionSensor;

        part boltSensor : BoltPositionSensor;

        connect controller.motorControl to deadbolt.control;
        connect controller.power to battery.powerOutput;
        connect deadbolt.powerIn to battery.powerOutput;
        connect controller.wireless to bluetooth.communication;
        connect controller.wireless to wifi.communication;
        connect controller.sensorInput to doorSensor.sensorOutput;
        connect controller.sensorInput to boltSensor.sensorOutput;
    }

    occurrence def SmartLockOperation {
        ref part user : HomeOwner;
        ref part app : MobileApplication;
        ref part lock : augustSmartLock;

        message unlockRequestMsg of unlockReq : UnlockRequest
            from app.unlockButtonPressed to lock.controller.wireless.unlockCmd;

        then message authenticationMsg
            from lock.controller to lock.controller;

        then message motorCommandMsg of torqueCmd : ISQ::torque
            from lock.controller.motorControl.torqueCommand to lock.deadbolt.control.torqueCommand;

        then message positionFeedbackMsg of position : LockPosition
            from lock.deadbolt.control.positionFeedback to lock.controller.motorControl.positionFeedback;

        then message statusUpdateMsg of status : StatusReport
            from lock.controller.wireless.status to app.statusCheckRequested;

        then message activityLogMsg of log : ActivityLog
            from lock.controller.wireless.activityLog to app.statusCheckRequested;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The August Home smart lock system shall provide secure, convenient, and automated access control for residential doors through wireless connectivity and intelligent automation. */

        subject augustSmartLock;

        require constraint {
            doc /* The system shall authenticate all access requests before granting entry. */
        }

        require constraint {
            doc /* The system shall support multiple access methods including mobile app, keypad, auto-unlock, and physical key. */
        }

        require constraint {
            doc /* The system shall maintain an activity log of all lock/unlock events with timestamps and user identification. */
        }
    }

    requirement def SecurityRequirement {
        doc /* The smart lock system shall implement end-to-end encryption for all wireless communications and maintain secure credential storage. */

        subject augustSmartLock;

        require constraint {
            doc /* All wireless transmissions shall use AES-256 encryption. */
        }
    }

    requirement def ReliabilityRequirement {
        doc /* The smart lock system shall operate reliably with battery life exceeding 6 months under normal usage conditions. */

        subject augustSmartLock.battery;

        require constraint {
            doc /* The system shall alert users when battery level drops below 15%. */
        }

        require constraint {
            doc /* The system shall maintain mechanical override capability via physical key. */
        }
    }

    requirement def UsabilityRequirement {
        doc /* The smart lock system shall provide intuitive operation with response time under 2 seconds for lock/unlock commands. */

        subject augustSmartLock;

        require constraint {
            doc /* Auto-unlock shall activate when authorized user is within 10 meters of the door. */
        }
    }

    requirement <'AUG-SYS-001'> augustHomeSystemRequirement {
        doc /* The August Home smart lock system shall provide a comprehensive residential access control solution combining security, convenience, and connectivity. */

        subject augustSmartLock;

        require primaryFunction : PrimaryFunctionRequirement;
        require security : SecurityRequirement;
        require reliability : ReliabilityRequirement;
        require usability : UsabilityRequirement;

        assume constraint {
            doc /* The installation door has a standard deadbolt configuration compatible with August mounting hardware. */
        }

        assume constraint {
            doc /* Bluetooth and WiFi connectivity are available at the installation location. */
        }

        assume constraint {
            doc /* Users have compatible smartphones with the August Home mobile application installed. */
        }
    }
}
