package BioartificialLiverSystem {

    import ScalarValues::*;

    // ============================================================
    // UNITS
    // ============================================================

    unit degC {
        doc "Degrees Celsius";
    }

    unit mmHg {
        doc "Millimeters of mercury";
    }

    unit mL_per_min {
        doc "Milliliters per minute";
    }

    unit mg_per_dL {
        doc "Milligrams per deciliter";
    }

    unit percent {
        doc "Percent";
    }

    unit rpm {
        doc "Revolutions per minute";
    }

    // ============================================================
    // VALUE TYPES
    // ============================================================

    value type TemperatureValue :> Real {
        doc "Temperature in degrees Celsius";
        unit :> degC;
    }

    value type PressureValue :> Real {
        doc "Pressure in millimeters of mercury";
        unit :> mmHg;
    }

    value type FlowRateValue :> Real {
        doc "Volume flow rate in milliliters per minute";
        unit :> mL_per_min;
    }

    value type ConcentrationValue :> Real {
        doc "Solute concentration in milligrams per deciliter";
        unit :> mg_per_dL;
    }

    value type SaturationValue :> Real {
        doc "Oxygen saturation as a percentage 0 to 100";
        unit :> percent;
    }

    value type ViabilityValue :> Real {
        doc "Cell viability as a percentage 0 to 100";
        unit :> percent;
    }

    value type RpmValue :> Integer {
        doc "Rotational speed in revolutions per minute";
        unit :> rpm;
    }

    // ============================================================
    // ITEM DEFINITIONS
    // ============================================================

    item def WholeBlood {
        doc "Patient whole blood containing plasma and blood cells";
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute oxygenSaturation : SaturationValue;
        attribute ammoniaLevel : ConcentrationValue;
        attribute toxinLevel : ConcentrationValue;
        attribute flowRate : FlowRateValue;
    }

    item def Plasma {
        doc "Liquid component of blood separated from blood cells";
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute oxygenSaturation : SaturationValue;
        attribute ammoniaLevel : ConcentrationValue;
        attribute toxinLevel : ConcentrationValue;
        attribute nutrientLevel : ConcentrationValue;
        attribute flowRate : FlowRateValue;
    }

    item def OxygenatedPlasma {
        doc "Plasma enriched with oxygen by the oxygenator";
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute oxygenSaturation : SaturationValue;
        attribute ammoniaLevel : ConcentrationValue;
        attribute toxinLevel : ConcentrationValue;
        attribute nutrientLevel : ConcentrationValue;
        attribute flowRate : FlowRateValue;
    }

    item def DetoxifiedPlasma {
        doc "Plasma after hepatocyte metabolic detoxification in the bioreactor";
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute oxygenSaturation : SaturationValue;
        attribute ammoniaLevel : ConcentrationValue;
        attribute toxinLevel : ConcentrationValue;
        attribute nutrientLevel : ConcentrationValue;
        attribute flowRate : FlowRateValue;
    }

    item def BloodCells {
        doc "Red and white blood cells separated from plasma";
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute oxygenSaturation : SaturationValue;
        attribute hemoglobinConcentration : ConcentrationValue;
        attribute flowRate : FlowRateValue;
    }

    item def OxygenGas {
        doc "Oxygen gas supplied to the oxygenator";
        attribute flowRate : Real;
        attribute purity : Real;
    }

    item def NutrientMedium {
        doc "Nutrient solution for hepatocyte culture in the bioreactor";
        attribute glucoseConcentration : ConcentrationValue;
        attribute aminoAcidConcentration : ConcentrationValue;
        attribute temperature : TemperatureValue;
        attribute flowRate : FlowRateValue;
    }

    item def Hepatocyte {
        doc "Living liver cell performing metabolic detoxification";
        attribute viability : ViabilityValue;
        attribute metabolicActivity : Real;
        attribute oxygenUptakeRate : Real;
        attribute ammoniaMetabolismRate : Real;
    }

    // ============================================================
    // PORT DEFINITIONS
    // ============================================================

    port def BloodInPort {
        doc "Inlet port for whole blood";
        in blood : WholeBlood;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def BloodOutPort {
        doc "Outlet port for whole blood";
        out blood : WholeBlood;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def PlasmaInPort {
        doc "Inlet port for separated plasma";
        in plasma : Plasma;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def PlasmaOutPort {
        doc "Outlet port for separated plasma";
        out plasma : Plasma;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def OxygenatedPlasmaInPort {
        doc "Inlet port for oxygenated plasma";
        in plasma : OxygenatedPlasma;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def OxygenatedPlasmaOutPort {
        doc "Outlet port for oxygenated plasma";
        out plasma : OxygenatedPlasma;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def DetoxifiedPlasmaInPort {
        doc "Inlet port for detoxified plasma";
        in plasma : DetoxifiedPlasma;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def DetoxifiedPlasmaOutPort {
        doc "Outlet port for detoxified plasma";
        out plasma : DetoxifiedPlasma;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def BloodCellInPort {
        doc "Inlet port for blood cells";
        in cells : BloodCells;
        attribute flowRate : FlowRateValue;
    }

    port def BloodCellOutPort {
        doc "Outlet port for blood cells";
        out cells : BloodCells;
        attribute flowRate : FlowRateValue;
    }

    port def OxygenInPort {
        doc "Inlet port for oxygen gas";
        in oxygen : OxygenGas;
    }

    port def OxygenOutPort {
        doc "Outlet port for oxygen gas";
        out oxygen : OxygenGas;
    }

    port def NutrientInPort {
        doc "Inlet port for nutrient medium";
        in nutrient : NutrientMedium;
        attribute flowRate : FlowRateValue;
    }

    port def NutrientOutPort {
        doc "Outlet port for nutrient medium";
        out nutrient : NutrientMedium;
        attribute flowRate : FlowRateValue;
    }

    port def ControlInPort {
        doc "Receptacle for control command signals";
        in startCommand : Boolean;
        in stopCommand : Boolean;
        in emergencyStopCommand : Boolean;
        in flowSetPoint : FlowRateValue;
        in temperatureSetPoint : TemperatureValue;
    }

    port def ControlOutPort {
        doc "Source of control command signals";
        out startCommand : Boolean;
        out stopCommand : Boolean;
        out emergencyStopCommand : Boolean;
        out flowSetPoint : FlowRateValue;
        out temperatureSetPoint : TemperatureValue;
    }

    port def MonitoringOutPort {
        doc "Source of monitoring data";
        out temperature : TemperatureValue;
        out pressure : PressureValue;
        out oxygenSaturation : SaturationValue;
        out toxinLevel : ConcentrationValue;
        out cellViability : ViabilityValue;
        out alarmActive : Boolean;
        out alarmCode : Integer;
        out alarmMessage : String;
    }

    port def MonitoringInPort {
        doc "Receptacle for monitoring data";
        in temperature : TemperatureValue;
        in pressure : PressureValue;
        in oxygenSaturation : SaturationValue;
        in toxinLevel : ConcentrationValue;
        in cellViability : ViabilityValue;
        in alarmActive : Boolean;
        in alarmCode : Integer;
        in alarmMessage : String;
    }

    // ============================================================
    // CONNECTION DEFINITIONS
    // ============================================================

    connection def BloodConnection {
        doc "Connection carrying whole blood between components";
        end source : BloodOutPort;
        end target : BloodInPort;
    }

    connection def PlasmaConnection {
        doc "Connection carrying separated plasma between components";
        end source : PlasmaOutPort;
        end target : PlasmaInPort;
    }

    connection def OxygenatedPlasmaConnection {
        doc "Connection carrying oxygenated plasma between components";
        end source : OxygenatedPlasmaOutPort;
        end target : OxygenatedPlasmaInPort;
    }

    connection def DetoxifiedPlasmaConnection {
        doc "Connection carrying detoxified plasma between components";
        end source : DetoxifiedPlasmaOutPort;
        end target : DetoxifiedPlasmaInPort;
    }

    connection def BloodCellConnection {
        doc "Connection carrying blood cells to the recombination unit";
        end source : BloodCellOutPort;
        end target : BloodCellInPort;
    }

    connection def OxygenConnection {
        doc "Connection carrying oxygen gas to the oxygenator";
        end source : OxygenOutPort;
        end target : OxygenInPort;
    }

    connection def NutrientConnection {
        doc "Connection carrying nutrient medium to the bioreactor";
        end source : NutrientOutPort;
        end target : NutrientInPort;
    }

    connection def ControlSignalConnection {
        doc "Connection carrying control command signals";
        end source : ControlOutPort;
        end target : ControlInPort;
    }

    connection def MonitoringDataConnection {
        doc "Connection carrying monitoring data from components to the monitoring system";
        end source : MonitoringOutPort;
        end target : MonitoringInPort;
    }

    // ============================================================
    // COMPONENT PART DEFINITIONS
    // ============================================================

    part def BloodPump {
        doc "Precision blood pump that draws blood from the patient and maintains a consistent flow rate through the device";

        port bloodIn : BloodInPort;
        port bloodOut : BloodOutPort;
        port control : ControlInPort;
        port monitoring : MonitoringOutPort;

        attribute nominalFlowRate : FlowRateValue = 200;
        attribute actualFlowRate : FlowRateValue;
        attribute pumpEnabled : Boolean = false;
        attribute pumpRpm : RpmValue;
        attribute maxRpm : RpmValue = 3000;

        action performPumping {
            doc "Continuously pump blood at the set flow rate by regulating pump RPM";
        }

        action enableMotor {
            doc "Enable the pump motor and begin rotation";
        }

        action disableMotor {
            doc "Disable the pump motor and stop rotation";
        }

        state pumpStateMachine {
            state PumpOff {
                entry : disableMotor;
                transition on control.startCommand then PumpOn;
            }
            state PumpOn {
                entry : enableMotor;
                do : performPumping;
                transition on control.stopCommand then PumpOff;
                transition on control.emergencyStopCommand then PumpOff;
            }
        }
    }

    part def PlasmaFilter {
        doc "Plasma separator that separates liquid plasma from blood cells using membrane filtration";

        port bloodIn : BloodInPort;
        port plasmaOut : PlasmaOutPort;
        port bloodCellsOut : BloodCellOutPort;
        port control : ControlInPort;
        port monitoring : MonitoringOutPort;

        attribute separationEfficiency : Real = 0.95;
        attribute filterPressureDrop : PressureValue;
        attribute membranePoreSize : Real;
        attribute bloodFlowRate : FlowRateValue;
        attribute plasmaFlowRate : FlowRateValue;
        attribute bloodCellFlowRate : FlowRateValue;

        action separatePlasma {
            doc "Separate plasma from whole blood using cross-flow membrane filtration";
        }

        action updateFilterMetrics {
            doc "Update filter pressure drop and individual flow rate readings";
        }

        state filterStateMachine {
            state FilterIdle {
                transition on control.startCommand then FilterActive;
            }
            state FilterActive {
                do : separatePlasma;
                do : updateFilterMetrics;
                transition on control.stopCommand then FilterIdle;
                transition on control.emergencyStopCommand then FilterIdle;
            }
        }
    }

    part def Oxygenator {
        doc "Oxygenator that enriches plasma with oxygen to support hepatocyte viability in the bioreactor";

        port plasmaIn : PlasmaInPort;
        port oxygenIn : OxygenInPort;
        port plasmaOut : OxygenatedPlasmaOutPort;
        port control : ControlInPort;
        port monitoring : MonitoringOutPort;

        attribute oxygenFlowRate : Real;
        attribute targetOxygenSaturation : SaturationValue = 95;
        attribute actualOxygenSaturation : SaturationValue;
        attribute oxygenTransferRate : Real;
        attribute gasExchangeEfficiency : Real = 0.90;

        action oxygenatePlasma {
            doc "Enrich plasma with oxygen to the target saturation level using gas exchange membrane";
        }

        action measureSaturation {
            doc "Measure and update the actual oxygen saturation of the output plasma";
        }

        state oxygenatorStateMachine {
            state OxygenatorIdle {
                transition on control.startCommand then OxygenatorActive;
            }
            state OxygenatorActive {
                do : oxygenatePlasma;
                do : measureSaturation;
                transition on control.stopCommand then OxygenatorIdle;
                transition on control.emergencyStopCommand then OxygenatorIdle;
            }
        }
    }

    part def BioreactorModule {
        doc "Bioreactor containing a culture of living hepatocytes that perform metabolic detoxification of the plasma";

        port plasmaIn : OxygenatedPlasmaInPort;
        port plasmaOut : DetoxifiedPlasmaOutPort;
        port nutrientIn : NutrientInPort;
        port control : ControlInPort;
        port monitoring : MonitoringOutPort;

        item hepatocyteCulture : Hepatocyte[1..*];
        attribute cellCount : Integer = 1000000000;
        attribute cellViability : ViabilityValue = 95;
        attribute metabolicRate : Real;
        attribute ammoniaReductionRate : Real;
        attribute minimumViabilityThreshold : ViabilityValue = 70;
        attribute bioreactorVolume : Real;
        attribute surfaceArea : Real;

        action detoxifyPlasma {
            doc "Process oxygenated plasma through the hepatocyte culture to break down ammonia and other toxins";
        }

        action assessViability {
            doc "Assess hepatocyte viability and metabolic activity during treatment";
        }

        action supplyNutrients {
            doc "Continuously supply nutrient medium from the reservoir to the hepatocytes";
        }

        state bioreactorStateMachine {
            state BioreactorIdle {
                transition on control.startCommand then BioreactorActive;
            }
            state BioreactorActive {
                do : detoxifyPlasma;
                do : supplyNutrients;
                do : assessViability;
                transition on control.stopCommand then BioreactorIdle;
                transition on control.emergencyStopCommand then BioreactorIdle;
                transition if cellViability < minimumViabilityThreshold then BioreactorIdle;
            }
        }
    }

    part def NutrientReservoir {
        doc "Reservoir that continuously supplies nutrient medium to the hepatocytes in the bioreactor";

        port nutrientOut : NutrientOutPort;
        port control : ControlInPort;
        port monitoring : MonitoringOutPort;

        attribute reservoirVolume : Real;
        attribute maxVolume : Real = 500;
        attribute nutrientFlowRate : FlowRateValue;
        attribute glucoseConcentration : ConcentrationValue;
        attribute aminoAcidConcentration : ConcentrationValue;
        attribute reservoirEmpty : Boolean = false;
        attribute lowVolumeThreshold : Real = 50;

        action dispenseNutrient {
            doc "Dispense nutrient medium at the required flow rate to the bioreactor";
        }

        action checkLevel {
            doc "Check reservoir level and update empty status when volume is low";
        }

        action raiseRefillAlarm {
            doc "Raise an alarm indicating the nutrient reservoir needs refilling";
        }

        state reservoirStateMachine {
            state ReservoirFull {
                do : dispenseNutrient;
                do : checkLevel;
                transition if reservoirEmpty then ReservoirEmpty;
                transition on control.emergencyStopCommand then ReservoirFull;
            }
            state ReservoirEmpty {
                entry : raiseRefillAlarm;
                transition if not reservoirEmpty then ReservoirFull;
            }
        }
    }

    part def TemperatureController {
        doc "Temperature controller that maintains the system at human body temperature approximately 37 degrees Celsius to keep hepatocytes healthy and functional";

        port control : ControlInPort;
        port monitoring : MonitoringOutPort;

        attribute targetTemperature : TemperatureValue = 37;
        attribute actualTemperature : TemperatureValue;
        attribute heaterEnabled : Boolean = false;
        attribute coolerEnabled : Boolean = false;
        attribute temperatureTolerance : TemperatureValue = 1;
        attribute heatingPower : Real;
        attribute coolingPower : Real;

        action regulateTemperature {
            doc "Regulate temperature by activating heater or cooler to maintain 37 degrees Celsius";
        }

        action adjustActuators {
            doc "Adjust heater and cooler output based on current versus target temperature";
        }

        action stopTemperatureControl {
            doc "Disable both heater and cooler";
        }

        state temperatureStateMachine {
            state TempControlOff {
                entry : stopTemperatureControl;
                transition on control.startCommand then TempControlOn;
            }
            state TempControlOn {
                do : regulateTemperature;
                do : adjustActuators;
                transition on control.stopCommand then TempControlOff;
                transition on control.emergencyStopCommand then TempControlOff;
            }
        }
    }

    part def PlasmaRecombiner {
        doc "Recombination unit that mixes detoxified plasma back with the patient blood cells for return to the body";

        port detoxifiedPlasmaIn : DetoxifiedPlasmaInPort;
        port bloodCellsIn : BloodCellInPort;
        port bloodOut : BloodOutPort;
        port control : ControlInPort;
        port monitoring : MonitoringOutPort;

        attribute recombinationEfficiency : Real = 0.98;
        attribute outputFlowRate : FlowRateValue;
        attribute outputPressure : PressureValue;
        attribute mixingChamberVolume : Real;

        action recombineBlood {
            doc "Combine detoxified plasma with blood cells to form whole blood for return to patient";
        }

        action updateOutputFlow {
            doc "Update the output flow rate and pressure readings";
        }

        state recombineTransformStateMachine {
            state RecombinerIdle {
                transition on control.startCommand then RecombinerActive;
            }
            state RecombinerActive {
                do : recombineBlood;
                do : updateOutputFlow;
                transition on control.stopCommand then RecombinerIdle;
                transition on control.emergencyStopCommand then RecombinerIdle;
            }
        }
    }

    part def MonitoringSystem {
        doc "Comprehensive monitoring system that measures critical parameters throughout the device and triggers alarms when parameters go outside safe ranges";

        port monitoringIn : MonitoringInPort;
        port monitoringOut : MonitoringOutPort;
        port control : ControlInPort;

        attribute bloodPressureReading : PressureValue;
        attribute temperatureReading : TemperatureValue;
        attribute oxygenSaturationReading : SaturationValue;
        attribute toxinLevelReading : ConcentrationValue;
        attribute cellViabilityReading : ViabilityValue;
        attribute alarmActive : Boolean = false;
        attribute alarmCode : Integer = 0;
        attribute alarmMessage : String = "";

        attribute safePressureMin : PressureValue = 50;
        attribute safePressureMax : PressureValue = 200;
        attribute safeTemperatureMin : TemperatureValue = 35;
        attribute safeTemperatureMax : TemperatureValue = 39;
        attribute safeOxygenSaturationMin : SaturationValue = 80;
        attribute safeToxinLevelMax : ConcentrationValue = 50;
        attribute minimumCellViability : ViabilityValue = 70;

        action collectReadings {
            doc "Collect and aggregate monitoring readings from all components";
        }

        action evaluateSafety {
            doc "Evaluate all readings against safe ranges and determine alarm status";
        }

        action updateAlarmState {
            doc "Update the alarm active flag code and message based on evaluation results";
        }

        action triggerAlarm {
            doc "Trigger an alarm with the appropriate code and message to alert medical staff";
        }

        action clearAlarm {
            doc "Clear the alarm and reset alarm state to normal";
        }

        state monitoringStateMachine {
            state MonitoringIdle {
                transition on control.startCommand then MonitoringActive;
            }
            state MonitoringActive {
                do : collectReadings;
                do : evaluateSafety;
                do : updateAlarmState;
                transition if alarmActive then MonitoringAlarm;
                transition on control.stopCommand then MonitoringIdle;
            }
            state MonitoringAlarm {
                entry : triggerAlarm;
                do : collectReadings;
                do : evaluateSafety;
                transition if not alarmActive then MonitoringActive;
                transition on control.emergencyStopCommand then MonitoringIdle;
            }
        }
    }

    // ============================================================
    // SYSTEM-LEVEL STATE MACHINE
    // ============================================================

    state def SystemOperationalState {
        doc "Top-level operational state machine for the bioartificial liver system";

        state Idle {
            doc "System on standby awaiting operator commands";
            entry : initializeSystem;
            transition on startTreatmentCommand then Priming;
        }

        state Priming {
            doc "Priming state to prepare all circuits fill with saline and verify all connections before treatment";
            entry : beginPrimingSequence;
            do : primeCircuits;
            transition on primingComplete then ActiveTreatment;
            transition on emergencyStopCommand then EmergencyShutdown;
        }

        state ActiveTreatment {
            doc "Active treatment state where blood is circulated plasma is treated and detoxified blood is returned to patient";
            entry : startTreatment;
            do : operateTreatment;
            transition on stopTreatmentCommand then Stopping;
            transition on emergencyStopCommand then EmergencyShutdown;
        }

        state Stopping {
            doc "Controlled stopping state to safely shut down treatment";
            entry : beginStoppingSequence;
            do : flushCircuits;
            transition on stoppingComplete then Idle;
        }

        state EmergencyShutdown {
            doc "Emergency shutdown state to immediately stop all pumps and isolate the patient from the device";
            entry : emergencyStop;
            do : isolatePatient;
            transition on emergencyResolved then Idle;
        }

        action initializeSystem {
            doc "Initialize all subsystems and set default values";
        }

        action beginPrimingSequence {
            doc "Begin the priming sequence to prepare all circuits for treatment";
        }

        action primeCircuits {
            doc "Fill all blood and plasma circuits with saline and remove air bubbles";
        }

        action startTreatment {
            doc "Start the active treatment by enabling all subsystems in sequence";
        }

        action operateTreatment {
            doc "Maintain operation during active treatment and coordinate all subsystems";
        }

        action beginStoppingSequence {
            doc "Begin controlled stopping sequence to safely end treatment";
        }

        action flushCircuits {
            doc "Flush remaining blood and plasma from the circuits";
        }

        action emergencyStop {
            doc "Immediately stop all pumps and shut down treatment to protect the patient";
        }

        action isolatePatient {
            doc "Isolate the patient blood circuit from the device during emergency shutdown";
        }
    }

    // ============================================================
    // TOP-LEVEL SYSTEM
    // ============================================================

    part def BioartificialLiverDevice {
        doc "Bioartificial liver system providing temporary life support for patients with acute or chronic liver failure functioning as an external temporary liver";

        // Control and monitoring subsystems
        part monitoringSystem : MonitoringSystem;
        part temperatureController : TemperatureController;

        // Blood circuit components
        part bloodPump : BloodPump;
        part plasmaFilter : PlasmaFilter;
        part oxygenator : Oxygenator;
        part bioreactor : BioreactorModule;
        part nutrientReservoir : NutrientReservoir;
        part plasmaRecombiner : PlasmaRecombiner;

        // Patient interface ports
        port patientBloodIn : BloodInPort {
            doc "Blood drawn from the patient into the system";
        }
        port patientBloodOut : BloodOutPort {
            doc "Treated blood returned to the patient";
        }
        port oxygenSupply : OxygenInPort {
            doc "External oxygen gas supply connection";
        }

        // System control and monitoring ports
        port systemControl : ControlInPort;
        port systemMonitoring : MonitoringOutPort;

        // System attributes
        attribute treatmentStartTime : Real;
        attribute treatmentDuration : Real;
        attribute systemOperationalState : String;
        attribute patientIdentifier : String;
        attribute treatmentActive : Boolean = false;
        attribute emergencyStopTriggered : Boolean = false;

        // Blood flow connections
        connection patientToPump : BloodConnection connect patientBloodIn to bloodPump.bloodIn;
        connection pumpToFilter : BloodConnection connect bloodPump.bloodOut to plasmaFilter.bloodIn;
        connection recombinerToPatient : BloodConnection connect plasmaRecombiner.bloodOut to patientBloodOut;

        // Plasma flow connections
        connection filterToOxygenator : PlasmaConnection connect plasmaFilter.plasmaOut to oxygenator.plasmaIn;
        connection oxygenatorToBioreactor : OxygenatedPlasmaConnection connect oxygenator.plasmaOut to bioreactor.plasmaIn;
        connection bioreactorToRecombiner : DetoxifiedPlasmaConnection connect bioreactor.plasmaOut to plasmaRecombiner.detoxifiedPlasmaIn;

        // Blood cell flow connection
        connection filterCellsToRecombiner : BloodCellConnection connect plasmaFilter.bloodCellsOut to plasmaRecombiner.bloodCellsIn;

        // Oxygen gas connection
        connection oxygenToOxygenator : OxygenConnection connect oxygenSupply to oxygenator.oxygenIn;

        // Nutrient medium connection
        connection nutrientToBioreactor : NutrientConnection connect nutrientReservoir.nutrientOut to bioreactor.nutrientIn;

        // Control signal connections from system control to components
        connection controlToPump : ControlSignalConnection connect systemControl to bloodPump.control;
        connection controlToFilter : ControlSignalConnection connect systemControl to plasmaFilter.control;
        connection controlToOxygenator : ControlSignalConnection connect systemControl to oxygenator.control;
        connection controlToBioreactor : ControlSignalConnection connect systemControl to bioreactor.control;
        connection controlToReservoir : ControlSignalConnection connect systemControl to nutrientReservoir.control;
        connection controlToTempController : ControlSignalConnection connect systemControl to temperatureController.control;
        connection controlToRecombiner : ControlSignalConnection connect systemControl to plasmaRecombiner.control;
        connection controlToMonitor : ControlSignalConnection connect systemControl to monitoringSystem.control;

        // Monitoring data connections from components to monitoring system
        connection pumpToMonitor : MonitoringDataConnection connect bloodPump.monitoring to monitoringSystem.monitoringIn;
        connection filterToMonitor : MonitoringDataConnection connect plasmaFilter.monitoring to monitoringSystem.monitoringIn;
        connection oxygenatorToMonitor : MonitoringDataConnection connect oxygenator.monitoring to monitoringSystem.monitoringIn;
        connection bioreactorToMonitor : MonitoringDataConnection connect bioreactor.monitoring to monitoringSystem.monitoringIn;
        connection reservoirToMonitor : MonitoringDataConnection connect nutrientReservoir.monitoring to monitoringSystem.monitoringIn;
        connection tempToMonitor : MonitoringDataConnection connect temperatureController.monitoring to monitoringSystem.monitoringIn;
        connection recombinerToMonitor : MonitoringDataConnection connect plasmaRecombiner.monitoring to monitoringSystem.monitoringIn;

        // Monitoring system output to system monitoring port
        connection monitorToSystem : MonitoringDataConnection connect monitoringSystem.monitoringOut to systemMonitoring;

        // System operational state machine
        exhibit SystemOperationalState;
    }

    // ============================================================
    // REQUIREMENTS
    // ============================================================

    requirement def SystemPurposeRequirement {
        doc "The bioartificial liver system shall provide temporary life support for patients experiencing acute or chronic liver failure by functioning as an external temporary liver";
        subject device : BioartificialLiverDevice;
    }

    requirement def BloodPumpFlowRateRequirement {
        doc "The blood pump shall draw blood from the patient and maintain a consistent flow rate through the device";
        subject pump : BloodPump;
        attribute minFlowRate : FlowRateValue = 50;
        attribute maxFlowRate : FlowRateValue = 300;
        assert pump.actualFlowRate >= minFlowRate;
        assert pump.actualFlowRate <= maxFlowRate;
    }

    requirement def PlasmaSeparationRequirement {
        doc "The plasma filter shall separate the liquid plasma from the blood cells so that only plasma carrying toxins is sent for treatment";
        subject filter : PlasmaFilter;
        attribute minSeparationEfficiency : Real = 0.90;
        assert filter.separationEfficiency >= minSeparationEfficiency;
    }

    requirement def OxygenationRequirement {
        doc "The oxygenator shall enrich the plasma with oxygen to support the health of living hepatocytes in the bioreactor";
        subject oxygenator : Oxygenator;
        attribute minOxygenSaturation : SaturationValue = 90;
        assert oxygenator.actualOxygenSaturation >= minOxygenSaturation;
    }

    requirement def BioreactorDetoxificationRequirement {
        doc "The bioreactor module shall contain living hepatocytes that detoxify the plasma by breaking down harmful substances including ammonia";
        subject bioreactor : BioreactorModule;
        attribute minCellViability : ViabilityValue = 70;
        assert bioreactor.cellViability >= minCellViability;
    }

    requirement def NutrientSupplyRequirement {
        doc "The nutrient reservoir shall continuously supply a nutrient medium to the hepatocytes to keep them alive and active";
        subject reservoir : NutrientReservoir;
        attribute minReservoirVolume : Real = 50;
        assert reservoir.reservoirVolume >= minReservoirVolume;
    }

    requirement def TemperatureControlRequirement {
        doc "The temperature controller shall precisely maintain the system at human body temperature approximately 37 degrees Celsius to ensure liver cells remain healthy and functional";
        subject controller : TemperatureController;
        attribute targetTemp : TemperatureValue = 37;
        attribute tolerance : TemperatureValue = 1;
        assert controller.actualTemperature >= targetTemp - tolerance;
        assert controller.actualTemperature <= targetTemp + tolerance;
    }

    requirement def BloodRecombinationRequirement {
        doc "After being cleansed in the bioreactor the detoxified plasma shall be recombined with the patient blood cells and returned to the patient body";
        subject recombiner : PlasmaRecombiner;
        attribute minRecombinationEfficiency : Real = 0.95;
        assert recombiner.recombinationEfficiency >= minRecombinationEfficiency;
    }

    requirement def MonitoringRequirement {
        doc "The monitoring system shall constantly measure critical parameters including blood pressure temperature oxygen saturation toxin levels and liver cell viability";
        subject monitor : MonitoringSystem;
        attribute measuredParameters : String = "bloodPressure, temperature, oxygenSaturation, toxinLevel, cellViability";
    }

    requirement def AlarmRequirement {
        doc "If any monitored parameter goes outside a safe range the system shall trigger an alarm to alert medical staff";
        subject monitor : MonitoringSystem;
        assert monitor.alarmActive == true if monitor.bloodPressureReading > monitor.safePressureMax or monitor.bloodPressureReading < monitor.safePressureMin;
        assert monitor.alarmActive == true if monitor.temperatureReading > monitor.safeTemperatureMax or monitor.temperatureReading < monitor.safeTemperatureMin;
        assert monitor.alarmActive == true if monitor.oxygenSaturationReading < monitor.safeOxygenSaturationMin;
        assert monitor.alarmActive == true if monitor.toxinLevelReading > monitor.safeToxinLevelMax;
        assert monitor.alarmActive == true if monitor.cellViabilityReading < monitor.minimumCellViability;
    }

    requirement def IdleStateRequirement {
        doc "The system shall include an idle state when on standby awaiting operator commands";
        subject device : BioartificialLiverDevice;
    }

    requirement def PrimingStateRequirement {
        doc "The system shall include a priming state to prepare the circuits for use before treatment begins";
        subject device : BioartificialLiverDevice;
    }

    requirement def ActiveTreatmentStateRequirement {
        doc "The system shall include an active treatment state during which blood is circulated and plasma is detoxified and returned to the patient";
        subject device : BioartificialLiverDevice;
    }

    requirement def EmergencyShutdownRequirement {
        doc "The system shall include clear protocols for emergency shutdown of the treatment ensuring patient safety at all times";
        subject device : BioartificialLiverDevice;
    }

    requirement def StartStopProtocolRequirement {
        doc "The system shall include clear protocols for starting and stopping the treatment to ensure patient safety at all times";
        subject device : BioartificialLiverDevice;
    }

    // ============================================================
    // REQUIREMENT SATISFACTION
    // ============================================================

    satisfaction satisfySystemPurpose : SystemPurposeRequirement {
        subject device : BioartificialLiverDevice;
    }

    satisfaction satisfyBloodPumpFlowRate : BloodPumpFlowRateRequirement {
        subject pump : BloodPump;
    }

    satisfaction satisfyPlasmaSeparation : PlasmaSeparationRequirement {
        subject filter : PlasmaFilter;
    }

    satisfaction satisfyOxygenation : OxygenationRequirement {
        subject oxygenator : Oxygenator;
    }

    satisfaction satisfyBioreactorDetoxification : BioreactorDetoxificationRequirement {
        subject bioreactor : BioreactorModule;
    }

    satisfaction satisfyNutrientSupply : NutrientSupplyRequirement {
        subject reservoir : NutrientReservoir;
    }

    satisfaction satisfyTemperatureControl : TemperatureControlRequirement {
        subject controller : TemperatureController;
    }

    satisfaction satisfyBloodRecombination : BloodRecombinationRequirement {
        subject recombiner : PlasmaRecombiner;
    }

    satisfaction satisfyMonitoring : MonitoringRequirement {
        subject monitor : MonitoringSystem;
    }

    satisfaction satisfyAlarm : AlarmRequirement {
        subject monitor : MonitoringSystem;
    }

    satisfaction satisfyIdleState : IdleStateRequirement {
        subject device : BioartificialLiverDevice;
    }

    satisfaction satisfyPrimingState : PrimingStateRequirement {
        subject device : BioartificialLiverDevice;
    }

    satisfaction satisfyActiveTreatmentState : ActiveTreatmentStateRequirement {
        subject device : BioartificialLiverDevice;
    }

    satisfaction satisfyEmergencyShutdown : EmergencyShutdownRequirement {
        subject device : BioartificialLiverDevice;
    }

    satisfaction satisfyStartStopProtocol : StartStopProtocolRequirement {
        subject device : BioartificialLiverDevice;
    }
}
