package MicrofluidicsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FluidType;
    attribute def SampleType :> FluidType;
    attribute def ReagentType :> FluidType;
    attribute def BufferType :> FluidType;
    attribute def WasteType :> FluidType;
    attribute def AnalysisResult;
    attribute def ValveCommand;
    attribute def PumpCommand;
    attribute def StartAnalysisSignal;
    attribute def AnalysisCompleteSignal;
    attribute def SystemResetSignal;
    
    port def FluidPort {
        in flowRate : ISQ::VolumeFlowValue;
        in pressure : ISQ::PressureValue;
        in fluidType : FluidType;
    }
    
    port def SampleInputPort {
        in sample : SampleType;
        in volume : ISQ::VolumeValue;
        in concentration : Real;
    }
    
    port def ReagentInputPort {
        in reagent : ReagentType;
        in volume : ISQ::VolumeValue;
    }
    
    port def DetectionPort {
        out signal : Real;
        out result : AnalysisResult;
    }
    
    port def WastePort {
        out waste : WasteType;
        out volume : ISQ::VolumeValue;
    }
    
    part def FluidReservoir {
        attribute capacity : ISQ::VolumeValue;
        attribute currentLevel : ISQ::VolumeValue;
        port outlet : FluidPort;
    }
    
    part def MicroPump {
        attribute maxFlowRate : ISQ::VolumeFlowValue;
        attribute maxPressure : ISQ::PressureValue;
        attribute currentFlowRate : ISQ::VolumeFlowValue;
        port inlet : FluidPort;
        port outlet : FluidPort;
        
        action def PumpFluid {
            in targetFlowRate : ISQ::VolumeFlowValue;
            in duration : ISQ::TimeValue;
            out actualFlowRate : ISQ::VolumeFlowValue;
            out outputPressure : ISQ::PressureValue;
        }
    }
    
    part def MicroValve {
        attribute isOpen : Boolean;
        attribute responseTime : ISQ::TimeValue;
        port inlet : FluidPort;
        port outlet : FluidPort;
        
        action def ActuateValve {
            in command : ValveCommand;
            in targetState : Boolean;
            out actualState : Boolean;
        }
    }
    
    part def Microchannel {
        attribute channelWidth : ISQ::LengthValue;
        attribute channelDepth : ISQ::LengthValue;
        attribute channelLength : ISQ::LengthValue;
        attribute hydraulicResistance : Real;
        port inlet : FluidPort;
        port outlet : FluidPort;
    }
    
    part def MixingChamber {
        attribute chamberVolume : ISQ::VolumeValue;
        attribute mixingEfficiency : Real;
        attribute mixingTime : ISQ::TimeValue;
        port sampleInput : SampleInputPort;
        port reagentInput : ReagentInputPort;
        port mixedOutput : FluidPort;
        
        action def MixFluids {
            in sampleVolume : ISQ::VolumeValue;
            in reagentVolume : ISQ::VolumeValue;
            in mixDuration : ISQ::TimeValue;
            out mixedConcentration : Real;
            out mixedVolume : ISQ::VolumeValue;
        }
    }
    
    part def OpticalDetector {
        attribute wavelength : ISQ::LengthValue;
        attribute sensitivity : Real;
        attribute detectionLimit : Real;
        port fluidInput : FluidPort;
        port detectionOutput : DetectionPort;
        
        action def DetectSignal {
            in fluid : FluidType;
            in concentration : Real;
            out opticalSignal : Real;
            out analysisResult : AnalysisResult;
        }
    }
    
    part def TemperatureController {
        attribute targetTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute tolerance : ISQ::ThermodynamicTemperatureValue;
        attribute heatingPower : ISQ::PowerValue;
        
        action def RegulateTemperature {
            in currentTemp : ISQ::ThermodynamicTemperatureValue;
            in setpoint : ISQ::ThermodynamicTemperatureValue;
            out controlSignal : ISQ::PowerValue;
        }
    }
    
    part def FlowSensor {
        attribute measurementRange : ISQ::VolumeFlowValue;
        attribute accuracy : Real;
        port fluidInput : FluidPort;
        
        action def MeasureFlow {
            in fluid : FluidType;
            out measuredFlowRate : ISQ::VolumeFlowValue;
        }
    }
    
    action def PrepareFluidSample {
        in sampleVolume : ISQ::VolumeValue;
        in reagentVolume : ISQ::VolumeValue;
        in bufferVolume : ISQ::VolumeValue;
        out preparedSample : FluidType;
        out totalVolume : ISQ::VolumeValue;
    }
    
    action def TransportFluid {
        in flowRate : ISQ::VolumeFlowValue;
        in distance : ISQ::LengthValue;
        in channelResistance : Real;
        out transportTime : ISQ::TimeValue;
        out pressureDrop : ISQ::PressureValue;
    }
    
    action def PerformBiochemicalAnalysis {
        in fluidSample : FluidType;
        in detectionMethod : String;
        in incubationTime : ISQ::TimeValue;
        out result : AnalysisResult;
        out confidence : Real;
    }
    
    action def PerformMicrofluidicAnalysis {
        in sampleVolume : ISQ::VolumeValue;
        in reagentVolume : ISQ::VolumeValue;
        in analysisTemperature : ISQ::ThermodynamicTemperatureValue;
        out finalResult : AnalysisResult;
        
        first start;
        then action loadSample : PrepareFluidSample {
            in sampleVolume = PerformMicrofluidicAnalysis::sampleVolume;
            in reagentVolume = PerformMicrofluidicAnalysis::reagentVolume;
            in bufferVolume = 50.0;
            out preparedSample : FluidType;
            out totalVolume : ISQ::VolumeValue;
        }
        then action transportToMixer : TransportFluid {
            in flowRate = 10.0;
            in distance = 15.0;
            in channelResistance = 1.5;
            out transportTime : ISQ::TimeValue;
            out pressureDrop : ISQ::PressureValue;
        }
        then merge mixingDecision;
        then decide;
            if transportToMixer.transportTime > 0.0 then performMixing;
        action performMixing {
            action mixReagents {
                in sample : FluidType = loadSample.preparedSample;
                in mixDuration : ISQ::TimeValue = 30.0;
                out mixedFluid : FluidType;
            }
            then action incubate {
                in duration : ISQ::TimeValue = 120.0;
                in temperature : ISQ::ThermodynamicTemperatureValue = analysisTemperature;
            }
        }
        then action transportToDetector : TransportFluid {
            in flowRate = 5.0;
            in distance = 10.0;
            in channelResistance = 1.2;
            out transportTime : ISQ::TimeValue;
            out pressureDrop : ISQ::PressureValue;
        }
        then action analyze : PerformBiochemicalAnalysis {
            in fluidSample : FluidType;
            in detectionMethod = "optical_absorbance";
            in incubationTime = 60.0;
            out result : AnalysisResult;
            out confidence : Real;
        }
        then assign finalResult = analyze.result;
        then done;
    }
    
    state def MicrofluidicSystemState {
        entry; then idle;
        
        state idle {
            doc /* System is ready and waiting for analysis command */
        }
        
        transition idle_to_initialization
            first idle
            accept startCmd : StartAnalysisSignal
            then initialization;
        
        state initialization {
            entry action initializePumps;
            do action primeChannels;
            exit action verifyReadiness;
        }
        
        transition initialization_to_loading
            first initialization
            if primeChannels.done
            then loading;
        
        state loading {
            entry action openSampleValve;
            do action loadFluidSample;
            exit action closeSampleValve;
        }
        
        transition loading_to_mixing
            first loading
            if loadFluidSample.done
            then mixing;
        
        state mixing {
            entry action openMixingValves;
            do action performFluidMixing;
            exit action closeMixingValves;
        }
        
        transition mixing_to_incubation
            first mixing
            if performFluidMixing.done
            then incubation;
        
        state incubation {
            entry action setIncubationTemperature;
            do action maintainTemperature;
            exit action disableHeating;
        }
        
        transition incubation_to_transport
            first incubation
            if maintainTemperature.done
            then transport;
        
        state transport {
            do action transportFluidToDetector;
        }
        
        transition transport_to_detection
            first transport
            if transportFluidToDetector.done
            then detection;
        
        state detection {
            entry action activateDetector;
            do action performDetection;
            exit action recordResults;
        }
        
        transition detection_to_cleaning
            first detection
            if performDetection.done
            then cleaning;
        
        state cleaning {
            entry action openWasteValve;
            do action flushChannels;
            exit action closeWasteValve;
        }
        
        transition cleaning_to_idle
            first cleaning
            if flushChannels.done
            then idle;
        
        transition emergency_shutdown
            first idle, initialization, loading, mixing, incubation, transport, detection, cleaning
            accept emergencyStop : SystemResetSignal
            then shutdown;
        
        state shutdown {
            entry action closeAllValves;
            do action stopAllPumps;
        }
    }
    
    part def MicrofluidicChip {
        doc /* 
            A microfluidic chip system that performs automated sample preparation,
            fluid mixing, reagent addition, incubation, and optical detection for
            biochemical and biomedical analysis at microscale volumes.
        */
        
        part sampleReservoir : FluidReservoir {
            attribute :>> capacity = 500.0;
            attribute :>> currentLevel = 500.0;
        }
        
        part reagentReservoir : FluidReservoir {
            attribute :>> capacity = 200.0;
            attribute :>> currentLevel = 200.0;
        }
        
        part bufferReservoir : FluidReservoir {
            attribute :>> capacity = 1000.0;
            attribute :>> currentLevel = 1000.0;
        }
        
        part samplePump : MicroPump {
            attribute :>> maxFlowRate = 100.0;
            attribute :>> maxPressure = 500.0;
            attribute :>> currentFlowRate = 0.0;
        }
        
        part reagentPump : MicroPump {
            attribute :>> maxFlowRate = 50.0;
            attribute :>> maxPressure = 500.0;
            attribute :>> currentFlowRate = 0.0;
        }
        
        part bufferPump : MicroPump {
            attribute :>> maxFlowRate = 75.0;
            attribute :>> maxPressure = 400.0;
            attribute :>> currentFlowRate = 0.0;
        }
        
        part sampleValve : MicroValve {
            attribute :>> isOpen = false;
            attribute :>> responseTime = 50.0;
        }
        
        part reagentValve : MicroValve {
            attribute :>> isOpen = false;
            attribute :>> responseTime = 50.0;
        }
        
        part bufferValve : MicroValve {
            attribute :>> isOpen = false;
            attribute :>> responseTime = 50.0;
        }
        
        part wasteValve : MicroValve {
            attribute :>> isOpen = false;
            attribute :>> responseTime = 50.0;
        }
        
        part sampleChannel : Microchannel {
            attribute :>> channelWidth = 100.0;
            attribute :>> channelDepth = 50.0;
            attribute :>> channelLength = 15.0;
            attribute :>> hydraulicResistance = 1.5;
        }
        
        part reagentChannel : Microchannel {
            attribute :>> channelWidth = 80.0;
            attribute :>> channelDepth = 50.0;
            attribute :>> channelLength = 12.0;
            attribute :>> hydraulicResistance = 1.8;
        }
        
        part bufferChannel : Microchannel {
            attribute :>> channelWidth = 120.0;
            attribute :>> channelDepth = 60.0;
            attribute :>> channelLength = 10.0;
            attribute :>> hydraulicResistance = 1.2;
        }
        
        part mixer : MixingChamber {
            attribute :>> chamberVolume = 20.0;
            attribute :>> mixingEfficiency = 0.95;
            attribute :>> mixingTime = 30.0;
        }
        
        part incubationChannel : Microchannel {
            attribute :>> channelWidth = 200.0;
            attribute :>> channelDepth = 100.0;
            attribute :>> channelLength = 50.0;
            attribute :>> hydraulicResistance = 0.8;
        }
        
        part detectionChannel : Microchannel {
            attribute :>> channelWidth = 150.0;
            attribute :>> channelDepth = 75.0;
            attribute :>> channelLength = 10.0;
            attribute :>> hydraulicResistance = 1.0;
        }
        
        part detector : OpticalDetector {
            attribute :>> wavelength = 450.0;
            attribute :>> sensitivity = 0.001;
            attribute :>> detectionLimit = 0.01;
        }
        
        part tempController : TemperatureController {
            attribute :>> targetTemperature = 310.15;
            attribute :>> tolerance = 0.5;
            attribute :>> heatingPower = 5.0;
        }
        
        part flowSensor1 : FlowSensor {
            attribute :>> measurementRange = 200.0;
            attribute :>> accuracy = 0.02;
        }
        
        part flowSensor2 : FlowSensor {
            attribute :>> measurementRange = 200.0;
            attribute :>> accuracy = 0.02;
        }
        
        connection sampleFlow connect sampleReservoir.outlet to samplePump.inlet;
        connection samplePumpToValve connect samplePump.outlet to sampleValve.inlet;
        connection sampleValveToChannel connect sampleValve.outlet to sampleChannel.inlet;
        connection sampleChannelToMixer connect sampleChannel.outlet to mixer.sampleInput;
        
        connection reagentFlow connect reagentReservoir.outlet to reagentPump.inlet;
        connection reagentPumpToValve connect reagentPump.outlet to reagentValve.inlet;
        connection reagentValveToChannel connect reagentValve.outlet to reagentChannel.inlet;
        connection reagentChannelToMixer connect reagentChannel.outlet to mixer.reagentInput;
        
        connection bufferFlow connect bufferReservoir.outlet to bufferPump.inlet;
        connection bufferPumpToValve connect bufferPump.outlet to bufferValve.inlet;
        
        connection mixerToIncubation connect mixer.mixedOutput to incubationChannel.inlet;
        connection incubationToDetection connect incubationChannel.outlet to detectionChannel.inlet;
        connection detectionToDetector connect detectionChannel.outlet to detector.fluidInput;
        
        connection flowMonitoring1 connect sampleChannel.outlet to flowSensor1.fluidInput;
        connection flowMonitoring2 connect detectionChannel.outlet to flowSensor2.fluidInput;
        
        perform action executeAnalysis : PerformMicrofluidicAnalysis {
            in sampleVolume = 10.0;
            in reagentVolume = 5.0;
            in analysisTemperature = 310.15;
            out finalResult : AnalysisResult;
        }
    }
    
    part microfluidicSystem : MicrofluidicChip;
    
    requirement def <'REQ-MF-001'> PrimaryFunctionRequirement {
        doc /* 
            The microfluidic system shall perform automated biochemical analysis
            by precisely controlling fluid flow, mixing samples with reagents,
            maintaining controlled incubation conditions, and detecting analytical
            signals at microscale volumes (1-100 microliters).
        */
        
        subject system : MicrofluidicChip;
        
        require constraint {
            system.mixer.mixingEfficiency >= 0.90
        }
        
        require constraint {
            system.detector.sensitivity <= 0.01
        }
    }
    
    requirement def <'REQ-MF-002'> FlowControlRequirement {
        doc /* 
            The system shall maintain precise flow control with accuracy
            better than 5% of target flow rate across all pumps.
        */
        
        subject pump : MicroPump;
        
        require constraint {
            pump.maxFlowRate >= 50.0
        }
        
        require constraint {
            pump.maxPressure >= 400.0
        }
    }
    
    requirement def <'REQ-MF-003'> TemperatureControlRequirement {
        doc /* 
            The system shall maintain temperature stability within specified
            tolerance during incubation and detection phases.
        */
        
        subject controller : TemperatureController;
        
        require constraint {
            controller.tolerance <= 0.5
        }
    }
    
    requirement def <'REQ-MF-004'> MixingEfficiencyRequirement {
        doc /* 
            The mixing chamber shall achieve at least 95% mixing efficiency
            within 30 seconds for sample volumes between 5-50 microliters.
        */
        
        subject mixer : MixingChamber;
        
        require constraint {
            mixer.mixingEfficiency >= 0.95
        }
        
        require constraint {
            mixer.mixingTime <= 30.0
        }
    }
    
    requirement def <'REQ-MF-005'> DetectionSensitivityRequirement {
        doc /* 
            The optical detector shall achieve detection sensitivity of at least
            0.001 absorbance units with detection limit below 0.01 concentration units.
        */
        
        subject detector : OpticalDetector;
        
        require constraint {
            detector.sensitivity <= 0.001
        }
        
        require constraint {
            detector.detectionLimit <= 0.01
        }
    }
    
    requirement def <'REQ-MF-006'> AnalysisThroughputRequirement {
        doc /* 
            The system shall complete a full analysis cycle from sample loading
            to result output within 5 minutes per sample.
        */
    }
    
    requirement def <'REQ-MF-007'> ValveResponseRequirement {
        doc /* 
            All microvalves shall respond to actuation commands within 100 milliseconds.
        */
        
        subject valve : MicroValve;
        
        require constraint {
            valve.responseTime <= 100.0
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for the microfluidic system */
        
        require primaryFunction : PrimaryFunctionRequirement;
        require flowControl : FlowControlRequirement;
        require temperatureControl : TemperatureControlRequirement;
        require mixingEfficiency : MixingEfficiencyRequirement;
        require detectionSensitivity : DetectionSensitivityRequirement;
        require analysisThroughput : AnalysisThroughputRequirement;
        require valveResponse : ValveResponseRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import MicrofluidicsSystem::*;

    part testSubject : FluidReservoir {
        exhibit state sm : MicrofluidicSystemState;
    }

    action orchestrator {
        attribute testTargetFlowRate : ISQ::VolumeFlowValue;
        attribute testDuration : ISQ::TimeValue;
        action actionProbe : PumpFluid {
            in targetFlowRate = testTargetFlowRate;
            in duration = testDuration;
        }
        first actionProbe;
    }
}
