package WireChamberDetectorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VoltageValue :> Real;
    attribute def CurrentValue :> Real;
    attribute def PositionValue :> Real;
    attribute def TimeValue :> Real;
    attribute def EnergyValue :> Real;
    attribute def PressureValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def FrequencyValue :> Real;
    
    enum def GasMixtureType {
        argonCO2_90_10;
        argonMethane_80_20;
        argonIsobutane_70_30;
    }
    
    enum def OperationalState {
        standby;
        armed;
        detecting;
        processing;
        readout;
    }
    
    item def ChargedParticle {
        attribute energy : EnergyValue;
        attribute charge : Real;
        attribute trajectory : PositionValue[3];
        attribute entryTime : TimeValue;
    }
    
    item def IonizationPair {
        attribute electronPosition : PositionValue[3];
        attribute ionPosition : PositionValue[3];
        attribute creationTime : TimeValue;
    }
    
    item def ElectronCluster {
        attribute driftTime : TimeValue;
        attribute arrivalPosition : PositionValue[3];
        attribute clusterSize : Integer;
    }
    
    item def DetectorSignal {
        attribute amplitude : VoltageValue;
        attribute risetime : TimeValue;
        attribute timestamp : TimeValue;
        attribute wireNumber : Integer;
    }
    
    item def EventData {
        attribute hitPositions : PositionValue[*];
        attribute hitTimes : TimeValue[*];
        attribute totalCharge : Real;
        attribute eventNumber : Integer;
    }
    
    part def AnodeWire {
        attribute wireNumber : Integer;
        attribute wireDiameter : PositionValue;
        attribute wirePosition : PositionValue[3];
        attribute appliedVoltage : VoltageValue;
        attribute wireLength : PositionValue;
        
        port signalOut {
            out current : CurrentValue;
            out detectionTime : TimeValue;
        }
        
        port hvIn {
            in voltage : VoltageValue;
        }
    }
    
    part def CathodePlane {
        attribute planePosition : PositionValue;
        attribute planeArea : PositionValue;
        attribute groundVoltage : VoltageValue;
        
        port hvIn {
            in voltage : VoltageValue;
        }
    }
    
    part def GasChamber {
        attribute volume : PositionValue;
        attribute gasMixture : GasMixtureType;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute driftVelocity : Real;
        attribute driftField : VoltageValue;
        
        port particleEntry {
            in particle : ChargedParticle;
        }
        
        port ionizationOut {
            out ionPairs : IonizationPair[*];
        }
        
        port gasSupply {
            in flowRate : Real;
        }
    }
    
    part def HighVoltageModule {
        attribute nominalVoltage : VoltageValue;
        attribute maxCurrent : CurrentValue;
        attribute voltageStability : Real;
        attribute ripple : VoltageValue;
        
        port hvOutput {
            out voltage : VoltageValue;
            out current : CurrentValue;
        }
        
        port control {
            in setVoltage : VoltageValue;
            in enable : Boolean;
        }
    }
    
    part def ChargeAmplifier {
        attribute gain : Real;
        attribute bandwidth : FrequencyValue;
        attribute noiseLevel : VoltageValue;
        attribute inputImpedance : Real;
        
        port signalIn {
            in rawCurrent : CurrentValue;
        }
        
        port signalOut {
            out amplifiedVoltage : VoltageValue;
        }
    }
    
    part def Discriminator {
        attribute threshold : VoltageValue;
        attribute hysteresis : VoltageValue;
        attribute deadTime : TimeValue;
        
        port analogIn {
            in signal : VoltageValue;
        }
        
        port digitalOut {
            out pulseDetected : Boolean;
            out pulseTime : TimeValue;
            out pulseAmplitude : VoltageValue;
        }
    }
    
    part def TimeDigitizer {
        attribute timeResolution : TimeValue;
        attribute numberOfChannels : Integer;
        attribute maxCountRate : FrequencyValue;
        attribute bufferDepth : Integer;
        
        port pulseIn {
            in detected : Boolean;
            in time : TimeValue;
            in amplitude : VoltageValue;
            in channel : Integer;
        }
        
        port dataOut {
            out digitalTime : Integer;
            out digitalAmplitude : Integer;
            out channelID : Integer;
        }
    }
    
    part def DataAcquisition {
        attribute eventBufferSize : Integer;
        attribute acquisitionRate : FrequencyValue;
        attribute triggerMode : Integer;
        
        port digitizedIn {
            in time : Integer;
            in amplitude : Integer;
            in channel : Integer;
        }
        
        port eventOut {
            out eventData : EventData;
        }
        
        port control {
            in startAcquisition : Boolean;
            in stopAcquisition : Boolean;
        }
    }
    
    part def GasFlowController {
        attribute targetFlowRate : Real;
        attribute targetPressure : PressureValue;
        attribute gasMixture : GasMixtureType;
        
        port gasOut {
            out flowRate : Real;
            out pressure : PressureValue;
        }
        
        port control {
            in setFlowRate : Real;
            in setPressure : PressureValue;
        }
    }
    
    action def IonizeGas {
        in particle : ChargedParticle;
        in gasProperties : GasMixtureType;
        in gasPressure : PressureValue;
        out ionPairs : IonizationPair[*];
    }
    
    action def DriftElectrons {
        in ionPairs : IonizationPair[*];
        in driftField : VoltageValue;
        in driftVelocity : Real;
        out electronClusters : ElectronCluster[*];
    }
    
    action def MultiplyCharge {
        in electronClusters : ElectronCluster[*];
        in wireVoltage : VoltageValue;
        out avalancheCharge : Real;
    }
    
    action def GenerateSignal {
        in avalancheCharge : Real;
        in wireNumber : Integer;
        out signal : DetectorSignal;
    }
    
    action def AmplifySignal {
        in rawSignal : DetectorSignal;
        in gain : Real;
        out amplifiedSignal : DetectorSignal;
    }
    
    action def DiscriminateSignal {
        in amplifiedSignal : DetectorSignal;
        in threshold : VoltageValue;
        out validPulse : Boolean;
        out pulseData : DetectorSignal;
    }
    
    action def DigitizeEvent {
        in pulseData : DetectorSignal;
        in resolution : TimeValue;
        out digitalData : Integer[*];
    }
    
    action def ReconstructEvent {
        in digitalData : Integer[*];
        in wirePositions : PositionValue[*];
        out eventData : EventData;
    }
    
    part def WireChamber {
        attribute chamberWidth : PositionValue;
        attribute chamberHeight : PositionValue;
        attribute chamberDepth : PositionValue;
        attribute numberOfWires : Integer;
        attribute wireSpacing : PositionValue;
        attribute operatingVoltage : VoltageValue;
        attribute detectionEfficiency : Real;
        attribute spatialResolution : PositionValue;
        attribute timeResolution : TimeValue;
        attribute maxCountRate : FrequencyValue;
        attribute currentState : OperationalState;
        
        part gasChamber : GasChamber {
            attribute :>> gasMixture = GasMixtureType::argonCO2_90_10;
            attribute :>> pressure = 101325.0;
            attribute :>> temperature = 293.15;
            attribute :>> driftVelocity = 50000.0;
            attribute :>> driftField = 1000.0;
        }
        
        part anodeWires : AnodeWire[128] {
            attribute :>> wireDiameter = 0.00002;
            attribute :>> wireSpacing = 0.002;
            attribute :>> wireLength = 0.1;
        }
        
        part cathodePlanes : CathodePlane[2] {
            attribute :>> groundVoltage = 0.0;
        }
        
        part hvModule : HighVoltageModule {
            attribute :>> nominalVoltage = 2800.0;
            attribute :>> maxCurrent = 0.002;
            attribute :>> voltageStability = 0.001;
            attribute :>> ripple = 0.001;
        }
        
        part amplifiers : ChargeAmplifier[128] {
            attribute :>> gain = 200.0;
            attribute :>> bandwidth = 100000000.0;
            attribute :>> noiseLevel = 0.002;
        }
        
        part discriminators : Discriminator[128] {
            attribute :>> threshold = 0.05;
            attribute :>> hysteresis = 0.005;
            attribute :>> deadTime = 0.00000001;
        }
        
        part tdc : TimeDigitizer {
            attribute :>> timeResolution = 0.0000000005;
            attribute :>> numberOfChannels = 128;
            attribute :>> maxCountRate = 1000000.0;
            attribute :>> bufferDepth = 4096;
        }
        
        part daq : DataAcquisition {
            attribute :>> eventBufferSize = 10000;
            attribute :>> acquisitionRate = 10000.0;
        }
        
        part gasController : GasFlowController {
            attribute :>> targetFlowRate = 5.0;
            attribute :>> targetPressure = 101325.0;
            attribute :>> gasMixture = GasMixtureType::argonCO2_90_10;
        }
        
        connect gasController.gasOut to gasChamber.gasSupply;
        connect hvModule.hvOutput to anodeWires.hvIn;
        connect hvModule.hvOutput to cathodePlanes.hvIn;
        connect anodeWires.signalOut to amplifiers.signalIn;
        connect amplifiers.signalOut to discriminators.analogIn;
        connect discriminators.digitalOut to tdc.pulseIn;
        connect tdc.dataOut to daq.digitizedIn;
        
        perform action detectAndMeasure : DetectAndMeasureParticle;
    }
    
    action def DetectAndMeasureParticle {
        first start;
        then merge waitForParticle;
        
        action waitForParticle {
            doc /* Monitor chamber volume for incoming charged particle */
        }
        then particleEnters;
        
        action particleEnters {
            doc /* Charged particle enters the gas chamber volume */
            out particle : ChargedParticle;
        }
        then ionizeGas;
        
        action ionizeGas : IonizeGas {
            doc /* Particle ionizes gas atoms creating electron-ion pairs along trajectory */
            in particle = particleEnters.particle;
        }
        then driftElectrons;
        
        action driftElectrons : DriftElectrons {
            doc /* Electrons drift toward anode wires under applied electric field */
            in ionPairs = ionizeGas.ionPairs;
        }
        then avalancheMultiplication;
        
        action avalancheMultiplication : MultiplyCharge {
            doc /* Electrons undergo avalanche multiplication near anode wire surface */
            in electronClusters = driftElectrons.electronClusters;
        }
        then induceSignal;
        
        action induceSignal : GenerateSignal {
            doc /* Avalanche charge induces electrical signal on anode wire */
            in avalancheCharge = avalancheMultiplication.avalancheCharge;
        }
        then amplifySignal;
        
        action amplifySignal : AmplifySignal {
            doc /* Charge-sensitive amplifier amplifies the induced signal */
            in rawSignal = induceSignal.signal;
        }
        then discriminateSignal;
        
        action discriminateSignal : DiscriminateSignal {
            doc /* Discriminator filters noise and validates signal above threshold */
            in amplifiedSignal = amplifySignal.amplifiedSignal;
        }
        then digitizeEvent;
        
        action digitizeEvent : DigitizeEvent {
            doc /* Time digitizer converts analog timing to digital values */
            in pulseData = discriminateSignal.pulseData;
        }
        then reconstructEvent;
        
        action reconstructEvent : ReconstructEvent {
            doc /* Reconstruct particle trajectory from wire hit positions and times */
            in digitalData = digitizeEvent.digitalData;
            out eventData : EventData;
        }
        then outputEvent;
        
        action outputEvent {
            doc /* Output reconstructed event data for analysis */
            in data : EventData = reconstructEvent.eventData;
        }
        then decide;
            if continuousMode then waitForParticle;
            if acquisitionComplete then done;
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    
    requirement <'REQ-WC-001'> primaryDetectionFunction : FunctionalRequirement {
        doc /* The wire chamber system shall detect charged particles passing through 
             * the detector volume and measure their spatial positions and arrival times 
             * by ionizing gas, drifting electrons to anode wires, amplifying the induced 
             * charge signals, and digitizing the timing information.
             */
        subject chamber : WireChamber;
        
        assume constraint gasQuality {
            doc /* Gas mixture must be pure and properly regulated */
            chamber.gasChamber.gasMixture == GasMixtureType::argonCO2_90_10 and
            chamber.gasChamber.pressure == 101325.0
        }
        
        assume constraint hvStability {
            doc /* High voltage must be stable and within operating range */
            chamber.hvModule.voltageStability <= 0.01 and
            chamber.hvModule.nominalVoltage >= 2500.0 and
            chamber.hvModule.nominalVoltage <= 3500.0
        }
    }
    
    requirement <'REQ-WC-002'> spatialResolutionRequirement : PerformanceRequirement {
        doc /* The wire chamber shall achieve spatial resolution better than 500 micrometers 
             * in the direction perpendicular to the anode wires.
             */
        subject chamber : WireChamber;
        
        require constraint {
            chamber.spatialResolution <= 0.0005
        }
    }
    
    requirement <'REQ-WC-003'> timeResolutionRequirement : PerformanceRequirement {
        doc /* The wire chamber shall achieve time resolution better than 5 nanoseconds 
             * for determining particle arrival time.
             */
        subject chamber : WireChamber;
        
        require constraint {
            chamber.timeResolution <= 0.000000005
        }
    }
    
    requirement <'REQ-WC-004'> detectionEfficiencyRequirement : PerformanceRequirement {
        doc /* The wire chamber shall maintain detection efficiency greater than 95% 
             * for minimum ionizing particles.
             */
        subject chamber : WireChamber;
        
        require constraint {
            chamber.detectionEfficiency >= 0.95
        }
    }
    
    requirement <'REQ-WC-005'> countRateRequirement : PerformanceRequirement {
        doc /* The wire chamber shall support maximum count rates up to 1 MHz 
             * without significant deadtime losses.
             */
        subject chamber : WireChamber;
        
        require constraint {
            chamber.maxCountRate >= 1000000.0
        }
    }
    
    requirement <'REQ-WC-006'> voltageOperatingRange : SafetyRequirement {
        doc /* The wire chamber shall operate within safe high voltage limits 
             * to prevent discharge and ensure stable gas amplification.
             */
        subject chamber : WireChamber;
        
        require constraint {
            chamber.operatingVoltage >= 2500.0 and
            chamber.operatingVoltage <= 3500.0
        }
    }
    
    part wireChamberDetector : WireChamber {
        attribute :>> chamberWidth = 0.256;
        attribute :>> chamberHeight = 0.256;
        attribute :>> chamberDepth = 0.02;
        attribute :>> numberOfWires = 128;
        attribute :>> wireSpacing = 0.002;
        attribute :>> operatingVoltage = 2800.0;
        attribute :>> detectionEfficiency = 0.98;
        attribute :>> spatialResolution = 0.0004;
        attribute :>> timeResolution = 0.000000003;
        attribute :>> maxCountRate = 1500000.0;
    }
    
    satisfy primaryDetectionFunction by wireChamberDetector;
    satisfy spatialResolutionRequirement by wireChamberDetector;
    satisfy timeResolutionRequirement by wireChamberDetector;
    satisfy detectionEfficiencyRequirement by wireChamberDetector;
    satisfy countRateRequirement by wireChamberDetector;
    satisfy voltageOperatingRange by wireChamberDetector;
}
