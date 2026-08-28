package CesiumAtomicClock {
    package Definitions {
        private import ScalarValues::*;
        private import ISQ::*;
        private import ValueDefinitions::*;
        private import PortDefinitions::*;
        private import ActionDefinitions::*;
        private import StateDefinitions::*;
        private import PartDefinitions::*;
        private import RequirementDefinitions::*;
        
        package ValueDefinitions {
            private import ScalarValues::*;
            private import ISQ::*;
            
            attribute def FrequencyValue :> ISQ::frequency;
            attribute def TemperatureValue :> ISQ::temperature;
            attribute def PressureValue :> ISQ::pressure;
            attribute def VoltageValue :> ISQ::voltage;
            attribute def PowerValue :> ISQ::power;
            attribute def TimeValue :> ISQ::time;
            
            attribute def RFSignal {
                attribute frequency : FrequencyValue;
                attribute amplitude : VoltageValue;
            }
            attribute def MicrowaveSignal {
                attribute frequency : FrequencyValue;
                attribute power : PowerValue;
            }
            attribute def AtomicResponse {
                attribute amplitude : Real;
                attribute phase : Real;
            }
            attribute def FrequencyError {
                attribute errorValue : FrequencyValue;
            }
            attribute def CorrectionSignal {
                attribute controlVoltage : VoltageValue;
            }
            attribute def TimePulse {
                attribute rate : FrequencyValue;
                attribute period : TimeValue;
            }
            attribute def ElectricalPower {
                attribute voltage : VoltageValue;
                attribute current : Real;
            }
            attribute def TemperatureCommand {
                attribute setPoint : TemperatureValue;
            }
            attribute def Cesium133;
            
            attribute def InitializationComplete;
            attribute def TemperatureStable;
            attribute def LockAchieved;
            attribute def LockVerified;
            attribute def FaultDetected;
            attribute def Reset;
        }
        
        package PortDefinitions {
            private import ValueDefinitions::*;
            
            port def RfOutPort { out rf : RFSignal; }
            port def RfInPort { in rf : RFSignal; }
            port def MicrowaveOutPort { out mw : MicrowaveSignal; }
            port def MicrowaveInPort { in mw : MicrowaveSignal; }
            port def ResponseOutPort { out resp : AtomicResponse; }
            port def ResponseInPort { in resp : AtomicResponse; }
            port def ErrorOutPort { out err : FrequencyError; }
            port def ErrorInPort { in err : FrequencyError; }
            port def CorrectionOutPort { out corr : CorrectionSignal; }
            port def CorrectionInPort { in corr : CorrectionSignal; }
            port def TimeOutputPort { out timePulse : TimePulse; }
            port def TemperatureOutPort { out tempCmd : TemperatureCommand; }
            port def TemperatureInPort { in tempCmd : TemperatureCommand; }
            port def PowerOutPort { out pwr : ElectricalPower; }
            port def PowerInPort { in pwr : ElectricalPower; }
        }
        
        package ActionDefinitions {
            action def InitializeSystem;
            action def WarmUpSystem;
            action def StabilizeLoop;
            action def GenerateTimeSignal;
            action def HandleFault;
            action def InterrogateAtoms;
            action def MaintainVacuum;
            action def ProvideShielding;
            action def ControlTemperature;
            action def GenerateRF;
            action def MultiplyFrequency;
            action def DetectPhaseError;
            action def CalculateCorrection;
            action def DivideFrequency;
            action def SupplyPower;
        }
        
        package StateDefinitions {
            private import ActionDefinitions::*;
            private import ValueDefinitions::*;
            
            state def ClockStates {
                entry; then Initialization;
                
                state Initialization;
                accept InitializationComplete then WarmingUp;
                
                state WarmingUp;
                accept TemperatureStable then Stabilization;
                
                state Stabilization;
                accept LockAchieved then Locked;
                
                state Locked;
                accept LockVerified then Operational;
                
                state Operational;
                accept FaultDetected then Fault;
                
                state Fault;
                accept Reset then Initialization;
            }
        }
        
        package PartDefinitions {
            private import ScalarValues::*;
            private import PortDefinitions::*;
            private import ValueDefinitions::*;
            private import StateDefinitions::*;
            private import ActionDefinitions::*;
            
            part def CesiumAtomicClockSystem {
                port timeOutput : TimeOutputPort;
                
                part resonator : CesiumResonator;
                part oscillator : CrystalOscillator;
                part multiplier : FrequencyMultiplier;
                part detector : PhaseDetector;
                part servo : ServoController;
                part divider : FrequencyDivider;
                part power : PowerSupply;
                part tempController : TemperatureController;
                
                flow rfToMultiplier of RFSignal from oscillator.rfOut.rf to multiplier.rfIn.rf;
                flow mwToResonator of MicrowaveSignal from multiplier.mwOut.mw to resonator.microwaveIn.mw;
                flow respToDetector of AtomicResponse from resonator.responseOut.resp to detector.responseIn.resp;
                flow errToServo of FrequencyError from detector.errorOut.err to servo.errorIn.err;
                flow corrToOscillator of CorrectionSignal from servo.correctionOut.corr to oscillator.correctionIn.corr;
                flow rfToDivider of RFSignal from oscillator.rfOut.rf to divider.rfIn.rf;
                flow timePulseOut of TimePulse from divider.timeOut.timePulse to timeOutput.timePulse;
                flow tempToResonator of TemperatureCommand from tempController.tempOut.tempCmd to resonator.tempIn.tempCmd;
                
                flow pwrToResonator of ElectricalPower from power.powerOut.pwr to resonator.powerIn.pwr;
                flow pwrToOscillator of ElectricalPower from power.powerOut.pwr to oscillator.powerIn.pwr;
                flow pwrToMultiplier of ElectricalPower from power.powerOut.pwr to multiplier.powerIn.pwr;
                flow pwrToDetector of ElectricalPower from power.powerOut.pwr to detector.powerIn.pwr;
                flow pwrToServo of ElectricalPower from power.powerOut.pwr to servo.powerIn.pwr;
                flow pwrToDivider of ElectricalPower from power.powerOut.pwr to divider.powerIn.pwr;
                flow pwrToTempController of ElectricalPower from power.powerOut.pwr to tempController.powerIn.pwr;
                
                exhibit state states : ClockStates;
            }
            
            part def CesiumResonator {
                port microwaveIn : MicrowaveInPort;
                port responseOut : ResponseOutPort;
                port tempIn : TemperatureInPort;
                port powerIn : PowerInPort;
                attribute resonanceFrequency : FrequencyValue = 9192631770.0;
                attribute cesiumAtoms : Cesium133;
                part vacuumChamber : VacuumChamber;
                part magneticShield : MagneticShield;
                perform action interrogateAtoms : InterrogateAtoms;
            }
            
            part def VacuumChamber {
                attribute internalPressure : PressureValue = 1.0e-9;
                perform action maintainVacuum : MaintainVacuum;
            }
            
            part def MagneticShield {
                attribute shieldingFactor : Real = 120.0;
                attribute layers : Integer = 3;
                perform action provideShielding : ProvideShielding;
            }
            
            part def TemperatureController {
                attribute targetTemperature : TemperatureValue = 300.0;
                port tempOut : TemperatureOutPort;
                port powerIn : PowerInPort;
                perform action controlTemperature : ControlTemperature;
            }
            
            part def CrystalOscillator {
                port rfOut : RfOutPort;
                port correctionIn : CorrectionInPort;
                port powerIn : PowerInPort;
                attribute nominalFrequency : FrequencyValue = 10.0e6;
                perform action generateRF : GenerateRF;
            }
            
            part def FrequencyMultiplier {
                port rfIn : RfInPort;
                port mwOut : MicrowaveOutPort;
                port powerIn : PowerInPort;
                attribute multiplicationFactor : Real = 919.263177;
                perform action multiplyFrequency : MultiplyFrequency;
            }
            
            part def PhaseDetector {
                port responseIn : ResponseInPort;
                port errorOut : ErrorOutPort;
                port powerIn : PowerInPort;
                perform action detectPhaseError : DetectPhaseError;
            }
            
            part def ServoController {
                port errorIn : ErrorInPort;
                port correctionOut : CorrectionOutPort;
                port powerIn : PowerInPort;
                perform action calculateCorrection : CalculateCorrection;
            }
            
            part def FrequencyDivider {
                port rfIn : RfInPort;
                port timeOut : TimeOutputPort;
                port powerIn : PowerInPort;
                attribute divisionFactor : Integer = 10000000;
                perform action divideFrequency : DivideFrequency;
            }
            
            part def PowerSupply {
                port powerOut : PowerOutPort;
                attribute outputPower : PowerValue;
                perform action supplyPower : SupplyPower;
            }
        }
        
        package RequirementDefinitions {
            private import ScalarValues::*;
            private import PartDefinitions::*;
            private import ValueDefinitions::*;
            
            requirement def StabilityRequirement {
                doc /* The system shall maintain a highly stable time reference based on cesium-133 resonance. */
                attribute requiredAllanDeviation : Real;
                subject clockSystem : CesiumAtomicClockSystem;
            }
            requirement def AccuracyRequirement {
                doc /* The system shall generate an accurate time signal. */
                attribute requiredAccuracy : Real;
                subject clockSystem : CesiumAtomicClockSystem;
            }
            requirement def VacuumRequirement {
                doc /* The vacuum chamber shall maintain pressure below 1e-9 Pa. */
                attribute maxPressure : PressureValue;
                subject vacuumChamber : VacuumChamber;
            }
            requirement def TemperatureStabilityRequirement {
                doc /* The temperature controller shall maintain resonator temperature within 0.01 K. */
                attribute maxDeviation : TemperatureValue;
                subject tempController : TemperatureController;
            }
            requirement def PowerRequirement {
                doc /* The entire system shall be powered by a central Power Supply. */
                subject clockSystem : CesiumAtomicClockSystem;
            }
        }
    }
    
    package Usages {
        private import ScalarValues::*;
        private import Definitions::*;
        
        part cesiumClock : CesiumAtomicClockSystem;
        
        requirement stabilityReq : StabilityRequirement {
            attribute redefines requiredAllanDeviation = 1.0e-14;
        }
        requirement accuracyReq : AccuracyRequirement {
            attribute redefines requiredAccuracy = 1.0e-12;
        }
        requirement vacuumReq : VacuumRequirement {
            attribute redefines maxPressure = 1.0e-9;
        }
        requirement tempStabilityReq : TemperatureStabilityRequirement {
            attribute redefines maxDeviation = 0.01;
        }
        requirement powerReq : PowerRequirement;
        
        satisfy stabilityReq by cesiumClock;
        satisfy accuracyReq by cesiumClock;
        satisfy vacuumReq by cesiumClock.resonator.vacuumChamber;
        satisfy tempStabilityReq by cesiumClock.tempController;
        satisfy powerReq by cesiumClock.power;
    }
}
