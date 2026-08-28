package BioartificialLiverSystemModel {
    private import ScalarValues::*;
    private import SI::*;

    attribute def TemperatureValue :> Real;
    attribute def PressureValue :> Real;
    attribute def FlowRateValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def ToxinLevelValue :> Real;

    item def Blood;
    item def BloodCells;
    item def Plasma;
    item def OxygenatedPlasma;
    item def DetoxifiedPlasma;
    item def NutrientMedium;
    item def Oxygen;
    item def StartCommand;
    item def StopCommand;
    item def EmergencyStopCommand;
    item def ResetCommand;
    item def AlarmSignal;

    port def BloodInPort {
        in item blood : Blood;
    }
    port def BloodOutPort {
        out item blood : Blood;
    }
    port def BloodCellsOutPort {
        out item cells : BloodCells;
    }
    port def BloodCellsInPort {
        in item cells : BloodCells;
    }
    port def PlasmaOutPort {
        out item plasma : Plasma;
    }
    port def PlasmaInPort {
        in item plasma : Plasma;
    }
    port def OxygenatedPlasmaOutPort {
        out item oxygenatedPlasma : OxygenatedPlasma;
    }
    port def OxygenatedPlasmaInPort {
        in item oxygenatedPlasma : OxygenatedPlasma;
    }
    port def DetoxifiedPlasmaOutPort {
        out item detoxifiedPlasma : DetoxifiedPlasma;
    }
    port def DetoxifiedPlasmaInPort {
        in item detoxifiedPlasma : DetoxifiedPlasma;
    }
    port def NutrientOutPort {
        out item medium : NutrientMedium;
    }
    port def NutrientInPort {
        in item medium : NutrientMedium;
    }
    port def OxygenOutPort {
        out item oxygen : Oxygen;
    }
    port def OxygenInPort {
        in item oxygen : Oxygen;
    }
    port def ControlPort {
        in item startCmd : StartCommand;
        in item stopCmd : StopCommand;
        in item emergencyCmd : EmergencyStopCommand;
        in item resetCmd : ResetCommand;
        out item alarmOut : AlarmSignal;
    }
    port def SensorPort {
        out attribute pressure : PressureValue;
        out attribute temperature : TemperatureValue;
        out attribute oxygenSaturation : Real;
        out attribute toxinLevel : ToxinLevelValue;
        out attribute cellViability : Real;
    }

    action def PumpBlood;
    action def SeparatePlasma;
    action def RecombineBlood;
    action def OxygenatePlasma;
    action def DetoxifyPlasma;
    action def SupplyNutrients;
    action def RegulateTemperature;
    action def MonitorParameters;
    action def TriggerAlarm;
    action def PrimeSystem;
    action def StartTreatment;
    action def StopTreatment;
    action def EmergencyShutdownAction;
    action def ProvideActiveTreatment;

    part def BloodPump {
        attribute flowRate : FlowRateValue;
        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        perform action pumpBlood : PumpBlood;
    }

    part def PlasmaFilter {
        port bloodIn : BloodInPort;
        port plasmaOut : PlasmaOutPort;
        port cellsOut : BloodCellsOutPort;
        perform action separatePlasma : SeparatePlasma;
    }

    part def BloodCellRecombiner {
        port cellsIn : BloodCellsInPort;
        port plasmaIn : DetoxifiedPlasmaInPort;
        port bloodOut : BloodOutPort;
        perform action recombineBlood : RecombineBlood;
    }

    part def Oxygenator {
        port plasmaIn : PlasmaInPort;
        port oxygenIn : OxygenInPort;
        port plasmaOut : OxygenatedPlasmaOutPort;
        perform action oxygenatePlasma : OxygenatePlasma;
    }

    part def BioreactorModule {
        attribute cellViability : Real = 100.0;
        port plasmaIn : OxygenatedPlasmaInPort;
        port nutrientIn : NutrientInPort;
        port plasmaOut : DetoxifiedPlasmaOutPort;
        port sensor : SensorPort;
        perform action detoxifyPlasma : DetoxifyPlasma;
    }

    part def NutrientReservoir {
        attribute volumeRemaining : VolumeValue;
        port nutrientOut : NutrientOutPort;
        perform action supplyNutrients : SupplyNutrients;
    }

    part def OxygenSource {
        attribute oxygenLevel : Real = 100.0;
        port oxygenOut : OxygenOutPort;
    }

    part def TemperatureController {
        attribute targetTemp : TemperatureValue = 37.0;
        attribute currentTemp : TemperatureValue;
        perform action regulateTemperature : RegulateTemperature;
    }

    part def MonitoringSystem {
        attribute maxPressure : PressureValue;
        attribute minPressure : PressureValue;
        attribute maxTemp : TemperatureValue;
        attribute minTemp : TemperatureValue;
        attribute minOxygenSaturation : Real;
        attribute maxToxinLevel : ToxinLevelValue;
        attribute minCellViability : Real;
        attribute alarmActive : Boolean = false;
        port sensor : SensorPort;
        perform action monitorParameters : MonitorParameters;
        perform action triggerAlarm : TriggerAlarm;
    }

    requirement def MaintainBodyTemperature {
        doc /* The system shall maintain the bioreactor temperature at 37 degrees Celsius plus or minus 0.5 degrees Celsius during active treatment. */
        attribute targetTemp : TemperatureValue = 37.0;
        attribute tolerance : TemperatureValue = 0.5;
        constraint { targetTemp >= 36.5 and targetTemp <= 37.5 }
    }

    requirement def SafeParameterRanges {
        doc /* All monitored physiological parameters must remain within predefined safe limits during active treatment. */
        attribute maxPressure : PressureValue;
        attribute minPressure : PressureValue;
        attribute maxTemp : TemperatureValue;
        attribute minTemp : TemperatureValue;
        attribute minOxygenSaturation : Real;
        attribute maxToxinLevel : ToxinLevelValue;
        attribute minCellViability : Real;
        constraint { maxPressure > minPressure and maxTemp > minTemp }
    }

    requirement def ToxinReduction {
        doc /* The system shall reduce toxin levels in the plasma by breaking down harmful substances such as ammonia using hepatocyte metabolic functions. */
        attribute maxLevel : ToxinLevelValue = 100.0;
        constraint { maxLevel > 0.0 }
    }

    requirement def CellViabilityMaintenance {
        doc /* Hepatocyte viability shall remain above 80 percent throughout the treatment session. */
        attribute minViability : Real = 80.0;
        constraint { minViability >= 80.0 }
    }

    requirement def EmergencyShutdownProtocol {
        doc /* The system shall provide an emergency shutdown protocol that safely stops blood flow and returns blood to the patient within 30 seconds. */
        attribute maxShutdownTime : Real = 30.0;
        constraint { maxShutdownTime <= 30.0 }
    }

    requirement def AlarmOnAbnormalCondition {
        doc /* The monitoring system shall trigger an alarm if any critical parameter exceeds its safe range to alert medical staff. */
        attribute alarmEnabled : Boolean = true;
        constraint { alarmEnabled == true }
    }

    part def BioartificialLiverSystem {
        port patientBloodIn : BloodInPort;
        port patientBloodOut : BloodOutPort;
        port systemControl : ControlPort;

        part bloodPump : BloodPump;
        part plasmaFilter : PlasmaFilter;
        part bloodCellRecombiner : BloodCellRecombiner;
        part oxygenator : Oxygenator;
        part bioreactor : BioreactorModule;
        part nutrientReservoir : NutrientReservoir;
        part oxygenSource : OxygenSource;
        part tempController : TemperatureController;
        part monitor : MonitoringSystem;

        connect patientBloodIn to bloodPump.bloodIn;
        connect bloodPump.bloodOut to plasmaFilter.bloodIn;
        connect plasmaFilter.plasmaOut to oxygenator.plasmaIn;
        connect plasmaFilter.cellsOut to bloodCellRecombiner.cellsIn;
        connect oxygenator.plasmaOut to bioreactor.plasmaIn;
        connect bioreactor.plasmaOut to bloodCellRecombiner.plasmaIn;
        connect bloodCellRecombiner.bloodOut to patientBloodOut;

        connect nutrientReservoir.nutrientOut to bioreactor.nutrientIn;
        connect oxygenSource.oxygenOut to oxygenator.oxygenIn;

        connect bioreactor.sensor to monitor.sensor;

        perform action primeSystem : PrimeSystem;
        perform action startTreatment : StartTreatment;
        perform action stopTreatment : StopTreatment;
        perform action emergencyShutdown : EmergencyShutdownAction;
        perform action provideActiveTreatment : ProvideActiveTreatment;

        requirement maintainTempReq : MaintainBodyTemperature;
        requirement safeParamsReq : SafeParameterRanges;
        requirement toxinReductionReq : ToxinReduction;
        requirement cellViabilityReq : CellViabilityMaintenance;
        requirement emergencyShutdownReq : EmergencyShutdownProtocol;
        requirement alarmReq : AlarmOnAbnormalCondition;

        state systemStates {
            entry; then idle;
            state idle;
            accept startCmd : StartCommand via systemControl
                do primeSystem
                then priming;
            state priming;
            accept after 5 [SI::min]
                do startTreatment
                then activeTreatment;
            state activeTreatment {
                do provideActiveTreatment;
            }
            accept stopCmd : StopCommand via systemControl
                do stopTreatment
                then idle;
            accept emergencyCmd : EmergencyStopCommand via systemControl
                do emergencyShutdown
                then emergencyShutdownState;
            accept when monitor.alarmActive == true
                do monitor.triggerAlarm
                then emergencyShutdownState;
            state emergencyShutdownState;
            accept after 30 [SI::s]
                then idle;
        }

        satisfy maintainTempReq by tempController;
        satisfy safeParamsReq by monitor;
        satisfy toxinReductionReq by bioreactor;
        satisfy cellViabilityReq by bioreactor;
        satisfy emergencyShutdownReq by bloodPump;
        satisfy alarmReq by monitor;
    }
}
