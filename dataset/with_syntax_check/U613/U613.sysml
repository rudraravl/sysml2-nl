package BioFETDetectionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def AnalyteConcentration :> Real {
        doc /* Molar concentration of target biomolecules in solution */
    }
    
    attribute def SurfaceChargeDensity :> Real {
        doc /* Charge density at the functionalized gate surface */
    }
    
    attribute def ThresholdVoltageShift :> ElectricPotentialValue {
        doc /* Change in threshold voltage due to biomolecule binding */
    }
    
    attribute def BindingAffinity :> Real {
        doc /* Affinity constant for biomolecule-receptor interaction */
    }
    
    attribute def SampleReady;
    attribute def CalibrationComplete;
    attribute def DetectionThresholdReached;
    attribute def MeasurementComplete;
    
    item def TargetBiomolecule {
        attribute molecularWeight : MassValue;
        attribute netCharge : Real;
        attribute concentration : AnalyteConcentration;
    }
    
    item def BufferSolution {
        attribute pH : Real;
        attribute ionicStrength : Real;
        attribute temperature : TemperatureValue;
    }
    
    port def FluidicInputPort {
        in flow sample : TargetBiomolecule;
        in flow buffer : BufferSolution;
    }
    
    port def FluidicOutputPort {
        out flow waste : BufferSolution;
    }
    
    port def ElectricalBiasPort {
        in flow gateVoltage : ElectricPotentialValue;
        in flow drainVoltage : ElectricPotentialValue;
        in flow sourceVoltage : ElectricPotentialValue;
    }
    
    port def ElectricalSensingPort {
        out flow drainCurrent : ElectricCurrentValue;
        out flow thresholdShift : ThresholdVoltageShift;
    }
    
    port def DataOutputPort {
        out flow concentrationReading : AnalyteConcentration;
        out flow signalQuality : Real;
    }
    
    part def FunctionalizedGate {
        doc /* Gate electrode with immobilized receptor molecules for selective biomolecule capture */
        attribute receptorDensity : Real;
        attribute surfaceArea : AreaValue;
        attribute boundMoleculeCount : Real;
        attribute surfaceCharge : SurfaceChargeDensity;
    }
    
    part def SemiconductorChannel {
        doc /* Conductive channel whose properties are modulated by gate surface charge */
        attribute channelLength : LengthValue;
        attribute channelWidth : LengthValue;
        attribute carrierMobility : Real;
        attribute carrierConcentration : Real;
        attribute conductance : Real;
    }
    
    part def SourceElectrode {
        attribute voltage : ElectricPotentialValue;
    }
    
    part def DrainElectrode {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    
    part def BioFETTransducer {
        doc /* Field-effect transistor with biologically functionalized gate for label-free biomolecule detection */
        
        port fluidicInterface : FluidicInputPort;
        port electricalBias : ElectricalBiasPort;
        port electricalOutput : ElectricalSensingPort;
        
        part gate : FunctionalizedGate {
            attribute receptorDensity = 1.0e12;
            attribute surfaceArea = 1.0e-6;
        }
        
        part channel : SemiconductorChannel {
            attribute channelLength = 1.0e-6;
            attribute channelWidth = 10.0e-6;
            attribute carrierMobility = 0.1;
        }
        
        part source : SourceElectrode;
        part drain : DrainElectrode;
    }
    
    part def MicrofluidicDeliverySystem {
        doc /* Precisely controls sample and buffer delivery to sensor surface */
        
        port sampleInput : FluidicInputPort;
        port sensorOutput : FluidicOutputPort;
        
        part injectionValve {
            attribute switchTime : TimeValue;
        }
        
        part microChannel {
            attribute flowRate : Real;
            attribute volume : VolumeValue;
        }
        
        part micropump {
            attribute pumpingRate : Real;
        }
    }
    
    part def TransimpedanceAmplifier {
        doc /* Converts drain current to voltage signal with low noise */
        
        port currentInput {
            in flow inputCurrent : ElectricCurrentValue;
        }
        
        port voltageOutput {
            out flow outputVoltage : ElectricPotentialValue;
        }
        
        attribute feedbackResistance : Real;
        attribute gain : Real;
        attribute bandwidth : FrequencyValue;
    }
    
    part def AnalogToDigitalConverter {
        doc /* Digitizes amplified signal for processing */
        
        port analogInput {
            in flow inputVoltage : ElectricPotentialValue;
        }
        
        port digitalOutput {
            out flow digitalValue : Real;
        }
        
        attribute resolution : Real;
        attribute samplingRate : FrequencyValue;
    }
    
    part def SignalProcessingUnit {
        doc /* Processes digitized signal and calculates analyte concentration */
        
        port dataInput {
            in flow rawSignal : Real;
        }
        
        port dataOutput : DataOutputPort;
        
        attribute calibrationCurve : Real[*];
        attribute baselineSignal : Real;
        attribute noiseThreshold : Real;
    }
    
    action def CaptureBiomolecules {
        in sampleConcentration : AnalyteConcentration;
        in receptorDensity : Real;
        in bindingAffinity : BindingAffinity;
        out boundMolecules : Real;
        out surfaceCharge : SurfaceChargeDensity;
    }
    
    action def ModulateChannelConductance {
        in surfaceCharge : SurfaceChargeDensity;
        in gateVoltage : ElectricPotentialValue;
        in carrierMobility : Real;
        out channelConductance : Real;
        out thresholdShift : ThresholdVoltageShift;
    }
    
    action def GenerateDrainCurrent {
        in channelConductance : Real;
        in drainVoltage : ElectricPotentialValue;
        in sourceVoltage : ElectricPotentialValue;
        out drainCurrent : ElectricCurrentValue;
    }
    
    action def AmplifySignal {
        in drainCurrent : ElectricCurrentValue;
        in gain : Real;
        out amplifiedVoltage : ElectricPotentialValue;
    }
    
    action def DigitizeSignal {
        in analogVoltage : ElectricPotentialValue;
        in resolution : Real;
        out digitalSignal : Real;
    }
    
    action def CalculateConcentration {
        in digitalSignal : Real;
        in baselineSignal : Real;
        in calibrationCurve : Real[*];
        out concentration : AnalyteConcentration;
        out signalQuality : Real;
    }
    
    action def PerformBiomoleculeDetection {
        doc /* Primary system function: detect and quantify target biomolecules through electrical signal transduction */
        
        in sampleConcentration : AnalyteConcentration;
        in gateVoltage : ElectricPotentialValue;
        in drainVoltage : ElectricPotentialValue;
        in sourceVoltage : ElectricPotentialValue;
        out detectedConcentration : AnalyteConcentration;
        out measurementQuality : Real;
        
        private attribute currentSurfaceCharge : SurfaceChargeDensity := 0.0;
        private attribute currentConductance : Real := 1.0e-6;
        private attribute currentDrainCurrent : ElectricCurrentValue;
        private attribute currentAmplifiedVoltage : ElectricPotentialValue;
        private attribute currentDigitalSignal : Real := 0.0;
        private attribute baselineEstablished : Boolean := false;
        private attribute baselineValue : Real := 0.0;
        
        first start;
        
        then action establishBaseline {
            doc /* Measure baseline signal with buffer only */
        }
        
        then accept calibrationDone : CalibrationComplete;
        
        then assign baselineEstablished := true;
        
        then accept sampleReady : SampleReady;
        
        then merge continueMeasurement;
        
        then action captureMolecules : CaptureBiomolecules {
            in sampleConcentration = sampleConcentration;
            in receptorDensity = 1.0e12;
            in bindingAffinity = 1.0e9;
            out boundMolecules;
            out surfaceCharge;
        }
        
        then assign currentSurfaceCharge := captureMolecules.surfaceCharge;
        
        then action modulateChannel : ModulateChannelConductance {
            in surfaceCharge = currentSurfaceCharge;
            in gateVoltage = gateVoltage;
            in carrierMobility = 0.1;
            out channelConductance;
            out thresholdShift;
        }
        
        then assign currentConductance := modulateChannel.channelConductance;
        
        then action generateCurrent : GenerateDrainCurrent {
            in channelConductance = currentConductance;
            in drainVoltage = drainVoltage;
            in sourceVoltage = sourceVoltage;
            out drainCurrent;
        }
        
        then assign currentDrainCurrent := generateCurrent.drainCurrent;
        
        then action amplify : AmplifySignal {
            in drainCurrent = currentDrainCurrent;
            in gain = 1.0e6;
            out amplifiedVoltage;
        }
        
        then assign currentAmplifiedVoltage := amplify.amplifiedVoltage;
        
        then action digitize : DigitizeSignal {
            in analogVoltage = currentAmplifiedVoltage;
            in resolution = 16.0;
            out digitalSignal;
        }
        
        then assign currentDigitalSignal := digitize.digitalSignal;
        
        then action calculate : CalculateConcentration {
            in digitalSignal = currentDigitalSignal;
            in baselineSignal = baselineValue;
            in calibrationCurve = (1.0, 2.0, 3.0);
            out concentration;
            out signalQuality;
        }
        
        then assign detectedConcentration := calculate.concentration;
        then assign measurementQuality := calculate.signalQuality;
        
        then decide;
            if measurementQuality < 0.95 then continueMeasurement;
            if measurementQuality >= 0.95 then finalizeMeasurement;
        
        action finalizeMeasurement {
            accept measurementDone : MeasurementComplete;
        }
        
        then done;
    }
    
    part bioFETSystem {
        doc /* Integrated Bio-FET system for real-time, label-free detection of biomolecules in solution */
        
        perform action detectBiomolecules : PerformBiomoleculeDetection;
        
        part transducer : BioFETTransducer {
            perform detectBiomolecules.captureMolecules;
            perform detectBiomolecules.modulateChannel;
            perform detectBiomolecules.generateCurrent;
        }
        
        part fluidics : MicrofluidicDeliverySystem;
        
        part amplifier : TransimpedanceAmplifier {
            attribute gain = 1.0e6;
            attribute bandwidth = 1000.0;
            perform detectBiomolecules.amplify;
        }
        
        part adc : AnalogToDigitalConverter {
            attribute resolution = 16.0;
            attribute samplingRate = 10000.0;
            perform detectBiomolecules.digitize;
        }
        
        part processor : SignalProcessingUnit {
            perform detectBiomolecules.calculate;
        }
        
        connection fluidicConnection connect 
            fluidics.sensorOutput to transducer.fluidicInterface;
        
        connection currentSensing connect 
            transducer.electricalOutput.drainCurrent to amplifier.currentInput.inputCurrent;
        
        connection amplifiedSignal connect 
            amplifier.voltageOutput.outputVoltage to adc.analogInput.inputVoltage;
        
        connection digitalData connect 
            adc.digitalOutput.digitalValue to processor.dataInput.rawSignal;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The Bio-FET system shall detect and quantify target biomolecules in aqueous solution through label-free electrical transduction */
        
        subject system : bioFETSystem;
        
        require constraint {
            doc /* System must convert biomolecular binding events to measurable electrical signals */
        }
    }
    
    requirement def SensitivityRequirement {
        doc /* The system shall detect biomolecule concentrations down to specified minimum level */
        
        attribute minimumDetectableConcentration : AnalyteConcentration;
        
        require constraint {
            minimumDetectableConcentration <= 1.0e-12
        }
    }
    
    requirement def SelectivityRequirement {
        doc /* The system shall selectively detect target biomolecules in presence of interferents */
        
        attribute selectivityRatio : Real;
        
        require constraint {
            selectivityRatio >= 100.0
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The system shall provide concentration measurement within specified time */
        
        attribute maximumResponseTime : TimeValue;
        
        require constraint {
            maximumResponseTime <= 300.0
        }
    }
    
    requirement def DynamicRangeRequirement {
        doc /* The system shall measure concentrations over specified range */
        
        attribute minimumConcentration : AnalyteConcentration;
        attribute maximumConcentration : AnalyteConcentration;
        
        require constraint {
            maximumConcentration / minimumConcentration >= 1.0e6
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for Bio-FET detection system */
        
        subject bioFETSystem;
        
        require reqPrimaryFunction : PrimaryFunctionRequirement;
        
        require reqSensitivity : SensitivityRequirement {
            attribute :>> minimumDetectableConcentration = 1.0e-15;
        }
        
        require reqSelectivity : SelectivityRequirement {
            attribute :>> selectivityRatio = 1000.0;
        }
        
        require reqResponseTime : ResponseTimeRequirement {
            attribute :>> maximumResponseTime = 120.0;
        }
        
        require reqDynamicRange : DynamicRangeRequirement {
            attribute :>> minimumConcentration = 1.0e-15;
            attribute :>> maximumConcentration = 1.0e-6;
        }
    }
}
