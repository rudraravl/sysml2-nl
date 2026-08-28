package TherapeuticStandingFrame {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def AngleValue :> ISQ::AngleValue;
    attribute def VoltageValue :> ISQ::VoltageValue;
    attribute def AngularVelocityValue :> ISQ::AngularVelocityValue;
    attribute def ElectricChargeValue :> ISQ::ElectricChargeValue;

    attribute def StartTiltUpCommand;
    attribute def StartTiltDownCommand;
    attribute def EmergencyStopCommand;
    attribute def ResetCommand;
    attribute def PatientSecuredSignal;
    attribute def TargetAngleReachedSignal;
    attribute def AngleZeroSignal;
    attribute def LockEngagedSignal;
    attribute def RestraintsReleasedSignal;
    attribute def BatteryLowSignal;

    requirement def MaxPatientWeightReq {
        doc /* The structural frame shall safely support patients weighing up to 150 kg. */
        attribute maxWeight : MassValue = 150 [kg];
    }

    requirement def TiltAngleRangeReq {
        doc /* The tilt mechanism shall move the platform from 0 to 85 degrees. */
        attribute minAngle : AngleValue = 0 [deg];
        attribute maxAngle : AngleValue = 85 [deg];
    }

    requirement def EmergencyStopReq {
        doc /* The safety controller shall immediately halt all motion upon emergency stop activation. */
    }

    requirement def TiltSpeedControlReq {
        doc /* The tilt speed shall be controlled for patient safety and comfort. */
        attribute maxTiltSpeed : AngularVelocityValue = 2 [deg/s];
    }

    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : Real;
    }

    port def PowerPort {
        out item power : ElectricalPower;
    }

    port def TiltControlPort {
        in attribute tiltUpCmd : StartTiltUpCommand;
        in attribute tiltDownCmd : StartTiltDownCommand;
        in attribute emergencyStop : EmergencyStopCommand;
        in attribute resetCmd : ResetCommand;
        out attribute currentAngle : AngleValue;
        out attribute lockEngaged : Boolean;
    }

    port def RestraintStatusPort {
        out attribute allSecured : Boolean;
    }

    action def PositionPatient;
    action def SecureRestraints;
    action def ReleaseRestraints;
    action def EngageLock;
    action def DisengageLock;
    action def MonitorPatient;
    action def CutPower;
    action def TiltUp;
    action def TiltDown;
    action def StopActuator;
    action def SupplyPower;
    action def HaltAllMotion;

    part def Patient {
        attribute weight : MassValue;
    }

    part def StructuralFrame {
        attribute maxLoadCapacity : MassValue = 150 [kg];
        part base;
        part verticalSupports[2];
        requirement maxPatientWeight : MaxPatientWeightReq;
        satisfy maxPatientWeight;
    }

    part def TiltMechanism {
        attribute currentAngle : AngleValue = 0 [deg];
        attribute maxAngle : AngleValue = 85 [deg];
        attribute tiltSpeed : AngularVelocityValue = 2 [deg/s];
        attribute isLocked : Boolean = false;

        port ctrlPort : TiltControlPort;
        port powerIn : ~PowerPort;

        part actuator {
            perform action tiltUp : TiltUp;
            perform action tiltDown : TiltDown;
            perform action stop : StopActuator;
        }

        part mechanicalLock {
            perform action engage : EngageLock;
            perform action disengage : DisengageLock;
        }

        requirement tiltAngleRange : TiltAngleRangeReq;
        requirement tiltSpeedControl : TiltSpeedControlReq;
        satisfy tiltAngleRange;
        satisfy tiltSpeedControl;
    }

    part def SupportPlatform {
        part footplate;
        part kneePads[2];
        part chestPad;
    }

    part def RestraintSystem {
        part pelvicStrap;
        part chestStrap;
        part footStraps[2];
        attribute allSecured : Boolean = false;

        port statusPort : RestraintStatusPort;

        perform action securePatient : SecureRestraints;
        perform action releasePatient : ReleaseRestraints;
    }

    part def Battery {
        attribute chargeLevel : Real = 100;
        attribute voltage : VoltageValue = 24 [V];
        port powerPort : PowerPort;
        event occurrence batteryLow;

        perform action supplyPower : SupplyPower;
    }

    part def UserInterface {
        port uiPort : ~TiltControlPort;
        port restraintIn : ~RestraintStatusPort;
    }

    part def SafetyController {
        attribute emergencyStopActive : Boolean = false;
        perform action haltAllMotion : HaltAllMotion;
        requirement emergencyStopReq : EmergencyStopReq;
        satisfy emergencyStopReq;
    }

    part def ControlSystem {
        part ui : UserInterface;
        part safetyController : SafetyController;
        part battery : Battery;
    }

    part def TherapeuticStandingFrame {
        attribute currentAngle : AngleValue = 0 [deg];
        attribute targetAngle : AngleValue = 85 [deg];

        part structFrame : StructuralFrame;
        part tiltMechanism : TiltMechanism;
        part platform : SupportPlatform;
        part restraints : RestraintSystem;
        part control : ControlSystem;

        ref patient : Patient;

        connect control.battery.powerPort to tiltMechanism.powerIn;
        connect control.ui.uiPort to tiltMechanism.ctrlPort;
        connect restraints.statusPort to control.ui.restraintIn;

        requirement maxPatientWeightUsage : MaxPatientWeightReq;
        requirement tiltAngleRangeUsage : TiltAngleRangeReq;
        requirement emergencyStopUsage : EmergencyStopReq;

        satisfy maxPatientWeightUsage by structFrame;
        satisfy tiltAngleRangeUsage by tiltMechanism;
        satisfy emergencyStopUsage by control.safetyController;

        perform action positionPatient : PositionPatient;
        perform action secureRestraints : SecureRestraints;
        perform action releaseRestraints : ReleaseRestraints;
        perform action engageLockAction : EngageLock;
        perform action disengageLockAction : DisengageLock;
        perform action monitorPatient : MonitorPatient;
        perform action cutPower : CutPower;
        perform action tiltUpAction : TiltUp;
        perform action tiltDownAction : TiltDown;

        exhibit state operationalLifecycle {
            entry; then seated;
            state seated {
                entry positionPatient;
            }
            then securing;
            state securing {
                entry secureRestraints;
            }
            accept PatientSecuredSignal if restraints.allSecured == true then readyToTilt;
            state readyToTilt;
            accept StartTiltUpCommand then tiltingUp;
            state tiltingUp {
                do tiltUpAction;
            }
            accept TargetAngleReachedSignal if tiltMechanism.currentAngle >= targetAngle then locking;
            accept EmergencyStopCommand then emergencyHalt;
            state locking {
                entry engageLockAction;
            }
            accept LockEngagedSignal if tiltMechanism.isLocked == true then therapy;
            accept EmergencyStopCommand then emergencyHalt;
            state therapy {
                do monitorPatient;
            }
            accept StartTiltDownCommand then tiltingDown;
            accept EmergencyStopCommand then emergencyHalt;
            state tiltingDown {
                entry disengageLockAction;
                do tiltDownAction;
            }
            accept AngleZeroSignal if tiltMechanism.currentAngle <= 0 [deg] then releasing;
            accept EmergencyStopCommand then emergencyHalt;
            state releasing {
                do releaseRestraints;
            }
            accept RestraintsReleasedSignal if restraints.allSecured == false then seated;
            state emergencyHalt {
                entry cutPower;
                entry engageLockAction;
            }
            accept ResetCommand then seated;
        }
    }

    part standingFrame : TherapeuticStandingFrame {
        ref patient : Patient {
            attribute :>> weight = 80 [kg];
        }
    }
}
