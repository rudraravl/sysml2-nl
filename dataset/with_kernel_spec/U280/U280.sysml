package 'Lead Shielding System' {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def RadiationDoseRateValue :> Real;
        attribute def ThicknessValue :> Real;

        item def AlarmSignal;
        item def InterlockSignal;

        port def RadiationPort {
            attribute doseRate : RadiationDoseRateValue;
        }
        port def AlarmSignalPort {
            attribute active : Boolean;
        }
        port def InterlockSignalPort {
            attribute engaged : Boolean;
        }

        action def EmitRadiation {
            out radiation : RadiationDoseRateValue;
        }
        action def AttenuateRadiation {
            in incomingDoseRate : RadiationDoseRateValue;
            out attenuatedDoseRate : RadiationDoseRateValue;
        }
        action def MeasureRadiation {
            in incomingDoseRate : RadiationDoseRateValue;
            out measuredDoseRate : RadiationDoseRateValue;
        }
        action def ActivateAlarm;
        action def EngageSafetyInterlock;

        state def MonitorStates;
        state def AlarmStates;
        state def InterlockStates;

        part def RadiationSource {
            attribute isotope : String = "Cobalt-60";
            attribute unshieldedDoseRate : RadiationDoseRateValue = 1000.0;
            port radiationOut : RadiationPort;
            perform action emitRadiation : EmitRadiation;
        }

        part def LeadShield {
            attribute thickness : ThicknessValue = 7.5;
            attribute attenuationFactor : Real = 0.01;
            port radiationIn : RadiationPort;
            port radiationOut : RadiationPort;
            perform action attenuate : AttenuateRadiation;
        }

        part def DosimeterSensor {
            attribute measuredDoseRate : RadiationDoseRateValue;
            port radiationIn : RadiationPort;
            port doseRateOut : RadiationPort;
            perform action measure : MeasureRadiation;
        }

        part def AlarmController {
            attribute maxPermissibleDoseRate : RadiationDoseRateValue = 5.0;
            port doseRateIn : RadiationPort;
            port alarmOut : AlarmSignalPort;
            port interlockOut : InterlockSignalPort;
            exhibit state monitorStates : MonitorStates;
        }

        part def Alarm {
            port alarmIn : AlarmSignalPort;
            perform action activate : ActivateAlarm;
            exhibit state alarmStates : AlarmStates;
        }

        part def SafetyInterlock {
            port interlockIn : InterlockSignalPort;
            perform action engage : EngageSafetyInterlock;
            exhibit state interlockStates : InterlockStates;
        }

        part def ProtectedZone {
            port radiationIn : RadiationPort;
            part dosimeterSensor : DosimeterSensor;
            part alarmController : AlarmController;
            part alarm : Alarm;
            part safetyInterlock : SafetyInterlock;
            connect radiationIn to dosimeterSensor.radiationIn;
            connect dosimeterSensor.doseRateOut to alarmController.doseRateIn;
            connect alarmController.alarmOut to alarm.alarmIn;
            connect alarmController.interlockOut to safetyInterlock.interlockIn;
        }

        part def ShieldingSystem {
            part radiationSource : RadiationSource;
            part leadShield : LeadShield;
            part protectedZone : ProtectedZone;
            connect radiationSource.radiationOut to leadShield.radiationIn;
            connect leadShield.radiationOut to protectedZone.radiationIn;
        }

        requirement def ShieldThicknessRequirement {
            in requiredThickness : ThicknessValue;
            doc /* The lead shield shall have a minimum thickness to ensure adequate radiation attenuation. */
        }

        requirement def MaxDoseRateRequirement {
            in maxPermissibleDoseRate : RadiationDoseRateValue;
            doc /* The radiation dose rate in the protected zone shall not exceed the maximum permissible level. */
        }

        requirement def RadiationSafetyRequirement {
            doc /* The system shall provide comprehensive radiation safety through passive shielding and active monitoring. */
        }
    }

    package Usages {
        private import Definitions::*;

        requirement shieldThicknessReq : ShieldThicknessRequirement {
            in requiredThickness = 7.5;
        }

        requirement maxDoseRateReq : MaxDoseRateRequirement {
            in maxPermissibleDoseRate = 5.0;
        }

        requirement radiationSafetyReq : RadiationSafetyRequirement;

        part shieldingSystem : ShieldingSystem {
            satisfy radiationSafetyReq by shieldingSystem;
            satisfy shieldThicknessReq by leadShield;
            satisfy maxDoseRateReq by protectedZone.alarmController;
        }

        state monitorStates : MonitorStates {
            entry; then monitoring;
            state monitoring;
            accept when shieldingSystem.protectedZone.alarmController.doseRateIn.doseRate > shieldingSystem.protectedZone.alarmController.maxPermissibleDoseRate
                then alarming;
            state alarming;
            accept when shieldingSystem.protectedZone.alarmController.doseRateIn.doseRate <= shieldingSystem.protectedZone.alarmController.maxPermissibleDoseRate
                then monitoring;
        }

        state alarmStates : AlarmStates {
            entry; then idle;
            state idle;
            accept AlarmSignal
                then sounding;
            state sounding;
            accept when shieldingSystem.protectedZone.alarm.alarmIn.active == false
                then idle;
        }

        state interlockStates : InterlockStates {
            entry; then disengaged;
            state disengaged;
            accept InterlockSignal
                then engaged;
            state engaged;
            accept when shieldingSystem.protectedZone.safetyInterlock.interlockIn.engaged == false
                then disengaged;
        }
    }
}
