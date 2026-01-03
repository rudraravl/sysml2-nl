package CryogenicParticleDetectorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def TemperatureValue :> ThermodynamicTemperatureValue;
    attribute def EnergyValue :> ISQ::EnergyValue;
    attribute def VoltageValue :> ElectricPotentialValue;
    attribute def CurrentValue :> ElectricCurrentValue;
    attribute def ResistanceValue :> Real;
    attribute def HeatCapacityValue :> Real;
    attribute def ThermalConductanceValue :> Real;
    attribute def SignalAmplitudeValue :> Real;
    
    enum def ParticleType {
        photon;
        electron;
        neutrino;
        darkMatter;
        neutron;
        alpha;
        unknown;
    }
    
    enum def DetectorMode {
        offline;
        cooldown;
        stabilizing;
        ready;
        acquiring;
        warmup;
        fault;
    }
    
    item def Particle {
        attribute particleType : ParticleType;
        attribute energy : EnergyValue;
        attribute arrivalTime : TimeValue;
    }
    
    item def DetectionEvent {
        attribute particle : Particle;
        attribute signalAmplitude : SignalAmplitudeValue;
        attribute temperatureRise : TemperatureValue;
        attribute baselineTemperature : TemperatureValue;
        attribute timestamp : TimeValue;
        attribute eventID : Integer;
    }
    
    item def ThermalSignal {
        attribute temperature : TemperatureValue;
        attribute heatFlow : PowerValue;
    }
    
    item def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    interface def ThermalInterface {
        in item heatInput : ThermalSignal;
        out attribute temperatureOutput : TemperatureValue;
    }
    
    interface def SensorInterface {
        in attribute thermalInput : TemperatureValue;
        out item electricalOutput : ElectricalSignal;
    }
    
    interface def SignalInterface {
        in item rawSignal : ElectricalSignal;
        out attribute processedSignal : VoltageValue;
    }
    
    interface def DataInterface {
        in item eventData : DetectionEvent;
        out item storedData : DetectionEvent;
    }
    
    interface def ControlInterface {
        in attribute command : DetectorMode;
        out attribute status : DetectorMode;
    }
    
    part def CryogenicAbsorber {
        doc /* Absorbs particle energy and converts it to a measurable temperature rise. */
        
        attribute mass : MassValue;
        attribute specificHeat : HeatCapacityValue;
        attribute baselineTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        attribute thermalTimeConstant : TimeValue;
        
        port thermalPort : ThermalInterface;
        
        assert constraint thermalResponse {
            thermalTimeConstant == mass * specificHeat / 1.0
        }
    }
    
    part def ThermistorSensor {
        doc /* Measures temperature changes in the absorber with high sensitivity. */
        
        attribute resistance : ResistanceValue;
        attribute temperatureCoefficient : Real;
        attribute operatingTemperature : TemperatureValue;
        attribute sensitivity : Real;
        attribute noiseLevel : VoltageValue;
        
        port sensorPort : SensorInterface;
        
        assert constraint operatingRange {
            operatingTemperature <= 0.1 [K]
        }
    }
    
    part def DilutionRefrigerator {
        doc /* Provides continuous cooling to maintain cryogenic temperatures. */
        
        attribute coolingPower : PowerValue;
        attribute baseTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        attribute cooldownTime : TimeValue;
        
        port coldStage : ThermalInterface;
        
        assert constraint coolingCapacity {
            coolingPower >= 100.0 [uW]
        }
    }
    
    part def ThermalLink {
        doc /* Provides weak thermal coupling between absorber and refrigerator. */
        
        attribute thermalConductance : ThermalConductanceValue;
        attribute length : LengthValue;
        attribute crossSection : AreaValue;
        
        port hotEnd : ThermalInterface;
        port coldEnd : ThermalInterface;
    }
    
    part def LowNoiseAmplifier {
        doc /* Amplifies weak electrical signals from the thermistor. */
        
        attribute gain : Real;
        attribute bandwidth : FrequencyValue;
        attribute inputNoiseVoltage : VoltageValue;
        attribute outputImpedance : ResistanceValue;
        
        port inputPort : SignalInterface;
        port outputPort : SignalInterface;
        
        assert constraint noisePerformance {
            inputNoiseVoltage <= 1.0 [nV]
        }
    }
    
    part def DigitalAcquisitionSystem {
        doc /* Digitizes and processes analog signals from the amplifier. */
        
        attribute samplingRate : FrequencyValue;
        attribute resolution : Integer;
        attribute bufferDepth : Integer;
        attribute triggerThreshold : VoltageValue;
        
        port analogInput : SignalInterface;
        port dataOutput : DataInterface;
        
        assert constraint adcPerformance {
            samplingRate >= 1.0 [MHz]
            and resolution >= 16
        }
    }
    
    part def VacuumChamber {
        doc /* Provides thermal isolation and reduces background radiation. */
        
        attribute pressure : Real;
        attribute volume : VolumeValue;
        attribute wallThickness : LengthValue;
        attribute material : String;
        
        assert constraint vacuumLevel {
            pressure <= 1.0e-6
        }
    }
    
    part def RadiationShield {
        doc /* Reduces external radiation background. */
        
        attribute shieldMaterial : String;
        attribute thickness : LengthValue;
        attribute attenuationFactor : Real;
        attribute layers : Integer;
        
        assert constraint shieldingEffectiveness {
            attenuationFactor >= 100.0
        }
    }
    
    part def ControlElectronics {
        doc /* Manages detector operation and monitors system health. */
        
        attribute operatingMode : DetectorMode;
        attribute targetTemperature : TemperatureValue;
        attribute acquisitionEnabled : Boolean;
        
        port controlPort : ControlInterface;
    }
    
    action def CooldownSequence {
        doc /* Cools the detector from room temperature to operating temperature. */
        
        in initialTemperature : TemperatureValue;
        in targetTemperature : TemperatureValue;
        out finalTemperature : TemperatureValue;
        out cooldownComplete : Boolean;
    }
    
    action def StabilizeTemperature {
        doc /* Maintains stable operating temperature. */
        
        in targetTemperature : TemperatureValue;
        in currentTemperature : TemperatureValue;
        out temperatureStable : Boolean;
    }
    
    action def DetectParticleInteraction {
        doc /* Detects and measures particle energy deposition. */
        
        in incomingParticle : Particle;
        out temperatureRise : TemperatureValue;
        out detectionSignal : ElectricalSignal;
    }
    
    action def AmplifySignal {
        doc /* Amplifies the weak thermistor signal. */
        
        in rawSignal : ElectricalSignal;
        in gainSetting : Real;
        out amplifiedSignal : VoltageValue;
    }
    
    action def DigitizeEvent {
        doc /* Converts analog signal to digital event data. */
        
        in analogSignal : VoltageValue;
        in baselineTemperature : TemperatureValue;
        out eventData : DetectionEvent;
    }
    
    action def AnalyzeEvent {
        doc /* Analyzes event data to determine particle properties. */
        
        in eventData : DetectionEvent;
        out particleType : ParticleType;
        out particleEnergy : EnergyValue;
        out validEvent : Boolean;
    }
    
    action def OperateDetector {
        doc /* Main operational sequence for particle detection. */
        
        first start;
        then merge checkMode;
        
        then decide;
            if isOffline then initiateCooldown;
            if isCoolingDown then monitorCooldown;
            if isStabilizing then stabilize;
            if isReady then waitForParticle;
            if isAcquiring then processEvent;
        
        action initiateCooldown : CooldownSequence {
            in initialTemperature = 300.0 [K];
            in targetTemperature = 0.015 [K];
        }
        then checkMode;
        
        action monitorCooldown {
            in currentTemp : TemperatureValue;
            in targetTemp : TemperatureValue;
        }
        then checkMode;
        
        action stabilize : StabilizeTemperature {
            in targetTemperature = 0.015 [K];
            in currentTemperature : TemperatureValue;
        }
        then checkMode;
        
        action waitForParticle {
            in monitoringActive : Boolean;
        }
        then detectInteraction;
        
        action detectInteraction : DetectParticleInteraction {
            in incomingParticle : Particle;
        }
        then amplify;
        
        action amplify : AmplifySignal {
            in rawSignal : ElectricalSignal;
            in gainSetting = 1000.0;
        }
        then digitize;
        
        action digitize : DigitizeEvent {
            in analogSignal : VoltageValue;
            in baselineTemperature = 0.015 [K];
        }
        then analyze;
        
        action analyze : AnalyzeEvent {
            in eventData : DetectionEvent;
        }
        then checkMode;
    }
    
    state def DetectorStateMachine {
        doc /* State machine governing detector operational modes. */
        
        entry; then offline;
        
        state offline {
            doc /* Detector is at room temperature and not operational. */
        }
        transition offline_to_cooldown
            first offline
            accept StartCooldown
            then cooldown;
        
        state cooldown {
            doc /* Detector is being cooled to operating temperature. */
            entry action cool : CooldownSequence;
        }
        transition cooldown_to_stabilizing
            first cooldown
            accept TargetTemperatureReached
            then stabilizing;
        
        state stabilizing {
            doc /* Temperature is stabilizing at operating point. */
            entry action stabilize : StabilizeTemperature;
        }
        transition stabilizing_to_ready
            first stabilizing
            accept TemperatureStable
            then ready;
        
        state ready {
            doc /* Detector is ready to acquire data. */
        }
        transition ready_to_acquiring
            first ready
            accept ParticleDetected
            then acquiring;
        
        state acquiring {
            doc /* Processing a particle detection event. */
            entry action detect : DetectParticleInteraction;
            do action amplify : AmplifySignal;
            do action digitize : DigitizeEvent;
            do action analyze : AnalyzeEvent;
        }
        transition acquiring_to_ready
            first acquiring
            accept EventProcessed
            then ready;
        
        transition ready_to_warmup
            first ready
            accept ShutdownCommand
            then warmup;
        
        state warmup {
            doc /* Detector is warming up to room temperature. */
        }
        transition warmup_to_offline
            first warmup
            accept WarmupComplete
            then offline;
        
        state fault {
            doc /* System has encountered an error condition. */
        }
        transition any_to_fault
            accept FaultDetected
            then fault;
        
        transition fault_to_offline
            first fault
            accept FaultCleared
            then offline;
    }
    
    part def CryogenicParticleDetector {
        doc /* Complete cryogenic particle detector system for rare event searches. */
        
        attribute operatingTemperature : TemperatureValue;
        attribute energyResolution : Real;
        attribute detectionEfficiency : Real;
        attribute backgroundRate : Real;
        attribute totalMass : MassValue;
        attribute operationalMode : DetectorMode;
        
        part absorber : CryogenicAbsorber {
            attribute :>> mass = 250.0 [g];
            attribute :>> specificHeat = 0.15;
            attribute :>> baselineTemperature = 0.015 [K];
            attribute :>> thermalTimeConstant = 100.0 [ms];
        }
        
        part sensor : ThermistorSensor {
            attribute :>> resistance = 10000.0;
            attribute :>> temperatureCoefficient = -0.05;
            attribute :>> operatingTemperature = 0.015 [K];
            attribute :>> sensitivity = 5000.0;
            attribute :>> noiseLevel = 0.5 [nV];
        }
        
        part refrigerator : DilutionRefrigerator {
            attribute :>> coolingPower = 200.0 [uW];
            attribute :>> baseTemperature = 0.010 [K];
            attribute :>> cooldownTime = 48.0 [h];
        }
        
        part thermalLink : ThermalLink {
            attribute :>> thermalConductance = 50.0;
            attribute :>> length = 0.05 [m];
            attribute :>> crossSection = 1.0e-6 [m^2];
        }
        
        part amplifier : LowNoiseAmplifier {
            attribute :>> gain = 1000.0;
            attribute :>> bandwidth = 100.0 [kHz];
            attribute :>> inputNoiseVoltage = 0.8 [nV];
            attribute :>> outputImpedance = 50.0;
        }
        
        part daq : DigitalAcquisitionSystem {
            attribute :>> samplingRate = 2.0 [MHz];
            attribute :>> resolution = 18;
            attribute :>> bufferDepth = 100000;
            attribute :>> triggerThreshold = 10.0 [mV];
        }
        
        part vacuum : VacuumChamber {
            attribute :>> pressure = 1.0e-7;
            attribute :>> volume = 0.5 [m^3];
            attribute :>> wallThickness = 0.01 [m];
            attribute :>> material = "Stainless Steel";
        }
        
        part shield : RadiationShield {
            attribute :>> shieldMaterial = "Lead";
            attribute :>> thickness = 0.15 [m];
            attribute :>> attenuationFactor = 1000.0;
            attribute :>> layers = 3;
        }
        
        part controller : ControlElectronics {
            attribute :>> operatingMode = DetectorMode::offline;
            attribute :>> targetTemperature = 0.015 [K];
            attribute :>> acquisitionEnabled = false;
        }
        
        connection thermalCoupling1 connect absorber.thermalPort to thermalLink.hotEnd;
        connection thermalCoupling2 connect thermalLink.coldEnd to refrigerator.coldStage;
        connection sensorConnection connect sensor.sensorPort to absorber.thermalPort;
        connection signalPath1 connect sensor.sensorPort to amplifier.inputPort;
        connection signalPath2 connect amplifier.outputPort to daq.analogInput;
        
        assert constraint thermalBalance {
            absorber.currentTemperature == refrigerator.currentTemperature + 0.005 [K]
        }
        
        assert constraint energyResolutionConstraint {
            energyResolution <= 0.001
        }
        
        perform action operation : OperateDetector;
        
        exhibit state behavior : DetectorStateMachine;
    }
    
    requirement <'REQ-CPD-001'> primaryDetectionFunction {
        doc /* The cryogenic particle detector shall detect rare particle interactions 
             * by measuring the minute temperature rise produced when a particle deposits 
             * energy in a cryogenic absorber maintained at millikelvin temperatures, 
             * enabling high-resolution calorimetric measurements for dark matter searches, 
             * neutrino physics, and rare decay experiments.
             */
        subject detector : CryogenicParticleDetector;
    }
    
    requirement <'REQ-CPD-002'> operatingTemperatureRequirement {
        doc /* The detector shall maintain an operating temperature at or below 20 mK 
             * to minimize thermal noise and maximize energy resolution.
             */
        subject detector : CryogenicParticleDetector;
        assert constraint {
            detector.operatingTemperature <= 0.020 [K]
        }
    }
    
    requirement <'REQ-CPD-003'> energyResolutionRequirement {
        doc /* The detector shall achieve energy resolution better than 0.1% 
             * to accurately measure particle energies.
             */
        subject detector : CryogenicParticleDetector;
        assert constraint {
            detector.energyResolution <= 0.001
        }
    }
    
    requirement <'REQ-CPD-004'> detectionEfficiencyRequirement {
        doc /* The detector shall maintain detection efficiency greater than 95% 
             * for particles within the target energy range.
             */
        subject detector : CryogenicParticleDetector;
        assert constraint {
            detector.detectionEfficiency >= 0.95
        }
    }
    
    requirement <'REQ-CPD-005'> backgroundRejectionRequirement {
        doc /* The detector shall be shielded to reduce background event rate 
             * to less than 1 event per kg per day.
             */
        subject detector : CryogenicParticleDetector;
        assert constraint {
            detector.backgroundRate <= 1.0
        }
    }
    
    requirement <'REQ-CPD-006'> thermalIsolationRequirement {
        doc /* The vacuum chamber shall maintain pressure below 1e-6 mbar 
             * to ensure adequate thermal isolation.
             */
        subject vacuum : CryogenicParticleDetector::vacuum;
        assert constraint {
            vacuum.pressure <= 1.0e-6
        }
    }
    
    requirement <'REQ-CPD-007'> coolingPowerRequirement {
        doc /* The refrigerator shall provide sufficient cooling power 
             * to maintain stable operating temperature.
             */
        subject refrigerator : CryogenicParticleDetector::refrigerator;
        assert constraint {
            refrigerator.coolingPower >= 100.0 [uW]
        }
    }
    
    part cryogenicDetectorSystem : CryogenicParticleDetector {
        attribute :>> operatingTemperature = 0.015 [K];
        attribute :>> energyResolution = 0.0008;
        attribute :>> detectionEfficiency = 0.97;
        attribute :>> backgroundRate = 0.5;
        attribute :>> totalMass = 300.0 [kg];
        attribute :>> operationalMode = DetectorMode::ready;
    }
    
    satisfy primaryDetectionFunction by cryogenicDetectorSystem;
    satisfy operatingTemperatureRequirement by cryogenicDetectorSystem;
    satisfy energyResolutionRequirement by cryogenicDetectorSystem;
    satisfy detectionEfficiencyRequirement by cryogenicDetectorSystem;
    satisfy backgroundRejectionRequirement by cryogenicDetectorSystem;
    satisfy thermalIsolationRequirement by cryogenicDetectorSystem.vacuum;
    satisfy coolingPowerRequirement by cryogenicDetectorSystem.refrigerator;
}
