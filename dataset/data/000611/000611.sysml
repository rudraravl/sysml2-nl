package FluidWarmerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def VolumeValue :> ISQ::VolumeValue;
    attribute def VoltageValue :> ISQ::VoltageValue;
    
    enum def OperatingMode {
        off;
        standby;
        warming;
        maintaining;
        alarm;
    }
    
    enum def FluidType {
        saline;
        blood;
        ringerLactate;
        dextrose;
    }
    
    item def MedicalFluid {
        attribute fluidType : FluidType;
        attribute currentTemperature : TemperatureValue;
        attribute volume : VolumeValue;
        attribute flowRate : FlowRateValue;
    }
    
    port def FluidPort {
        out fluid : MedicalFluid;
    }
    
    port def SensorPort {
        out temperature : TemperatureValue;
        out flowRate : FlowRateValue;
    }
    
    port def ControlPort {
        in targetTemperature : TemperatureValue;
        out heaterPower : PowerValue;
    }
    
    port def PowerPort {
        in voltage : VoltageValue;
        out power : PowerValue;
    }
    
    part def TemperatureSensor {
        attribute measuredTemperature : TemperatureValue;
        attribute accuracy : TemperatureValue = 0.1 [SI::K];
        port sensorOutput : SensorPort;
    }
    
    part def FlowSensor {
        attribute measuredFlowRate : FlowRateValue;
        attribute accuracy : FlowRateValue = 5.0e-6 [SI::m^3/SI::s];
        port sensorOutput : SensorPort;
    }
    
    part def HeatingElement {
        attribute maxPower : PowerValue = 150.0 [SI::W];
        attribute currentPower : PowerValue;
        attribute surfaceTemperature : TemperatureValue;
        port powerInput : PowerPort;
    }
    
    part def WarmingChamber {
        attribute chamberTemperature : TemperatureValue;
        attribute chamberVolume : VolumeValue = 5.0e-5 [SI::m^3];
        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
    }
    
    part def ControlUnit {
        attribute targetTemperature : TemperatureValue = 310.15 [SI::K];
        attribute temperatureTolerance : TemperatureValue = 0.5 [SI::K];
        attribute currentMode : OperatingMode;
        port temperatureInput : SensorPort;
        port flowInput : SensorPort;
        port heaterControl : ControlPort;
    }
    
    part def AlarmSystem {
        attribute alarmActive : Boolean = false;
        attribute maxSafeTemperature : TemperatureValue = 312.15 [SI::K];
        attribute minSafeTemperature : TemperatureValue = 308.15 [SI::K];
    }
    
    part def UserInterface {
        attribute displayedTemperature : TemperatureValue;
        attribute displayedFlowRate : FlowRateValue;
        attribute displayedMode : OperatingMode;
    }
    
    part def PowerSupply {
        attribute inputVoltage : VoltageValue = 120.0 [SI::V];
        attribute outputPower : PowerValue = 200.0 [SI::W];
        port powerOutput : PowerPort;
    }
    
    action def MonitorTemperature {
        in currentTemp : TemperatureValue;
        in targetTemp : TemperatureValue;
        in tolerance : TemperatureValue;
        out tempDifference : TemperatureValue;
        out withinRange : Boolean;
    }
    
    action def AdjustHeatingPower {
        in tempDifference : TemperatureValue;
        in currentPower : PowerValue;
        in maxPower : PowerValue;
        out newPower : PowerValue;
    }
    
    action def CheckSafetyLimits {
        in currentTemp : TemperatureValue;
        in maxSafe : TemperatureValue;
        in minSafe : TemperatureValue;
        out safetyViolation : Boolean;
    }
    
    action def WarmFluidControl {
        in targetTemp : TemperatureValue;
        in tolerance : TemperatureValue;
        in maxPower : PowerValue;
        in maxSafe : TemperatureValue;
        in minSafe : TemperatureValue;
        out heaterPower : PowerValue;
        out alarmTriggered : Boolean;
        
        first start;
        then merge controlLoop;
        
        then action monitor : MonitorTemperature {
            in currentTemp : TemperatureValue;
            in targetTemp = targetTemp;
            in tolerance = tolerance;
            out tempDifference : TemperatureValue;
            out withinRange : Boolean;
        }
        
        then action safetyCheck : CheckSafetyLimits {
            in currentTemp = monitor.currentTemp;
            in maxSafe = maxSafe;
            in minSafe = minSafe;
            out safetyViolation : Boolean;
        }
        
        then decide;
            if safetyCheck.safetyViolation then triggerAlarm;
            if !safetyCheck.safetyViolation && !monitor.withinRange then adjustPower;
            if !safetyCheck.safetyViolation && monitor.withinRange then maintainPower;
        
        action adjustPower : AdjustHeatingPower {
            in tempDifference = monitor.tempDifference;
            in currentPower : PowerValue;
            in maxPower = maxPower;
            out newPower : PowerValue;
        }
        then controlLoop;
        
        action maintainPower : AdjustHeatingPower {
            in tempDifference = monitor.tempDifference;
            in currentPower : PowerValue;
            in maxPower = maxPower;
            out newPower : PowerValue;
        }
        then controlLoop;
        
        action triggerAlarm {
            out alarmSignal : Boolean;
        }
        then done;
    }
    
    state def FluidWarmerStateMachine {
        entry; then idle;
        
        state idle {
            entry assign currentMode = OperatingMode::off;
        }
        accept powerOn;
        then standby;
        
        state standby {
            entry assign currentMode = OperatingMode::standby;
        }
        accept startWarming;
        then warming;
        
        state warming {
            entry assign currentMode = OperatingMode::warming;
        }
        accept targetReached;
        then maintaining;
        accept alarmCondition;
        then alarm;
        
        state maintaining {
            entry assign currentMode = OperatingMode::maintaining;
        }
        accept stopWarming;
        then standby;
        accept alarmCondition;
        then alarm;
        
        state alarm {
            entry assign currentMode = OperatingMode::alarm;
        }
        accept alarmReset;
        then standby;
        accept powerOff;
        then idle;
    }
    
    part def FluidWarmer {
        attribute operatingTemperatureRange : TemperatureValue[2] = (308.15 [SI::K], 312.15 [SI::K]);
        attribute maxFlowRate : FlowRateValue = 8.33e-6 [SI::m^3/SI::s];
        attribute totalPowerConsumption : PowerValue;
        
        part warmingChamber : WarmingChamber {
            attribute :>> chamberTemperature : TemperatureValue;
            attribute :>> chamberVolume = 5.0e-5 [SI::m^3];
        }
        
        part heatingElement : HeatingElement {
            attribute :>> maxPower = 150.0 [SI::W];
            attribute :>> currentPower : PowerValue;
        }
        
        part inputTempSensor : TemperatureSensor {
            attribute :>> accuracy = 0.1 [SI::K];
        }
        
        part outputTempSensor : TemperatureSensor {
            attribute :>> accuracy = 0.1 [SI::K];
        }
        
        part flowSensor : FlowSensor {
            attribute :>> accuracy = 5.0e-6 [SI::m^3/SI::s];
        }
        
        part controller : ControlUnit {
            attribute :>> targetTemperature = 310.15 [SI::K];
            attribute :>> temperatureTolerance = 0.5 [SI::K];
            attribute :>> currentMode : OperatingMode;
        }
        
        part userInterface : UserInterface;
        
        part alarmSystem : AlarmSystem {
            attribute :>> alarmActive = false;
            attribute :>> maxSafeTemperature = 312.15 [SI::K];
            attribute :>> minSafeTemperature = 308.15 [SI::K];
        }
        
        part powerSupply : PowerSupply {
            attribute :>> inputVoltage = 120.0 [SI::V];
            attribute :>> outputPower = 200.0 [SI::W];
        }
        
        connection tempSensorToController 
            connect outputTempSensor.sensorOutput to controller.temperatureInput;
        
        connection flowSensorToController
            connect flowSensor.sensorOutput to controller.flowInput;
        
        connection controllerToHeater
            connect controller.heaterControl to heatingElement.powerInput;
        
        connection powerToHeater
            connect powerSupply.powerOutput to heatingElement.powerInput;
        
        perform action warmingOperation : WarmFluidControl {
            in targetTemp = controller.targetTemperature;
            in tolerance = controller.temperatureTolerance;
            in maxPower = heatingElement.maxPower;
            in maxSafe = alarmSystem.maxSafeTemperature;
            in minSafe = alarmSystem.minSafeTemperature;
            out heaterPower : PowerValue;
            out alarmTriggered : Boolean;
        }
    }
    
    requirement <'REQ-FW-001'> warmFluidToBodyTemperature {
        doc /* The fluid warmer shall heat intravenous fluids to physiological 
             * body temperature (37°C ± 0.5°C) to prevent hypothermia in patients 
             * receiving fluid therapy during medical procedures.
             */
        subject fluidWarmer : FluidWarmer;
    }
    
    requirement <'REQ-FW-002'> temperatureAccuracy {
        doc /* The system shall maintain output fluid temperature within ±0.5°C 
             * of the target temperature during continuous operation.
             */
        subject fluidWarmer : FluidWarmer;
        assert constraint {
            fluidWarmer.outputTempSensor.measuredTemperature >= 309.65 [SI::K] &&
            fluidWarmer.outputTempSensor.measuredTemperature <= 310.65 [SI::K]
        }
    }
    
    requirement <'REQ-FW-003'> flowRateCapacity {
        doc /* The fluid warmer shall support flow rates up to 500 mL/min 
             * while maintaining target temperature.
             */
        subject fluidWarmer : FluidWarmer;
        assert constraint {
            fluidWarmer.maxFlowRate >= 8.33e-6 [SI::m^3/SI::s]
        }
    }
    
    requirement <'REQ-FW-004'> safetyAlarms {
        doc /* The system shall activate alarms when temperature exceeds safe 
             * limits (>39°C or <35°C) and immediately cease heating.
             */
        subject fluidWarmer : FluidWarmer;
    }
    
    requirement <'REQ-FW-005'> powerConsumption {
        doc /* The total power consumption shall not exceed 200W during 
             * normal operation.
             */
        subject fluidWarmer : FluidWarmer;
        assert constraint {
            fluidWarmer.totalPowerConsumption <= 200.0 [SI::W]
        }
    }
    
    part fluidWarmerSystem : FluidWarmer {
        attribute :>> operatingTemperatureRange = (308.15 [SI::K], 312.15 [SI::K]);
        attribute :>> maxFlowRate = 8.33e-6 [SI::m^3/SI::s];
        attribute :>> totalPowerConsumption = 150.0 [SI::W];
    }
    
    satisfy warmFluidToBodyTemperature by fluidWarmerSystem;
    satisfy temperatureAccuracy by fluidWarmerSystem;
    satisfy flowRateCapacity by fluidWarmerSystem;
    satisfy safetyAlarms by fluidWarmerSystem;
    satisfy powerConsumption by fluidWarmerSystem;
}
