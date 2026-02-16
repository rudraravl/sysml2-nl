package 'LVDT Measurement System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def ACVoltageValue :> ISQ::VoltageValue {
        attribute frequency : ISQ::FrequencyValue;
        attribute amplitude : ISQ::VoltageValue;
    }
    
    attribute def DCVoltageValue :> ISQ::VoltageValue;
    
    attribute def DisplacementValue :> ISQ::LengthValue;
    
    attribute def InductanceValue :> Real;
    
    attribute def CouplingCoefficientValue :> Real;
    
    attribute def SensitivityValue :> Real;

    port def ExcitationPort {
        in excitationVoltage : ACVoltageValue;
    }
    
    port def SecondaryOutputPort {
        out outputVoltage : ACVoltageValue;
    }
    
    port def MechanicalInputPort {
        in displacement : DisplacementValue;
    }
    
    port def ConditionedOutputPort {
        out dcVoltage : DCVoltageValue;
    }
    
    port def PowerInputPort {
        in supplyVoltage : DCVoltageValue;
    }

    part def PrimaryCoil {
        port excitationInput : ExcitationPort;
        attribute numberOfTurns : Real;
        attribute resistance : Real;
        attribute inductance : InductanceValue;
    }
    
    part def SecondaryCoil {
        port secondaryOutput : SecondaryOutputPort;
        attribute numberOfTurns : Real;
        attribute resistance : Real;
        attribute inductance : InductanceValue;
    }
    
    part def FerriteCore {
        port mechanicalInput : MechanicalInputPort;
        attribute length : ISQ::LengthValue;
        attribute diameter : ISQ::LengthValue;
        attribute permeability : Real;
        attribute currentPosition : DisplacementValue;
    }
    
    part def TransformerAssembly {
        port excitation : ExcitationPort;
        port secondary1Output : SecondaryOutputPort;
        port secondary2Output : SecondaryOutputPort;
        port coreInput : MechanicalInputPort;
        
        attribute nominalSensitivity : SensitivityValue;
        attribute linearRange : ISQ::LengthValue;
        
        part primary : PrimaryCoil {
            attribute :>> numberOfTurns = 1000.0;
            attribute :>> resistance = 50.0;
            attribute :>> inductance = 0.1;
        }
        
        part secondary1 : SecondaryCoil {
            attribute :>> numberOfTurns = 500.0;
            attribute :>> resistance = 25.0;
            attribute :>> inductance = 0.05;
        }
        
        part secondary2 : SecondaryCoil {
            attribute :>> numberOfTurns = 500.0;
            attribute :>> resistance = 25.0;
            attribute :>> inductance = 0.05;
        }
        
        part core : FerriteCore {
            attribute :>> length = 100.0;
            attribute :>> diameter = 6.0;
            attribute :>> permeability = 2500.0;
            attribute :>> currentPosition = 0.0;
        }
        
        connect primary.excitationInput to excitation;
        connect secondary1.secondaryOutput to secondary1Output;
        connect secondary2.secondaryOutput to secondary2Output;
        connect core.mechanicalInput to coreInput;
    }
    
    part def ExcitationSource {
        port powerInput : PowerInputPort;
        port excitationOutput : ExcitationPort;
        
        attribute carrierFrequency : ISQ::FrequencyValue;
        attribute outputAmplitude : ISQ::VoltageValue;
    }
    
    part def SignalConditioner {
        port secondary1Input : SecondaryOutputPort;
        port secondary2Input : SecondaryOutputPort;
        port conditionedOutput : ConditionedOutputPort;
        
        attribute gain : Real;
        attribute filterCutoff : ISQ::FrequencyValue;
        attribute demodulationFrequency : ISQ::FrequencyValue;
    }
    
    part def PowerSupply {
        port output : PowerInputPort;
        attribute nominalVoltage : DCVoltageValue;
        attribute currentRating : ISQ::ElectricCurrentValue;
    }
    
    part def DisplayUnit {
        port input : ConditionedOutputPort;
        attribute displayedPosition : DisplacementValue;
        attribute resolution : DisplacementValue;
    }

    action def GenerateExcitation {
        in supplyVoltage : DCVoltageValue;
        in frequency : ISQ::FrequencyValue;
        in amplitude : ISQ::VoltageValue;
        out excitationSignal : ACVoltageValue;
    }
    
    action def TransduceDisplacement {
        in excitation : ACVoltageValue;
        in corePosition : DisplacementValue;
        in primaryInductance : InductanceValue;
        in secondaryInductance : InductanceValue;
        in couplingCoefficient : CouplingCoefficientValue;
        out secondary1Voltage : ACVoltageValue;
        out secondary2Voltage : ACVoltageValue;
    }
    
    action def ComputeDifferential {
        in voltage1 : ACVoltageValue;
        in voltage2 : ACVoltageValue;
        out differentialVoltage : ACVoltageValue;
    }
    
    action def DemodulateSignal {
        in differentialSignal : ACVoltageValue;
        in carrierFrequency : ISQ::FrequencyValue;
        out demodulatedSignal : DCVoltageValue;
    }
    
    action def FilterAndAmplify {
        in rawSignal : DCVoltageValue;
        in gain : Real;
        in cutoffFrequency : ISQ::FrequencyValue;
        out conditionedSignal : DCVoltageValue;
    }
    
    action def ConvertToDisplacement {
        in voltageSignal : DCVoltageValue;
        in sensitivity : SensitivityValue;
        out displacement : DisplacementValue;
    }
    
    action def MeasurePosition {
        in coreDisplacement : DisplacementValue;
        in excitationFrequency : ISQ::FrequencyValue;
        in excitationAmplitude : ISQ::VoltageValue;
        in systemSensitivity : SensitivityValue;
        in conditionerGain : Real;
        out measuredPosition : DisplacementValue;
        
        first start;
        
        then action generateExcitation : GenerateExcitation {
            in supplyVoltage : DCVoltageValue;
            in frequency = excitationFrequency;
            in amplitude = excitationAmplitude;
            out excitationSignal : ACVoltageValue;
        }
        
        flow generateExcitation.excitationSignal to transduceDisplacement.excitation;
        
        then action transduceDisplacement : TransduceDisplacement {
            in excitation : ACVoltageValue;
            in corePosition = coreDisplacement;
            in primaryInductance : InductanceValue;
            in secondaryInductance : InductanceValue;
            in couplingCoefficient : CouplingCoefficientValue;
            out secondary1Voltage : ACVoltageValue;
            out secondary2Voltage : ACVoltageValue;
        }
        
        flow transduceDisplacement.secondary1Voltage to computeDifferential.voltage1;
        flow transduceDisplacement.secondary2Voltage to computeDifferential.voltage2;
        
        then action computeDifferential : ComputeDifferential {
            in voltage1 : ACVoltageValue;
            in voltage2 : ACVoltageValue;
            out differentialVoltage : ACVoltageValue;
        }
        
        flow computeDifferential.differentialVoltage to demodulateSignal.differentialSignal;
        
        then action demodulateSignal : DemodulateSignal {
            in differentialSignal : ACVoltageValue;
            in carrierFrequency = excitationFrequency;
            out demodulatedSignal : DCVoltageValue;
        }
        
        flow demodulateSignal.demodulatedSignal to filterAndAmplify.rawSignal;
        
        then action filterAndAmplify : FilterAndAmplify {
            in rawSignal : DCVoltageValue;
            in gain = conditionerGain;
            in cutoffFrequency : ISQ::FrequencyValue;
            out conditionedSignal : DCVoltageValue;
        }
        
        flow filterAndAmplify.conditionedSignal to convertToDisplacement.voltageSignal;
        
        then action convertToDisplacement : ConvertToDisplacement {
            in voltageSignal : DCVoltageValue;
            in sensitivity = systemSensitivity;
            out displacement : DisplacementValue;
        }
        
        flow convertToDisplacement.displacement to measuredPosition;
        
        then done;
    }

    part def LVDTPositionMeasurementSystem {
        doc /* 
            A Linear Variable Differential Transformer (LVDT) position measurement system 
            that converts mechanical displacement into a proportional electrical signal.
            
            Primary Function: The system continuously measures the linear position of a 
            movable ferrite core by electromagnetic induction. An AC excitation voltage 
            energizes a primary coil, inducing voltages in two secondary coils. As the 
            core moves, the coupling between primary and secondaries changes differentially, 
            producing an output voltage proportional to displacement. Signal conditioning 
            circuitry demodulates, filters, and amplifies this differential signal to 
            provide a calibrated DC voltage or digital readout representing absolute position.
        */
        
        attribute measuredDisplacement : DisplacementValue;
        attribute actualDisplacement : DisplacementValue;
        attribute measurementError : DisplacementValue;
        
        part powerSupply : PowerSupply {
            attribute :>> nominalVoltage = 24.0;
            attribute :>> currentRating = 1.0;
        }
        
        part excitationSource : ExcitationSource {
            attribute :>> carrierFrequency = 5000.0;
            attribute :>> outputAmplitude = 5.0;
            perform measurementCycle.generateExcitation;
        }
        
        part lvdtTransformer : TransformerAssembly {
            attribute :>> nominalSensitivity = 120.0;
            attribute :>> linearRange = 50.0;
            perform measurementCycle.transduceDisplacement;
        }
        
        part signalConditioner : SignalConditioner {
            attribute :>> gain = 15.0;
            attribute :>> filterCutoff = 100.0;
            attribute :>> demodulationFrequency = 5000.0;
            perform measurementCycle.computeDifferential;
            perform measurementCycle.demodulateSignal;
            perform measurementCycle.filterAndAmplify;
        }
        
        part display : DisplayUnit {
            attribute :>> resolution = 0.01;
            perform measurementCycle.convertToDisplacement;
        }
        
        connect powerSupply.output to excitationSource.powerInput;
        connect excitationSource.excitationOutput to lvdtTransformer.excitation;
        connect lvdtTransformer.secondary1Output to signalConditioner.secondary1Input;
        connect lvdtTransformer.secondary2Output to signalConditioner.secondary2Input;
        connect signalConditioner.conditionedOutput to display.input;
        
        bind lvdtTransformer.core.currentPosition to actualDisplacement;
        bind display.displayedPosition to measuredDisplacement;
        
        action measurementCycle : MeasurePosition {
            in coreDisplacement = actualDisplacement;
            in excitationFrequency = excitationSource.carrierFrequency;
            in excitationAmplitude = excitationSource.outputAmplitude;
            in systemSensitivity = lvdtTransformer.nominalSensitivity;
            in conditionerGain = signalConditioner.gain;
            out measuredPosition : DisplacementValue;
        }
        
        bind measuredPosition to measurementCycle.measuredPosition;
    }

    requirement def SystemFunctionRequirement {
        doc /* 
            The LVDT position measurement system shall convert linear mechanical 
            displacement of a ferrite core into a proportional electrical output 
            signal through electromagnetic induction and signal conditioning.
        */
        subject system : LVDTPositionMeasurementSystem;
    }
    
    requirement def MeasurementRangeRequirement {
        doc /* 
            The system shall measure displacement over a linear range of ±25 mm 
            from the null position with monotonic output.
        */
        subject system : LVDTPositionMeasurementSystem;
        require constraint {
            system.lvdtTransformer.linearRange >= 50.0
        }
    }
    
    requirement def LinearityRequirement {
        doc /* 
            The system shall maintain linearity within ±0.5% of full scale 
            over the specified measurement range.
        */
        subject system : LVDTPositionMeasurementSystem;
        require constraint {
            system.measurementError <= 0.005 * system.lvdtTransformer.linearRange
        }
    }
    
    requirement def SensitivityRequirement {
        doc /* 
            The system shall provide minimum sensitivity of 100 mV/mm 
            to ensure adequate signal-to-noise ratio.
        */
        subject system : LVDTPositionMeasurementSystem;
        require constraint {
            system.lvdtTransformer.nominalSensitivity >= 100.0
        }
    }
    
    requirement def ExcitationFrequencyRequirement {
        doc /* 
            The excitation source shall operate at a carrier frequency 
            between 2 kHz and 10 kHz to minimize electromagnetic interference 
            and ensure adequate transformer coupling.
        */
        subject system : LVDTPositionMeasurementSystem;
        require constraint {
            system.excitationSource.carrierFrequency >= 2000.0 and 
            system.excitationSource.carrierFrequency <= 10000.0
        }
    }
    
    requirement def ResolutionRequirement {
        doc /* 
            The display unit shall provide position readout with 
            resolution of 0.01 mm or better.
        */
        subject system : LVDTPositionMeasurementSystem;
        require constraint {
            system.display.resolution <= 0.01
        }
    }
    
    requirement systemRequirement : SystemFunctionRequirement {
        subject system : LVDTPositionMeasurementSystem;
        
        assume constraint {
            doc /* Core displacement remains within calibrated range. */
            system.actualDisplacement >= -25.0 and 
            system.actualDisplacement <= 25.0
        }
        
        require rangeReq : MeasurementRangeRequirement;
        require linearityReq : LinearityRequirement;
        require sensitivityReq : SensitivityRequirement;
        require frequencyReq : ExcitationFrequencyRequirement;
        require resolutionReq : ResolutionRequirement;
    }
}
