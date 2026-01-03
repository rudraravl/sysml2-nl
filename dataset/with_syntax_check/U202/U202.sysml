package DielectricHeatingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def FrequencyValue :> ISQ::frequency;
    attribute def ElectricFieldStrengthValue :> ISQ::electricFieldStrength;
    attribute def DielectricConstantValue :> Real;
    attribute def LossFactor :> Real;
    attribute def TemperatureValue :> ISQ::thermodynamicTemperature;
    attribute def PowerValue :> ISQ::power;
    attribute def VoltageValue :> ISQ::voltage;
    attribute def MassValue :> ISQ::mass;
    attribute def VolumeValue :> ISQ::volume;
    attribute def VolumeFlowRateValue :> ISQ::volumeFlowRate;
    attribute def DurationValue :> Time::Duration;
    
    enum def OperatingMode {
        enum standby;
        enum preheating;
        enum activeHeating;
        enum holding;
        enum cooling;
        enum fault;
    }
    
    item def DielectricMaterial {
        attribute dielectricConstant : DielectricConstantValue;
        attribute lossFactor : LossFactor;
        attribute temperature : TemperatureValue;
        attribute mass : MassValue;
        attribute specificHeatCapacity : Real;
    }
    
    port def RFPowerPort {
        out power : PowerValue;
        out frequency : FrequencyValue;
    }
    
    port def MaterialPort {
        inout material : DielectricMaterial;
    }
    
    port def TemperaturePort {
        in materialTemp : TemperatureValue;
        out measuredTemp : TemperatureValue;
    }
    
    port def ControlPort {
        in targetPower : PowerValue;
        in enable : Boolean;
        out actualPower : PowerValue;
    }
    
    port def UserInterfacePort {
        in setTemperature : TemperatureValue;
        in startCommand : Boolean;
        in stopCommand : Boolean;
        out currentMode : OperatingMode;
        out currentTemperature : TemperatureValue;
    }
    
    part def RFPowerGenerator {
        attribute nominalFrequency : FrequencyValue;
        attribute maxPower : PowerValue;
        attribute efficiency : Real;
        attribute currentPowerOutput : PowerValue;
        
        port rfOutput : RFPowerPort;
        port controlInput : ~ControlPort;
        
        action def GenerateRFPower {
            in targetPower : PowerValue;
            in enable : Boolean;
            out outputPower : PowerValue;
            out outputFrequency : FrequencyValue;
        }
    }
    
    part def DielectricApplicator {
        attribute fieldStrength : ElectricFieldStrengthValue;
        attribute chamberVolume : VolumeValue;
        attribute fieldUniformity : Real;
        
        port rfInput : ~RFPowerPort;
        port materialInterface : MaterialPort;
        
        action def ApplyElectricField {
            in rfPower : PowerValue;
            in frequency : FrequencyValue;
            inout material : DielectricMaterial;
            out heatingRate : PowerValue;
        }
    }
    
    part def TemperatureSensor {
        attribute sensorType : String;
        attribute accuracy : TemperatureValue;
        attribute responseTime : DurationValue;
        attribute currentReading : TemperatureValue;
        
        port sensing : TemperaturePort;
        
        action def MeasureTemperature {
            in materialTemp : TemperatureValue;
            out measuredTemp : TemperatureValue;
        }
    }
    
    part def HeatingController {
        attribute targetTemperature : TemperatureValue;
        attribute currentMode : OperatingMode;
        attribute powerLevel : Real;
        attribute pidGainP : Real;
        attribute pidGainI : Real;
        attribute pidGainD : Real;
        
        port temperatureInput : ~TemperaturePort;
        port powerControl : ControlPort;
        port userInterface : ~UserInterfacePort;
        
        action def CalculateRequiredPower {
            in currentTemp : TemperatureValue;
            in targetTemp : TemperatureValue;
            in maxPower : PowerValue;
            out requiredPower : PowerValue;
        }
        
        action def UpdateControlLoop {
            in measuredTemp : TemperatureValue;
            in targetTemp : TemperatureValue;
            out powerCommand : PowerValue;
            out enableCommand : Boolean;
        }
    }
    
    part def CoolingSystem {
        attribute coolingCapacity : PowerValue;
        attribute flowRate : VolumeFlowRateValue;
        attribute coolantTemperature : TemperatureValue;
        
        port coolingInterface {
            in heatLoad : PowerValue;
            out coolingPower : PowerValue;
        }
        
        action def ProvideCooling {
            in heatLoad : PowerValue;
            out coolingPower : PowerValue;
        }
    }
    
    part def SafetySystem {
        attribute doorClosed : Boolean;
        attribute maxTemperatureLimit : TemperatureValue;
        attribute emergencyStopActive : Boolean;
        attribute interlockStatus : Boolean;
        
        port safetyMonitor {
            in currentTemp : TemperatureValue;
            in doorStatus : Boolean;
            in emergencyStop : Boolean;
            out shutdownSignal : Boolean;
            out safeToOperate : Boolean;
        }
        
        action def MonitorSafety {
            in temperature : TemperatureValue;
            in doorClosed : Boolean;
            in emergencyStop : Boolean;
            out safeToOperate : Boolean;
            out shutdownRequired : Boolean;
        }
    }
    
    action def MonitorTemperature {
        in currentTemp : TemperatureValue;
        in targetTemp : TemperatureValue;
        out tempError : TemperatureValue;
        out withinTolerance : Boolean;
    }
    
    action def AdjustPower {
        in tempError : TemperatureValue;
        in currentPower : PowerValue;
        in maxPower : PowerValue;
        out newPower : PowerValue;
    }
    
    action def ApplyHeating {
        in power : PowerValue;
        in frequency : FrequencyValue;
        inout material : DielectricMaterial;
        out heatingRate : PowerValue;
    }
    
    action def CheckSafety {
        in temperature : TemperatureValue;
        in doorStatus : Boolean;
        in emergencyStop : Boolean;
        out safeToOperate : Boolean;
    }
    
    action def DielectricHeatingProcess {
        in targetTemp : TemperatureValue;
        in maxPower : PowerValue;
        in operatingFreq : FrequencyValue;
        inout material : DielectricMaterial;
        
        first start;
        then merge safetyCheck;
        
        action safety : CheckSafety {
            in temperature = material.temperature;
            in doorStatus;
            in emergencyStop;
            out safeToOperate;
        }
        
        then decide;
            if safety.safeToOperate then monitorTemp;
            if !safety.safeToOperate then shutdown;
        
        action monitorTemp : MonitorTemperature {
            in currentTemp = material.temperature;
            in targetTemp = targetTemp;
            out tempError;
            out withinTolerance;
        }
        
        then decide;
            if monitorTemp.withinTolerance then maintainPower;
            if !monitorTemp.withinTolerance then adjustPower;
        
        action adjustPower : AdjustPower {
            in tempError = monitorTemp.tempError;
            in currentPower;
            in maxPower = maxPower;
            out newPower;
        }
        
        then applyHeating;
        
        action maintainPower {
            in currentPower;
        }
        
        then applyHeating;
        
        action applyHeating : ApplyHeating {
            in power;
            in frequency = operatingFreq;
            inout material = material;
            out heatingRate;
        }
        
        then safetyCheck;
        
        action shutdown;
        then done;
    }
    
    state def HeatingSystemStateMachine {
        entry; then idle;
        
        state idle;
        
        accept at idle
            if startCommand
            then preheating;
        
        state preheating;
        
        accept at preheating
            if measuredTemp >= targetTemperature * 0.4
            then heating;
        
        state heating;
        
        accept at heating
            if measuredTemp >= targetTemperature
            then holding;
        
        accept at heating
            if stopCommand
            then cooling;
        
        state holding;
        
        accept at holding
            if measuredTemp < targetTemperature * 0.95
            then heating;
        
        accept at holding
            if stopCommand
            then cooling;
        
        state cooling;
        
        accept at cooling
            if measuredTemp <= targetTemperature * 0.3
            then idle;
        
        accept at idle, preheating, heating, holding, cooling
            if emergencyStopActive or !interlockStatus
            then faultState;
        
        state faultState;
        
        accept at faultState
            if interlockStatus and !emergencyStopActive
            then idle;
    }
    
    requirement <'SYS-REQ-001'> primaryHeatingFunction {
        doc /* The dielectric heating system shall convert high-frequency electromagnetic 
             * energy into thermal energy within dielectric materials through molecular 
             * dipole rotation and ionic conduction, enabling rapid, uniform, and 
             * controllable volumetric heating for industrial processing applications. */
        
        subject heatingSystem : DielectricHeatingSystem;
    }
    
    requirement <'SYS-REQ-002'> heatingEfficiency {
        doc /* The system shall achieve energy conversion efficiency greater than 60% 
             * for materials with loss factor above 0.1. */
        
        subject generator : RFPowerGenerator;
        
        require constraint {
            generator.efficiency >= 0.6
        }
    }
    
    requirement <'SYS-REQ-003'> temperatureControl {
        doc /* The system shall maintain target temperature within +/- 5 degrees Celsius 
             * during active heating and holding operations. */
        
        subject controller : HeatingController;
    }
    
    requirement <'SYS-REQ-004'> safetyShutdown {
        doc /* The system shall immediately shut down RF power if door is opened, 
             * emergency stop is activated, or temperature exceeds maximum safe limit. */
        
        subject safety : SafetySystem;
    }
    
    requirement <'SYS-REQ-005'> frequencyCompliance {
        doc /* The RF generator shall operate at ISM band frequencies: 
             * 13.56 MHz, 27.12 MHz, or 2.45 GHz. */
        
        subject generator : RFPowerGenerator;
    }
    
    part def DielectricHeatingSystem {
        doc /* A dielectric heating system uses high-frequency electromagnetic fields 
             * to generate heat within dielectric materials through molecular friction 
             * caused by dipole rotation and ionic conduction. */
        
        attribute operatingFrequency : FrequencyValue;
        attribute maxPowerRating : PowerValue;
        attribute systemEfficiency : Real;
        attribute targetProcessTemperature : TemperatureValue;
        
        part rfGenerator : RFPowerGenerator {
            attribute :>> nominalFrequency : FrequencyValue;
            attribute :>> maxPower : PowerValue;
            attribute :>> efficiency : Real;
        }
        
        part applicator : DielectricApplicator {
            attribute :>> fieldStrength : ElectricFieldStrengthValue;
            attribute :>> chamberVolume : VolumeValue;
            attribute :>> fieldUniformity : Real;
        }
        
        part tempSensor : TemperatureSensor {
            attribute :>> sensorType = "Fiber Optic";
            attribute :>> accuracy : TemperatureValue;
            attribute :>> responseTime : DurationValue;
        }
        
        part controller : HeatingController {
            attribute :>> targetTemperature : TemperatureValue;
            attribute :>> currentMode : OperatingMode;
            attribute :>> pidGainP = 1.2;
            attribute :>> pidGainI = 0.5;
            attribute :>> pidGainD = 0.1;
            
            exhibit state systemStateMachine : HeatingSystemStateMachine;
        }
        
        part coolingSystem : CoolingSystem {
            attribute :>> coolingCapacity : PowerValue;
            attribute :>> flowRate : VolumeFlowRateValue;
        }
        
        part safetySystem : SafetySystem {
            attribute :>> doorClosed : Boolean;
            attribute :>> maxTemperatureLimit : TemperatureValue;
            attribute :>> emergencyStopActive : Boolean;
        }
        
        connection rfPowerConnection connect rfGenerator.rfOutput to applicator.rfInput;
        connection tempMonitoringConnection connect tempSensor.sensing to controller.temperatureInput;
        connection powerControlConnection connect controller.powerControl to rfGenerator.controlInput;
        
        assert constraint efficiencyCalculation {
            systemEfficiency == rfGenerator.efficiency * applicator.fieldUniformity * 0.9
        }
        
        assert constraint powerLimit {
            rfGenerator.currentPowerOutput <= maxPowerRating
        }
    }
    
    part industrialDielectricHeater : DielectricHeatingSystem {
        attribute :>> operatingFrequency : FrequencyValue = 27.12e6 [Hz];
        attribute :>> maxPowerRating : PowerValue = 50000.0 [W];
        attribute :>> systemEfficiency = 0.68;
        attribute :>> targetProcessTemperature : TemperatureValue = 373.15 [K];
        
        part :>> rfGenerator {
            attribute :>> nominalFrequency = industrialDielectricHeater.operatingFrequency;
            attribute :>> maxPower : PowerValue = 50000.0 [W];
            attribute :>> efficiency = 0.78;
        }
        
        part :>> applicator {
            attribute :>> chamberVolume : VolumeValue = 0.8 [m^3];
            attribute :>> fieldUniformity = 0.92;
        }
        
        part :>> tempSensor {
            attribute :>> accuracy : TemperatureValue = 1.0 [K];
            attribute :>> responseTime : DurationValue = 0.5 [s];
        }
        
        part :>> controller {
            attribute :>> targetTemperature = industrialDielectricHeater.targetProcessTemperature;
        }
        
        part :>> coolingSystem {
            attribute :>> coolingCapacity : PowerValue = 20000.0 [W];
            attribute :>> flowRate : VolumeFlowRateValue = 0.05 [m^3/s];
        }
        
        part :>> safetySystem {
            attribute :>> maxTemperatureLimit : TemperatureValue = 473.15 [K];
        }
    }
    
    satisfy primaryHeatingFunction by industrialDielectricHeater;
    satisfy heatingEfficiency by industrialDielectricHeater.rfGenerator;
    satisfy temperatureControl by industrialDielectricHeater.controller;
    satisfy safetyShutdown by industrialDielectricHeater.safetySystem;
    satisfy frequencyCompliance by industrialDielectricHeater.rfGenerator;
}
