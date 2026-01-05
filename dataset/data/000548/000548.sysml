package BioartificialLiverSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ToxinConcentration :> ISQ::MassConcentrationValue;
    attribute def BloodFlowRate :> ISQ::VolumeFlowRateValue;
    attribute def OxygenSaturation :> Real;
    attribute def CellViability :> Real;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def PressureValue :> ISQ::PressureValue;
    
    item def Blood {
        attribute toxinLevel : ToxinConcentration;
        attribute oxygenSaturation : OxygenSaturation;
        attribute temperature : TemperatureValue;
        attribute flowRate : BloodFlowRate;
    }
    
    item def Plasma {
        attribute toxinLevel : ToxinConcentration;
        attribute proteinContent : ISQ::MassConcentrationValue;
    }
    
    item def NutrientMedium {
        attribute glucoseLevel : ISQ::MassConcentrationValue;
        attribute aminoAcidLevel : ISQ::MassConcentrationValue;
        attribute temperature : TemperatureValue;
    }
    
    item def OxygenGas {
        attribute purity : Real;
        attribute flowRate : ISQ::VolumeFlowRateValue;
    }
    
    item def StartTreatment;
    item def StopTreatment;
    item def EmergencyShutdown;
    
    port def BloodInletPort {
        in item blood : Blood;
    }
    
    port def BloodOutletPort {
        out item blood : Blood;
    }
    
    port def PlasmaPort {
        inout item plasma : Plasma;
    }
    
    port def NutrientPort {
        in item nutrient : NutrientMedium;
    }
    
    port def OxygenPort {
        in item oxygen : OxygenGas;
    }
    
    part def BloodPump {
        attribute targetFlowRate : BloodFlowRate;
        attribute currentPressure : PressureValue;
        port inlet : BloodInletPort;
        port outlet : BloodOutletPort;
    }
    
    part def PlasmaFilter {
        attribute membraneArea : ISQ::AreaValue;
        attribute filterEfficiency : Real;
        port bloodIn : BloodInletPort;
        port plasmaOut : PlasmaPort;
        port cellsOut : BloodOutletPort;
    }
    
    part def Oxygenator {
        attribute membraneArea : ISQ::AreaValue;
        attribute oxygenTransferRate : ISQ::VolumeFlowRateValue;
        port bloodIn : BloodInletPort;
        port bloodOut : BloodOutletPort;
        port oxygenIn : OxygenPort;
    }
    
    part def BioreactorModule {
        attribute hepatocyteCount : Real;
        attribute cellViability : CellViability;
        attribute temperature : TemperatureValue;
        attribute metabolicActivity : Real;
        port plasmaIn : PlasmaPort;
        port plasmaOut : PlasmaPort;
        port nutrientIn : NutrientPort;
        
        part hepatocyteCulture[*] {
            attribute viability : Real;
            attribute metabolicRate : Real;
            attribute detoxificationCapacity : Real;
        }
    }
    
    part def TemperatureController {
        attribute targetTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        attribute heatingPower : ISQ::PowerValue;
    }
    
    part def MonitoringSystem {
        attribute measuredToxinLevel : ToxinConcentration;
        attribute measuredOxygenLevel : OxygenSaturation;
        attribute measuredTemperature : TemperatureValue;
        attribute measuredPressure : PressureValue;
        attribute measuredCellViability : CellViability;
        port sensorInputs[*];
        port alarmOutput;
    }
    
    part def NutrientReservoir {
        attribute capacity : ISQ::VolumeValue;
        attribute currentLevel : ISQ::VolumeValue;
        port nutrientOut : NutrientPort;
    }
    
    action def PumpBlood {
        in bloodInput : Blood;
        in targetFlow : BloodFlowRate;
        out bloodOutput : Blood;
    }
    
    action def FilterPlasma {
        in wholeBlood : Blood;
        out plasma : Plasma;
        out bloodCells : Blood;
    }
    
    action def OxygenateBlood {
        in deoxygenatedBlood : Blood;
        in oxygenSupply : OxygenGas;
        out oxygenatedBlood : Blood;
    }
    
    action def DetoxifyPlasma {
        in contaminatedPlasma : Plasma;
        in cellActivity : Real;
        out detoxifiedPlasma : Plasma;
    }
    
    action def SupplyNutrients {
        in metabolicDemand : Real;
        out nutrientFlow : NutrientMedium;
    }
    
    action def RegulateTemperature {
        in targetTemp : TemperatureValue;
        in currentTemp : TemperatureValue;
        out controlSignal : ISQ::PowerValue;
    }
    
    action def MonitorParameters {
        in bloodSample : Blood;
        in plasmaSample : Plasma;
        in cellViability : CellViability;
        out toxinLevel : ToxinConcentration;
        out oxygenLevel : OxygenSaturation;
        out temperature : TemperatureValue;
        out alarmStatus : Boolean;
    }
    
    action def ProvideLiverSupport {
        in patientBlood : Blood;
        in oxygenSupply : OxygenGas;
        in nutrientSupply : NutrientMedium;
        out treatedBlood : Blood;
        
        first start;
        then merge continueTreatment;
        
        then action pumpBlood : PumpBlood {
            in bloodInput = patientBlood;
            in targetFlow : BloodFlowRate;
            out bloodOutput : Blood;
        }
        
        flow pumpBlood.bloodOutput to filterPlasma.wholeBlood;
        
        then action filterPlasma : FilterPlasma {
            in wholeBlood : Blood;
            out plasma : Plasma;
            out bloodCells : Blood;
        }
        
        flow filterPlasma.plasma to oxygenatePlasma.deoxygenatedBlood;
        
        then action oxygenatePlasma : OxygenateBlood {
            in deoxygenatedBlood : Blood;
            in oxygenSupply = oxygenSupply;
            out oxygenatedBlood : Blood;
        }
        
        flow oxygenatePlasma.oxygenatedBlood to detoxifyPlasma.contaminatedPlasma;
        
        then action detoxifyPlasma : DetoxifyPlasma {
            in contaminatedPlasma : Plasma;
            in cellActivity : Real;
            out detoxifiedPlasma : Plasma;
        }
        
        then action supplyNutrients : SupplyNutrients {
            in metabolicDemand : Real;
            out nutrientFlow : NutrientMedium;
        }
        
        then action regulateTemp : RegulateTemperature {
            in targetTemp : TemperatureValue;
            in currentTemp : TemperatureValue;
            out controlSignal : ISQ::PowerValue;
        }
        
        then action monitorParams : MonitorParameters {
            in bloodSample : Blood;
            in plasmaSample : Plasma;
            in cellViability : CellViability;
            out toxinLevel : ToxinConcentration;
            out oxygenLevel : OxygenSaturation;
            out temperature : TemperatureValue;
            out alarmStatus : Boolean;
        }
        
        then decide;
            if monitorParams.alarmStatus == false then continueTreatment;
            if monitorParams.alarmStatus == true then emergencyStop;
        
        action emergencyStop;
        then done;
    }
    
    state def DeviceOperationalStates {
        entry; then idle;
        
        state idle {
            doc /* Device is powered but not actively treating. */
        }
        
        transition idle_to_priming
            first idle
            accept StartTreatment
            then priming;
        
        state priming {
            doc /* System is being prepared for treatment. */
        }
        
        transition priming_to_active
            first priming
            if systemReady
            then activeTreatment;
        
        state activeTreatment {
            doc /* Device is actively treating patient blood. */
            
            state circulating {
                doc /* Blood is being circulated through the system. */
            }
            
            state detoxifying {
                doc /* Hepatocytes are metabolizing toxins. */
            }
            
            state monitoring {
                doc /* Parameters are being continuously monitored. */
            }
        }
        
        transition active_to_alarm
            first activeTreatment
            if alarmCondition
            then alarm;
        
        state alarm {
            doc /* Alarm condition detected, treatment paused. */
        }
        
        transition alarm_to_shutdown
            first alarm
            accept EmergencyShutdown
            then shutdown;
        
        transition active_to_shutdown
            first activeTreatment
            accept StopTreatment
            then shutdown;
        
        state shutdown {
            doc /* Device is safely shutting down. */
        }
        
        then done;
        
        attribute systemReady : Boolean;
        attribute alarmCondition : Boolean;
    }
    
    requirement def FunctionalRequirement {
        doc /* Defines functional capabilities of the bioartificial liver device. */
    }
    
    requirement def SafetyRequirement {
        doc /* Defines safety constraints for patient protection. */
    }
    
    requirement def PerformanceRequirement {
        doc /* Defines performance metrics for treatment efficacy. */
    }
    
    requirement <'REQ-001'> detoxificationEfficiency : PerformanceRequirement {
        doc /* The device shall reduce blood toxin concentration by at least 50% per treatment cycle. */
        subject device : BioartificialLiverDevice;
    }
    
    requirement <'REQ-002'> bloodFlowControl : PerformanceRequirement {
        doc /* The device shall maintain blood flow rate between 150 and 400 mL/min. */
        subject device : BioartificialLiverDevice;
    }
    
    requirement <'REQ-003'> temperatureRegulation : SafetyRequirement {
        doc /* The bioreactor temperature shall be maintained at 37°C ± 0.3°C. */
        subject device : BioartificialLiverDevice;
    }
    
    requirement <'REQ-004'> cellViabilityMaintenance : PerformanceRequirement {
        doc /* Hepatocyte viability shall remain above 90% during treatment. */
        subject device : BioartificialLiverDevice;
    }
    
    requirement <'REQ-005'> oxygenationLevel : SafetyRequirement {
        doc /* Blood oxygen saturation shall be maintained above 95%. */
        subject device : BioartificialLiverDevice;
    }
    
    requirement <'REQ-006'> biocompatibility : SafetyRequirement {
        doc /* All blood-contacting surfaces shall be biocompatible and prevent hemolysis. */
        subject device : BioartificialLiverDevice;
    }
    
    part def BioartificialLiverDevice {
        doc /* 
            A bioartificial liver device provides temporary hepatic support to patients 
            with acute or chronic liver failure. The device circulates patient blood through 
            an extracorporeal circuit where plasma is separated, oxygenated, and exposed to 
            living hepatocytes cultured in a bioreactor module. These cells perform critical 
            liver functions including detoxification of ammonia and other metabolic waste products, 
            synthesis of essential proteins, and biotransformation of drugs and toxins. 
            The treated blood is then returned to the patient, bridging liver function until 
            transplantation or native liver recovery.
        */
        
        port bloodInlet : BloodInletPort;
        port bloodOutlet : BloodOutletPort;
        
        part pump : BloodPump;
        part plasmaFilter : PlasmaFilter;
        part oxygenator : Oxygenator;
        part bioreactor : BioreactorModule;
        part tempController : TemperatureController;
        part monitor : MonitoringSystem;
        part nutrientReservoir : NutrientReservoir;
        
        connection inletToPump connect bloodInlet to pump.inlet;
        connection pumpToFilter connect pump.outlet to plasmaFilter.bloodIn;
        connection filterToOxygenator connect plasmaFilter.plasmaOut to oxygenator.bloodIn;
        connection oxygenatorToBioreactor connect oxygenator.bloodOut to bioreactor.plasmaIn;
        connection bioreactorToOutlet connect bioreactor.plasmaOut to bloodOutlet;
        connection nutrientToBioreactor connect nutrientReservoir.nutrientOut to bioreactor.nutrientIn;
        
        perform action treatmentCycle : ProvideLiverSupport;
        
        exhibit state operationalStates : DeviceOperationalStates;
    }
    
    part bioartificialLiverSystem : BioartificialLiverDevice {
        satisfy detoxificationEfficiency;
        satisfy bloodFlowControl;
        satisfy temperatureRegulation;
        satisfy cellViabilityMaintenance;
        satisfy oxygenationLevel;
        satisfy biocompatibility;
    }
}
