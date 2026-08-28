package SmartLockSystem {
    import ScalarValues::*;
    import SI::*;

    enum def CommandKind {
        lock;
        unlock;
        queryStatus;
    }
    
    enum def LockStatusKind {
        locked;
        unlocked;
        jammed;
        error;
    }
    
    enum def DoorStateKind {
        open;
        closed;
    }
    
    enum def MotorCommandKind {
        extendBolt;
        retractBolt;
        stopMotor;
    }
    
    enum def AuthResultKind {
        success;
        failure;
    }

    item def AccessCode {
        value digits : String;
    }
    
    item def FingerprintData {
        value template : String;
    }

    value def BatteryVoltage :> Real {
        unit = Volt;
    }
    
    value def ReLockTimeout :> Duration;

    port def KeypadPort {
        in accessCode : AccessCode;
    }
    
    port def BiometricPort {
        in fingerprint : FingerprintData;
    }
    
    port def WirelessInPort {
        in command : CommandKind;
    }
    
    port def WirelessOutPort {
        out status : LockStatusKind;
    }
    
    port def DoorSensorPort {
        in doorState : DoorStateKind;
    }
    
    port def MotorControlPort {
        in motorCmd : MotorCommandKind;
    }
    
    port def PowerPort {
        in voltage : BatteryVoltage;
    }

    requirement def MultiModalAuthentication {
        doc { The system shall support access codes, fingerprints, and remote commands for authentication. }
        subject lockSystem;
    }
    
    requirement def DoorClosedInterlock {
        doc { The system shall verify the door is closed before extending the lock bolt. }
        subject lockSystem;
    }
    
    requirement def AutoReLock {
        doc { The system shall automatically re-lock 30 seconds after unlocking. }
        subject lockSystem;
    }
    
    requirement def FailSecure {
        doc { The system shall remain locked in case of power failure or system error. }
        subject lockSystem;
    }
    
    requirement def StatusReporting {
        doc { The system shall transmit lock status via the wireless module. }
        subject lockSystem;
    }

    part def InternalBattery {
        port powerOut : ~PowerPort;
        attribute capacity : BatteryVoltage = 6.0 [Volt];
        flow powerOut.voltage = capacity;
    }
    
    part def NumericKeypad {
        port keypadOut : ~KeypadPort;
        attribute isBacklit : Boolean = true;
    }
    
    part def BiometricScanner {
        port bioOut : ~BiometricPort;
        attribute resolutionDpi : Integer = 500;
    }
    
    part def WirelessModule {
        port rfIn : WirelessInPort;
        port rfOut : ~WirelessOutPort;
        attribute protocol : String = "Bluetooth";
    }
    
    part def MagneticDoorSensor {
        port sensorOut : ~DoorSensorPort;
    }
    
    part def LockMechanism {
        port motorIn : MotorControlPort;
        attribute currentBoltPosition : LockStatusKind = LockStatusKind::locked;
        attribute isJammed : Boolean = false;
    }

    part def CentralControlProcessor {
        port powerIn : PowerPort;
        port keypadIn : KeypadPort;
        port bioIn : BiometricPort;
        port rfInInternal : ~WirelessInPort;
        port rfOutInternal : WirelessOutPort;
        port sensorIn : DoorSensorPort;
        port motorOut : ~MotorControlPort;
        
        attribute authorizedCodes : AccessCode[*];
        attribute authorizedFingerprints : FingerprintData[*];
        attribute currentStatus : LockStatusKind = LockStatusKind::locked;
        attribute relockTimeout : ReLockTimeout = 30 [s];
        
        private function checkCode(in code : AccessCode) : Boolean;
        private function checkFingerprint(in fp : FingerprintData) : Boolean;
        
        state machine ControlStateMachine {
            state Locked {
                entry { 
                    currentStatus = LockStatusKind::locked; 
                    rfOutInternal.status = currentStatus; 
                }
            }
            state Unlocking {
                entry { motorOut.motorCmd = MotorCommandKind::retractBolt; }
            }
            state Unlocked {
                entry { 
                    currentStatus = LockStatusKind::unlocked; 
                    rfOutInternal.status = currentStatus; 
                }
            }
            state Locking {
                entry { 
                    if (sensorIn.doorState == DoorStateKind::closed) {
                        motorOut.motorCmd = MotorCommandKind::extendBolt;
                    } else {
                        currentStatus = LockStatusKind::error;
                        rfOutInternal.status = currentStatus;
                    }
                }
            }
            state Jammed {
                entry { 
                    currentStatus = LockStatusKind::jammed; 
                    rfOutInternal.status = currentStatus; 
                }
            }
            state Error {
                entry { 
                    currentStatus = LockStatusKind::error; 
                    rfOutInternal.status = currentStatus; 
                }
            }
            
            transition from Locked to Unlocking on keypadIn.accessCode if (checkCode(keypadIn.accessCode));
            transition from Locked to Unlocking on bioIn.fingerprint if (checkFingerprint(bioIn.fingerprint));
            transition from Locked to Unlocking on rfInInternal.command if (rfInInternal.command == CommandKind::unlock);
            
            transition from Unlocking to Unlocked on motorRetractComplete;
            transition from Unlocking to Jammed on motorFault;
            
            transition from Unlocked to Locking on rfInInternal.command if (rfInInternal.command == CommandKind::lock);
            transition from Unlocked to Locking after relockTimeout;
            
            transition from Locking to Locked on motorExtendComplete if (sensorIn.doorState == DoorStateKind::closed);
            transition from Locking to Jammed on motorFault;
            
            transition from Jammed to Error on systemReset;
            transition from Error to Locked on systemReset;
            
            transition from Unlocking to Locked on powerLoss;
            transition from Unlocked to Locked on powerLoss;
            transition from Locking to Locked on powerLoss;
            transition from Jammed to Locked on powerLoss;
            transition from Error to Locked on powerLoss;
        }
    }

    part def SmartLock {
        part battery : InternalBattery;
        part keypad : NumericKeypad;
        part scanner : BiometricScanner;
        part wireless : WirelessModule;
        part doorSensor : MagneticDoorSensor;
        part lockMech : LockMechanism;
        part processor : CentralControlProcessor;
        
        satisfy MultiModalAuthentication;
        satisfy DoorClosedInterlock;
        satisfy AutoReLock;
        satisfy FailSecure;
        satisfy StatusReporting;
        
        connection powerConn connect battery.powerOut to processor.powerIn;
        connection keypadConn connect keypad.keypadOut to processor.keypadIn;
        connection bioConn connect scanner.bioOut to processor.bioIn;
        connection rfInConn connect wireless.rfIn to processor.rfInInternal;
        connection rfOutConn connect processor.rfOutInternal to wireless.rfOut;
        connection sensorConn connect doorSensor.sensorOut to processor.sensorIn;
        connection motorConn connect processor.motorOut to lockMech.motorIn;
    }
}
