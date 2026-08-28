package AutonomousIntelligenceSystem {
    public import Definitions::*;
    
    package Definitions {
        public import AttributeDefinitions::*;
        public import PortDefinitions::*;
        public import ActionDefinitions::*;
        public import StateDefinitions::*;
        public import RequirementDefinitions::*;
        public import PartDefinitions::*;
        
        package AttributeDefinitions {
            private import ISQ::*;
            private import ScalarValues::*;
            
            enum def MaturityLevel {
                Concept;
                PrototypeDemonstration;
                OperationallyDemonstrated;
                Complete;
            }
            
            attribute def Command {
                attribute target : String;
                attribute parameter : String;
            }
            
            attribute def SensorData {
                attribute resolution : Integer;
                attribute payload : String;
            }
            
            attribute def Intelligence {
                attribute summary : String;
                attribute confidence : Real;
            }
            
            attribute def PowerStatus {
                attribute availablePower : PowerValue;
            }
            
            attribute def MaintenanceComplete;
        }
        
        package PortDefinitions {
            private import AttributeDefinitions::*;
            
            port def DataPort {
                out data : SensorData;
            }
            port def IntelligencePort {
                out intel : Intelligence;
            }
            port def CmdPort {
                out cmd : Command;
            }
            port def PowerPort {
                out status : PowerStatus;
            }
        }
        
        package ActionDefinitions {
            private import AttributeDefinitions::*;
            
            action def AcquireData {
                in inputCmd : Command;
                out data : SensorData;
            }
            action def ValidateData {
                in inputData : SensorData;
                out validData : SensorData;
            }
            action def AnalyzePatterns {
                in data : SensorData;
                out analysis : Intelligence;
            }
            action def GenerateIntelligence {
                in inputAnalysis : Intelligence;
                out report : Intelligence;
            }
            action def ProcessData {
                in data : SensorData;
                out intel : Intelligence;
                action validate : ValidateData {
                    in inputData = data;
                }
                action analyze : AnalyzePatterns;
                action generate : GenerateIntelligence {
                    out report = intel;
                }
                flow validate.validData to analyze.data;
                flow analyze.analysis to generate.inputAnalysis;
                first start;
                then validate;
                then analyze;
                then generate;
                then done;
            }
            action def TransmitIntelligence {
                in inputIntel : Intelligence;
            }
            action def ReceiveCommand {
                out cmd : Command;
            }
            action def AutonomousMission {
                in cmd : Command;
                out intel : Intelligence;
                action acquire : AcquireData {
                    in inputCmd = cmd;
                }
                action process : ProcessData;
                action transmit : TransmitIntelligence;
                flow acquire.data to process.data;
                flow process.intel to transmit.inputIntel;
                first start;
                then acquire;
                then process;
                then transmit;
                then done;
            }
        }
        
        package StateDefinitions {
            private import AttributeDefinitions::*;
            
            state def SensorStates {
                entry; then idle;
                state idle;
                transition first idle accept cmd : Command then acquiring;
                state acquiring;
                transition first acquiring then transmitting;
                state transmitting;
                transition first transmitting then idle;
                state maintenance;
                transition first idle accept MaintenanceComplete then maintenance;
                transition first maintenance then idle;
            }
            
            state def AIStates {
                entry; then ready;
                state ready;
                transition first ready accept data : SensorData then processing;
                state processing;
                transition first processing then ready;
            }
            
            state def CommStates {
                entry; then standby;
                state standby;
                transition first standby accept intel : Intelligence then transmitting;
                state transmitting;
                transition first transmitting then standby;
                transition first standby accept cmd : Command then receiving;
                state receiving;
                transition first receiving then standby;
            }
            
            state def PowerStates {
                entry; then active;
                state active;
            }
        }
        
        package RequirementDefinitions {
            private import AttributeDefinitions::*;
            private import ISQ::*;
            
            requirement def PowerMarginRequirement {
                attribute maxPower : PowerValue = 1000[W];
                attribute totalConsumption : PowerValue;
                constraint { totalConsumption <= maxPower * 0.8 }
            }
            requirement def CommRangeRequirement {
                attribute maxRange : LengthValue = 50[km];
                attribute actualRange : LengthValue;
                constraint { actualRange <= maxRange }
            }
            requirement def TechnologyReadinessRequirement {
                attribute minMaturity : MaturityLevel = MaturityLevel::PrototypeDemonstration;
            }
        }
        
        package PartDefinitions {
            private import AttributeDefinitions::*;
            private import PortDefinitions::*;
            private import ActionDefinitions::*;
            private import StateDefinitions::*;
            private import RequirementDefinitions::*;
            private import ISQ::*;
            
            part def AutonomousIntelligenceSystem {
                attribute maturity : MaturityLevel = MaturityLevel::PrototypeDemonstration;
                port cmdPort : ~CmdPort;
                port intelPort : IntelligencePort;
                
                part sensor : AdvancedSensorModule;
                part aiCore : AIProcessingCore;
                part comm : CommunicationSubsystem;
                part power : PowerManagementUnit;
                
                connect comm.cmdOut to sensor.cmdIn;
                connect sensor.dataOut to aiCore.dataIn;
                connect aiCore.intelOut to comm.intelIn;
                connect power.powerOut to sensor.powerIn;
                connect power.powerOut to aiCore.powerIn;
                connect power.powerOut to comm.powerIn;
                
                perform action mission : AutonomousMission;
                satisfy TechnologyReadinessRequirement;
            }
            
            part def AdvancedSensorModule {
                attribute maturity : MaturityLevel = MaturityLevel::OperationallyDemonstrated;
                port cmdIn : ~CmdPort;
                port dataOut : DataPort;
                port powerIn : ~PowerPort;
                perform action acquire : AcquireData;
                exhibit state sensorStates : SensorStates;
            }
            
            part def AIProcessingCore {
                attribute maturity : MaturityLevel = MaturityLevel::PrototypeDemonstration;
                port dataIn : ~DataPort;
                port intelOut : IntelligencePort;
                port powerIn : ~PowerPort;
                perform action process : ProcessData;
                exhibit state aiStates : AIStates;
            }
            
            part def CommunicationSubsystem {
                attribute maturity : MaturityLevel = MaturityLevel::Complete;
                port intelIn : ~IntelligencePort;
                port cmdOut : CmdPort;
                port powerIn : ~PowerPort;
                attribute actualRange : LengthValue = 50[km];
                perform action transmit : TransmitIntelligence;
                perform action receive : ReceiveCommand;
                exhibit state commStates : CommStates;
                satisfy CommRangeRequirement;
            }
            
            part def PowerManagementUnit {
                port powerOut : PowerPort;
                attribute totalCapacity : PowerValue = 1000[W];
                attribute totalConsumption : PowerValue;
                exhibit state powerStates : PowerStates;
                satisfy PowerMarginRequirement;
            }
        }
    }
}
