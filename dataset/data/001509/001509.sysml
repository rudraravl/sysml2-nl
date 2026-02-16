package 'Nanomaterial Sensor System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def NanometerUnit :> Real {
        doc /* Custom unit for nanometer scale measurements */
    }
    
    value def ParticleSizeValue :> ISQ::LengthValue {
        doc /* Size of nanoparticles in nanometers */
    }
    
    value def SurfaceAreaValue :> ISQ::AreaValue {
        doc /* Surface area of nanomaterial layer */
    }
    
    value def ConcentrationValue :> Real {
        doc /* Gas concentration in parts per million */
    }
    
    value def SensitivityValue :> Real {
        doc /* Sensor sensitivity in inverse ppm */
    }
    
    value def ResponseTimeValue :> ISQ::DurationValue {
        doc /* Time to reach 90% of final response */
    }
    
    item def AnalyteGas {
        attribute concentration : ConcentrationValue;
        attribute molecularWeight : ISQ::MassValue;
    }
    
    item def ElectricalSignal {
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute current : ISQ::ElectricCurrentValue;
        attribute resistance : Real;
    }
    
    port def GasExposurePort {
        in analyte : AnalyteGas;
    }
    
    port def SignalOutputPort {
        out signal : ElectricalSignal;
    }
    
    port def PowerSupplyPort {
        in voltage : ISQ::ElectricPotentialValue;
    }
    
    part def NanoparticleLayer {
        attribute particleSize : ParticleSizeValue;
        attribute surfaceArea : SurfaceAreaValue;
        attribute baselineResistance : Real;
        
        port gasInterface : GasExposurePort;
        port electricalInterface : SignalOutputPort;
        
        state def SensingBehavior {
            entry; then baseline;
            
            state baseline;
            accept exposureEvent : AnalyteGas
                then adsorbing;
            
            state adsorbing;
            accept saturationEvent
                then saturated;
            
            state saturated;
            accept purgeEvent
                then desorbing;
            
            state desorbing;
            then baseline;
        }
    }
    
    part def SignalProcessor {
        attribute gain : Real;
        attribute filterCutoff : ISQ::FrequencyValue;
        
        port signalInput : SignalOutputPort;
        port dataOutput {
            out processedConcentration : ConcentrationValue;
        }
    }
    
    part def PowerManagement {
        attribute inputVoltage : ISQ::ElectricPotentialValue;
        attribute outputVoltage : ISQ::ElectricPotentialValue;
        attribute efficiency : Real;
        
        port powerIn : PowerSupplyPort;
        port powerOut : PowerSupplyPort;
    }
    
    action def AdsorptionProcess {
        in gasConcentration : ConcentrationValue;
        in surfaceArea : SurfaceAreaValue;
        out resistanceChange : Real;
    }
    
    action def SignalConversion {
        in resistanceChange : Real;
        in baselineResistance : Real;
        out outputSignal : ElectricalSignal;
    }
    
    action def ConcentrationCalculation {
        in inputSignal : ElectricalSignal;
        in sensitivity : SensitivityValue;
        out measuredConcentration : ConcentrationValue;
    }
    
    action def SensingCycle {
        in exposedGas : AnalyteGas;
        in sensorSensitivity : SensitivityValue;
        in sensorSurfaceArea : SurfaceAreaValue;
        in sensorBaseline : Real;
        out finalConcentration : ConcentrationValue;
        
        first start;
        
        then action adsorb : AdsorptionProcess {
            in gasConcentration = exposedGas.concentration;
            in surfaceArea = sensorSurfaceArea;
            out resistanceChange;
        }
        
        flow adsorb.resistanceChange to convert.resistanceChange;
        
        then action convert : SignalConversion {
            in resistanceChange;
            in baselineResistance = sensorBaseline;
            out outputSignal;
        }
        
        flow convert.outputSignal to calculate.inputSignal;
        
        then action calculate : ConcentrationCalculation {
            in inputSignal;
            in sensitivity = sensorSensitivity;
            out measuredConcentration;
        }
        
        then assign finalConcentration := calculate.measuredConcentration;
        
        then done;
    }
    
    requirement def PerformanceRequirement;
    requirement def PhysicalRequirement;
    requirement def SafetyRequirement;
    
    requirement <'NANO-REQ-001'> detectionSensitivity : PerformanceRequirement {
        doc /* The nanomaterial sensor shall detect target gas concentrations 
               as low as 1 ppm with a sensitivity of at least 0.05 ppm^-1. */
        
        subject sensor : NanomaterialSensorSystem;
        require constraint {
            sensor.sensitivity >= 0.05
        }
    }
    
    requirement <'NANO-REQ-002'> responseTime : PerformanceRequirement {
        doc /* The sensor system shall achieve 90% of final response 
               within 30 seconds of gas exposure. */
        
        subject sensor : NanomaterialSensorSystem;
    }
    
    requirement <'NANO-REQ-003'> particleCharacteristics : PhysicalRequirement {
        doc /* Nanoparticles shall have a mean diameter between 10 and 50 nanometers 
               to maximize surface area while maintaining structural stability. */
        
        subject layer : NanoparticleLayer;
    }
    
    requirement <'NANO-REQ-004'> operationalSafety : SafetyRequirement {
        doc /* The sensor system shall operate safely at voltages not exceeding 5V 
               to prevent thermal damage to nanomaterial layer. */
        
        subject power : PowerManagement;
    }
    
    part def NanomaterialSensorSystem {
        doc /* A gas detection system utilizing nanomaterial-based sensing elements 
               to detect and quantify trace concentrations of target analytes through 
               changes in electrical resistance upon molecular adsorption. */
        
        attribute sensitivity : SensitivityValue;
        attribute responseTime : ResponseTimeValue;
        attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
        
        part nanoLayer : NanoparticleLayer {
            :>> particleSize = 25.0;
            :>> surfaceArea = 150.0;
            :>> baselineResistance = 10000.0;
        }
        
        part processor : SignalProcessor {
            :>> gain = 100.0;
        }
        
        part powerModule : PowerManagement {
            :>> inputVoltage = 12.0;
            :>> outputVoltage = 3.3;
            :>> efficiency = 0.85;
        }
        
        connection gasFlow 
            connect nanoLayer.gasInterface to exposureInterface;
        
        connection signalPath
            connect nanoLayer.electricalInterface to processor.signalInput;
        
        port exposureInterface : GasExposurePort;
        port measurementOutput {
            out concentration : ConcentrationValue;
        }
        port systemPower : PowerSupplyPort;
        
        perform action sensing[*] ordered :> SensingCycle {
            in exposedGas = exposureInterface.analyte;
            in sensorSensitivity = sensitivity;
            in sensorSurfaceArea = nanoLayer.surfaceArea;
            in sensorBaseline = nanoLayer.baselineResistance;
            out finalConcentration;
        }
        
        satisfy detectionSensitivity;
        satisfy responseTime;
        satisfy operationalSafety by powerModule;
    }
    
    part sensorInstance : NanomaterialSensorSystem {
        :>> sensitivity = 0.08;
        :>> responseTime = 25.0;
        :>> operatingTemperature = 298.15;
        
        part nanoLayer {
            satisfy particleCharacteristics;
        }
    }
}
