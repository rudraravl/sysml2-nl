package 'Cranial Electrotherapy Stimulation System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Microampere :> ISQ::ElectricCurrentValue {
        doc /* Electric current in microamperes */
    }
    
    attribute def Millivolt :> ISQ::ElectricPotentialValue {
        doc /* Voltage in millivolts */
    }
    
    attribute def SessionTime :> ISQ::TimeValue {
        doc /* Duration of therapy session */
    }
    
    attribute def StimulationFrequency :> ISQ::FrequencyValue {
        doc /* Frequency of electrical stimulation waveform */
    }
    
    attribute def SkinImpedance :> ISQ::ResistanceValue {
        doc /* Measured impedance at electrode-skin interface */
    }
    
    attribute def TherapyIntensity :> Real {
        doc /* User-selected therapy intensity level (0-10 scale) */
    }
    
    item def StimulationWaveform {
        attribute current : Microampere;
        attribute frequency : StimulationFrequency;
        attribute voltage : Millivolt;
        attribute pulseWidth : ISQ::TimeValue;
    }
    
    item def TherapyParameters {
        attribute intensity : TherapyIntensity;
        attribute duration : SessionTime;
        attribute frequency : StimulationFrequency;
        attribute currentLevel : Microampere;
    }
    
    item def SafetyStatus {
        attribute impedanceSafe : Boolean;
        attribute currentSafe : Boolean;
        attribute temperatureSafe : Boolean;
        attribute overallSafe : Boolean;
    }
    
    port def ElectricalOutputPort {
        out waveform : StimulationWaveform;
    }
    
    port def ElectricalInputPort {
        in waveform : StimulationWaveform;
        out impedance : SkinImpedance;
    }
    
    port def ControlSignalPort {
        in parameters : TherapyParameters;
        out status : SafetyStatus;
    }
    
    port def PowerSupplyPort {
        out voltage : ISQ::ElectricPotentialValue;
        out current : ISQ::ElectricCurrentValue;
    }
    
    part def BatteryPack {
        doc /* Rechargeable battery providing portable power */
        attribute capacity : ISQ::EnergyValue;
        attribute chargeLevel : Real;
        port powerOut : PowerSupplyPort;
    }
    
    part def MicrocontrollerUnit {
        doc /* Central processor managing therapy delivery and safety monitoring */
        port controlIn : ControlSignalPort;
        port safetyMonitor : ControlSignalPort;
        port waveformCommand : ControlSignalPort;
        
        action def ProcessUserInput {
            in userParams : TherapyParameters;
            out validatedParams : TherapyParameters;
        }
        
        action def MonitorSafetyConditions {
            in impedance : SkinImpedance;
            in currentLevel : Microampere;
            out safetyStatus : SafetyStatus;
        }
    }
    
    part def WaveformGeneratorCircuit {
        doc /* Precision circuit generating therapeutic electrical waveform */
        port commandIn : ControlSignalPort;
        port powerIn : PowerSupplyPort;
        port waveformOut : ElectricalOutputPort;
        
        attribute maxCurrent : Microampere;
        attribute maxVoltage : Millivolt;
        
        action def SynthesizeWaveform {
            in targetCurrent : Microampere;
            in targetFrequency : StimulationFrequency;
            in impedance : SkinImpedance;
            out generatedWaveform : StimulationWaveform;
        }
    }
    
    part def CurrentRegulationCircuit {
        doc /* Maintains constant current despite impedance variations */
        port feedbackIn : ElectricalInputPort;
        port regulatedOut : ElectricalOutputPort;
        
        action def AdjustOutputVoltage {
            in targetCurrent : Microampere;
            in measuredImpedance : SkinImpedance;
            out adjustedVoltage : Millivolt;
        }
    }
    
    part def SafetyCircuit {
        doc /* Hardware safety interlocks and fault detection */
        port monitorIn : ElectricalInputPort;
        port safetyOut : ControlSignalPort;
        
        attribute maxSafeImpedance : SkinImpedance;
        attribute minSafeImpedance : SkinImpedance;
        
        action def DetectFaultConditions {
            in impedance : SkinImpedance;
            in current : Microampere;
            out faultDetected : Boolean;
            out faultType : String;
        }
    }
    
    part def UserInterfacePanel {
        doc /* Control panel for therapy parameter selection and status display */
        port userControl : ControlSignalPort;
        
        action def CaptureUserSettings {
            out selectedIntensity : TherapyIntensity;
            out selectedDuration : SessionTime;
            out selectedFrequency : StimulationFrequency;
        }
        
        action def DisplayStatus {
            in currentStatus : SafetyStatus;
            in remainingTime : SessionTime;
        }
    }
    
    part def EarClipElectrode {
        doc /* Conductive electrode clipping to ear lobe for current delivery */
        port electricalInterface : ElectricalInputPort;
        
        attribute contactArea : ISQ::AreaValue;
        attribute conductivity : Real;
    }
    
    action def InitializeSystem {
        doc /* System startup and self-test sequence */
        
        first start;
        then action performSelfTest {
            out testPassed : Boolean;
        }
        then decide;
            if performSelfTest.testPassed then readyForTherapy;
            if !performSelfTest.testPassed then systemFault;
        
        action readyForTherapy;
        then done;
        
        action systemFault;
        then done;
    }
    
    action def MeasureElectrodeImpedance {
        doc /* Pre-therapy impedance check to verify electrode contact */
        in testCurrent : Microampere;
        out measuredImpedance : SkinImpedance;
        out contactQuality : Real;
        
        first start;
        then action applyTestSignal {
            in current = testCurrent;
            out voltage : Millivolt;
        }
        then action calculateImpedance {
            in voltage = applyTestSignal.voltage;
            in current = testCurrent;
            out impedance : SkinImpedance;
        }
        then assign measuredImpedance := calculateImpedance.impedance;
        then action assessQuality {
            in impedance = measuredImpedance;
            out quality : Real;
        }
        then assign contactQuality := assessQuality.quality;
        then done;
    }
    
    action def DeliverCranialElectrotherapy {
        doc /* Primary therapy delivery action coordinating all subsystems */
        in therapyParams : TherapyParameters;
        out therapyCompleted : Boolean;
        out totalChargeDelivered : ISQ::ElectricChargeValue;
        
        first start;
        then merge checkConditions;
        
        action impedanceTest : MeasureElectrodeImpedance {
            in testCurrent : Microampere;
            out measuredImpedance : SkinImpedance;
            out contactQuality : Real;
        }
        
        then decide;
            if impedanceTest.contactQuality >= 0.7 then beginStimulation;
            if impedanceTest.contactQuality < 0.7 then alertPoorContact;
        
        action alertPoorContact {
            doc /* Notify user to adjust electrode placement */
        }
        then checkConditions;
        
        action beginStimulation {
            action generateTherapeuticWaveform {
                in intensity = therapyParams.intensity;
                in frequency = therapyParams.frequency;
                in duration = therapyParams.duration;
                out waveform : StimulationWaveform;
            }
            
            flow generateTherapeuticWaveform.waveform to regulateOutput.inputWaveform;
            
            action regulateOutput {
                in inputWaveform : StimulationWaveform;
                in impedance = impedanceTest.measuredImpedance;
                out regulatedWaveform : StimulationWaveform;
            }
            
            action continuousMonitoring {
                in currentWaveform = regulateOutput.regulatedWaveform;
                in impedance = impedanceTest.measuredImpedance;
                out safetyStatus : SafetyStatus;
            }
        }
        
        then decide;
            if beginStimulation.continuousMonitoring.safetyStatus.overallSafe then continueTherapy;
            if !beginStimulation.continuousMonitoring.safetyStatus.overallSafe then emergencyStop;
        
        action continueTherapy;
        then checkConditions;
        
        action emergencyStop {
            doc /* Immediate cessation of stimulation due to safety fault */
        }
        then assign therapyCompleted := false;
        then done;
    }
    
    part def CranialElectrotherapyStimulator {
        doc /* Medical device delivering low-intensity electrical stimulation to the brain via ear clip electrodes for treatment of anxiety, depression, and insomnia */
        
        part battery : BatteryPack;
        part mcu : MicrocontrollerUnit;
        part waveformGen : WaveformGeneratorCircuit;
        part currentReg : CurrentRegulationCircuit;
        part safetyCircuit : SafetyCircuit;
        part ui : UserInterfacePanel;
        part leftElectrode : EarClipElectrode;
        part rightElectrode : EarClipElectrode;
    }
    
    part cesSystem : CranialElectrotherapyStimulator {
        doc /* Complete CES device for non-invasive neuromodulation therapy */
        
        part redefines battery {
            attribute capacity := 7200.0;
            attribute chargeLevel := 1.0;
        }
        
        part redefines waveformGen {
            attribute maxCurrent := 500.0e-6;
            attribute maxVoltage := 15.0;
        }
        
        part redefines safetyCircuit {
            attribute maxSafeImpedance := 10000.0;
            attribute minSafeImpedance := 500.0;
        }
        
        connection powerToBattery connect battery.powerOut to waveformGen.powerIn;
        connection controlToMCU connect ui.userControl to mcu.controlIn;
        connection mcuToWaveform connect mcu.waveformCommand to waveformGen.commandIn;
        connection waveformToRegulator connect waveformGen.waveformOut to currentReg.regulatedOut;
        connection regulatorToLeftElectrode connect currentReg.regulatedOut to leftElectrode.electricalInterface;
        connection safetyMonitoring connect leftElectrode.electricalInterface to safetyCircuit.monitorIn;
        connection safetyToMCU connect safetyCircuit.safetyOut to mcu.safetyMonitor;
        
        perform action therapySession : DeliverCranialElectrotherapy {
            in therapyParams : TherapyParameters;
            out therapyCompleted : Boolean;
            out totalChargeDelivered : ISQ::ElectricChargeValue;
        }
    }
    
    requirement def PrimaryTherapeuticFunction {
        doc /* The CES system shall deliver controlled microcurrent electrical stimulation to the cranium to modulate neural activity and provide therapeutic benefit for neuropsychiatric conditions */
        subject device : CranialElectrotherapyStimulator;
    }
    
    requirement def CurrentSafetyLimit {
        doc /* Maximum output current shall not exceed 500 microamperes to ensure patient safety */
        subject device : CranialElectrotherapyStimulator;
        require constraint {
            device.waveformGen.maxCurrent <= 500.0e-6
        }
    }
    
    requirement def ImpedanceMonitoring {
        doc /* System shall continuously monitor electrode-skin impedance and alert if outside safe range */
        subject device : CranialElectrotherapyStimulator;
        require constraint {
            device.safetyCircuit.minSafeImpedance >= 500.0 and
            device.safetyCircuit.maxSafeImpedance <= 10000.0
        }
    }
    
    requirement def TherapyDurationControl {
        doc /* System shall limit therapy session duration and provide automatic shutoff */
        subject device : CranialElectrotherapyStimulator;
    }
    
    requirement def WaveformAccuracy {
        doc /* Generated waveform shall maintain current accuracy within ±5% of target value */
        subject device : CranialElectrotherapyStimulator;
    }
    
    requirement def BatteryOperationalLife {
        doc /* Battery shall support minimum of 10 therapy sessions per charge */
        subject device : CranialElectrotherapyStimulator;
        require constraint {
            device.battery.capacity >= 7200.0
        }
    }
    
    requirement def ElectrodeContactVerification {
        doc /* System shall verify adequate electrode contact before initiating therapy */
        subject device : CranialElectrotherapyStimulator;
    }
    
    requirement cesSystemRequirements {
        doc /* Top-level requirements for cranial electrotherapy stimulation system */
        subject cesDevice : CranialElectrotherapyStimulator;
        
        require primaryFunction : PrimaryTherapeuticFunction {
            subject device = cesDevice;
        }
        require currentSafety : CurrentSafetyLimit {
            subject device = cesDevice;
        }
        require impedanceCheck : ImpedanceMonitoring {
            subject device = cesDevice;
        }
        require durationControl : TherapyDurationControl {
            subject device = cesDevice;
        }
        require waveformQuality : WaveformAccuracy {
            subject device = cesDevice;
        }
        require batteryLife : BatteryOperationalLife {
            subject device = cesDevice;
        }
        require contactVerification : ElectrodeContactVerification {
            subject device = cesDevice;
        }
    }
}
