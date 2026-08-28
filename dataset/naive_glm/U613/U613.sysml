package BioFETDetectionSystem {
    import ScalarValues::*;

    // ================================================================
    // Value Types
    // ================================================================

    value def ElectricCurrent :> Real {
        doc "Electric current (A)";
    }

    value def Voltage :> Real {
        doc "Electric potential (V)";
    }

    value def Concentration :> Real {
        doc "Molar concentration (mol/L)";
    }

    value def FlowRate :> Real {
        doc "Volumetric flow rate (uL/min)";
    }

    value def Duration :> Real {
        doc "Time duration (s)";
    }

    value def ElectricCharge :> Real {
        doc "Electric charge (C)";
    }

    value def Conductivity :> Real {
        doc "Electrical conductivity (S)";
    }

    value def DigitalValue :> Integer {
        doc "Digital converter output (counts)";
    }

    value def TransimpedanceGain :> Real {
        doc "Transimpedance gain (V/A)";
    }

    value def Length :> Real {
        doc "Length (um)";
    }

    value def Area :> Real {
        doc "Area (cm^2)";
    }

    // ================================================================
    // Items
    // ================================================================

    item def BufferSolution {
        doc "Stable buffer solution for baseline measurement";
        attribute pH : Real = 7.4;
        attribute ionicStrength : Real;
    }

    item def Sample {
        doc "Liquid sample potentially containing target biomolecule";
        attribute volume : Real;
    }

    item def TargetBiomolecule {
        doc "Specific biomolecule to be detected";
        attribute molecularCharge : ElectricCharge;
        attribute molecularWeight : Real;
    }

    item def ReceptorMolecule {
        doc "Receptor molecule functionalized on gate surface";
        attribute bindingAffinity : Real;
        attribute specificity : String;
    }

    item def BoundComplex {
        doc "Complex formed when target binds receptor";
        ref receptor : ReceptorMolecule;
        ref target : TargetBiomolecule;
        attribute boundCharge : ElectricCharge;
    }

    // ================================================================
    // Ports
    // ================================================================

    port def FluidInPort {
        in item fluid;
    }

    port def FluidOutPort {
        out item fluid;
    }

    port def CurrentInPort {
        in attribute current : ElectricCurrent;
    }

    port def CurrentOutPort {
        out attribute current : ElectricCurrent;
    }

    port def VoltageInPort {
        in attribute voltage : Voltage;
    }

    port def VoltageOutPort {
        out attribute voltage : Voltage;
    }

    port def DigitalInPort {
        in attribute value : DigitalValue;
    }

    port def DigitalOutPort {
        out attribute value : DigitalValue;
    }

    port def ConcentrationOutPort {
        out attribute concentration : Concentration;
    }

    // ================================================================
    // Connection Definitions
    // ================================================================

    connection def FluidConnection {
        end source : FluidOutPort;
        end target : FluidInPort;
    }

    connection def CurrentConnection {
        end source : CurrentOutPort;
        end target : CurrentInPort;
    }

    connection def VoltageConnection {
        end source : VoltageOutPort;
        end target : VoltageInPort;
    }

    connection def DigitalConnection {
        end source : DigitalOutPort;
        end target : DigitalInPort;
    }

    // ================================================================
    // Component Definitions
    // ================================================================

    part def Micropump {
        doc "Precision micropump for controlled fluid delivery";
        attribute nominalFlowRate : FlowRate = 5.0;
        attribute accuracyPct : Real = 2.0;
        port pumpIn : FluidInPort;
        port pumpOut : FluidOutPort;
    }

    part def Microchannel {
        doc "Microfluidic channel for sample transport";
        attribute channelLength : Length = 5000.0;
        attribute channelWidth : Length = 100.0;
        attribute channelHeight : Length = 50.0;
        port channelIn : FluidInPort;
        port channelOut : FluidOutPort;
    }

    part def FunctionalizedGate {
        doc "FET gate with functionalized receptor molecules for selective capture";
        attribute receptorDensity : Real = 1.0e12;
        attribute gateArea : Area = 1.0e-4;
        attribute surfaceChargeDensity : ElectricCharge;
        item receptors : ReceptorMolecule[*];

        action def CaptureTarget {
            doc "Selective binding of target biomolecule to receptor";
            in item target : TargetBiomolecule;
            out item boundComplex : BoundComplex;
        }

        action def InduceCharge {
            doc "Bound target induces surface charge change at gate";
            in item boundComplex : BoundComplex;
            out attribute surfaceCharge : ElectricCharge;
        }
    }

    part def SemiconductorChannel {
        doc "FET semiconductor channel whose conductivity is modulated by gate charge";
        attribute baseConductivity : Conductivity = 1.0e-3;
        attribute modulatedConductivity : Conductivity;
        attribute channelLength : Length = 10.0;
        attribute channelWidth : Length = 5.0;

        action def ModulateConductivity {
            doc "Modulate channel conductivity based on surface charge";
            in attribute surfaceCharge : ElectricCharge;
            out attribute conductivity : Conductivity;
        }
    }

    part def SourceElectrode {
        doc "Source electrode for current injection into FET channel";
        attribute material : String = "Au";
    }

    part def DrainElectrode {
        doc "Drain electrode for current collection from FET channel";
        attribute material : String = "Au";
    }

    part def BioFETTransducer {
        doc "Core Bio-FET transducer converting biomolecule binding to electrical current change";

        port fluidIn : FluidInPort;
        port sourceCurrentOut : CurrentOutPort;
        port drainCurrentOut : CurrentOutPort;

        part gate : FunctionalizedGate;
        part channel : SemiconductorChannel;
        part source : SourceElectrode;
        part drain : DrainElectrode;

        attribute biasVoltage : Voltage = 0.1;
        attribute baselineCurrent : ElectricCurrent;
        attribute modulatedCurrent : ElectricCurrent;

        action def BindTargets {
            doc "Target molecules in fluid bind to receptors on gate surface";
            in item fluid;
            out item capturedComplexes : BoundComplex[*];
        }

        action def GenerateCurrent {
            doc "Surface charge change modulates channel conductivity and source-drain current";
            in item capturedComplexes : BoundComplex[*];
            out attribute outputCurrent : ElectricCurrent;
        }

        action def EstablishBaselineCurrent {
            doc "Establish stable baseline current with buffer solution";
            in item buffer : BufferSolution;
            out attribute baseline : ElectricCurrent;
        }
    }

    part def MicrofluidicDeliverySystem {
        doc "Microfluidic system for controlled delivery of buffer and sample to transducer";

        port bufferInput : FluidInPort;
        port sampleInput : FluidInPort;
        port fluidOutput : FluidOutPort;

        part pump : Micropump {
            attribute nominalFlowRate : FlowRate = 5.0;
        }
        part bufferChannel : Microchannel;
        part sampleChannel : Microchannel;

        action def DeliverBuffer {
            doc "Deliver buffer solution to transducer for baseline establishment";
            in item buffer : BufferSolution;
            out item deliveredBuffer : BufferSolution;
        }

        action def DeliverSample {
            doc "Deliver sample solution to transducer for detection";
            in item sample : Sample;
            out item deliveredSample : Sample;
        }

        connection bufferToPump connect bufferChannel.channelOut to pump.pumpIn;
        connection sampleToPump connect sampleChannel.channelOut to pump.pumpIn;
        connection pumpToOutput connect pump.pumpOut to fluidOutput;
    }

    part def TransimpedanceAmplifier {
        doc "Transimpedance amplifier converting small current to measurable voltage";

        port currentInput : CurrentInPort;
        port voltageOutput : VoltageOutPort;

        attribute gain : TransimpedanceGain = 1.0e6;
        attribute outputVoltage : Voltage;

        action def ConvertCurrentToVoltage {
            doc "Convert input current to output voltage using transimpedance gain";
            in attribute inputCurrent : ElectricCurrent;
            out attribute outputVoltage : Voltage;
        }
    }

    part def AnalogToDigitalConverter {
        doc "Analog-to-digital converter digitizing voltage from TIA";

        port voltageInput : VoltageInPort;
        port digitalOutput : DigitalOutPort;

        attribute resolutionBits : Integer = 16;
        attribute samplingRateHz : Real = 1000.0;
        attribute referenceVoltage : Voltage = 5.0;
        attribute outputValue : DigitalValue;

        action def Digitize {
            doc "Convert analog voltage to digital value";
            in attribute analogVoltage : Voltage;
            out attribute digitalValue : DigitalValue;
        }
    }

    part def SignalProcessingUnit {
        doc "Digital signal processor calculating concentration from digital data using calibration";

        port digitalInput : DigitalInPort;
        port concentrationOutput : ConcentrationOutPort;

        attribute baselineValue : DigitalValue;
        attribute sampleValue : DigitalValue;
        attribute calibrationSlope : Real = 1.0;
        attribute calibrationIntercept : Real = 0.0;
        attribute computedConcentration : Concentration;

        action def RecordBaseline {
            doc "Record baseline digital reading from buffer measurement";
            in attribute baselineData : DigitalValue;
            out attribute storedBaseline : DigitalValue;
        }

        action def ComputeConcentration {
            doc "Compute concentration using calibration curve and baseline subtraction";
            in attribute digitalData : DigitalValue;
            in attribute baseline : DigitalValue;
            out attribute concentration : Concentration;
        }

        action def OutputConcentration {
            doc "Output final concentration result";
            in attribute concentration : Concentration;
            out attribute result : Concentration;
        }
    }

    // ================================================================
    // Top-Level System
    // ================================================================

    part def BioFETDetectionSystem {
        doc "Integrated Bio-FET detection system for real-time, label-free biomolecule detection and quantification";

        port systemBufferInput : FluidInPort;
        port systemSampleInput : FluidInPort;
        port systemResultOutput : ConcentrationOutPort;

        part microfluidics : MicrofluidicDeliverySystem;
        part transducer : BioFETTransducer;
        part tia : TransimpedanceAmplifier;
        part adc : AnalogToDigitalConverter;
        part spu : SignalProcessingUnit;

        // Inter-component connections
        connection fluidDelivery : FluidConnection
            connect microfluidics.fluidOutput to transducer.fluidIn;
        connection currentSignal : CurrentConnection
            connect transducer.drainCurrentOut to tia.currentInput;
        connection voltageSignal : VoltageConnection
            connect tia.voltageOutput to adc.voltageInput;
        connection digitalData : DigitalConnection
            connect adc.digitalOutput to spu.digitalInput;

        // External port delegations
        connection bufferSupply
            connect systemBufferInput to microfluidics.bufferInput;
        connection sampleSupply
            connect systemSampleInput to microfluidics.sampleInput;
        connection resultExport
            connect spu.concentrationOutput to systemResultOutput;

        // System state attributes
        attribute systemStatus : String = "Idle";
        attribute startAnalysis : Boolean = false;
        attribute baselineStable : Boolean = false;
        attribute sampleDelivered : Boolean = false;
        attribute bindingDetected : Boolean = false;
        attribute digitizationComplete : Boolean = false;
        attribute calculationComplete : Boolean = false;
        attribute resultAcknowledged : Boolean = false;
        attribute lastConcentration : Concentration;
        attribute maxResponseTime : Duration = 60.0;

        // State machine for system operation
        state machine operationStateMachine {
            doc "State machine governing the complete detection cycle";

            state initializing {
                doc "Power-on initialization and self-test of all subsystems";
            }

            state idle {
                doc "Waiting for analysis command from operator";
            }

            state baselinePhase {
                doc "Deliver buffer solution and establish stable baseline electrical reading";
            }

            state samplePhase {
                doc "Deliver sample containing target biomolecule to transducer gate surface";
            }

            state detectionPhase {
                doc "Biomolecules bind to functionalized gate receptors modulating channel current";
            }

            state conversionPhase {
                doc "TIA converts current to voltage and ADC digitizes the signal";
            }

            state processingPhase {
                doc "Signal processor subtracts baseline and applies calibration curve";
            }

            state resultPhase {
                doc "Output final computed concentration reading";
            }

            transition from initializing to idle;
            transition from idle to baselinePhase when startAnalysis;
            transition from baselinePhase to samplePhase when baselineStable;
            transition from samplePhase to detectionPhase when sampleDelivered;
            transition from detectionPhase to conversionPhase when bindingDetected;
            transition from conversionPhase to processingPhase when digitizationComplete;
            transition from processingPhase to resultPhase when calculationComplete;
            transition from resultPhase to idle when resultAcknowledged;
        }
    }

    // ================================================================
    // Requirements
    // ================================================================

    requirement def LabelFreeDetectionRequirement {
        doc "The system shall detect and quantify biomolecules without requiring fluorescent or radioactive labels";
        subject detectionSystem : BioFETDetectionSystem;
        objective {
            doc "Enable direct, label-free biomolecule detection for simplified assay workflow";
        }
    }

    requirement def RealTimeResponseRequirement {
        doc "The system shall provide a concentration reading within 60 seconds of sample delivery";
        subject detectionSystem : BioFETDetectionSystem;
        attribute maxResponseTime : Duration = 60.0;
        objective {
            doc "Ensure rapid analysis for real-time clinical or field applications";
        }
    }

    requirement def SensitivityRequirement {
        doc "The system shall detect target biomolecules at concentrations as low as 1 femtomolar";
        subject detectionSystem : BioFETDetectionSystem;
        attribute minimumDetectableConcentration : Concentration = 1.0e-15;
        objective {
            doc "Enable highly sensitive detection for trace biomolecule analysis";
        }
    }

    requirement def SelectivityRequirement {
        doc "The transducer shall selectively capture only the target biomolecule via functionalized receptors";
        subject transducer : BioFETTransducer;
        objective {
            doc "Ensure specificity and reduce false positives from non-target molecules";
        }
    }

    requirement def FlowControlRequirement {
        doc "The microfluidic delivery system shall deliver fluids at controlled rates between 1 and 20 uL/min";
        subject microfluidics : MicrofluidicDeliverySystem;
        attribute minimumFlowRate : FlowRate = 1.0;
        attribute maximumFlowRate : FlowRate = 20.0;
        objective {
            doc "Ensure reproducible and controlled fluid delivery to transducer surface";
        }
    }

    requirement def SignalResolutionRequirement {
        doc "The ADC shall provide at least 16-bit resolution for digitizing the voltage signal";
        subject adc : AnalogToDigitalConverter;
        attribute minimumResolutionBits : Integer = 16;
        objective {
            doc "Ensure adequate digital resolution for precise concentration calculation";
        }
    }

    requirement def TransimpedanceGainRequirement {
        doc "The TIA shall provide transimpedance gain of at least 1e6 V/A to amplify nanoampere currents";
        subject tia : TransimpedanceAmplifier;
        attribute minimumGain : TransimpedanceGain = 1.0e6;
        objective {
            doc "Ensure small current signals are amplified to measurable voltage levels";
        }
    }

    requirement def CalibrationRequirement {
        doc "The signal processor shall use a pre-loaded calibration curve for accurate concentration calculation";
        subject spu : SignalProcessingUnit;
        objective {
            doc "Ensure quantitative accuracy of concentration output against known standards";
        }
    }

    requirement def BaselineStabilityRequirement {
        doc "The system shall establish a stable baseline with buffer solution before sample delivery";
        subject detectionSystem : BioFETDetectionSystem;
        objective {
            doc "Ensure accurate differential measurement by comparing sample signal against baseline";
        }
    }

    requirement def QuantificationAccuracyRequirement {
        doc "The system shall quantify target biomolecule concentration with error less than 10 percent";
        subject detectionSystem : BioFETDetectionSystem;
        attribute maximumErrorPct : Real = 10.0;
        objective {
            doc "Provide reliable quantitative results suitable for clinical diagnostics";
        }
    }
}
