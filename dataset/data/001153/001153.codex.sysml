package NanosensorSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Concentration {
        :> scalarValue;
        unit = "nmol/L";
    }

    attribute def ParticleDiameter {
        :> scalarValue;
        unit = "nm";
    }

    attribute def SampleVolume {
        :> scalarValue;
        unit = "uL";
    }

    attribute def ElectricPotential {
        :> scalarValue;
        unit = "mV";
    }

    attribute def SignalCurrent {
        :> scalarValue;
        unit = "nA";
    }

    attribute def TemperatureCelsius {
        :> scalarValue;
        unit = "degC";
    }

    attribute def DetectionConfidence {
        :> scalarValue;
        unit = "percent";
    }

    attribute def TimeSeconds {
        :> scalarValue;
        unit = "s";
    }

    enum def SensorMode {
        enum idle;
        enum calibrating;
        enum sampling;
        enum detecting;
        enum reporting;
        enum fault;
    }

    enum def AnalyteClass {
        enum biomarkerProtein;
        enum toxicIon;
        enum pathogenFragment;
        enum volatileMolecule;
    }

    item def LiquidSample {
        attribute volume : SampleVolume;
        attribute temperature : TemperatureCelsius;
        attribute targetAnalyte : AnalyteClass;
        attribute expectedConcentration : Concentration;
    }

    item def NanoInteraction {
        attribute boundParticleDiameter : ParticleDiameter;
        attribute surfacePotentialShift : ElectricPotential;
        attribute reactionTime : TimeSeconds;
    }

    item def RawElectricalSignal {
        attribute current : SignalCurrent;
        attribute potential : ElectricPotential;
        attribute temperature : TemperatureCelsius;
        attribute timestamp : TimeSeconds;
    }

    item def DetectionResult {
        attribute detectedAnalyte : AnalyteClass;
        attribute measuredConcentration : Concentration;
        attribute confidence : DetectionConfidence;
        attribute valid : Boolean;
    }

    port def FluidInletPort {
        in item sample : LiquidSample;
    }

    port def NanoSurfacePort {
        in item sample : LiquidSample;
        out item interaction : NanoInteraction;
    }

    port def SignalPort {
        out item signal : RawElectricalSignal;
    }

    port def DataPort {
        out item result : DetectionResult;
    }

    port def PowerPort {
        in attribute supplyVoltage : ElectricPotential;
    }

    port def ControlPort {
        in attribute requestedMode : SensorMode;
        out attribute actualMode : SensorMode;
    }

    part def NanoFunctionalizedSurface {
        attribute particleDiameter : ParticleDiameter = 25;
        attribute receptorSpacing : ParticleDiameter = 8;
        attribute nominalBindingTime : TimeSeconds = 12;
        attribute operatingTemperature : TemperatureCelsius = 25;

        port surface : NanoSurfacePort;

        action bindAnalyte {
            in item incomingSample : LiquidSample;
            out item interaction : NanoInteraction;

            first start;
            then exposeSurface;
            then selectiveBinding;
            then produceSurfacePotentialShift;
            then done;

            action exposeSurface;
            action selectiveBinding;
            action produceSurfacePotentialShift;
        }
    }

    part def Transducer {
        attribute baselinePotential : ElectricPotential = 0;
        attribute sensitivity : SignalCurrent = 4;
        attribute noiseFloor : SignalCurrent = 0.05;

        port nanoInput : NanoSurfacePort;
        port signalOutput : SignalPort;

        action convertInteractionToSignal {
            in item interaction : NanoInteraction;
            out item signal : RawElectricalSignal;

            first receiveInteraction;
            then measurePotentialShift;
            then amplifyCurrent;
            then emitRawSignal;

            action receiveInteraction;
            action measurePotentialShift;
            action amplifyCurrent;
            action emitRawSignal;
        }
    }

    part def MicrofluidicChannel {
        attribute minimumSampleVolume : SampleVolume = 10;
        attribute nominalSampleVolume : SampleVolume = 25;
        attribute flowStabilizationTime : TimeSeconds = 3;

        port inlet : FluidInletPort;
        port outlet : NanoSurfacePort;

        action conditionSample {
            in item rawSample : LiquidSample;
            out item conditionedSample : LiquidSample;

            first receiveSample;
            then meterVolume;
            then stabilizeFlow;
            then deliverToNanoSurface;

            action receiveSample;
            action meterVolume;
            action stabilizeFlow;
            action deliverToNanoSurface;
        }
    }

    part def SignalProcessor {
        attribute detectionThreshold : SignalCurrent = 0.5;
        attribute minimumConfidence : DetectionConfidence = 95;
        attribute maximumProcessingTime : TimeSeconds = 2;

        port signalInput : SignalPort;
        port dataOutput : DataPort;
        port control : ControlPort;

        action analyzeSignal {
            in item signal : RawElectricalSignal;
            out item result : DetectionResult;

            first filterNoise;
            then subtractBaseline;
            then classifyAnalyte;
            then estimateConcentration;
            then computeConfidence;
            then publishResult;

            action filterNoise;
            action subtractBaseline;
            action classifyAnalyte;
            action estimateConcentration;
            action computeConfidence;
            action publishResult;
        }
    }

    part def PowerAndControlUnit {
        attribute regulatedVoltage : ElectricPotential = 3300;
        attribute startupTime : TimeSeconds = 1;
        attribute mode : SensorMode = SensorMode::idle;

        port powerOut : PowerPort;
        port command : ControlPort;

        state machine operatingModes {
            state off;
            state idle;
            state calibrating;
            state sampling;
            state detecting;
            state reporting;
            state fault;

            entry; then off;

            transition powerApplied
                first off
                then idle;

            transition calibrationRequested
                first idle
                then calibrating;

            transition calibrationComplete
                first calibrating
                then sampling;

            transition sampleAvailable
                first sampling
                then detecting;

            transition detectionComplete
                first detecting
                then reporting;

            transition reportSent
                first reporting
                then idle;

            transition faultDetected
                first idle
                then fault;

            transition samplingFault
                first sampling
                then fault;

            transition detectionFault
                first detecting
                then fault;

            transition reset
                first fault
                then idle;
        }
    }

    part def NanosensorSystem {
        attribute primaryFunction : String = "Detect nanoscale chemical or biological interactions in a small sample and convert them into a validated analyte concentration result.";
        attribute requiredSampleVolume : SampleVolume = 25;
        attribute minimumDetectableConcentration : Concentration = 0.1;
        attribute responseTimeLimit : TimeSeconds = 20;

        port sampleInput : FluidInletPort;
        port resultOutput : DataPort;
        port externalPower : PowerPort;
        port operatorControl : ControlPort;

        part channel : MicrofluidicChannel;
        part nanoSurface : NanoFunctionalizedSurface;
        part transducer : Transducer;
        part processor : SignalProcessor;
        part controller : PowerAndControlUnit;

        connect sampleInput to channel.inlet;
        connect channel.outlet to nanoSurface.surface;
        connect nanoSurface.surface to transducer.nanoInput;
        connect transducer.signalOutput to processor.signalInput;
        connect processor.dataOutput to resultOutput;
        connect externalPower to controller.powerOut;
        connect operatorControl to controller.command;
        connect controller.command to processor.control;

        action performDetection {
            in item sample : LiquidSample;
            out item result : DetectionResult;

            first acceptSample;
            then conditionSample;
            then bindTargetAnalyte;
            then transduceNanoInteraction;
            then processSignal;
            then reportDetectionResult;

            action acceptSample;
            action conditionSample;
            action bindTargetAnalyte;
            action transduceNanoInteraction;
            action processSignal;
            action reportDetectionResult;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc "The system shall detect the presence and concentration of a target analyte by using nanoscale surface interactions and shall report a validated detection result.";
        subject system : NanosensorSystem;

        require constraint {
            system.minimumDetectableConcentration <= 0.1
        }
    }

    requirement def SampleVolumeRequirement {
        doc "The system shall perform one detection cycle using no more than 25 microliters of liquid sample.";
        subject system : NanosensorSystem;

        require constraint {
            system.requiredSampleVolume <= 25
        }
    }

    requirement def ResponseTimeRequirement {
        doc "The system shall complete sample conditioning, nanoscale binding, signal transduction, processing, and reporting within 20 seconds.";
        subject system : NanosensorSystem;

        require constraint {
            system.responseTimeLimit <= 20
        }
    }

    requirement def ConfidenceRequirement {
        doc "The system shall report positive detections only when computed confidence is at least 95 percent.";
        subject processor : SignalProcessor;

        require constraint {
            processor.minimumConfidence >= 95
        }
    }

    requirement def SignalSensitivityRequirement {
        doc "The transducer shall resolve analyte-induced surface interactions above the electrical noise floor.";
        subject transducer : Transducer;

        require constraint {
            transducer.sensitivity > transducer.noiseFloor
        }
    }

    satisfy PrimaryFunctionRequirement by NanosensorSystem;
    satisfy SampleVolumeRequirement by NanosensorSystem;
    satisfy ResponseTimeRequirement by NanosensorSystem;
    satisfy ConfidenceRequirement by SignalProcessor;
    satisfy SignalSensitivityRequirement by Transducer;

    part nanosensorSystem : NanosensorSystem;

}