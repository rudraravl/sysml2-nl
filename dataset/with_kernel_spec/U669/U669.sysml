package 'Engine Knock Control System' {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        enum def KnockSeverity {
            light;
            moderate;
            severe;
        }

        attribute def VibrationFrequencyValue :> ISQ::FrequencyValue;
        attribute def SparkTimingValue :> ISQ::AngleValue;
        attribute def FuelEnrichmentFactorValue :> Real;

        item def KnockSignal {
            attribute intensity : Real;
            attribute severity : KnockSeverity;
            attribute frequency : VibrationFrequencyValue;
        }

        item def SparkTimingCommand {
            attribute delayAmount : SparkTimingValue;
        }

        item def FuelEnrichmentCommand {
            attribute enrichmentFactor : FuelEnrichmentFactorValue;
        }

        port def KnockSignalOutPort {
            out knockSignal : KnockSignal;
        }

        port def KnockSignalInPort {
            in knockSignal : KnockSignal;
        }

        port def SparkTimingCommandInPort {
            in sparkTimingCommand : SparkTimingCommand;
        }

        port def SparkTimingCommandOutPort {
            out sparkTimingCommand : SparkTimingCommand;
        }

        port def FuelEnrichmentCommandInPort {
            in fuelEnrichmentCommand : FuelEnrichmentCommand;
        }

        port def FuelEnrichmentCommandOutPort {
            out fuelEnrichmentCommand : FuelEnrichmentCommand;
        }

        action def SenseKnockAction {
            out knockSignal : KnockSignal;
        }

        action def AnalyzeKnockAction {
            in knockSignal : KnockSignal;
            out severity : KnockSeverity;
        }

        action def AdjustTimingAction {
            in sparkTimingCommand : SparkTimingCommand;
        }

        action def AdjustMixtureAction {
            in fuelEnrichmentCommand : FuelEnrichmentCommand;
        }

        action def MitigateLightKnockAction {
            out sparkTimingCommand : SparkTimingCommand;
        }

        action def MitigateModerateKnockAction {
            out sparkTimingCommand : SparkTimingCommand;
            out fuelEnrichmentCommand : FuelEnrichmentCommand;
        }

        action def SevereProtectionAction {
            out sparkTimingCommand : SparkTimingCommand;
            out fuelEnrichmentCommand : FuelEnrichmentCommand;
        }

        part def KnockSensor {
            port knockSignalOut : KnockSignalOutPort;
            perform action senseKnock : SenseKnockAction;
        }

        part def IgnitionSystem {
            port sparkTimingIn : SparkTimingCommandInPort;
            perform action adjustTiming : AdjustTimingAction;
        }

        part def FuelInjectionSystem {
            port fuelEnrichmentIn : FuelEnrichmentCommandInPort;
            perform action adjustMixture : AdjustMixtureAction;
        }

        state def ECUStates;

        part def EngineControlUnit {
            port knockSignalIn : KnockSignalInPort;
            port sparkTimingOut : SparkTimingCommandOutPort;
            port fuelEnrichmentOut : FuelEnrichmentCommandOutPort;
            
            attribute maxLightKnockThreshold : Real = 30.0;
            attribute maxModerateKnockThreshold : Real = 70.0;
            
            exhibit state ecuStates : ECUStates {
                entry; then NormalMonitoring;
                
                state NormalMonitoring;
                accept knockSignal : KnockSignal
                    if knockSignal.severity == KnockSeverity::light
                    then ActiveMitigation;
                accept knockSignal : KnockSignal
                    if knockSignal.severity == KnockSeverity::moderate
                    then ActiveMitigation;
                accept knockSignal : KnockSignal
                    if knockSignal.severity == KnockSeverity::severe
                    then AggressiveProtection;
                
                state ActiveMitigation {
                    entry action mitigateLight : MitigateLightKnockAction;
                }
                accept knockSignal : KnockSignal
                    if knockSignal.severity == KnockSeverity::severe
                    then AggressiveProtection;
                accept knockSignal : KnockSignal
                    if knockSignal.severity == KnockSeverity::light
                    then NormalMonitoring;
                
                state AggressiveProtection {
                    entry action severeProtect : SevereProtectionAction;
                }
                accept knockSignal : KnockSignal
                    if knockSignal.severity == KnockSeverity::moderate
                    then ActiveMitigation;
                accept knockSignal : KnockSignal
                    if knockSignal.severity == KnockSeverity::light
                    then NormalMonitoring;
            }
        }

        part def EngineAssembly {
            part knockSensor1 : KnockSensor;
            part knockSensor2 : KnockSensor;
            part ecu : EngineControlUnit;
            part ignitionSystem : IgnitionSystem;
            part fuelInjectionSystem : FuelInjectionSystem;
        }

        requirement def KnockDetectionRequirement {
            doc "The system shall detect engine knock using one or more knock sensors mounted on the engine block.";
        }
        
        requirement def KnockClassificationRequirement {
            doc "The ECU shall classify detected knock as light, moderate, or severe based on signal intensity.";
        }
        
        requirement def LightKnockMitigationRequirement {
            doc "For light knock, the ECU shall command the ignition system to delay spark timing.";
        }
        
        requirement def ModerateSevereKnockMitigationRequirement {
            doc "For moderate or severe knock, the ECU shall delay spark timing and command fuel enrichment.";
        }
        
        requirement def ClosedLoopVerificationRequirement {
            doc "After mitigation action, the ECU shall continue monitoring to confirm knock elimination.";
        }
        
        requirement def SevereKnockProtectionRequirement {
            doc "For severe persistent knock, the system shall enter aggressive protection mode to prevent catastrophic engine failure.";
        }
    }

    package Usages {
        private import Definitions::*;
        
        part engineAssembly : EngineAssembly {
            connect knockSensor1.knockSignalOut to ecu.knockSignalIn;
            connect knockSensor2.knockSignalOut to ecu.knockSignalIn;
            connect ecu.sparkTimingOut to ignitionSystem.sparkTimingIn;
            connect ecu.fuelEnrichmentOut to fuelInjectionSystem.fuelEnrichmentIn;
            
            flow knockSignalFlow1 of KnockSignal
                from knockSensor1.knockSignalOut.knockSignal 
                to ecu.knockSignalIn.knockSignal;
            
            flow knockSignalFlow2 of KnockSignal
                from knockSensor2.knockSignalOut.knockSignal 
                to ecu.knockSignalIn.knockSignal;
            
            flow sparkTimingCommandFlow of SparkTimingCommand
                from ecu.sparkTimingOut.sparkTimingCommand
                to ignitionSystem.sparkTimingIn.sparkTimingCommand;
            
            flow fuelEnrichmentCommandFlow of FuelEnrichmentCommand
                from ecu.fuelEnrichmentOut.fuelEnrichmentCommand
                to fuelInjectionSystem.fuelEnrichmentIn.fuelEnrichmentCommand;
        }
        
        satisfy knockDetectionReq1 : KnockDetectionRequirement by engineAssembly.knockSensor1;
        satisfy knockDetectionReq2 : KnockDetectionRequirement by engineAssembly.knockSensor2;
        satisfy knockClassificationReq : KnockClassificationRequirement by engineAssembly.ecu;
        satisfy lightKnockMitigationReq : LightKnockMitigationRequirement by engineAssembly.ecu;
        satisfy moderateSevereKnockMitigationReq : ModerateSevereKnockMitigationRequirement by engineAssembly.ecu;
        satisfy closedLoopVerificationReq : ClosedLoopVerificationRequirement by engineAssembly.ecu;
        satisfy severeKnockProtectionReq : SevereKnockProtectionRequirement by engineAssembly.ecu;
    }
}
