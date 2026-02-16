package VeinoplusSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def StimulationIntensity :> Real;
    attribute def PulseFrequency :> ISQ::FrequencyValue;
    attribute def PulseWidth :> ISQ::TimeValue;
    attribute def SessionDuration :> ISQ::TimeValue;
    attribute def BatteryLevel :> Real;
    attribute def SkinImpedance :> Real;
    
    enum def OperatingMode {
        enum off;
        enum standby;
        enum stimulating;
        enum paused;
        enum lowBattery;
        enum fault;
    }
    
    enum def StimulationProgram {
        enum continuous;
        enum pulsed;
        enum progressive;
    }
    
    item def ElectricalStimulus {
        attribute intensity : StimulationIntensity;
        attribute frequency : PulseFrequency;
        attribute pulseWidth : PulseWidth;
        attribute waveform : String;
    }
    
    item def VenousBloodFlow {
        attribute flowRate : ISQ::VolumeFlowRateValue;
        attribute velocity : ISQ::SpeedValue;
    }
    
    port def PowerPort {
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute current : ISQ::ElectricCurrentValue;
    }
    
    port def StimulationOutputPort {
        out item stimulus : ElectricalStimulus;
    }
    
    port def ElectrodeContactPort {
        in item stimulus : ElectricalStimulus;
        attribute impedance : SkinImpedance;
    }
    
    port def UserControlPort {
        in attribute programSelect : StimulationProgram;
        in attribute intensityAdjust : Real;
        in attribute startCommand : Boolean;
        in attribute stopCommand : Boolean;
        out attribute statusIndicator : OperatingMode;
    }
    
    part def BatteryModule {
        attribute capacity : Real = 1800.0;
        attribute currentCharge : BatteryLevel = 100.0;
        attribute voltage : ISQ::ElectricPotentialValue = 9.0 [V];
        
        port powerOut : PowerPort;
        
        action def DischargeBattery {
            in loadCurrent : ISQ::ElectricCurrentValue;
            in duration : ISQ::TimeValue;
            inout charge : BatteryLevel;
        }
    }
    
    part def ControlModule {
        attribute operatingMode : OperatingMode = OperatingMode::off;
        attribute selectedProgram : StimulationProgram = StimulationProgram::continuous;
        attribute currentIntensity : StimulationIntensity = 0.0;
        attribute sessionTimer : SessionDuration;
        
        port powerIn : PowerPort;
        port userInterface : UserControlPort;
        
        action def ManageDeviceState {
            in powerCommand : Boolean;
            in startCmd : Boolean;
            in stopCmd : Boolean;
            in pauseCmd : Boolean;
            in batteryLevel : BatteryLevel;
            inout deviceMode : OperatingMode;
        }
    }
    
    part def PulseGenerator {
        attribute outputIntensity : StimulationIntensity = 0.0;
        attribute outputFrequency : PulseFrequency = 1.0 [Hz];
        attribute outputPulseWidth : PulseWidth = 150.0 [us];
        
        port stimulationOutput : StimulationOutputPort;
        
        action def GenerateStimulationPulse {
            in intensity : StimulationIntensity;
            in frequency : PulseFrequency;
            in pulseWidth : PulseWidth;
            in program : StimulationProgram;
            out stimulus : ElectricalStimulus;
        }
    }
    
    part def ElectrodePad {
        attribute padArea : ISQ::AreaValue = 50.0 [cm^2];
        attribute contactQuality : Real = 0.95;
        attribute measuredImpedance : SkinImpedance;
        
        port electrodeContact : ElectrodeContactPort;
        
        action def TransferStimulus {
            in stimulus : ElectricalStimulus;
            in impedance : SkinImpedance;
            out deliveredStimulus : ElectricalStimulus;
        }
    }
    
    part def SafetyMonitor {
        attribute maxIntensity : StimulationIntensity = 99.0;
        attribute minImpedance : SkinImpedance = 100.0;
        attribute maxImpedance : SkinImpedance = 5000.0;
        attribute skinTemperature : ISQ::ThermodynamicTemperatureValue;
        
        action def MonitorSafetyParameters {
            in intensity : StimulationIntensity;
            in impedance : SkinImpedance;
            in temperature : ISQ::ThermodynamicTemperatureValue;
            out safetyStatus : Boolean;
            out faultDetected : Boolean;
        }
    }
    
    part def CalfMuscle {
        attribute restingTone : Real = 0.2;
        attribute contractionStrength : Real = 0.0;
        attribute fatigueLevel : Real = 0.0;
        
        port stimulationInput : ElectrodeContactPort;
        
        action def ContractMuscle {
            in stimulus : ElectricalStimulus;
            in currentTone : Real;
            out contractionForce : ISQ::ForceValue;
            out metabolicDemand : Real;
        }
    }
    
    part def VenousVessel {
        attribute baselineFlow : ISQ::VolumeFlowRateValue = 150.0 [mL/min];
        attribute enhancedFlow : ISQ::VolumeFlowRateValue;
        attribute vesselDiameter : ISQ::LengthValue = 8.0 [mm];
        
        action def EnhanceVenousReturn {
            in muscleContractionForce : ISQ::ForceValue;
            in baseFlow : ISQ::VolumeFlowRateValue;
            out enhancedFlow : ISQ::VolumeFlowRateValue;
            out bloodVelocity : ISQ::SpeedValue;
        }
    }
    
    action def DeliverElectricalStimulation {
        in program : StimulationProgram;
        in intensity : StimulationIntensity;
        in frequency : PulseFrequency;
        in duration : SessionDuration;
        out stimulusSequence : ElectricalStimulus[*] ordered;
        
        action generatePulse : GenerateStimulationPulse {
            in intensity;
            in frequency;
            in pulseWidth = 150.0 [us];
            in program;
            out stimulus;
        }
        
        flow generatePulse.stimulus to transferToSkin.stimulus;
        
        action transferToSkin : TransferStimulus {
            in stimulus;
            in impedance = 1000.0;
            out deliveredStimulus;
        }
    }
    
    action def InduceMuscleContraction {
        in stimulus : ElectricalStimulus;
        in muscleTone : Real;
        out contractionForce : ISQ::ForceValue;
        
        action contractMuscle : ContractMuscle {
            in stimulus;
            in currentTone = muscleTone;
            out contractionForce;
            out metabolicDemand;
        }
    }
    
    action def ImproveVenousCirculation {
        in contractionForce : ISQ::ForceValue;
        in baselineFlow : ISQ::VolumeFlowRateValue;
        out improvedFlow : ISQ::VolumeFlowRateValue;
        out flowIncrease : Real;
        
        action enhanceReturn : EnhanceVenousReturn {
            in muscleContractionForce = contractionForce;
            in baseFlow = baselineFlow;
            out enhancedFlow;
            out bloodVelocity;
        }
        
        then action calculateImprovement {
            assign flowIncrease := (enhanceReturn.enhancedFlow - baselineFlow) / baselineFlow * 100.0;
            assign improvedFlow := enhanceReturn.enhancedFlow;
        }
    }
    
    action def PerformTherapySession {
        in selectedProgram : StimulationProgram;
        in targetIntensity : StimulationIntensity;
        in sessionDuration : SessionDuration;
        out therapeuticOutcome : Real;
        
        first start;
        then merge checkConditions;
        
        action initializeSession {
            out deviceReady : Boolean;
            out safetyChecked : Boolean;
        }
        then checkConditions;
        
        then decide;
            if initializeSession.deviceReady and initializeSession.safetyChecked then beginStimulation;
            if not initializeSession.deviceReady or not initializeSession.safetyChecked then abortSession;
        
        action beginStimulation {
            perform action deliverStimulation : DeliverElectricalStimulation {
                in program = selectedProgram;
                in intensity = targetIntensity;
                in frequency = 1.0 [Hz];
                in duration = sessionDuration;
                out stimulusSequence;
            }
            
            perform action induceMuscle : InduceMuscleContraction {
                in stimulus = deliverStimulation.stimulusSequence->first();
                in muscleTone = 0.2;
                out contractionForce;
            }
            
            perform action improveCirculation : ImproveVenousCirculation {
                in contractionForce = induceMuscle.contractionForce;
                in baselineFlow = 150.0 [mL/min];
                out improvedFlow;
                out flowIncrease;
            }
        }
        then monitorSession;
        
        action monitorSession {
            out elapsedTime : SessionDuration;
            out safetyOk : Boolean;
        }
        then decide;
            if monitorSession.elapsedTime < sessionDuration and monitorSession.safetyOk then continueTherapy;
            if monitorSession.elapsedTime >= sessionDuration then completeSession;
            if not monitorSession.safetyOk then abortSession;
        
        action continueTherapy;
        then checkConditions;
        
        action completeSession {
            assign therapeuticOutcome := 75.0;
        }
        then done;
        
        action abortSession {
            assign therapeuticOutcome := 0.0;
        }
        then done;
    }
    
    part veinoplusDevice {
        part battery : BatteryModule {
            attribute currentCharge = 85.0;
        }
        
        part controller : ControlModule {
            attribute selectedProgram = StimulationProgram::continuous;
            attribute currentIntensity = 50.0;
        }
        
        part generator : PulseGenerator {
            attribute outputIntensity = 50.0;
            attribute outputFrequency = 1.0 [Hz];
            attribute outputPulseWidth = 150.0 [us];
        }
        
        part leftElectrode : ElectrodePad {
            attribute padArea = 50.0 [cm^2];
        }
        
        part rightElectrode : ElectrodePad {
            attribute padArea = 50.0 [cm^2];
        }
        
        part safetySystem : SafetyMonitor {
            attribute maxIntensity = 99.0;
        }
        
        connect battery.powerOut to controller.powerIn;
        connect generator.stimulationOutput to leftElectrode.electrodeContact;
        connect generator.stimulationOutput to rightElectrode.electrodeContact;
    }
    
    part patientLowerLimb {
        part leftCalf : CalfMuscle {
            attribute restingTone = 0.2;
        }
        
        part rightCalf : CalfMuscle {
            attribute restingTone = 0.2;
        }
        
        part deepVeins : VenousVessel {
            attribute baselineFlow = 150.0 [mL/min];
        }
        
        part superficialVeins : VenousVessel {
            attribute baselineFlow = 80.0 [mL/min];
        }
    }
    
    requirement def TherapeuticEffectiveness;
    requirement def SafetyCompliance;
    requirement def UserComfort;
    requirement def DeviceReliability;
    
    requirement <'VNP-REQ-001'> primaryTherapeuticFunction : TherapeuticEffectiveness {
        doc /* The Veinoplus system shall improve venous blood circulation in the lower limbs 
             by delivering controlled neuromuscular electrical stimulation to the calf muscles, 
             inducing rhythmic contractions that enhance venous return and reduce venous stasis. */
        
        subject device : veinoplusDevice;
        
        assume constraint patientCompliance {
            doc /* Patient maintains proper electrode placement and completes prescribed treatment duration. */
        }
        
        require constraint flowImprovement {
            doc /* Venous blood flow shall increase by at least 50% during active stimulation. */
        }
    }
    
    requirement <'VNP-REQ-002'> safetyRequirement : SafetyCompliance {
        doc /* The device shall continuously monitor stimulation parameters and skin impedance, 
             automatically terminating stimulation if unsafe conditions are detected. */
        
        subject safetySystem : SafetyMonitor;
        
        require constraint {
            safetySystem.minImpedance <= 5000.0 and
            safetySystem.maxIntensity <= 99.0
        }
    }
    
    requirement <'VNP-REQ-003'> comfortRequirement : UserComfort {
        doc /* Stimulation intensity shall be adjustable from 0 to 99 levels to accommodate 
             individual patient sensitivity and comfort preferences. */
        
        subject generator : PulseGenerator;
        
        require constraint {
            generator.outputIntensity >= 0.0 and
            generator.outputIntensity <= 99.0
        }
    }
    
    requirement <'VNP-REQ-004'> reliabilityRequirement : DeviceReliability {
        doc /* The device shall operate for minimum 30 therapy sessions on a single battery charge. */
        
        subject battery : BatteryModule;
        
        require constraint {
            battery.capacity >= 1800.0 and
            battery.currentCharge > 10.0
        }
    }
    
    requirement <'VNP-SYS-001'> systemLevelRequirement {
        doc /* The Veinoplus system shall provide safe, effective, and comfortable neuromuscular 
             electrical stimulation therapy to improve venous circulation in patients with 
             venous insufficiency or at risk of deep vein thrombosis. */
        
        refine primaryTherapeuticFunction;
        refine safetyRequirement;
        refine comfortRequirement;
        refine reliabilityRequirement;
    }
    
    action therapySession : PerformTherapySession {
        in selectedProgram = StimulationProgram::continuous;
        in targetIntensity = 60.0;
        in sessionDuration = 30.0 [min];
        out therapeuticOutcome;
    }
}
