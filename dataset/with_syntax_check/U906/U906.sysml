package TaperedElementOscillatingMicrobalanceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MassConcentration :> ISQ::DensityValue;
    attribute def ResonantFrequency :> ISQ::FrequencyValue;
    attribute def FrequencyShift :> ISQ::FrequencyValue;
    attribute def AirFlowRate :> ISQ::VolumeFlowRateValue;
    attribute def ParticulateMass :> ISQ::MassValue;
    attribute def ElementMass :> ISQ::MassValue;
    attribute def OscillationAmplitude :> ISQ::LengthValue;
    attribute def DriveVoltage :> ISQ::ElectricPotentialValue;
    attribute def SamplingDuration :> ISQ::TimeValue;
    
    item def AirSample {
        attribute flowRate : AirFlowRate;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute pressure : ISQ::PressureValue;
        attribute particulateContent : ParticulateMass;
    }
    
    item def FrequencyData {
        attribute frequency : ResonantFrequency;
        attribute timestamp : ISQ::TimeValue;
        attribute amplitude : OscillationAmplitude;
    }
    
    item def MassData {
        attribute concentration : MassConcentration;
        attribute totalMass : ParticulateMass;
        attribute timestamp : ISQ::TimeValue;
    }
    
    port def AirInletPort {
        in item airSample : AirSample;
    }
    
    port def AirOutletPort {
        out item airSample : AirSample;
    }
    
    port def FrequencyMonitorPort {
        out item frequencyData : FrequencyData;
    }
    
    port def DriveSignalPort {
        in attribute driveVoltage : DriveVoltage;
    }
    
    port def DataOutputPort {
        out item massData : MassData;
    }
    
    port def ControlCommandPort {
        in attribute startMeasurement : Boolean;
        in attribute stopMeasurement : Boolean;
        in attribute calibrate : Boolean;
    }
    
    part def TaperedElement {
        attribute baseWidth : ISQ::LengthValue;
        attribute tipWidth : ISQ::LengthValue;
        attribute elementLength : ISQ::LengthValue;
        attribute baseMass : ElementMass;
        attribute naturalFrequency : ResonantFrequency;
        attribute springConstant : Real;
        attribute dampingCoefficient : Real;
        
        port inlet : AirInletPort;
        port outlet : AirOutletPort;
        port driveInput : DriveSignalPort;
        port frequencyOutput : FrequencyMonitorPort;
    }
    
    part def PiezoelectricDriver {
        attribute driveFrequency : ResonantFrequency;
        attribute driveAmplitude : DriveVoltage;
        
        port controlInput : ControlCommandPort;
        port driveOutput : DriveSignalPort;
    }
    
    part def FrequencyDetector {
        attribute measurementResolution : FrequencyShift;
        attribute samplingRate : ISQ::FrequencyValue;
        
        port signalInput : FrequencyMonitorPort;
    }
    
    part def VacuumPump {
        attribute flowCapacity : AirFlowRate;
        attribute operatingPressure : ISQ::PressureValue;
        
        port inlet : AirInletPort;
        port outlet : AirOutletPort;
    }
    
    part def FilterAssembly {
        attribute filterArea : ISQ::AreaValue;
        attribute collectionEfficiency : Real;
        
        port inlet : AirInletPort;
        port outlet : AirOutletPort;
    }
    
    part def TemperatureController {
        attribute setpoint : ISQ::ThermodynamicTemperatureValue;
        attribute controlRange : ISQ::ThermodynamicTemperatureValue;
    }
    
    part def DataProcessor {
        attribute calibrationFactor : Real;
        attribute baselineFrequency : ResonantFrequency;
        
        port frequencyInput : FrequencyMonitorPort;
        port dataOutput : DataOutputPort;
    }
    
    action def InitializeSystem {
        in targetFlowRate : AirFlowRate;
        out baselineFrequency : ResonantFrequency;
        out systemReady : Boolean;
    }
    
    action def DriveOscillation {
        in driveVoltage : DriveVoltage;
        in targetFrequency : ResonantFrequency;
        out actualFrequency : ResonantFrequency;
    }
    
    action def MeasureFrequency {
        out currentFrequency : ResonantFrequency;
        out frequencyStability : Boolean;
    }
    
    action def CalculateParticulateMass {
        in baselineFrequency : ResonantFrequency;
        in measuredFrequency : ResonantFrequency;
        in elementMass : ElementMass;
        out depositedMass : ParticulateMass;
    }
    
    action def ComputeConcentration {
        in depositedMass : ParticulateMass;
        in flowRate : AirFlowRate;
        in samplingTime : SamplingDuration;
        out concentration : MassConcentration;
    }
    
    action def RecordMeasurement {
        in massConcentration : MassConcentration;
        in timestamp : ISQ::TimeValue;
    }
    
    state def OperationalState {
        entry;
        then idle;
        
        state idle;
        state initializing;
        state baseline;
        state sampling;
        state computing;
        
        transition idle_to_initializing
            first idle
            accept StartCommand
            then initializing;
        
        transition initializing_to_baseline
            first initializing
            if initializationComplete
            then baseline;
        
        transition baseline_to_sampling
            first baseline
            if baselineStable
            then sampling;
        
        transition sampling_to_computing
            first sampling
            if samplingComplete
            then computing;
        
        transition computing_to_sampling
            first computing
            if continueSampling
            then sampling;
        
        transition computing_to_idle
            first computing
            accept StopCommand
            then idle;
        
        attribute initializationComplete : Boolean;
        attribute baselineStable : Boolean;
        attribute samplingComplete : Boolean;
        attribute continueSampling : Boolean;
    }
    
    action def PerformContinuousMeasurement {
        in attribute targetFlowRate : AirFlowRate;
        in attribute samplingInterval : SamplingDuration;
        out attribute latestConcentration : MassConcentration;
        
        first start;
        
        then action initialize : InitializeSystem {
            in targetFlowRate = targetFlowRate;
            out baselineFrequency;
            out systemReady;
        }
        
        then merge continuousCycle;
        
        then action driveElement : DriveOscillation {
            in driveVoltage;
            in targetFrequency = initialize.baselineFrequency;
            out actualFrequency;
        }
        
        then action measureFreq : MeasureFrequency {
            out currentFrequency;
            out frequencyStability;
        }
        
        then decide;
            if measureFreq.frequencyStability then calculateMass;
        
        action calculateMass : CalculateParticulateMass {
            in baselineFrequency = initialize.baselineFrequency;
            in measuredFrequency = measureFreq.currentFrequency;
            in elementMass;
            out depositedMass;
        }
        
        then action computeConc : ComputeConcentration {
            in depositedMass = calculateMass.depositedMass;
            in flowRate = targetFlowRate;
            in samplingTime = samplingInterval;
            out concentration;
        }
        
        then action record : RecordMeasurement {
            in massConcentration = computeConc.concentration;
            in timestamp;
        }
        
        then assign latestConcentration := computeConc.concentration;
        
        then continuousCycle;
    }
    
    part teomSystem : TEOMInstrument {
        attribute operatingFlowRate : AirFlowRate;
        attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute measurementResolution : MassConcentration;
        
        part taperedBeam : TaperedElement {
            attribute baseWidth = 200.0e-6 [SI::m];
            attribute tipWidth = 20.0e-6 [SI::m];
            attribute elementLength = 1.0e-3 [SI::m];
            attribute baseMass = 5.0e-6 [SI::kg];
            attribute naturalFrequency = 8000.0 [SI::Hz];
            attribute springConstant = 100.0;
            attribute dampingCoefficient = 0.01;
        }
        
        part filter : FilterAssembly {
            attribute filterArea = 1.0e-4 [SI::'m^2'];
            attribute collectionEfficiency = 0.99;
        }
        
        part driver : PiezoelectricDriver {
            attribute driveFrequency = 8000.0 [SI::Hz];
            attribute driveAmplitude = 5.0 [SI::V];
        }
        
        part detector : FrequencyDetector {
            attribute measurementResolution = 0.01 [SI::Hz];
            attribute samplingRate = 1000.0 [SI::Hz];
        }
        
        part pump : VacuumPump {
            attribute flowCapacity = 20.0 [SI::L/SI::min];
            attribute operatingPressure = 1.0e5 [SI::Pa];
        }
        
        part tempController : TemperatureController {
            attribute setpoint = 323.15 [SI::K];
            attribute controlRange = 1.0 [SI::K];
        }
        
        part processor : DataProcessor {
            attribute calibrationFactor = 1.0;
            attribute baselineFrequency = 8000.0 [SI::Hz];
        }
        
        port airInlet : AirInletPort;
        port airOutlet : AirOutletPort;
        port controlInterface : ControlCommandPort;
        port dataInterface : DataOutputPort;
        
        connect airInlet to pump.inlet;
        connect pump.outlet to filter.inlet;
        connect filter.outlet to taperedBeam.inlet;
        connect taperedBeam.outlet to airOutlet;
        connect driver.driveOutput to taperedBeam.driveInput;
        connect taperedBeam.frequencyOutput to detector.signalInput;
        connect detector.signalInput to processor.frequencyInput;
        connect processor.dataOutput to dataInterface;
        connect controlInterface to driver.controlInput;
        
        perform action measurementCycle : PerformContinuousMeasurement {
            in targetFlowRate = operatingFlowRate;
            in samplingInterval = 60.0 [SI::s];
            out latestConcentration;
        }
        
        exhibit state operationalBehavior : OperationalState;
    }
    
    part def TEOMInstrument {
        doc /*
        A Tapered Element Oscillating Microbalance (TEOM) system continuously measures 
        airborne particulate matter concentration by monitoring the resonant frequency 
        shift of a vibrating tapered element as particulate mass accumulates on its surface.
        
        The primary function is real-time measurement of particulate mass concentration in 
        ambient or source air streams. The system draws air through a filter mounted on a 
        hollow tapered glass element that oscillates at its natural resonant frequency. 
        As particulate matter collects on the filter, the effective mass of the oscillating 
        system increases, causing a measurable decrease in resonant frequency. By precisely 
        tracking this frequency shift and knowing the air flow rate, the system calculates 
        mass concentration continuously with high temporal resolution.
        
        The tapered element design provides high sensitivity to mass changes while maintaining 
        mechanical stability. The system operates at elevated temperature to prevent moisture 
        condensation and ensure accurate mass measurements independent of volatile components.
        */
    }
    
    requirement <'TEOM-REQ-001'> massResolutionRequirement {
        doc /* The system shall achieve a mass resolution of at least 0.1 micrograms. */
        
        subject teomSystem;
    }
    
    requirement <'TEOM-REQ-002'> frequencyStabilityRequirement {
        doc /* The resonant frequency shall be stable to within 0.01 Hz over 60 seconds 
               under constant conditions. */
        
        subject teomSystem.taperedBeam;
    }
    
    requirement <'TEOM-REQ-003'> temperatureControlRequirement {
        doc /* The system shall maintain the tapered element at 50°C ± 1°C to eliminate 
               moisture effects on mass measurements. */
        
        subject teomSystem.tempController;
    }
    
    requirement <'TEOM-REQ-004'> flowRateRequirement {
        doc /* The system shall maintain a constant volumetric flow rate of 16.7 L/min 
               through the tapered element. */
        
        subject teomSystem.pump;
    }
    
    requirement <'TEOM-REQ-005'> collectionEfficiencyRequirement {
        doc /* The filter assembly shall collect particulate matter with at least 99% 
               efficiency for particles larger than 0.1 micrometers. */
        
        subject teomSystem.filter;
    }
    
    requirement <'TEOM-SYS-MISSION'> systemMissionRequirement {
        doc /* The Tapered Element Oscillating Microbalance system shall provide continuous, 
               real-time measurement of airborne particulate mass concentration by detecting 
               resonant frequency shifts in a vibrating tapered element as particulate matter 
               accumulates, enabling high-resolution temporal monitoring of air quality with 
               microgram-level sensitivity. */
        
        subject teomSystem;
        
        require massResolutionRequirement;
        require frequencyStabilityRequirement;
        require temperatureControlRequirement;
        require flowRateRequirement;
        require collectionEfficiencyRequirement;
    }
}
