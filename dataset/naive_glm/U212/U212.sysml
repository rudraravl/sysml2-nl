package EffluentDecontaminationSystem {
    import SI::*;
    import ISQ::*;

    // ===== Custom Units =====
    unit ppm {
        doc /* Parts per million for contaminant concentration */;
    }
    unit L_per_min {
        doc /* Liters per minute for flow rate */;
    }
    unit mL_per_L {
        doc /* Milliliters per liter for dosing */;
    }

    // ===== Value Types =====
    value type ConcentrationValue :> Real {
        unit ppm;
        doc /* Contaminant concentration in ppm */;
    }
    value type pHValue :> Real {
        doc /* pH scale value from 0 to 14 */;
        constraint { 0.0 <= self and self <= 14.0 }
    }
    value type FlowRateValue :> Real {
        unit L_per_min;
        doc /* Flow rate in liters per minute */;
    }
    value type VolumeValue :> Real {
        unit L;
        doc /* Volume in liters */;
    }
    value type PowerValue :> Real {
        unit W;
        doc /* Power in watts */;
    }
    value type DurationValue :> Real {
        unit s;
        doc /* Duration in seconds */;
    }
    value type DoseValue :> Real {
        unit mL_per_L;
        doc /* Dose in milliliters per liter */;
    }

    // ===== Item Definitions =====
    item def Wastewater {
        doc /* Base type for all wastewater in the system */;
        attribute contaminantLevel : ConcentrationValue;
        attribute pH : pHValue;
        attribute totalSuspendedSolids : ConcentrationValue;
    }
    item def RawEffluent :> Wastewater {
        doc /* Raw contaminated wastewater entering the system */;
        attribute source : String;
    }
    item def FilteredEffluent :> RawEffluent {
        doc /* Effluent after removal of large solid particles */;
        attribute suspendedSolidsRemoved : ConcentrationValue;
    }
    item def ChemicallyTreatedEffluent :> FilteredEffluent {
        doc /* Effluent after chemical neutralization */;
        attribute reagentDoseApplied : DoseValue;
        attribute neutralizedContaminants : ConcentrationValue;
    }
    item def BiologicallyTreatedEffluent :> ChemicallyTreatedEffluent {
        doc /* Effluent after biological digestion */;
        attribute organicLoadReduction : ConcentrationValue;
        attribute digestionTime : DurationValue;
    }
    item def SterilizedEffluent :> BiologicallyTreatedEffluent {
        doc /* Effluent after UV disinfection, final treated water */;
        attribute microbialCount : ConcentrationValue;
        attribute uvExposureDose : PowerValue;
    }
    item def ChemicalReagent {
        doc /* Chemical reagent for neutralizing contaminants */;
        attribute reagentName : String;
        attribute concentration : ConcentrationValue;
        attribute volume : VolumeValue;
    }
    item def Biomass {
        doc /* Concentrated biomass for biological treatment */;
        attribute biomassType : String;
        attribute concentration : ConcentrationValue;
        attribute volume : VolumeValue;
    }
    item def SampleData {
        doc /* Quality monitor sample data */;
        attribute contaminantLevel : ConcentrationValue;
        attribute pH : pHValue;
        attribute sampleTime : DurationValue;
    }
    item def AlarmSignal {
        doc /* Alarm signal raised on quality failure */;
        attribute severity : Integer;
        attribute message : String;
        attribute alarmTime : DurationValue;
    }
    item def ControlCommand {
        doc /* Control command for subsystems */;
        attribute commandType : String;
        attribute commandValue : Real;
    }

    // ===== Port Definitions =====
    port def FluidInPort {
        in item effluent : Wastewater;
        doc /* Inlet port for wastewater flow */;
    }
    port def FluidOutPort {
        out item effluent : Wastewater;
        doc /* Outlet port for wastewater flow */;
    }
    port def ReagentOutPort {
        out item reagent : ChemicalReagent;
        doc /* Outlet port for chemical reagent */;
    }
    port def ReagentInPort {
        in item reagent : ChemicalReagent;
        doc /* Inlet port for chemical reagent */;
    }
    port def BiomassOutPort {
        out item biomass : Biomass;
        doc /* Outlet port for biomass */;
    }
    port def BiomassInPort {
        in item biomass : Biomass;
        doc /* Inlet port for biomass */;
    }
    port def SampleOutPort {
        out item sample : SampleData;
        doc /* Outlet port for quality sample data */;
    }
    port def SampleInPort {
        in item sample : SampleData;
        doc /* Inlet port for quality sample data */;
    }
    port def AlarmOutPort {
        out item alarm : AlarmSignal;
        doc /* Outlet port for alarm signal */;
    }
    port def AlarmInPort {
        in item alarm : AlarmSignal;
        doc /* Inlet port for alarm signal */;
    }
    port def CommandOutPort {
        out item command : ControlCommand;
        doc /* Outlet port for control commands */;
    }
    port def CommandInPort {
        in item command : ControlCommand;
        doc /* Inlet port for control commands */;
    }

    // ===== Part Definitions =====
    part def IntakePump {
        doc /* Draws raw effluent into the system at a minimum of 1000 L/min */;
        attribute ratedFlowRate : FlowRateValue = 1200 [L_per_min];
        attribute isRunning : Boolean = false;
        attribute powerConsumption : PowerValue = 1500 [W];
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port commandIn : CommandInPort;
        action def PumpOperation {
            doc /* Pumps raw effluent at rated flow rate */;
            in item rawEffluent : RawEffluent;
            out item pumpedEffluent : RawEffluent;
        }
    }

    part def PreTreatmentFilter {
        doc /* Removes large solid particles from raw effluent */;
        attribute filterMeshSize : ConcentrationValue = 50 [ppm];
        attribute isClogged : Boolean = false;
        attribute filterEfficiency : Real = 0.95;
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        action def FilterOperation {
            doc /* Physical filtration of large suspended solids */;
            in item incomingEffluent : RawEffluent;
            out item filteredEffluent : FilteredEffluent;
        }
    }

    part def ChemicalReactor {
        doc /* Introduces chemical reagent to neutralize contaminants */;
        attribute reagentDoseRate : DoseValue = 5 [mL_per_L];
        attribute reactionTime : DurationValue = 120 [s];
        attribute tankVolume : VolumeValue = 500 [L];
        attribute isMixing : Boolean = false;
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port reagentIn : ReagentInPort;
        port commandIn : CommandInPort;
        action def ChemicalReaction {
            doc /* Chemical reagent neutralizes specific contaminants */;
            in item incomingEffluent : FilteredEffluent;
            in item reagent : ChemicalReagent;
            out item treatedEffluent : ChemicallyTreatedEffluent;
        }
    }

    part def BiologicalTreatmentUnit {
        doc /* Uses concentrated biomass to digest organic waste over a set period */;
        attribute digestionPeriod : DurationValue = 3600 [s];
        attribute biomassConcentration : ConcentrationValue = 2000 [ppm];
        attribute tankVolume : VolumeValue = 2000 [L];
        attribute aerationRate : FlowRateValue = 50 [L_per_min];
        attribute isActive : Boolean = false;
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port biomassIn : BiomassInPort;
        port commandIn : CommandInPort;
        action def BiologicalDigestion {
            doc /* Microorganisms digest and break down organic waste */;
            in item incomingEffluent : ChemicallyTreatedEffluent;
            in item biomass : Biomass;
            out item digestedEffluent : BiologicallyTreatedEffluent;
        }
    }

    part def UVSterilizer {
        doc /* Uses high-intensity UV light to disinfect water, killing bacteria and viruses */;
        attribute uvPower : PowerValue = 200 [W];
        attribute exposureTime : DurationValue = 30 [s];
        attribute uvWavelength_nm : Real = 254;
        attribute isOperational : Boolean = false;
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port commandIn : CommandInPort;
        action def UVDisinfection {
            doc /* UV light kills remaining bacteria and viruses */;
            in item incomingEffluent : BiologicallyTreatedEffluent;
            in attribute power : PowerValue;
            out item sterilizedEffluent : SterilizedEffluent;
        }
    }

    part def QualityMonitor {
        doc /* Samples treated effluent and measures final contaminant concentration and pH */;
        attribute samplingInterval : DurationValue = 60 [s];
        attribute isCalibrated : Boolean = true;
        attribute lastContaminantReading : ConcentrationValue;
        attribute lastpHReading : pHValue;
        port fluidIn : FluidInPort;
        port sampleOut : SampleOutPort;
        port commandIn : CommandInPort;
        action def SamplingAndAnalysis {
            doc /* Samples effluent and measures contaminant level and pH */;
            in item incomingEffluent : SterilizedEffluent;
            out item sampleData : SampleData;
        }
    }

    part def ControlSystem {
        doc /* Central control system that uses quality data to ensure treatment effectiveness */;
        attribute maxAllowableContaminant : ConcentrationValue = 10 [ppm];
        attribute targetpHMin : pHValue = 6.5;
        attribute targetpHMax : pHValue = 8.5;
        attribute isOperational : Boolean = false;
        attribute currentContaminantLevel : ConcentrationValue;
        attribute currentpH : pHValue;
        attribute isApproved : Boolean = false;
        attribute sampleReceived : Boolean = false;
        port sampleIn : SampleInPort;
        port commandOut : CommandOutPort;
        port alarmOut : AlarmOutPort;
        action def EvaluateQuality {
            doc /* Evaluates water quality against safety standards */;
            in item sample : SampleData;
            out attribute approved : Boolean;
        }
        state def ControlState {
            doc /* Control system state machine for quality monitoring and alarm */;
            entry Idle;
            state Idle {
                doc /* System not running */;
            }
            state Monitoring {
                doc /* Receiving and processing sample data */;
            }
            state Evaluating {
                doc /* Checking sample against thresholds */;
            }
            state Approved {
                doc /* Quality meets standards, approved for discharge */;
            }
            state AlarmState {
                doc /* Quality fails, alarm active */;
            }
            transition from Idle to Monitoring when isOperational;
            transition from Monitoring to Evaluating when sampleReceived;
            transition from Evaluating to Approved when currentContaminantLevel <= maxAllowableContaminant;
            transition from Evaluating to AlarmState when currentContaminantLevel > maxAllowableContaminant;
            transition from Approved to Monitoring when isApproved;
            transition from AlarmState to Idle when not isOperational;
        }
        state controlState : ControlState;
    }

    part def AlarmSystem {
        doc /* Raises alarm to alert operators of system failure */;
        attribute isActive : Boolean = false;
        attribute alarmVolume : PowerValue = 80 [W];
        attribute alarmMessage : String = "Quality Failure: Contaminant Level Exceeds 10 ppm";
        port alarmIn : AlarmInPort;
        port alarmOut : AlarmOutPort;
    }

    part def OperatorInterface {
        doc /* Operator display and control interface */;
        attribute displayActive : Boolean = true;
        attribute operatorAcknowledged : Boolean = false;
        port alarmIn : AlarmInPort;
        port commandOut : CommandOutPort;
    }

    part def ReagentTank {
        doc /* Storage tank for chemical reagent supply */;
        attribute reagentName : String = "SodiumHypochlorite";
        attribute concentration : ConcentrationValue = 10000 [ppm];
        attribute volume : VolumeValue = 1000 [L];
        attribute minVolume : VolumeValue = 100 [L];
        port reagentOut : ReagentOutPort;
    }

    part def BiomassTank {
        doc /* Storage tank for biomass supply */;
        attribute biomassType : String = "ActivatedSludge";
        attribute concentration : ConcentrationValue = 5000 [ppm];
        attribute volume : VolumeValue = 500 [L];
        attribute minVolume : VolumeValue = 50 [L];
        port biomassOut : BiomassOutPort;
    }

    // ===== Connection Definitions =====
    connection def FluidConnection {
        end source : FluidOutPort;
        end target : FluidInPort;
        doc /* Connection for fluid effluent flow */;
    }
    connection def ReagentConnection {
        end source : ReagentOutPort;
        end target : ReagentInPort;
        doc /* Connection for chemical reagent flow */;
    }
    connection def BiomassConnection {
        end source : BiomassOutPort;
        end target : BiomassInPort;
        doc /* Connection for biomass flow */;
    }
    connection def SampleDataConnection {
        end source : SampleOutPort;
        end target : SampleInPort;
        doc /* Connection for quality sample data */;
    }
    connection def AlarmDataConnection {
        end source : AlarmOutPort;
        end target : AlarmInPort;
        doc /* Connection for alarm signal */;
    }
    connection def CommandDataConnection {
        end source : CommandOutPort;
        end target : CommandInPort;
        doc /* Connection for control commands */;
    }

    // ===== Main System Assembly =====
    part def EffluentDecontaminationPlant {
        doc /* Multi-stage effluent decontamination system treating raw contaminated wastewater through physical, chemical, and biological treatments before discharge */;

        attribute systemFlowRate : FlowRateValue = 1200 [L_per_min];
        attribute isRunning : Boolean = false;
        attribute startCommand : Boolean = false;
        attribute intakeComplete : Boolean = false;
        attribute filteringComplete : Boolean = false;
        attribute chemicalReactionComplete : Boolean = false;
        attribute biologicalDigestionComplete : Boolean = false;
        attribute uvExposureComplete : Boolean = false;
        attribute qualityApproved : Boolean = false;
        attribute qualityFailed : Boolean = false;
        attribute dischargeComplete : Boolean = false;
        attribute operatorReset : Boolean = false;

        // Subsystem parts
        part intakePump : IntakePump;
        part preTreatmentFilter : PreTreatmentFilter;
        part chemicalReactor : ChemicalReactor;
        part biologicalTreatmentUnit : BiologicalTreatmentUnit;
        part uvSterilizer : UVSterilizer;
        part qualityMonitor : QualityMonitor;
        part controlSystem : ControlSystem;
        part alarmSystem : AlarmSystem;
        part operatorInterface : OperatorInterface;
        part reagentTank : ReagentTank;
        part biomassTank : BiomassTank;

        // External ports
        port rawEffluentIn : FluidInPort;
        port treatedEffluentOut : FluidOutPort;
        port alarmSignalOut : AlarmOutPort;

        // Fluid flow connections
        connection rawInflow from rawEffluentIn to intakePump.fluidIn;
        connection pumpToFilter from intakePump.fluidOut to preTreatmentFilter.fluidIn;
        connection filterToReactor from preTreatmentFilter.fluidOut to chemicalReactor.fluidIn;
        connection reagentToReactor from reagentTank.reagentOut to chemicalReactor.reagentIn;
        connection reactorToBiological from chemicalReactor.fluidOut to biologicalTreatmentUnit.fluidIn;
        connection biomassToBiological from biomassTank.biomassOut to biologicalTreatmentUnit.biomassIn;
        connection biologicalToUV from biologicalTreatmentUnit.fluidOut to uvSterilizer.fluidIn;
        connection uvToMonitor from uvSterilizer.fluidOut to qualityMonitor.fluidIn;
        connection monitorToDischarge from qualityMonitor.fluidOut to treatedEffluentOut;

        // Data and control connections
        connection monitorToControl from qualityMonitor.sampleOut to controlSystem.sampleIn;
        connection controlToAlarm from controlSystem.alarmOut to alarmSystem.alarmIn;
        connection alarmToOperator from alarmSystem.alarmOut to operatorInterface.alarmIn;
        connection alarmToExternal from alarmSystem.alarmOut to alarmSignalOut;
        connection controlToPump from controlSystem.commandOut to intakePump.commandIn;
        connection controlToReactor from controlSystem.commandOut to chemicalReactor.commandIn;
        connection controlToBiological from controlSystem.commandOut to biologicalTreatmentUnit.commandIn;
        connection controlToUV from controlSystem.commandOut to uvSterilizer.commandIn;
        connection controlToMonitor from controlSystem.commandOut to qualityMonitor.commandIn;

        // Overall system state machine
        state def TreatmentProcess {
            doc /* Sequential automated treatment process state machine */;
            entry Idle;
            state Idle {
                doc /* System not running, waiting for start command */;
            }
            state Intaking {
                doc /* Intake pump drawing raw effluent into the system */;
            }
            state PreFiltering {
                doc /* Pre-treatment filter removing large solid particles */;
            }
            state ChemicalTreatment {
                doc /* Chemical reactor introducing reagent to neutralize contaminants */;
            }
            state BiologicalDigestion {
                doc /* Biological treatment unit using biomass to digest organic waste */;
            }
            state UVDisinfection {
                doc /* UV sterilizer using high-intensity UV light to disinfect water */;
            }
            state QualityMonitoring {
                doc /* Quality monitor measuring final contaminant concentration and pH */;
            }
            state Discharging {
                doc /* Treated effluent approved for final discharge */;
            }
            state SystemFailure {
                doc /* Alarm raised, water quality does not meet safety standards */;
            }
            transition from Idle to Intaking when startCommand;
            transition from Intaking to PreFiltering when intakeComplete;
            transition from PreFiltering to ChemicalTreatment when filteringComplete;
            transition from ChemicalTreatment to BiologicalDigestion when chemicalReactionComplete;
            transition from BiologicalDigestion to UVDisinfection when biologicalDigestionComplete;
            transition from UVDisinfection to QualityMonitoring when uvExposureComplete;
            transition from QualityMonitoring to Discharging when qualityApproved;
            transition from QualityMonitoring to SystemFailure when qualityFailed;
            transition from Discharging to Intaking when dischargeComplete;
            transition from SystemFailure to Idle when operatorReset;
        }
        state treatmentProcess : TreatmentProcess;
    }

    // ===== Requirements =====
    requirement def ContaminantLevelRequirement {
        doc /* Treated effluent must have a contaminant level of 10 ppm or less for discharge */;
        attribute contaminantLevel : ConcentrationValue;
        constraint { contaminantLevel <= 10 [ppm] }
    }

    requirement def pHRequirement {
        doc /* Treated effluent pH must be within acceptable range for discharge */;
        attribute pH : pHValue;
        constraint { pH >= 6.5 and pH <= 8.5 }
    }

    requirement def ProcessingRateRequirement {
        doc /* System must process a minimum of 1000 liters of wastewater per minute */;
        attribute flowRate : FlowRateValue;
        constraint { flowRate >= 1000 [L_per_min] }
    }

    requirement def AlarmOnFailureRequirement {
        doc /* Control system must raise an alarm when contaminant level exceeds 10 ppm */;
        attribute sampleContaminantLevel : ConcentrationValue;
        attribute alarmRaised : Boolean;
        constraint { sampleContaminantLevel > 10 [ppm] implies alarmRaised }
    }

    requirement def SequentialTreatmentRequirement {
        doc /* Treatment must follow sequential stages: intake, pre-filter, chemical, biological, UV, quality monitoring */;
        attribute stageCount : Integer;
        constraint { stageCount >= 6 }
    }

    requirement def PreTreatmentFilterRequirement {
        doc /* Pre-treatment filter must remove large solid particles from raw effluent */;
        attribute suspendedSolidsRemoved : ConcentrationValue;
        constraint { suspendedSolidsRemoved > 0 [ppm] }
    }

    requirement def ChemicalReactorRequirement {
        doc /* Chemical reactor must introduce a chemical reagent to neutralize contaminants */;
        attribute reagentDoseApplied : DoseValue;
        constraint { reagentDoseApplied > 0 [mL_per_L] }
    }

    requirement def BiologicalTreatmentRequirement {
        doc /* Biological treatment unit must use concentrated biomass to digest organic waste over a set period */;
        attribute digestionPeriod : DurationValue;
        attribute biomassConcentration : ConcentrationValue;
        constraint { digestionPeriod > 0 [s] and biomassConcentration > 0 [ppm] }
    }

    requirement def UVSterilizerRequirement {
        doc /* UV sterilizer must use high-intensity UV light to disinfect water */;
        attribute uvPower : PowerValue;
        attribute exposureTime : DurationValue;
        constraint { uvPower > 0 [W] and exposureTime > 0 [s] }
    }

    requirement def QualityMonitoringRequirement {
        doc /* Quality monitor must measure final contaminant concentration and pH levels */;
        attribute contaminantMeasured : Boolean;
        attribute pHMeasured : Boolean;
        constraint { contaminantMeasured and pHMeasured }
    }

    requirement def EffluentDecontaminationRequirements {
        doc /* Complete requirements for the effluent decontamination system */;
        requirement contamReq : ContaminantLevelRequirement;
        requirement pHReq : pHRequirement;
        requirement flowReq : ProcessingRateRequirement;
        requirement alarmReq : AlarmOnFailureRequirement;
        requirement seqReq : SequentialTreatmentRequirement;
        requirement filterReq : PreTreatmentFilterRequirement;
        requirement chemReq : ChemicalReactorRequirement;
        requirement bioReq : BiologicalTreatmentRequirement;
        requirement uvReq : UVSterilizerRequirement;
        requirement qualityMonReq : QualityMonitoringRequirement;
    }

    // ===== Verification Definitions =====
    verification def ContaminantLevelVerification {
        subject plant : EffluentDecontaminationPlant;
        objective {
            doc /* Verify treated effluent has contaminant level at or below 10 ppm */;
        }
        return result : Boolean;
    }

    verification def ProcessingRateVerification {
        subject plant : EffluentDecontaminationPlant;
        objective {
            doc /* Verify system processes at least 1000 liters per minute */;
        }
        return result : Boolean;
    }

    verification def AlarmVerification {
        subject plant : EffluentDecontaminationPlant;
        objective {
            doc /* Verify alarm is raised when contaminant level exceeds 10 ppm */;
        }
        return result : Boolean;
    }

    verification def SequentialProcessVerification {
        subject plant : EffluentDecontaminationPlant;
        objective {
            doc /* Verify all six treatment stages execute in sequence */;
        }
        return result : Boolean;
    }
}
