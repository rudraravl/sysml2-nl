package BioFETDetectionSystem {
    private import ScalarValues::*;

    attribute def ElectricCurrent;
    attribute def Voltage;
    attribute def Concentration;
    attribute def DigitalValue;

    item def Biomolecule;
    item def BufferSolution;
    item def Sample {
        item biomolecules : Biomolecule[*];
    }
    item def CurrentSignal { attribute value : ElectricCurrent; }
    item def VoltageSignal { attribute value : Voltage; }
    item def DigitalSignal { attribute value : DigitalValue; }
    item def ConcentrationResult { attribute concentration : Concentration; }

    item def Start;
    item def BaselineStable;
    item def SampleDelivered;
    item def CurrentStable;
    item def DataReady;
    item def CalculationComplete;

    part def MicrofluidicDeliverySystem {
        port fluidOut { out fluid : Sample; }
        action deliverBuffer {
            out item buffer : BufferSolution;
        }
        then action deliverSample {
            out item sample : Sample;
        }
    }

    part def BioFETTransducer {
        port fluidIn { in fluid : Sample; }
        port currentOut { out current : CurrentSignal; }

        part functionalizedGate {
            item receptors;
            in item targetBiomolecule : Biomolecule;
        }
        part semiconductorChannel {
            part sourceElectrode;
            part drainElectrode;
        }

        action bindMolecules {
            in item fluid : Sample;
            out item boundMolecules : Biomolecule[*];
        }
        then action modulateCurrent {
            in item boundMolecules : Biomolecule[*];
            out item current : CurrentSignal;
        }
    }

    part def TransimpedanceAmplifier {
        port currentIn { in current : CurrentSignal; }
        port voltageOut { out voltage : VoltageSignal; }
        attribute gain : Real = 1e6;
        action convert {
            in item current : CurrentSignal;
            out item voltage : VoltageSignal;
        }
    }

    part def ADC {
        port voltageIn { in voltage : VoltageSignal; }
        port digitalOut { out digital : DigitalSignal; }
        attribute resolution : Integer = 16;
        action digitize {
            in item voltage : VoltageSignal;
            out item digital : DigitalSignal;
        }
    }

    part def SignalProcessingUnit {
        port digitalIn { in digital : DigitalSignal; }
        port concentrationOut { out concentration : ConcentrationResult; }
        attribute baseline : DigitalValue;
        attribute calibrationSlope : Real = 1.0;
        attribute calibrationIntercept : Real = 0.0;

        action process {
            in item digital : DigitalSignal;
            out item concentration : ConcentrationResult;
        }
    }

    part def BioFETSystem {
        part microfluidics : MicrofluidicDeliverySystem;
        part transducer : BioFETTransducer;
        part amplifier : TransimpedanceAmplifier;
        part adc : ADC;
        part processor : SignalProcessingUnit;

        flow of Sample from microfluidics.fluidOut.fluid to transducer.fluidIn.fluid;
        flow of CurrentSignal from transducer.currentOut.current to amplifier.currentIn.current;
        flow of VoltageSignal from amplifier.voltageOut.voltage to adc.voltageIn.voltage;
        flow of DigitalSignal from adc.digitalOut.digital to processor.digitalIn.digital;

        port resultOut { out concentration : ConcentrationResult; }
        flow of ConcentrationResult from processor.concentrationOut.concentration to resultOut.concentration;

        state detectionBehavior {
            entry; then Idle;
            state Idle;
            state BaselineEstablishment {
                do action deliverBuffer;
            }
            state SampleDelivery {
                do action deliverSample;
            }
            state BindingAndDetection {
                do action bindAndModulate;
            }
            state SignalConversion {
                do action convertAndDigitize;
            }
            state Processing {
                do action processSignal;
            }

            transition first Idle accept Start then BaselineEstablishment;
            transition first BaselineEstablishment accept BaselineStable then SampleDelivery;
            transition first SampleDelivery accept SampleDelivered then BindingAndDetection;
            transition first BindingAndDetection accept CurrentStable then SignalConversion;
            transition first SignalConversion accept DataReady then Processing;
            transition first Processing accept CalculationComplete then Idle;
        }
    }

    requirement def DetectionRequirement {
        subject system : BioFETSystem;
        objective {
            doc "The system shall detect and quantify specific biomolecules in liquid samples in real-time.";
        }
    }

    requirement def SensitivityRequirement {
        subject transducer : BioFETTransducer;
        objective {
            doc "The transducer shall convert biomolecule binding events into a measurable electrical current.";
        }
    }

    requirement def QuantificationRequirement {
        subject processor : SignalProcessingUnit;
        objective {
            doc "The signal processing unit shall calculate concentration using a calibration curve and baseline comparison.";
        }
    }
}
