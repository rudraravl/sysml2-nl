package 'Smart Lock System' {
    private import ScalarValues::*;
    private import ISQ::*;

    value type DurationValue :> Real;
    unit s : DurationValue;

    attribute def AccessCode;
    attribute def FingerprintData;
    attribute def UnlockCommand;
    attribute def LockCommand;
    attribute def AuthSuccess;
    attribute def AuthFailure;
    attribute def SystemError;
    attribute def PowerLoss;
    attribute def PowerRestored;

    attribute def StatusSignal;
    attribute def LockedStatus :> StatusSignal;
    attribute def UnlockedStatus :> StatusSignal;
    attribute def ErrorStatus :> StatusSignal;
    attribute def JammedStatus :> StatusSignal;

    attribute def EngageBoltCommand;
    attribute def RetractBoltCommand;
    attribute def BoltEngagedSignal;
    attribute def BoltRetractedSignal;
    attribute def BoltJammedSignal;

    attribute def DoorClosedSignal;
    attribute def DoorOpenSignal;

    action def AuthenticateCode { in code : AccessCode; out success : Boolean; }
    action def AuthenticateBiometric { in print : FingerprintData; out success : Boolean; }
    action def AuthenticateCommand { in cmd : UnlockCommand; out success : Boolean; }

    port def KeypadPort { out code : AccessCode; }
    port def BiometricPort { out print : FingerprintData; }
    port def WirelessCmdPort { out unlock : UnlockCommand; out lock : LockCommand; }
    port def WirelessStatusPort { out status : StatusSignal; }
    port def DoorSensorPort { out closed : DoorClosedSignal; }
    port def LockControlPort { out engage : EngageBoltCommand; out retract : RetractBoltCommand; }
    port def LockStatusPort { out engaged : BoltEngagedSignal; out retracted : BoltRetractedSignal; out jammed : BoltJammedSignal; }
    port def PowerPort { out loss : PowerLoss; out restored : PowerRestored; }

    part def Battery {
        attribute voltage : Real = 6.0;
        attribute capacity : Real = 2000;
        port powerOut : PowerPort;
    }

    part def Keypad {
        attribute backlit : Boolean = true;
        port codeOut : KeypadPort;
    }

    part def BiometricScanner {
        attribute resolution : Integer = 500;
        port printOut : BiometricPort;
    }

    part def WirelessModule {
        port cmdOut : WirelessCmdPort;
        port statusIn : ~WirelessStatusPort;
    }

    part def MagneticDoorSensor {
        attribute isClosed : Boolean;
        port sensorOut : DoorSensorPort;
    }

    part def MotorizedLockMechanism {
        attribute boltPosition : String;
        port controlIn : ~LockControlPort;
        port statusOut : LockStatusPort;
    }

    part def ControlProcessor {
        attribute authorizedCodes : AccessCode[0..*];
        attribute authorizedPrints : FingerprintData[0..*];
        port keypadIn : ~KeypadPort;
        port biometricIn : ~BiometricPort;
        port wirelessCmdIn : ~WirelessCmdPort;
        port doorSensorIn : ~DoorSensorPort;
        port lockStatusIn : ~LockStatusPort;
        port lockControlOut : LockControlPort;
        port wirelessStatusOut : WirelessStatusPort;
        port powerIn : ~PowerPort;
        perform action authenticateCode : AuthenticateCode;
        perform action authenticateBiometric : AuthenticateBiometric;
        perform action authenticateCommand : AuthenticateCommand;
    }

    part def SmartLock {
        part processor : ControlProcessor;
        part keypad : Keypad;
        part scanner : BiometricScanner;
        part wireless : WirelessModule;
        part doorSensor : MagneticDoorSensor;
        part mechanism : MotorizedLockMechanism;
        part battery : Battery;
        connect keypad.codeOut to processor.keypadIn;
        connect scanner.printOut to processor.biometricIn;
        connect wireless.cmdOut to processor.wirelessCmdIn;
        connect processor.wirelessStatusOut to wireless.statusIn;
        connect doorSensor.sensorOut to processor.doorSensorIn;
        connect processor.lockControlOut to mechanism.controlIn;
        connect mechanism.statusOut to processor.lockStatusIn;
        connect battery.powerOut to processor.powerIn;
    }

    state def LockStates;

    requirement MultiAuthentication {
        doc /* The system shall support authentication via numeric keypad, biometric scanner, and wireless commands. */
    }
    requirement FailSecure {
        doc /* The system shall remain in the locked state in case of power failure or system error. */
    }
    requirement DoorClosedSafety {
        doc /* The lock bolt shall only engage when the door is confirmed closed by the magnetic sensor. */
    }
    requirement AutoRelock30s {
        doc /* The system shall automatically re-lock after 30 seconds if no command is received while unlocked. */
    }
    requirement StatusReporting {
        doc /* The system shall transmit its current status via the wireless module upon state change. */
    }

    part smartLock : SmartLock {
        state lockStates : LockStates {
            entry; then locked;

            state locked;
            accept AuthSuccess
                do send new RetractBoltCommand() to smartLock.mechanism
                then unlocking;
            accept PowerLoss
                then error;
            accept SystemError
                then error;

            state unlocking;
            accept BoltRetractedSignal
                do send new UnlockedStatus() to smartLock.wireless
                then unlocked;
            accept BoltJammedSignal
                do send new JammedStatus() to smartLock.wireless
                then jammed;

            state unlocked;
            accept after 30 [s]
                if smartLock.doorSensor.isClosed
                do send new EngageBoltCommand() to smartLock.mechanism
                then locking;
            accept LockCommand
                if smartLock.doorSensor.isClosed
                do send new EngageBoltCommand() to smartLock.mechanism
                then locking;
            accept PowerLoss
                then error;
            accept SystemError
                then error;

            state locking;
            accept BoltEngagedSignal
                do send new LockedStatus() to smartLock.wireless
                then locked;
            accept BoltJammedSignal
                do send new JammedStatus() to smartLock.wireless
                then jammed;

            state jammed;
            accept LockCommand
                do send new EngageBoltCommand() to smartLock.mechanism
                then locking;
            accept PowerLoss
                then error;
            accept SystemError
                then error;

            state error;
            accept PowerRestored
                do send new EngageBoltCommand() to smartLock.mechanism
                then locking;
        }

        satisfy MultiAuthentication by lockStates;
        satisfy FailSecure by lockStates;
        satisfy DoorClosedSafety by lockStates;
        satisfy AutoRelock30s by lockStates;
        satisfy StatusReporting by lockStates;
    }
}
