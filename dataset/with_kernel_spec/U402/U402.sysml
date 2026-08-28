package MedicalStretcherSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def HeightCmd;
        attribute def BackrestCmd;
        attribute def BrakeCmd;
        attribute def RailCmd;
        attribute def SafetyStatus;
        attribute def 'PatientSecuredSignal';
        attribute def 'RailsRaisedSignal';
        attribute def 'ReadyToMoveSignal';
        attribute def 'ArrivedSignal';
        attribute def 'WheelsLockedSignal';
        attribute def 'PatientTransferredSignal';
        attribute def 'DoneSignal';

        part def MainFrame {
            attribute maxLoad : MassValue = 250 [kg];
        }

        part def Wheel;

        part def BrakeMechanism {
            attribute isEngaged : Boolean = false;
            in port brakeInput : BrakeCmd;
        }

        part def WheelAssembly {
            part wheels : Wheel[4];
            part brake : BrakeMechanism;
            in port brakeCmd : BrakeCmd;
            binding brakeCmd = brake.brakeInput;
        }

        part def HeightAdjustment {
            attribute minHeight : LengthValue = 50 [cm];
            attribute maxHeight : LengthValue = 90 [cm];
            attribute currentHeight : LengthValue = 50 [cm];
            in port heightInput : HeightCmd;
        }

        part def BackrestAdjustment {
            attribute minAngle : PlaneAngleValue = 0 [deg];
            attribute maxAngle : PlaneAngleValue = 75 [deg];
            attribute currentAngle : PlaneAngleValue = 0 [deg];
            in port backrestInput : BackrestCmd;
        }

        part def SafetyRail {
            attribute isRaised : Boolean = false;
            attribute isLocked : Boolean = false;
            in port railInput : RailCmd;
        }

        part def CentralController {
            out port heightCmd : HeightCmd;
            out port backrestCmd : BackrestCmd;
            out port brakeCmd : BrakeCmd;
            out port leftRailCmd : RailCmd;
            out port rightRailCmd : RailCmd;
            in port safetyStatus : SafetyStatus;
            exhibit state 'controller states' : ControllerStates;
        }

        state def ControllerStates {
            entry; then idle;
            state idle;
            accept HeightCmd then adjusting_height;
            state adjusting_height;
            accept 'DoneSignal' then idle;
            accept BackrestCmd then adjusting_backrest;
            state adjusting_backrest;
            accept 'DoneSignal' then idle;
            accept BrakeCmd then adjusting_brake;
            state adjusting_brake;
            accept 'DoneSignal' then idle;
        }

        state def StretcherStates;

        action def SecurePatient;
        action def RaiseRails;
        action def MovePatient;
        action def LockWheels;
        action def TransferPatient;
        action def CheckSafety { out safe : Boolean; }

        requirement def LoadCapacity {
            doc /* The stretcher shall support a maximum load of 250 kg. */
            attribute maxLoad : MassValue = 250 [kg];
        }
        requirement def HeightRange {
            doc /* The height adjustment shall allow positioning between 50 cm and 90 cm. */
            attribute minHeight : LengthValue = 50 [cm];
            attribute maxHeight : LengthValue = 90 [cm];
        }
        requirement def BackrestAngleRange {
            doc /* The backrest shall adjust from 0 to 75 degrees. */
            attribute minAngle : PlaneAngleValue = 0 [deg];
            attribute maxAngle : PlaneAngleValue = 75 [deg];
        }
        requirement def SafetyInterlock {
            doc /* The stretcher shall not move unless safety rails are raised and patient is secured. */
        }
        requirement def WheelLockBeforeTransfer {
            doc /* Wheels shall be locked before patient transfer. */
        }

        part def StretcherSystem {
            part mainFrame : MainFrame;
            part wheelAssy : WheelAssembly;
            part heightAdj : HeightAdjustment;
            part backrestAdj : BackrestAdjustment;
            part leftRail : SafetyRail;
            part rightRail : SafetyRail;
            part controller : CentralController;

            binding controller.heightCmd = heightAdj.heightInput;
            binding controller.backrestCmd = backrestAdj.backrestInput;
            binding controller.brakeCmd = wheelAssy.brakeCmd;
            binding controller.leftRailCmd = leftRail.railInput;
            binding controller.rightRailCmd = rightRail.railInput;

            perform action 'secure patient' : SecurePatient;
            perform action 'raise rails' : RaiseRails;
            perform action 'move patient' : MovePatient;
            perform action 'lock wheels' : LockWheels;
            perform action 'transfer patient' : TransferPatient;
            perform action 'check safety' : CheckSafety;

            exhibit state 'stretcher states' : StretcherStates;
        }
    }

    package Usages {
        private import Definitions::*;

        part stretcher : StretcherSystem;

        action 'secure patient' : SecurePatient;
        action 'raise rails' : RaiseRails;
        action 'move patient' : MovePatient;
        action 'lock wheels' : LockWheels;
        action 'transfer patient' : TransferPatient;
        action 'check safety' : CheckSafety;

        state 'stretcher states' : StretcherStates {
            entry; then idle;
            state idle;
            accept 'PatientSecuredSignal'
                do 'secure patient'
                then securing;
            state securing;
            accept 'RailsRaisedSignal'
                do 'raise rails'
                then raising;
            state raising;
            accept 'ReadyToMoveSignal'
                then moving;
            state moving {
                do 'move patient';
            }
            accept 'ArrivedSignal'
                do 'lock wheels'
                then locking;
            state locking;
            accept 'WheelsLockedSignal'
                do 'transfer patient'
                then transferring;
            state transferring;
            accept 'PatientTransferredSignal'
                then idle;
        }
    }
}
