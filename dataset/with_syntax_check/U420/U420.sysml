package TranscutaneousElectricalNerveStimulationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def PulseFrequency :> ISQ::FrequencyValue;
    attribute def PulseWidth :> ISQ::DurationValue;
    attribute def StimulationCurrent :> ISQ::ElectricCurrentValue;
    attribute def SkinImpedance :> ISQ::ResistanceValue;
    attribute def BatteryVoltage :> ISQ::VoltageValue;
    attribute def PainIntensity :> Real;
    
    enum def TherapyMode {
        continuous;
        burst;
        modulated;
    }
    
    enum def SystemState {
        off;
        standby;
        active;
        fault;
    }
    
    item def ElectricalPulse {
        attribute frequency : PulseFrequency;
        attribute width : PulseWidth;
        attribute amplitude : StimulationCurrent;
    }
    
    item def NerveSignal {
        attribute intensity : Real;
        attribute frequency : Real;
    }
    
    port def ElectrodeInterface {
        out stimulusPulse : ElectricalPulse;
        in impedanceFeedback : SkinImpedance;
    }
    
    port def PowerInterface {
        in voltage : BatteryVoltage;
        out currentDraw : ISQ::ElectricCurrentValue;
    }
    
    port def ControlInterface {
        in modeSelection : TherapyMode;
        in intensityAdjustment : Real;
        out statusIndication : SystemState;
    }
    
    part def BatteryPack {
        attribute nominalVoltage : BatteryVoltage;
        attribute capacity : Real;
        attribute remainingCharge : Real;
        
        port powerOut : PowerInterface;
    }
    
    part def MicrocontrollerUnit {
        attribute currentMode : TherapyMode;
        attribute targetFrequency : PulseFrequency;
        attribute targetWidth : PulseWidth;
        attribute targetAmplitude : StimulationCurrent;
        
        port controlIn : ControlInterface;
        port powerIn : PowerInterface;
        
        action processUserInput {
            in mode : TherapyMode;
            in intensity : Real;
            out frequency : PulseFrequency;
            out width : PulseWidth;
            out amplitude : StimulationCurrent;
        }
        
        action monitorSafety {
            in impedance : SkinImpedance;
            in current : StimulationCurrent;
            out safetyStatus : Boolean;
        }
    }
    
    part def PulseGeneratorCircuit {
        attribute outputFrequency : PulseFrequency;
        attribute outputWidth : PulseWidth;
        attribute outputAmplitude : StimulationCurrent;
        attribute maxOutputCurrent : StimulationCurrent;
        
        port powerIn : PowerInterface;
        port electrodeOut : ElectrodeInterface;
        
        action generatePulse {
            in frequency : PulseFrequency;
            in width : PulseWidth;
            in amplitude : StimulationCurrent;
            out pulse : ElectricalPulse;
        }
        
        action measureImpedance {
            out impedance : SkinImpedance;
        }
    }
    
    part def ElectrodePad {
        attribute contactArea : ISQ::AreaValue;
        attribute skinImpedance : SkinImpedance;
        attribute position : Real;
        
        port electrodePort : ElectrodeInterface;
        
        action deliverStimulation {
            in pulse : ElectricalPulse;
            out nerveActivation : NerveSignal;
        }
    }
    
    part def UserControlPanel {
        attribute selectedMode : TherapyMode;
        attribute intensityLevel : Real;
        attribute displayStatus : SystemState;
        
        port control : ControlInterface;
        
        action adjustIntensity {
            in currentLevel : Real;
            in increment : Real;
            out newLevel : Real;
        }
        
        action changeMode {
            in newMode : TherapyMode;
        }
    }
    
    part def SafetyMonitoringSystem {
        attribute impedanceThreshold : SkinImpedance;
        attribute currentLimit : StimulationCurrent;
        attribute alarmState : Boolean;
        
        action checkElectrodeContact {
            in impedance : SkinImpedance;
            out contactOK : Boolean;
        }
        
        action enforceCurrentLimit {
            in requestedCurrent : StimulationCurrent;
            out safeCurrent : StimulationCurrent;
        }
        
        action triggerShutdown;
    }
    
    part def TENSDevice {
        attribute systemState : SystemState;
        attribute operatingMode : TherapyMode;
        attribute sessionDuration : ISQ::DurationValue;
        
        part battery : BatteryPack {
            attribute :>> nominalVoltage = 9.0 [SI::V];
            attribute :>> capacity = 1200.0;
            attribute :>> remainingCharge = 100.0;
        }
        
        part controller : MicrocontrollerUnit {
            attribute :>> currentMode = TherapyMode::continuous;
            attribute :>> targetFrequency = 80.0 [SI::Hz];
            attribute :>> targetWidth = 200.0e-6 [SI::s];
            attribute :>> targetAmplitude = 0.020 [SI::A];
        }
        
        part pulseGenerator : PulseGeneratorCircuit {
            attribute :>> maxOutputCurrent = 0.080 [SI::A];
        }
        
        part anodeElectrode : ElectrodePad {
            attribute :>> contactArea = 25.0e-4 [SI::'m^2'];
        }
        
        part cathodeElectrode : ElectrodePad {
            attribute :>> contactArea = 25.0e-4 [SI::'m^2'];
        }
        
        part userInterface : UserControlPanel {
            attribute :>> selectedMode = TherapyMode::continuous;
            attribute :>> intensityLevel = 50.0;
        }
        
        part safetySystem : SafetyMonitoringSystem {
            attribute :>> impedanceThreshold = 5000.0 [SI::Ω];
            attribute :>> currentLimit = 0.080 [SI::A];
        }
        
        connection batteryToController connect battery.powerOut to controller.powerIn;
        connection batteryToGenerator connect battery.powerOut to pulseGenerator.powerIn;
        connection userToController connect userInterface.control to controller.controlIn;
        connection generatorToAnode connect pulseGenerator.electrodeOut to anodeElectrode.electrodePort;
        connection generatorToCathode connect pulseGenerator.electrodeOut to cathodeElectrode.electrodePort;
        
        perform action deliverTherapy;
    }
    
    action def InitializeSystem {
        out initialMode : TherapyMode;
        out initialIntensity : Real;
    }
    
    action def CheckSystemSafety {
        in impedance : SkinImpedance;
        in current : StimulationCurrent;
        out isSafe : Boolean;
    }
    
    action def GenerateTherapyPulse {
        in mode : TherapyMode;
        in frequency : PulseFrequency;
        in width : PulseWidth;
        in amplitude : StimulationCurrent;
        out pulse : ElectricalPulse;
    }
    
    action def MonitorTherapyProgress {
        in elapsedTime : ISQ::DurationValue;
        in targetDuration : ISQ::DurationValue;
        out continueTherapy : Boolean;
    }
    
    action deliverTherapy {
        first start;
        then initialize;
        
        action initialize : InitializeSystem {
            out initialMode : TherapyMode;
            out initialIntensity : Real;
        }
        then merge therapyCycle;
        
        action checkSafety : CheckSystemSafety {
            in impedance : SkinImpedance;
            in current : StimulationCurrent;
            out isSafe : Boolean;
        }
        then checkSafety;
        
        then decide safetyCheck;
            if checkSafety.isSafe then generatePulse;
            if not checkSafety.isSafe then emergencyStop;
        
        action generatePulse : GenerateTherapyPulse {
            in mode : TherapyMode;
            in frequency : PulseFrequency;
            in width : PulseWidth;
            in amplitude : StimulationCurrent;
            out pulse : ElectricalPulse;
        }
        then monitorProgress;
        
        action monitorProgress : MonitorTherapyProgress {
            in elapsedTime : ISQ::DurationValue;
            in targetDuration : ISQ::DurationValue;
            out continueTherapy : Boolean;
        }
        
        then decide continuationCheck;
            if monitorProgress.continueTherapy then therapyCycle;
            if not monitorProgress.continueTherapy then completeSession;
        
        action emergencyStop;
        then completeSession;
        
        action completeSession;
        then done;
    }
    
    requirement <'REQ-TENS-001'> primaryFunctionRequirement {
        doc /* The TENS device shall provide therapeutic pain relief by delivering 
             * controlled low-voltage electrical pulses through skin-mounted electrodes 
             * to stimulate peripheral nerves and modulate pain perception.
            */
        subject device : TENSDevice;
    }
    
    requirement <'REQ-TENS-002'> outputCurrentRangeRequirement {
        doc /* The pulse generator shall provide adjustable output current 
             * from 0 mA to 80 mA with user control.
            */
        subject generator : TENSDevice::pulseGenerator;
        
        assert constraint {
            generator.outputAmplitude >= 0.0 [SI::A] and 
            generator.outputAmplitude <= generator.maxOutputCurrent
        }
    }
    
    requirement <'REQ-TENS-003'> frequencyRangeRequirement {
        doc /* The device shall support pulse frequencies between 2 Hz and 150 Hz 
             * to accommodate different therapy protocols.
            */
        subject generator : TENSDevice::pulseGenerator;
        
        assert constraint {
            generator.outputFrequency >= 2.0 [SI::Hz] and 
            generator.outputFrequency <= 150.0 [SI::Hz]
        }
    }
    
    requirement <'REQ-TENS-004'> pulseWidthRequirement {
        doc /* The pulse width shall be adjustable between 50 microseconds 
             * and 400 microseconds.
            */
        subject generator : TENSDevice::pulseGenerator;
        
        assert constraint {
            generator.outputWidth >= 50.0e-6 [SI::s] and 
            generator.outputWidth <= 400.0e-6 [SI::s]
        }
    }
    
    requirement <'REQ-TENS-005'> safetyMonitoringRequirement {
        doc /* The system shall continuously monitor electrode impedance and 
             * automatically shut down if impedance exceeds safe threshold, 
             * indicating poor contact or electrode detachment.
            */
        subject safety : TENSDevice::safetySystem;
        
        assert constraint {
            safety.impedanceThreshold == 5000.0 [SI::Ω]
        }
    }
    
    requirement <'REQ-TENS-006'> batteryOperationRequirement {
        doc /* The battery shall provide minimum 8 hours of continuous operation 
             * at typical therapy settings.
            */
        subject battery : TENSDevice::battery;
    }
    
    requirement <'REQ-TENS-007'> multiModeOperationRequirement {
        doc /* The device shall support multiple therapy modes including continuous, 
             * burst, and modulated stimulation patterns.
            */
        subject device : TENSDevice;
    }
    
    part tensTherapySystem : TENSDevice {
        attribute :>> systemState = SystemState::standby;
        attribute :>> operatingMode = TherapyMode::continuous;
        attribute :>> sessionDuration = 1800.0 [SI::s];
        
        part :>> controller {
            attribute :>> targetFrequency = 80.0 [SI::Hz];
            attribute :>> targetWidth = 200.0e-6 [SI::s];
            attribute :>> targetAmplitude = 0.025 [SI::A];
        }
        
        part :>> pulseGenerator {
            attribute :>> outputFrequency = 80.0 [SI::Hz];
            attribute :>> outputWidth = 200.0e-6 [SI::s];
            attribute :>> outputAmplitude = 0.025 [SI::A];
        }
    }
    
    satisfy primaryFunctionRequirement by tensTherapySystem;
    satisfy outputCurrentRangeRequirement by tensTherapySystem.pulseGenerator;
    satisfy frequencyRangeRequirement by tensTherapySystem.pulseGenerator;
    satisfy pulseWidthRequirement by tensTherapySystem.pulseGenerator;
    satisfy safetyMonitoringRequirement by tensTherapySystem.safetySystem;
    satisfy batteryOperationRequirement by tensTherapySystem.battery;
    satisfy multiModeOperationRequirement by tensTherapySystem;
}
