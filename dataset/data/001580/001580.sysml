package SmartLockSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def AccessCode {
        attribute code : String;
        attribute expirationTime : ISQ::TimeValue;
    }
    
    attribute def BiometricData {
        attribute fingerprintHash : String;
        attribute confidence : Real;
    }
    
    attribute def RemoteCommand {
        attribute commandType : CommandType;
        attribute timestamp : ISQ::TimeValue;
        attribute userId : String;
    }
    
    enum def CommandType {
        lock;
        unlock;
        queryStatus;
    }
    
    enum def AuthenticationMethod {
        keypad;
        biometric;
        remote;
    }
    
    enum def LockStatus {
        locked;
        unlocked;
        jammed;
        error;
    }
    
    port def PowerPort {
        attribute voltage : ISQ::ElectricPotentialDifferenceValue;
        attribute current : ISQ::ElectricCurrentValue;
    }
    
    port def DataPort {
        in attribute inputData : String;
        out attribute outputData : String;
    }
    
    port def SensorPort {
        out attribute sensorValue : Boolean;
    }
    
    part def Battery {
        attribute capacity : ISQ::EnergyValue;
        attribute remainingCharge : ISQ::EnergyValue;
        port powerOutput : PowerPort;
        
        action def SupplyPower {
            in requiredVoltage : ISQ::ElectricPotentialDifferenceValue;
            in requiredCurrent : ISQ::ElectricCurrentValue;
            out suppliedVoltage : ISQ::ElectricPotentialDifferenceValue;
            out suppliedCurrent : ISQ::ElectricCurrentValue;
        }
    }
    
    part def BiometricScanner {
        attribute resolution : Real;
        attribute scanTimeout : ISQ::TimeValue;
        port power : PowerPort;
        port data : DataPort;
        
        action def ScanFingerprint {
            out biometricData : BiometricData;
            out scanSuccess : Boolean;
        }
    }
    
    part def KeypadInterface {
        attribute numberOfKeys : Integer;
        attribute backlightEnabled : Boolean;
        port power : PowerPort;
        port data : DataPort;
        
        action def ReadAccessCode {
            out enteredCode : AccessCode;
            out inputComplete : Boolean;
        }
    }
    
    part def WirelessModule {
        attribute protocol : String;
        attribute signalStrength : Real;
        port power : PowerPort;
        port communication : DataPort;
        
        action def ReceiveRemoteCommand {
            out command : RemoteCommand;
            out commandValid : Boolean;
        }
        
        action def TransmitStatus {
            in currentStatus : LockStatus;
            out transmissionSuccess : Boolean;
        }
    }
    
    part def LockMechanism {
        attribute boltExtension : ISQ::LengthValue;
        attribute motorTorque : ISQ::TorqueValue;
        attribute currentPosition : LockStatus;
        port power : PowerPort;
        port control : DataPort;
        
        action def EngageLock {
            out lockEngaged : Boolean;
            out finalStatus : LockStatus;
        }
        
        action def DisengageLock {
            out lockDisengaged : Boolean;
            out finalStatus : LockStatus;
        }
        
        action def CheckMechanismStatus {
            out mechanismStatus : LockStatus;
        }
    }
    
    part def DoorSensor {
        attribute sensorType : String;
        port sensor : SensorPort;
        
        action def DetectDoorClosed {
            out doorClosed : Boolean;
        }
    }
    
    part def ControlProcessor {
        attribute processorSpeed : ISQ::FrequencyValue;
        attribute memorySize : Real;
        attribute storedAccessCodes : AccessCode[*];
        attribute storedBiometricData : BiometricData[*];
        port power : PowerPort;
        
        action def ValidateAccessCode {
            in enteredCode : AccessCode;
            in validCodes : AccessCode[*];
            out isValid : Boolean;
        }
        
        action def ValidateBiometric {
            in scannedData : BiometricData;
            in storedData : BiometricData[*];
            out isValid : Boolean;
            out matchConfidence : Real;
        }
        
        action def ProcessRemoteCommand {
            in command : RemoteCommand;
            out commandAuthorized : Boolean;
        }
        
        action def DetermineAction {
            in authenticationSuccess : Boolean;
            in method : AuthenticationMethod;
            in doorClosed : Boolean;
            out shouldLock : Boolean;
            out shouldUnlock : Boolean;
        }
    }
    
    part def SmartLock {
        attribute lockIdentifier : String;
        attribute firmwareVersion : String;
        attribute installationDate : ISQ::TimeValue;
        
        part battery : Battery {
            :>> capacity = 54000.0 [SI::J];
            :>> remainingCharge = 45000.0 [SI::J];
        }
        
        part biometricScanner : BiometricScanner {
            :>> resolution = 500.0;
            :>> scanTimeout = 5.0 [SI::s];
        }
        
        part keypad : KeypadInterface {
            :>> numberOfKeys = 12;
            :>> backlightEnabled = true;
        }
        
        part wirelessModule : WirelessModule {
            :>> protocol = "Bluetooth 5.0";
            :>> signalStrength = 0.85;
        }
        
        part lockMechanism : LockMechanism {
            :>> boltExtension = 25.0 [SI::mm];
            :>> motorTorque = 0.5 [SI::'N·m'];
            :>> currentPosition = LockStatus::locked;
        }
        
        part doorSensor : DoorSensor {
            :>> sensorType = "Magnetic Reed";
        }
        
        part controller : ControlProcessor {
            :>> processorSpeed = 120.0 [SI::MHz];
            :>> memorySize = 512.0;
        }
        
        connect battery.powerOutput to biometricScanner.power;
        connect battery.powerOutput to keypad.power;
        connect battery.powerOutput to wirelessModule.power;
        connect battery.powerOutput to lockMechanism.power;
        connect battery.powerOutput to controller.power;
        
        connect keypad.data to controller;
        connect biometricScanner.data to controller;
        connect wirelessModule.communication to controller;
        connect lockMechanism.control to controller;
    }
    
    action def AuthenticateAndControlAccess {
        in ref lock : SmartLock;
        out accessGranted : Boolean;
        out finalLockStatus : LockStatus;
        
        first start;
        then merge waitForAuthentication;
        
        then action checkDoorStatus : DoorSensor::DetectDoorClosed {
            out doorClosed : Boolean;
        }
        
        then decide;
            if checkDoorStatus.doorClosed then proceedWithAuth;
            else rejectDoorOpen;
        
        action rejectDoorOpen {
            then assign accessGranted := false;
            then assign finalLockStatus := LockStatus::error;
        }
        then done;
        
        action proceedWithAuth;
        then merge authenticationInput;
        
        then decide;
            if true then tryKeypad;
            if true then tryBiometric;
            if true then tryRemote;
        
        action tryKeypad {
            action readCode : KeypadInterface::ReadAccessCode {
                out enteredCode : AccessCode;
                out inputComplete : Boolean;
            }
            
            then decide;
                if readCode.inputComplete then validateCode;
                else authenticationInput;
            
            action validateCode : ControlProcessor::ValidateAccessCode {
                in enteredCode = readCode.enteredCode;
                in validCodes = lock.controller.storedAccessCodes;
                out isValid : Boolean;
            }
            
            then decide;
                if validateCode.isValid then unlockDoor;
                else rejectKeypad;
            
            action rejectKeypad;
            then authenticationInput;
        }
        
        action tryBiometric {
            action scanFinger : BiometricScanner::ScanFingerprint {
                out biometricData : BiometricData;
                out scanSuccess : Boolean;
            }
            
            then decide;
                if scanFinger.scanSuccess then validateBiometric;
                else authenticationInput;
            
            action validateBiometric : ControlProcessor::ValidateBiometric {
                in scannedData = scanFinger.biometricData;
                in storedData = lock.controller.storedBiometricData;
                out isValid : Boolean;
                out matchConfidence : Real;
            }
            
            then decide;
                if validateBiometric.isValid then unlockDoor;
                else rejectBiometric;
            
            action rejectBiometric;
            then authenticationInput;
        }
        
        action tryRemote {
            action receiveCommand : WirelessModule::ReceiveRemoteCommand {
                out command : RemoteCommand;
                out commandValid : Boolean;
            }
            
            then decide;
                if receiveCommand.commandValid then processCommand;
                else authenticationInput;
            
            action processCommand : ControlProcessor::ProcessRemoteCommand {
                in command = receiveCommand.command;
                out commandAuthorized : Boolean;
            }
            
            then decide;
                if processCommand.commandAuthorized then handleCommand;
                else rejectRemote;
            
            action handleCommand;
            then decide;
                if receiveCommand.command.commandType == CommandType::unlock then unlockDoor;
                if receiveCommand.command.commandType == CommandType::lock then lockDoor;
                if receiveCommand.command.commandType == CommandType::queryStatus then sendStatus;
            
            action rejectRemote;
            then authenticationInput;
        }
        
        action unlockDoor : LockMechanism::DisengageLock {
            out lockDisengaged : Boolean;
            out finalStatus : LockStatus;
        }
        then action notifyUnlock {
            then assign accessGranted := true;
            then assign finalLockStatus := unlockDoor.finalStatus;
        }
        then action transmitUnlockStatus : WirelessModule::TransmitStatus {
            in currentStatus = unlockDoor.finalStatus;
            out transmissionSuccess : Boolean;
        }
        then waitForAuthentication;
        
        action lockDoor : LockMechanism::EngageLock {
            out lockEngaged : Boolean;
            out finalStatus : LockStatus;
        }
        then action notifyLock {
            then assign accessGranted := false;
            then assign finalLockStatus := lockDoor.finalStatus;
        }
        then action transmitLockStatus : WirelessModule::TransmitStatus {
            in currentStatus = lockDoor.finalStatus;
            out transmissionSuccess : Boolean;
        }
        then waitForAuthentication;
        
        action sendStatus : WirelessModule::TransmitStatus {
            in currentStatus = lock.lockMechanism.currentPosition;
            out transmissionSuccess : Boolean;
        }
        then waitForAuthentication;
    }
    
    state def LockStateMachine {
        entry; then idle;
        
        state idle {
            entry action initializeSystem;
        }
        transition idle to authenticating
            accept authenticationAttempt;
        
        state authenticating {
            entry action processAuthentication;
        }
        transition authenticating to unlocking
            accept authenticationSuccess;
        transition authenticating to idle
            accept authenticationFailure;
        
        state unlocking {
            entry action disengageLockMechanism;
        }
        transition unlocking to unlocked
            accept unlockComplete;
        transition unlocking to error
            accept mechanismJammed;
        
        state unlocked {
            entry action notifyUnlockedState;
        }
        transition unlocked to locking
            accept lockCommand;
        transition unlocked to locking
            accept timeout after 30.0 [SI::s];
        
        state locking {
            entry action engageLockMechanism;
        }
        transition locking to locked
            accept lockComplete;
        transition locking to error
            accept mechanismJammed;
        
        state locked {
            entry action notifyLockedState;
        }
        transition locked to authenticating
            accept authenticationAttempt;
        
        state error {
            entry action notifyErrorState;
        }
        transition error to idle
            accept systemReset;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The smart lock system shall provide secure, keyless access control 
                by authenticating users through multiple methods and automatically 
                actuating the lock mechanism based on successful authentication. */
    }
    
    requirement def MultiFactorAuthenticationRequirement {
        doc /* The system shall support at least three independent authentication 
                methods: access code entry, biometric scanning, and remote wireless commands. */
    }
    
    requirement def FailSecureRequirement {
        doc /* In the event of power loss or system failure, the lock mechanism 
                shall default to the locked state to maintain security. */
    }
    
    requirement def DoorSensorRequirement {
        doc /* The system shall verify the door is properly closed before allowing 
                the lock mechanism to engage, preventing damage to the mechanism. */
    }
    
    requirement def BatteryLifeRequirement {
        doc /* The battery shall provide sufficient power for a minimum of 
                6 months of normal operation under typical usage patterns. */
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The system shall complete authentication and actuate the lock 
                mechanism within 2 seconds of receiving valid credentials. */
    }
    
    requirement <'SL-REQ-001'> smartLockPrimaryFunction : PrimaryFunctionRequirement {
        subject smartLockSystem;
        
        require multiFactorAuth : MultiFactorAuthenticationRequirement;
        require failSecure : FailSecureRequirement;
        require doorSensor : DoorSensorRequirement;
        require batteryLife : BatteryLifeRequirement;
        require responseTime : ResponseTimeRequirement;
    }
    
    part smartLockSystem : SmartLock {
        :>> lockIdentifier = "SL-2024-001";
        :>> firmwareVersion = "2.1.0";
        :>> installationDate = 0.0 [SI::s];
        
        perform action accessControl[*] ordered references AuthenticateAndControlAccess {
            in ref lock = smartLockSystem;
        }
        
        perform stateMachine lockBehavior : LockStateMachine;
    }
    
    satisfy smartLockPrimaryFunction by smartLockSystem;
}
