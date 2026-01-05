package MetamaterialCloakingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RefractiveIndex :> Real;
    attribute def Permittivity :> Real;
    attribute def Permeability :> Real;
    attribute def ScatteringCrossSection :> AreaValue;
    attribute def PhaseDelay :> Real;
    
    value def WaveBand {
        attribute centerFrequency : FrequencyValue;
        attribute bandwidth : FrequencyValue;
    }
    
    item def ElectromagneticWave {
        attribute frequency : FrequencyValue;
        attribute wavelength : LengthValue;
        attribute amplitude : Real;
        attribute polarization : Real;
        attribute incidentAngle : Real;
        attribute propagationVector : Real[3];
    }
    
    item def MetamaterialCell {
        attribute cellDimensions : LengthValue[3];
        attribute effectivePermittivity : Permittivity;
        attribute effectivePermeability : Permeability;
        attribute refractiveIndex : RefractiveIndex;
        attribute resonantFrequency : FrequencyValue;
    }
    
    attribute def CloakingCommand;
    attribute def ActivateCloak :> CloakingCommand;
    attribute def DeactivateCloak :> CloakingCommand;
    attribute def ReconfigureCloak :> CloakingCommand;
    
    port def WavePort {
        in attribute incidentWave : ElectromagneticWave;
        out attribute transmittedWave : ElectromagneticWave;
    }
    
    port def ControlPort {
        in attribute command : CloakingCommand;
        out attribute status : Real;
    }
    
    port def SensorPort {
        out attribute detectedWave : ElectromagneticWave;
        out attribute environmentalData : Real[*];
    }
    
    part def MetamaterialLayer {
        attribute layerThickness : LengthValue;
        attribute cellCount : Integer;
        attribute gradientProfile : RefractiveIndex[*];
        
        part cells : MetamaterialCell[*] {
            doc /* Array of engineered metamaterial unit cells */
        }
        
        port waveInterface : WavePort;
    }
    
    part def WaveSensor {
        attribute detectionBand : WaveBand;
        attribute sensitivity : Real;
        attribute samplingRate : FrequencyValue;
        
        port sensorOutput : SensorPort;
    }
    
    part def AdaptiveController {
        attribute updateRate : FrequencyValue;
        attribute optimizationAlgorithm : String;
        
        port sensorInput : SensorPort;
        port controlOutput : ControlPort;
        port layerControl {
            out attribute configurationData : Real[*];
        }
    }
    
    part def PowerSupply {
        attribute outputPower : PowerValue;
        attribute efficiency : Real;
        
        port powerOutput {
            out attribute suppliedPower : PowerValue;
        }
    }
    
    part def TargetObject {
        attribute objectSize : LengthValue[3];
        attribute objectMaterial : String;
        attribute baselineScattering : ScatteringCrossSection;
    }
    
    action def SenseIncidentWave {
        in detectionBand : WaveBand;
        out detectedWave : ElectromagneticWave;
        out waveCharacteristics : Real[*];
    }
    
    action def ComputeOptimalConfiguration {
        in incidentWave : ElectromagneticWave;
        in targetReduction : Real;
        out layerPermittivities : Permittivity[*];
        out layerPermeabilities : Permeability[*];
        out phaseDelays : PhaseDelay[*];
    }
    
    action def ApplyConfiguration {
        in permittivities : Permittivity[*];
        in permeabilities : Permeability[*];
        out configurationApplied : Boolean;
    }
    
    action def BendWaveAroundObject {
        in incidentWave : ElectromagneticWave;
        in metamaterialConfig : Real[*];
        out redirectedWave : ElectromagneticWave;
        out exitingWave : ElectromagneticWave;
    }
    
    action def MeasureCloakingEffectiveness {
        in baselineScattering : ScatteringCrossSection;
        in currentScattering : ScatteringCrossSection;
        out reductionFactor : Real;
    }
    
    attribute def CalibrationComplete;
    attribute def WaveDetected;
    attribute def ConfigurationReady;
    attribute def CloakingActive;
    attribute def PerformanceDegraded;
    attribute def AdaptationComplete;
    
    action def PerformCloaking {
        doc /* 
            Primary cloaking operation: continuously sense electromagnetic environment,
            compute optimal metamaterial configuration, and redirect waves around target
        */
        
        first start;
        then merge operationLoop;
        
        then action sense : SenseIncidentWave {
            in detectionBand : WaveBand;
            out detectedWave : ElectromagneticWave;
            out waveCharacteristics : Real[*];
        }
        
        then action compute : ComputeOptimalConfiguration {
            in incidentWave = sense.detectedWave;
            in targetReduction = 0.95;
            out layerPermittivities : Permittivity[*];
            out layerPermeabilities : Permeability[*];
            out phaseDelays : PhaseDelay[*];
        }
        
        then action apply : ApplyConfiguration {
            in permittivities = compute.layerPermittivities;
            in permeabilities = compute.layerPermeabilities;
            out configurationApplied : Boolean;
        }
        
        then action redirect : BendWaveAroundObject {
            in incidentWave = sense.detectedWave;
            in metamaterialConfig : Real[*];
            out redirectedWave : ElectromagneticWave;
            out exitingWave : ElectromagneticWave;
        }
        
        then action measure : MeasureCloakingEffectiveness {
            in baselineScattering : ScatteringCrossSection;
            in currentScattering : ScatteringCrossSection;
            out reductionFactor : Real;
        }
        
        then decide;
            if measure.reductionFactor >= 0.90 then maintainConfig;
            if measure.reductionFactor < 0.90 then reconfigure;
        
        action maintainConfig {
            doc /* Continue with current configuration */
        }
        then operationLoop;
        
        action reconfigure {
            doc /* Recompute configuration for better performance */
        }
        then operationLoop;
    }
    
    state def CloakingSystemStates {
        entry; then standby;
        
        state standby {
            doc /* System powered but not actively cloaking */
        }
        
        transition standby_to_initializing
            first standby
            accept activateCommand : ActivateCloak
            then initializing;
        
        state initializing {
            doc /* Calibrating sensors and metamaterial layers */
        }
        
        transition initializing_to_sensing
            first initializing
            accept calibrationDone : CalibrationComplete
            then sensing;
        
        state sensing {
            doc /* Monitoring electromagnetic environment */
        }
        
        transition sensing_to_computing
            first sensing
            accept waveFound : WaveDetected
            then computing;
        
        state computing {
            doc /* Calculating optimal metamaterial configuration */
        }
        
        transition computing_to_activeCloaking
            first computing
            accept configReady : ConfigurationReady
            then activeCloaking;
        
        state activeCloaking {
            doc /* Actively redirecting electromagnetic waves */
        }
        
        transition activeCloaking_to_monitoring
            first activeCloaking
            accept cloakActive : CloakingActive
            then monitoring;
        
        state monitoring {
            doc /* Continuously monitoring cloaking performance */
        }
        
        transition monitoring_to_adapting
            first monitoring
            accept perfDegraded : PerformanceDegraded
            then adapting;
        
        transition monitoring_to_standby
            first monitoring
            accept deactivateCommand : DeactivateCloak
            then standby;
        
        state adapting {
            doc /* Adjusting configuration for optimal performance */
        }
        
        transition adapting_to_activeCloaking
            first adapting
            accept adaptDone : AdaptationComplete
            then activeCloaking;
    }
    
    part def CloakingSystem {
        attribute operatingBand : WaveBand;
        attribute targetCloakingEfficiency : Real;
        attribute maxObjectDimension : LengthValue;
        
        part target : TargetObject;
        part innerLayers : MetamaterialLayer[6];
        part outerLayers : MetamaterialLayer[4];
        part sensors : WaveSensor[8];
        part controller : AdaptiveController;
        part power : PowerSupply;
    }
    
    part cloakingSystem : CloakingSystem {
        doc /* 
            Metamaterial cloaking system that manipulates electromagnetic wave propagation
            to render objects invisible by guiding incident waves around a target object
            using engineered metamaterial structures with tailored refractive properties.
            The system achieves cloaking by creating a coordinate transformation in 
            electromagnetic space, causing waves to flow smoothly around the concealed
            object and reconverge on the opposite side with minimal disturbance.
        */
        
        attribute :>> operatingBand : WaveBand {
            centerFrequency = 10.0 [SI::GHz];
            bandwidth = 4.0 [SI::GHz];
        }
        attribute :>> targetCloakingEfficiency : Real = 0.95;
        attribute :>> maxObjectDimension : LengthValue = 0.5 [SI::m];
        
        part :>> target : TargetObject {
            doc /* Object to be concealed from electromagnetic detection */
            objectSize = (0.3 [SI::m], 0.3 [SI::m], 0.4 [SI::m]);
            objectMaterial = "Metallic";
            baselineScattering = 0.25 [SI::m^2];
        }
        
        part :>> innerLayers : MetamaterialLayer[6] {
            doc /* Inner gradient-index layers for wave bending */
            layerThickness = 0.015 [SI::m];
            cellCount = 144;
        }
        
        part :>> outerLayers : MetamaterialLayer[4] {
            doc /* Outer impedance-matching layers */
            layerThickness = 0.010 [SI::m];
            cellCount = 96;
        }
        
        part :>> sensors : WaveSensor[8] {
            doc /* Distributed sensors for omnidirectional wave detection */
            detectionBand = operatingBand;
            sensitivity = 0.001;
            samplingRate = 1.0 [SI::kHz];
        }
        
        part :>> controller : AdaptiveController {
            doc /* Real-time adaptive control system */
            updateRate = 100.0 [SI::Hz];
            optimizationAlgorithm = "Gradient Descent";
        }
        
        part :>> power : PowerSupply {
            doc /* Power supply for active tuning elements */
            outputPower = 250.0 [SI::W];
            efficiency = 0.88;
        }
        
        perform action cloakingOperation : PerformCloaking;
        
        exhibit state systemBehavior : CloakingSystemStates;
        
        connection sensorToController
            connect sensors.sensorOutput to controller.sensorInput;
        
        connection controllerToInnerLayers
            connect controller.layerControl to innerLayers;
        
        connection controllerToOuterLayers
            connect controller.layerControl to outerLayers;
        
        connection powerToController
            connect power.powerOutput to controller;
        
        connection powerToLayers
            connect power.powerOutput to innerLayers;
    }
    
    requirement def CloakingPerformanceRequirement {
        doc /* Performance requirements for electromagnetic cloaking */
        
        subject system : CloakingSystem;
        
        require constraint scatteringReduction {
            doc /* System shall reduce radar cross-section by at least 90% */
            system.targetCloakingEfficiency >= 0.90
        }
        
        require constraint operatingFrequencyRange {
            doc /* System shall operate across specified frequency band */
            system.operatingBand.centerFrequency >= 8.0 [SI::GHz] and
            system.operatingBand.centerFrequency <= 12.0 [SI::GHz]
        }
        
        require constraint adaptationSpeed {
            doc /* System shall adapt to changing conditions within 50 ms */
        }
        
        require constraint powerConsumption {
            doc /* System power consumption shall not exceed 300 W */
        }
    }
    
    requirement def PhysicalDesignRequirement {
        doc /* Physical design and material constraints */
        
        require constraint layerThicknessLimit {
            doc /* Each metamaterial layer shall be subwavelength thickness */
        }
        
        require constraint refractiveIndexRange {
            doc /* Metamaterial shall achieve negative refractive index -3.0 to -0.3 */
        }
        
        require constraint mechanicalStability {
            doc /* Structure shall maintain electromagnetic properties under vibration */
        }
        
        require constraint thermalStability {
            doc /* Properties shall remain stable from -40°C to +85°C */
        }
    }
    
    requirement <'CLK-SYS-001'> primaryCloakingRequirement {
        doc /* 
            The metamaterial cloaking system shall render objects electromagnetically
            invisible by manipulating the propagation of incident electromagnetic waves
            through engineered metamaterial structures. The system guides waves smoothly
            around the concealed object using gradient refractive index profiles and
            reconstitutes the wavefront on the exit side, creating the electromagnetic
            equivalent of empty space and preventing detection by radar or other
            electromagnetic sensors.
        */
        
        subject cloakingSystem;
        
        assume constraint incidentWaveAssumption {
            doc /* Incident waves are within system operating frequency band */
        }
        
        assume constraint environmentalAssumption {
            doc /* System operates in controlled electromagnetic environment */
        }
        
        require performanceReq : CloakingPerformanceRequirement {
            subject system = cloakingSystem;
        }
        
        require designReq : PhysicalDesignRequirement;
    }
}
