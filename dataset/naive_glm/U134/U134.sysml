package Veinoplus {

    // ===== Value Types with Units =====
    
    package Units {
        scalar value type ElectricCurrentValue :> Real {
            unit ampere [A];
        }
        scalar value type VoltageValue :> Real {
            unit volt [V];
        }
        scalar value type ImpedanceValue :> Real {
            unit ohm [Ω];
        }
        scalar value type FrequencyValue :> Real {
            unit hertz [Hz];
        }
        scalar value type TimeValue :> Real {
            unit second [s];
        }
        scalar value type PowerValue :> Real {
            unit watt [W];
        }
        scalar value type FlowRateValue :> Real {
            unit 'milliliter per minute' [mL/min];
        }
        scalar value type VelocityValue :> Real {
            unit 'centimeter per second' [cm/s];
        }
        scalar value type ForceValue :> Real {
            unit newton [N];
        }
        scalar value type PercentageValue :> Real {
            unit percent [%];
        }
    }
    
    import Units::*;
    
    // ===== Item Definitions =====
    
    item def ElectricPulse {
        attribute amplitude : VoltageValue;
        attribute frequency : FrequencyValue;
        attribute pulseWidth : TimeValue;
        attribute waveform : String;
    }
    
    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : ElectricCurrentValue;
    }
    
    item def UserCommand {
        attribute commandType : String;
        attribute intensityLevel : PercentageValue;
        attribute programType : String;
    }
    
    item def StimulationParameters {
        attribute program : String;
        attribute intensity : PercentageValue;
        attribute sessionDuration : TimeValue;
    }
    
    item def SafetyStatus {
        attribute impedance : ImpedanceValue;
        attribute current : ElectricCurrentValue;
        attribute contactOk : Boolean;
    }
    
    item def VenousBlood {
        attribute flowRate : FlowRateValue;
        attribute velocity : VelocityValue;
    }
    
    // ===== Enumeration Definitions =====
    
    enum def DeviceState {
        OFF = 0;
        STANDBY = 1;
        STIMULATING = 2;
        PAUSED = 3;
        FAULT = 4;
    }
    
    enum def StimulationProgram {
        CONTINUOUS = 0;
        PULSED = 1;
        PROGRESSIVE = 2;
    }
    
    // ===== Port Definitions =====
    
    port def PowerPort {
        out power : ElectricalPower;
    }
    
    port def CommandPort {
        in command : UserCommand;
    }
    
    port def PulseOutputPort {
        out pulse : ElectricPulse;
    }
    
    port def PulseInputPort {
        in pulse : ElectricPulse;
    }
    
    port def SafetyMonitorPort {
        out status : SafetyStatus;
    }
    
    port def ControlSignalPort {
        out parameters : StimulationParameters;
    }
    
    port def ElectrodeContactPort {
        out impedance : ImpedanceValue;
        in pulse : ElectricPulse;
    }
    
    port def MuscleContractionPort {
        out contractionForce : ForceValue;
    }
    
    port def VenousFlowPort {
        out blood : VenousBlood;
    }
    
    // ===== Part Definitions =====
    
    part def BatteryModule {
        attribute nominalVoltage : VoltageValue = 3.7 [V];
        attribute capacity : ElectricCurrentValue = 1500 [A]; // mAh represented
        attribute chargeLevel : PercentageValue = 100 [%];
        
        port powerOut : PowerPort;
        
        action def supplyPower {
            in voltage : VoltageValue;
            out power : ElectricalPower;
        }
        
        perform supplyPower {
            in voltage = nominalVoltage;
            out power = powerOut.power;
        }
    }
    
    part def ControlModule {
        attribute currentState : DeviceState = DeviceState::OFF;
        attribute selectedProgram : StimulationProgram = StimulationProgram::CONTINUOUS;
        attribute intensitySetting : PercentageValue = 50 [%];
        attribute sessionTimer : TimeValue = 0 [s];
        attribute sessionDuration : TimeValue = 1800 [s];
        
        port commandIn : CommandPort;
        port controlOut : ControlSignalPort;
        port safetyIn : SafetyMonitorPort;
        port powerIn : PowerPort;
        
        state machine ControlStateMachine {
            entry;
            
            state OFF {
                entry;
                transition off_to_standby
                    first OFF
                    then STANDBY
                    accept commandIn.command
                    when commandIn.command.commandType == "powerOn";
            }
            
            state STANDBY {
                entry;
                transition standby_to_stimulating
                    first STANDBY
                    then STIMULATING
                    accept commandIn.command
                    when commandIn.command.commandType == "start";
                
                transition standby_to_off
                    first STANDBY
                    then OFF
                    accept commandIn.command
                    when commandIn.command.commandType == "powerOff";
            }
            
            state STIMULATING {
                entry;
                do runSessionTimer;
                transition stimulating_to_paused
                    first STIMULATING
                    then PAUSED
                    accept commandIn.command
                    when commandIn.command.commandType == "pause";
                
                transition stimulating_to_standby
                    first STIMULATING
                    then STANDBY
                    accept commandIn.command
                    when commandIn.command.commandType == "stop";
                
                transition stimulating_to_fault
                    first STIMULATING
                    then FAULT
                    when safetyIn.status.contactOk == false
                    or safetyIn.status.impedance > 5000 [Ω]
                    or safetyIn.status.current > 100 [A];
            }
            
            state PAUSED {
                entry;
                transition paused_to_stimulating
                    first PAUSED
                    then STIMULATING
                    accept commandIn.command
                    when commandIn.command.commandType == "resume";
                
                transition paused_to_standby
                    first PAUSED
                    then STANDBY
                    accept commandIn.command
                    when commandIn.command.commandType == "stop";
            }
            
            state FAULT {
                entry;
                transition fault_to_off
                    first FAULT
                    then OFF
                    accept commandIn.command
                    when commandIn.command.commandType == "powerOff";
            }
            
            transition initial_to_off first initial then OFF;
        }
        
        action def runSessionTimer {
            in duration : TimeValue;
            out elapsed : TimeValue;
        }
        
        action def processCommand {
            in cmd : UserCommand;
            out params : StimulationParameters;
        }
        
        perform processCommand {
            in cmd = commandIn.command;
            out params = controlOut.parameters;
        }
    }
    
    part def PulseGenerator {
        attribute waveformType : String = "biphasic";
        attribute baseFrequency : FrequencyValue = 40 [Hz];
        attribute pulseWidth : TimeValue = 0.0002 [s]; // 200 microseconds
        attribute maxAmplitude : VoltageValue = 80 [V];
        
        port controlIn : ControlSignalPort;
        port pulseOut : PulseOutputPort;
        port powerIn : PowerPort;
        
        action def generatePulse {
            in params : StimulationParameters;
            out pulse : ElectricPulse;
            
            // Compute amplitude based on intensity
            private attribute computedAmplitude : VoltageValue = maxAmplitude * (params.intensity / 100.0);
        }
        
        perform generatePulse {
            in params = controlIn.parameters;
            out pulse = pulseOut.pulse;
        }
    }
    
    part def SafetyMonitor {
        attribute minImpedance : ImpedanceValue = 100 [Ω];
        attribute maxImpedance : ImpedanceValue = 5000 [Ω];
        attribute maxCurrent : ElectricCurrentValue = 100 [A];
        attribute maxIntensity : PercentageValue = 100 [%];
        attribute shutdownTriggered : Boolean = false;
        
        port monitorOut : SafetyMonitorPort;
        port electrodeFeedback : ElectrodeContactPort;
        
        action def checkSafety {
            in impedance : ImpedanceValue;
            in current : ElectricCurrentValue;
            out status : SafetyStatus;
            
            // Evaluate contact and limits
            private attribute contactValid : Boolean = (impedance >= minImpedance and impedance <= maxImpedance);
            private attribute currentSafe : Boolean = (current <= maxCurrent);
        }
        
        perform checkSafety {
            in impedance = electrodeFeedback.impedance;
            in current = 0 [A]; // placeholder replaced by measured value
            out status = monitorOut.status;
        }
        
        action def triggerShutdown {
            out triggered : Boolean = true;
        }
    }
    
    part def ElectrodePad {
        attribute contactArea : Real = 50.0; // cm^2
        attribute adhesiveType : String = "hypoallergenic";
        attribute measuredImpedance : ImpedanceValue = 500 [Ω];
        
        port pulseIn : PulseInputPort;
        port contactOut : ElectrodeContactPort;
        port skinContact : ElectrodeContactPort;
        
        action def transferStimulus {
            in pulse : ElectricPulse;
            out impedance : ImpedanceValue;
        }
        
        perform transferStimulus {
            in pulse = pulseIn.pulse;
            out impedance = contactOut.impedance;
        }
    }
    
    part def CalfMuscle {
        attribute muscleType : String = "gastrocnemius";
        attribute contractionForce : ForceValue = 0 [N];
        attribute maxForce : ForceValue = 50 [N];
        
        port stimulusIn : PulseInputPort;
        port contractionOut : MuscleContractionPort;
        
        action def contract {
            in pulse : ElectricPulse;
            out force : ForceValue;
            
            // Force proportional to pulse amplitude and frequency
            private attribute inducedForce : ForceValue = maxForce * (pulse.amplitude / 80.0) * (pulse.frequency / 40.0);
        }
        
        perform contract {
            in pulse = stimulusIn.pulse;
            out force = contractionOut.contractionForce;
        }
    }
    
    part def VenousVessel {
        attribute vesselType : String = "deep_vein";
        attribute baselineFlowRate : FlowRateValue = 20 [mL/min];
        attribute baselineVelocity : VelocityValue = 5 [cm/s];
        attribute currentFlowRate : FlowRateValue = 20 [mL/min];
        attribute currentVelocity : VelocityValue = 5 [cm/s];
        
        port forceIn : MuscleContractionPort;
        port bloodOut : VenousFlowPort;
        
        action def compressAndPump {
            in force : ForceValue;
            out blood : VenousBlood;
            
            // Increased flow proportional to contraction force
            private attribute enhancedFlowRate : FlowRateValue = baselineFlowRate + (force * 2.0);
            private attribute enhancedVelocity : VelocityValue = baselineVelocity + (force * 0.5);
        }
        
        perform compressAndPump {
            in force = forceIn.contractionForce;
            out blood = bloodOut.blood;
        }
    }
    
    part def UserInterface {
        attribute displayType : String = "LCD";
        attribute buttonCount : Integer = 4;
        
        port commandOut : CommandPort;
        
        action def receiveUserInput {
            out command : UserCommand;
        }
        
        perform receiveUserInput {
            out command = commandOut.command;
        }
    }
    
    // ===== Top-Level System =====
    
    part def VeinoplusDevice {
        attribute deviceName : String = "Veinoplus";
        attribute deviceVersion : String = "2.0";
        attribute isPortable : Boolean = true;
        
        part battery : BatteryModule;
        part controlUnit : ControlModule;
        part pulseGen : PulseGenerator;
        part safetyMon : SafetyMonitor;
        part userInterface : UserInterface;
        part leftElectrode : ElectrodePad;
        part rightElectrode : ElectrodePad;
        
        // External anatomical parts (context)
        part leftCalfMuscle : CalfMuscle;
        part rightCalfMuscle : CalfMuscle;
        part leftVenousVessel : VenousVessel;
        part rightVenousVessel : VenousVessel;
        
        // Internal connections
        connection powerToControl connect battery.powerOut to controlUnit.powerIn;
        connection powerToPulseGen connect battery.powerOut to pulseGen.powerIn;
        connection commandToControl connect userInterface.commandOut to controlUnit.commandIn;
        connection controlToPulseGen connect controlUnit.controlOut to pulseGen.controlIn;
        connection safetyToControl connect safetyMon.monitorOut to controlUnit.safetyIn;
        
        // Pulse delivery to electrodes
        connection pulseToLeftElectrode connect pulseGen.pulseOut to leftElectrode.pulseIn;
        connection pulseToRightElectrode connect pulseGen.pulseOut to rightElectrode.pulseIn;
        
        // Electrode feedback to safety monitor
        connection leftElectrodeToSafety connect leftElectrode.contactOut to safetyMon.electrodeFeedback;
        connection rightElectrodeToSafety connect rightElectrode.contactOut to safetyMon.electrodeFeedback;
        
        // Electrode stimulus to calf muscles
        connection leftElectrodeToMuscle connect leftElectrode.skinContact to leftCalfMuscle.stimulusIn;
        connection rightElectrodeToMuscle connect rightElectrode.skinContact to rightCalfMuscle.stimulusIn;
        
        // Muscle contraction to venous vessels
        connection leftMuscleToVein connect leftCalfMuscle.contractionOut to leftVenousVessel.forceIn;
        connection rightMuscleToVein connect rightCalfMuscle.contractionOut to rightVenousVessel.forceIn;
    }
    
    // ===== Requirements =====
    
    requirement def MedicalSafetyRequirement {
        doc "The device shall maintain safe electrical stimulation parameters at all times."
        attribute maxOutputVoltage : VoltageValue = 80 [V];
        attribute maxOutputCurrent : ElectricCurrentValue = 100 [A];
        attribute minElectrodeImpedance : ImpedanceValue = 100 [Ω];
        attribute maxElectrodeImpedance : ImpedanceValue = 5000 [Ω];
        
        constraint { pulseGen.maxAmplitude <= maxOutputVoltage }
        constraint { safetyMon.maxCurrent <= maxOutputCurrent }
    }
    
    requirement def StimulationEffectivenessRequirement {
        doc "The device shall induce calf muscle contractions that increase venous blood flow by at least 50% above baseline."
        attribute minFlowRateIncrease : PercentageValue = 50 [%];
        attribute targetFrequency : FrequencyValue = 40 [Hz];
        attribute targetPulseWidth : TimeValue = 0.0002 [s];
        
        constraint { pulseGen.baseFrequency == targetFrequency }
        constraint { pulseGen.pulseWidth == targetPulseWidth }
    }
    
    requirement def PortabilityRequirement {
        doc "The device shall be battery-powered and portable for patient use in any setting."
        attribute maxWeight : Real = 0.3; // kg
        attribute batteryLife : TimeValue = 7200 [s];
        
        constraint { VeinoplusDevice.isPortable == true }
    }
    
    requirement def ElectrodeContactRequirement {
        doc "The safety monitor shall detect loss of electrode contact and shut down stimulation within 1 second."
        attribute maxResponseTime : TimeValue = 1 [s];
        
        constraint { safetyMon.minImpedance >= 100 [Ω] }
        constraint { safetyMon.maxImpedance <= 5000 [Ω] }
    }
    
    requirement def TherapySessionRequirement {
        doc "The control module shall support therapy sessions of up to 30 minutes with programmable intensity and program selection."
        attribute maxSessionDuration : TimeValue = 1800 [s];
        attribute minIntensity : PercentageValue = 0 [%];
        attribute maxIntensity : PercentageValue = 100 [%];
        
        constraint { controlUnit.sessionDuration <= maxSessionDuration }
    }
    
    // ===== Requirement Satisfaction =====
    
    satisfaction satisfyStimulationEffectiveness by VeinoplusDevice satisfy StimulationEffectivenessRequirement;
    satisfaction satisfyMedicalSafety by VeinoplusDevice satisfy MedicalSafetyRequirement;
    satisfaction satisfyPortability by VeinoplusDevice satisfy PortabilityRequirement;
    satisfaction satisfyElectrodeContact by VeinoplusDevice satisfy ElectrodeContactRequirement;
    satisfaction satisfyTherapySession by VeinoplusDevice satisfy TherapySessionRequirement;
    
}
