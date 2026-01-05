package DiathermySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PowerLevel :> Real;
    attribute def TemperatureReading :> ISQ::ThermodynamicTemperatureValue;
    attribute def ImpedanceReading :> ISQ::ResistanceValue;
    attribute def FrequencyValue :> ISQ::FrequencyValue;
    
    enum def TreatmentMode {
        continuous;
        pulsed;
        shortwave;
        microwave;
    }
    
    enum def SystemState {
        idle;
        warmup;
        active;
        fault;
        shutdown;
    }
    
    item def ElectromagneticEnergy {
        attribute frequency : FrequencyValue;
        attribute power : ISQ::PowerValue;
        attribute voltage : ISQ::ElectricPotentialValue;
    }
    
    item def ThermalEnergy {
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute heatFlux : ISQ::HeatFlowRateValue;
    }
    
    port def PowerInputPort {
        in item electricalPower : ElectromagneticEnergy;
    }
    
    port def EMOutputPort {
        out item emEnergy : ElectromagneticEnergy;
    }
    
    port def TissueInterfacePort {
        out item thermalOutput : ThermalEnergy;
        in attribute tissueImpedance : ImpedanceReading;
        in attribute tissueTemperature : TemperatureReading;
    }
    
    port def ControlPort {
        in attribute powerLevel : PowerLevel;
        in attribute mode : TreatmentMode;
        out attribute systemStatus : SystemState;
        out attribute currentTemp : TemperatureReading;
    }
    
    part def RFGenerator {
        port powerIn : PowerInputPort;
        port emOut : EMOutputPort;
        port control : ControlPort;
        
        attribute operatingFrequency : FrequencyValue;
        attribute maxPowerOutput : ISQ::PowerValue;
        attribute currentPowerOutput : ISQ::PowerValue;
        attribute efficiency : Real;
        
        action def GenerateEMField {
            in powerSetting : PowerLevel;
            in frequency : FrequencyValue;
            in operatingMode : TreatmentMode;
            out emOutput : ElectromagneticEnergy;
        }
    }
    
    part def Applicator {
        port emIn : EMOutputPort;
        port tissueInterface : TissueInterfacePort;
        
        attribute applicatorType : String;
        attribute effectiveArea : ISQ::AreaValue;
        attribute penetrationDepth : ISQ::LengthValue;
        
        action def DeliverEnergy {
            in emEnergy : ElectromagneticEnergy;
            in tissueProperties : ImpedanceReading;
            out thermalEnergy : ThermalEnergy;
        }
    }
    
    part def TemperatureSensor {
        port tissueSense : TissueInterfacePort;
        port feedback : ControlPort;
        
        attribute maxSafeTemperature : TemperatureReading;
        attribute currentTemperature : TemperatureReading;
        attribute samplingRate : ISQ::FrequencyValue;
        
        action def MeasureTemperature {
            in tissueTemp : TemperatureReading;
            out tempReading : TemperatureReading;
            out overheatingDetected : Boolean;
        }
    }
    
    part def ImpedanceMonitor {
        port tissueMonitor : TissueInterfacePort;
        port safetyFeedback : ControlPort;
        
        attribute impedanceThreshold : ImpedanceReading;
        attribute currentImpedance : ImpedanceReading;
        
        action def MonitorImpedance {
            in tissueImpedance : ImpedanceReading;
            out impedanceStatus : Boolean;
            out contactQuality : Real;
        }
    }
    
    part def SafetyInterlock {
        port monitorInput : ControlPort;
        port systemControl : ControlPort;
        
        attribute emergencyStopActive : Boolean;
        attribute timerDuration : ISQ::TimeValue;
        attribute treatmentTimeElapsed : ISQ::TimeValue;
        
        action def EvaluateSafety {
            in temperature : TemperatureReading;
            in impedance : ImpedanceReading;
            in timeElapsed : ISQ::TimeValue;
            out safeToOperate : Boolean;
        }
    }
    
    part def ControlUnit {
        port userInterface : ControlPort;
        port generatorControl : ControlPort;
        port safetyControl : ControlPort;
        
        attribute selectedMode : TreatmentMode;
        attribute selectedPower : PowerLevel;
        attribute currentState : SystemState;
        attribute treatmentDuration : ISQ::TimeValue;
        
        perform action manageTreatment : ManageDiathermyTreatment;
    }
    
    part def CoolingSystem {
        port applicatorCooling : TissueInterfacePort;
        
        attribute coolantFlowRate : ISQ::VolumeFlowRateValue;
        attribute coolantTemperature : TemperatureReading;
        
        action def RegulateTemperature {
            in surfaceTemp : TemperatureReading;
            out coolingPower : ISQ::PowerValue;
        }
    }
    
    action def MonitorTissueConditions {
        in impedance : ImpedanceReading;
        in temperature : TemperatureReading;
        out impedanceOK : Boolean;
        out temperatureOK : Boolean;
    }
    
    action def AdjustPowerOutput {
        in currentPower : ISQ::PowerValue;
        in targetTemperature : TemperatureReading;
        in measuredTemperature : TemperatureReading;
        out adjustedPower : ISQ::PowerValue;
    }
    
    action def DeliverTherapeuticHeat {
        in emEnergy : ElectromagneticEnergy;
        in tissueDepth : ISQ::LengthValue;
        in tissueImpedance : ImpedanceReading;
        out thermalEffect : ThermalEnergy;
    }
    
    action def ManageDiathermyTreatment {
        in powerSetting : PowerLevel;
        in treatmentMode : TreatmentMode;
        in targetDuration : ISQ::TimeValue;
        out tissueHeating : ThermalEnergy;
        
        private attribute elapsedTime : ISQ::TimeValue := 0.0;
        private attribute currentTemp : TemperatureReading;
        private attribute currentImpedance : ImpedanceReading;
        private attribute safetyStatus : Boolean := true;
        
        first start;
        then merge treatmentLoop;
        
        then action monitorConditions : MonitorTissueConditions {
            in impedance = currentImpedance;
            in temperature = currentTemp;
            out impedanceOK : Boolean;
            out temperatureOK : Boolean;
        }
        
        then decide;
            if monitorConditions.impedanceOK and monitorConditions.temperatureOK and safetyStatus then deliverEnergy;
            if not monitorConditions.impedanceOK or not monitorConditions.temperatureOK or not safetyStatus then adjustParameters;
        
        action deliverEnergy : DeliverTherapeuticHeat {
            in emEnergy : ElectromagneticEnergy;
            in tissueDepth : ISQ::LengthValue;
            in tissueImpedance = currentImpedance;
            out thermalEffect = tissueHeating;
        }
        then assign elapsedTime := elapsedTime + 1.0;
        then decide;
            if elapsedTime < targetDuration then treatmentLoop;
            if elapsedTime >= targetDuration then endTreatment;
        
        action adjustParameters : AdjustPowerOutput {
            in currentPower : ISQ::PowerValue;
            in targetTemperature : TemperatureReading;
            in measuredTemperature = currentTemp;
            out adjustedPower : ISQ::PowerValue;
        }
        then treatmentLoop;
        
        action endTreatment;
        then done;
    }
    
    part def DiathermyTherapySystem {
        attribute operatingFrequencyRange : FrequencyValue[2];
        attribute maxTreatmentDuration : ISQ::TimeValue;
        attribute powerRange : ISQ::PowerValue[2];
        attribute safetyStandard : String;
    }
    
    part diathermyDevice : DiathermyTherapySystem {
        doc /* 
            A medical diathermy system that converts high-frequency electromagnetic 
            energy into controlled deep tissue heating for therapeutic purposes, 
            including pain relief, improved circulation, and tissue healing through 
            the application of shortwave or microwave radiation.
        */
        
        perform action therapeuticTreatment : ManageDiathermyTreatment {
            in powerSetting : PowerLevel;
            in treatmentMode : TreatmentMode;
            in targetDuration : ISQ::TimeValue;
            out tissueHeating : ThermalEnergy;
        }
        
        part rfGenerator : RFGenerator {
            attribute operatingFrequency = 27.12 [MHz];
            attribute maxPowerOutput = 400.0 [W];
            perform therapeuticTreatment.deliverEnergy;
        }
        
        part applicator : Applicator {
            attribute applicatorType = "Capacitive Plate";
            attribute effectiveArea = 150.0 [cm^2];
            attribute penetrationDepth = 3.0 [cm];
            perform therapeuticTreatment.deliverEnergy;
        }
        
        part temperatureSensor : TemperatureSensor {
            attribute maxSafeTemperature = 45.0 [Celsius];
            attribute samplingRate = 10.0 [Hz];
            perform therapeuticTreatment.monitorConditions;
        }
        
        part impedanceMonitor : ImpedanceMonitor {
            attribute impedanceThreshold = 500.0 [ohm];
            perform therapeuticTreatment.monitorConditions;
        }
        
        part safetyInterlock : SafetyInterlock {
            attribute timerDuration = 1800.0 [s];
        }
        
        part controlUnit : ControlUnit {
            attribute selectedMode = TreatmentMode::continuous;
            attribute selectedPower = 50.0;
            attribute treatmentDuration = 1200.0 [s];
            perform therapeuticTreatment;
        }
        
        part coolingSystem : CoolingSystem {
            attribute coolantFlowRate = 2.0 [L/min];
            attribute coolantTemperature = 20.0 [Celsius];
        }
        
        connection powerDelivery connect rfGenerator.emOut to applicator.emIn;
        connection tissueMonitoring connect applicator.tissueInterface to temperatureSensor.tissueSense;
        connection impedanceMonitoring connect applicator.tissueInterface to impedanceMonitor.tissueMonitor;
        connection generatorControl connect controlUnit.generatorControl to rfGenerator.control;
        connection safetyMonitoring connect controlUnit.safetyControl to safetyInterlock.systemControl;
        connection temperatureFeedback connect temperatureSensor.feedback to controlUnit.userInterface;
        connection impedanceFeedback connect impedanceMonitor.safetyFeedback to safetyInterlock.monitorInput;
        connection surfaceCooling connect coolingSystem.applicatorCooling to applicator.tissueInterface;
    }
    
    requirement def TherapeuticEffectivenessRequirement {
        doc /* Requirements for achieving therapeutic tissue heating */
    }
    
    requirement def SafetyRequirement {
        doc /* Safety requirements for patient protection during diathermy */
    }
    
    requirement def OperationalRequirement {
        doc /* Operational requirements for system performance */
    }
    
    requirement <'REQ-DTH-001'> primaryFunction : TherapeuticEffectivenessRequirement {
        doc /* 
            The diathermy system shall convert high-frequency electromagnetic energy 
            into controlled deep tissue heating to achieve therapeutic temperatures 
            between 40-45 degrees Celsius at specified tissue depths for pain relief, 
            improved blood circulation, and accelerated tissue healing.
        */
        
        subject diathermyDevice;
        
        require constraint {
            diathermyDevice.temperatureSensor.currentTemperature >= 40.0 [Celsius] and
            diathermyDevice.temperatureSensor.currentTemperature <= 45.0 [Celsius]
        }
    }
    
    requirement <'REQ-DTH-002'> temperatureSafety : SafetyRequirement {
        doc /* 
            The system shall continuously monitor tissue temperature and automatically 
            reduce or halt power delivery if temperature exceeds safe therapeutic limits 
            to prevent tissue burns or thermal damage.
        */
        
        subject diathermyDevice.temperatureSensor;
        subject diathermyDevice.safetyInterlock;
        
        require constraint {
            diathermyDevice.temperatureSensor.currentTemperature <= 
            diathermyDevice.temperatureSensor.maxSafeTemperature
        }
    }
    
    requirement <'REQ-DTH-003'> impedanceMonitoring : SafetyRequirement {
        doc /* 
            The system shall monitor tissue impedance to ensure proper applicator 
            contact and detect abnormal conditions that could indicate poor coupling 
            or patient safety concerns.
        */
        
        subject diathermyDevice.impedanceMonitor;
        
        require constraint {
            diathermyDevice.impedanceMonitor.currentImpedance <= 
            diathermyDevice.impedanceMonitor.impedanceThreshold
        }
    }
    
    requirement <'REQ-DTH-004'> powerControl : OperationalRequirement {
        doc /* 
            The system shall provide adjustable power output with precise control 
            to accommodate different treatment protocols, tissue types, and patient 
            tolerance levels while maintaining stable electromagnetic field generation.
        */
        
        subject diathermyDevice.rfGenerator;
        subject diathermyDevice.controlUnit;
        
        require constraint {
            diathermyDevice.rfGenerator.currentPowerOutput <= 
            diathermyDevice.rfGenerator.maxPowerOutput
        }
    }
    
    requirement <'REQ-DTH-005'> treatmentDuration : OperationalRequirement {
        doc /* 
            The system shall support programmable treatment durations with automatic 
            shutoff to ensure consistent therapy delivery and prevent overexposure.
        */
        
        subject diathermyDevice.controlUnit;
        subject diathermyDevice.safetyInterlock;
        
        require constraint {
            diathermyDevice.safetyInterlock.treatmentTimeElapsed <= 
            diathermyDevice.safetyInterlock.timerDuration
        }
    }
    
    requirement <'REQ-DTH-006'> penetrationDepth : TherapeuticEffectivenessRequirement {
        doc /* 
            The system shall deliver electromagnetic energy capable of achieving 
            therapeutic heating at tissue depths of 2-5 cm to effectively treat 
            deep-seated musculoskeletal conditions.
        */
        
        subject diathermyDevice.applicator;
        
        require constraint {
            diathermyDevice.applicator.penetrationDepth >= 2.0 [cm] and
            diathermyDevice.applicator.penetrationDepth <= 5.0 [cm]
        }
    }
}
