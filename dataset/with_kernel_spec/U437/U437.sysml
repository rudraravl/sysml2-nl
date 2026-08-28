package VacuumBellSystem {
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def PressureValue :> ISQ::PressureValue;
    attribute def DurationValue :> ISQ::TimeValue;
    attribute def PumpControlSignal :> Real;

    attribute def StartTreatment;
    attribute def EndTreatment;
    attribute def EmergencyStop;
    attribute def PressureReleased;
    attribute def GradualReleaseCmd;
    attribute def RapidReleaseCmd;
    attribute def OverPressureAlert;

    action def MonitorPressure;
    action def ControlPump;
    action def RegulatePressure;
    action def MeasurePressure;
    action def PumpAir;

    port def VacuumPort {
        inout pressure : PressureValue;
    }
    port def PumpControlPort {
        in signal : PumpControlSignal;
    }
    port def SensorDataPort {
        out reading : PressureValue;
    }
    port def ReleaseCommandPort {
        in gradual : GradualReleaseCmd;
        in rapid : RapidReleaseCmd;
    }
    port def AlertPort {
        out alert : OverPressureAlert;
    }

    part def Patient {
        port chestPort;
    }

    part def BellChamber {
        port chestInterface;
        port vacuumPort : VacuumPort;
        attribute volume : ISQ::VolumeValue;
    }

    part def VacuumPump {
        port controlPort : PumpControlPort;
        port vacuumPort : VacuumPort;
        attribute maxFlowRate : ISQ::VolumeFlowRateValue;
        perform action pumpAir : PumpAir;
    }

    part def PressureSensor {
        port sensePort : VacuumPort;
        port dataPort : SensorDataPort;
        attribute reading : PressureValue;
        perform action measurePressure : MeasurePressure;
    }

    state def ControlStates;

    part def ControlUnit {
        port sensorDataPort : ~SensorDataPort;
        port pumpControlPort : ~PumpControlPort;
        port releaseCommandPort : ~ReleaseCommandPort;
        port alertPort : ~AlertPort;
        attribute targetPressure : PressureValue;
        attribute treatmentDuration : DurationValue;
        attribute maxSafePressure : PressureValue;
        attribute currentPressure : PressureValue;
        perform action monitorPressure : MonitorPressure;
        perform action controlPump : ControlPump;
        exhibit state controlStates : ControlStates {
            entry; then idle;
            state idle;
            accept StartTreatment then active;
            state active {
                entry monitorPressure;
                do controlPump;
            }
            accept EndTreatment then gradualRelease;
            accept EmergencyStop then emergencyRelease;
            state gradualRelease;
            accept PressureReleased then idle;
            state emergencyRelease;
            accept PressureReleased then idle;
        }
    }

    part def PressureRegulator {
        port inletPort : VacuumPort;
        port outletPort : VacuumPort;
        perform action regulatePressure : RegulatePressure;
    }

    state def SafetyStates;

    part def SafetyValve {
        port monitorPort : VacuumPort;
        port ventPort : VacuumPort;
        port alertPort : AlertPort;
        attribute threshold : PressureValue;
        attribute vacuumPressure : PressureValue;
        exhibit state safetyStates : SafetyStates {
            entry; then closed;
            state closed;
            accept when vacuumPressure > threshold then open;
            state open;
        }
    }

    state def ReleaseStates;

    part def ReleaseValve {
        port vacuumPort : VacuumPort;
        port ventPort : VacuumPort;
        port controlPort : ReleaseCommandPort;
        exhibit state releaseStates : ReleaseStates {
            entry; then closed;
            state closed;
            accept GradualReleaseCmd then gradualOpen;
            accept RapidReleaseCmd then rapidOpen;
            state gradualOpen;
            accept PressureReleased then closed;
            state rapidOpen;
            accept PressureReleased then closed;
        }
    }

    part vacuumBellSystem {
        part bellChamber : BellChamber;
        part vacuumPump : VacuumPump;
        part pressureSensor : PressureSensor;
        part controlUnit : ControlUnit;
        part pressureRegulator : PressureRegulator;
        part safetyValve : SafetyValve;
        part releaseValve : ReleaseValve;
        ref patient : Patient;
        connect patient.chestPort to bellChamber.chestInterface;
        connect vacuumPump.vacuumPort to pressureRegulator.inletPort;
        connect pressureRegulator.outletPort to bellChamber.vacuumPort;
        connect bellChamber.vacuumPort to pressureSensor.sensePort;
        connect bellChamber.vacuumPort to safetyValve.monitorPort;
        connect releaseValve.vacuumPort to bellChamber.vacuumPort;
        connect safetyValve.ventPort to bellChamber.vacuumPort;
        connect releaseValve.ventPort to bellChamber.vacuumPort;
        connect pressureSensor.dataPort to controlUnit.sensorDataPort;
        connect controlUnit.pumpControlPort to vacuumPump.controlPort;
        connect controlUnit.releaseCommandPort to releaseValve.controlPort;
        connect safetyValve.alertPort to controlUnit.alertPort;
    }

    requirement def TherapeuticPressureRequirement {
        attribute targetPressure : PressureValue;
        attribute duration : DurationValue;
        subject patient : Patient;
    }

    requirement def SafetyPressureRequirement {
        attribute maxSafePressure : PressureValue;
    }

    requirement def GradualReleaseRequirement;
    requirement def EmergencyReleaseRequirement;

    requirement therapeuticPressure : TherapeuticPressureRequirement {
        attribute targetPressure : PressureValue = 50;
        attribute duration : DurationValue = 1800;
    }

    requirement safetyPressure : SafetyPressureRequirement {
        attribute maxSafePressure : PressureValue = 100;
    }

    requirement gradualReleaseReq : GradualReleaseRequirement;
    requirement emergencyReleaseReq : EmergencyReleaseRequirement;

    satisfy therapeuticPressure by vacuumBellSystem.controlUnit;
    satisfy safetyPressure by vacuumBellSystem.safetyValve;
    satisfy gradualReleaseReq by vacuumBellSystem.releaseValve;
    satisfy emergencyReleaseReq by vacuumBellSystem.releaseValve;
}
