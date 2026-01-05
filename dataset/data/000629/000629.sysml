package 'Hot Air Oven System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def HeaterCommand;
    attribute def FanCommand;
    attribute def StartCommand;
    attribute def StopCommand;
    
    enum def HeaterState {
        off;
        on;
    }
    
    enum def FanState {
        off;
        low;
        high;
    }
    
    enum def DoorState {
        closed;
        open;
    }
    
    enum def OperatingPhase {
        idle;
        preheating;
        maintaining;
        cooling;
        complete;
    }
    
    port def ElectricalPowerPort {
        in voltage : ISQ::VoltageValue;
        in current : ISQ::ElectricCurrentValue;
        out powerDraw : ISQ::PowerValue;
    }
    
    port def ThermalPort {
        out heatOutput : ISQ::PowerValue;
        out surfaceTemp : ISQ::ThermodynamicTemperatureValue;
    }
    
    port def AirFlowPort {
        out flowRate : ISQ::VolumeFlowRateValue;
        out airTemp : ISQ::ThermodynamicTemperatureValue;
    }
    
    port def SensorPort {
        out reading : ISQ::ThermodynamicTemperatureValue;
    }
    
    port def ControlPort {
        in command : Real;
        out status : Real;
    }
    
    item def ElectricalSupply {
        attribute voltage : ISQ::VoltageValue;
        attribute frequency : ISQ::FrequencyValue;
    }
    
    part def HeatingElement {
        port powerIn : ElectricalPowerPort;
        port thermalOut : ThermalPort;
        port control : ControlPort;
        
        attribute ratedPower : ISQ::PowerValue;
        attribute maxTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute currentState : HeaterState;
    }
    
    part def CirculationFan {
        port powerIn : ElectricalPowerPort;
        port airOut : AirFlowPort;
        port control : ControlPort;
        
        attribute ratedSpeed : Real;
        attribute currentSpeed : Real;
        attribute currentState : FanState;
    }
    
    part def TemperatureSensor {
        port sense : SensorPort;
        
        attribute accuracy : ISQ::ThermodynamicTemperatureValue;
        attribute responseTime : ISQ::TimeValue;
    }
    
    part def DoorLatch {
        attribute doorState : DoorState;
        attribute isLocked : Boolean;
    }
    
    part def OvenChamber {
        attribute volume : ISQ::VolumeValue;
        attribute insulationThickness : ISQ::LengthValue;
        attribute currentTemperature : ISQ::ThermodynamicTemperatureValue;
        
        part insulation;
        part airSpace;
    }
    
    part def ControlUnit {
        attribute setpointTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute operatingDuration : ISQ::TimeValue;
        attribute currentPhase : OperatingPhase;
        attribute elapsedTime : ISQ::TimeValue;
        
        port tempInput : SensorPort;
        port heaterControl : ControlPort;
        port fanControl : ControlPort;
    }
    
    part def UserInterface {
        attribute displayTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute displayTime : ISQ::TimeValue;
        attribute displayPhase : OperatingPhase;
        
        out attribute commandedSetpoint : ISQ::ThermodynamicTemperatureValue;
        out attribute commandedDuration : ISQ::TimeValue;
        out attribute startSignal : Boolean;
        out attribute stopSignal : Boolean;
    }
    
    requirement def <'REQ-FUNC-001'> primaryFunctionRequirement {
        doc /* The hot air oven shall provide uniform thermal processing by 
                circulating heated air throughout an insulated chamber to achieve 
                and maintain a specified temperature for a controlled duration. */
        
        require constraint temperatureRange {
            doc /* Operating temperature range shall be 50°C to 300°C. */
        }
        
        require constraint temperatureStability {
            doc /* Temperature shall be maintained within ±3°C of setpoint during operation. */
        }
        
        require constraint uniformity {
            doc /* Temperature uniformity across chamber shall be within ±5°C. */
        }
    }
    
    requirement def <'REQ-SAFE-001'> safetyRequirement {
        doc /* The oven shall prevent hazardous conditions through interlocks and automatic shutdown. */
        
        require constraint doorInterlock {
            doc /* Heating shall be disabled when door is open. */
        }
        
        require constraint overtemperatureProtection {
            doc /* System shall shut down if temperature exceeds 320°C. */
        }
    }
    
    requirement def <'REQ-PERF-001'> performanceRequirement {
        doc /* The oven shall achieve specified heating rates and energy efficiency. */
        
        require constraint heatingRate {
            doc /* Oven shall reach 200°C from ambient within 20 minutes. */
        }
    }
    
    action def MeasureTemperature {
        in sensorSignal : Real;
        out measuredTemp : ISQ::ThermodynamicTemperatureValue;
    }
    
    action def CalculateHeaterPower {
        in currentTemp : ISQ::ThermodynamicTemperatureValue;
        in setpoint : ISQ::ThermodynamicTemperatureValue;
        in tolerance : ISQ::ThermodynamicTemperatureValue;
        out powerCommand : Real;
    }
    
    action def DetermineFanSpeed {
        in currentPhase : OperatingPhase;
        in currentTemp : ISQ::ThermodynamicTemperatureValue;
        out speedCommand : Real;
    }
    
    action def UpdateTimer {
        in deltaTime : ISQ::TimeValue;
        in elapsed : ISQ::TimeValue;
        in duration : ISQ::TimeValue;
        out newElapsed : ISQ::TimeValue;
        out isComplete : Boolean;
    }
    
    action def CheckSafety {
        in doorState : DoorState;
        in currentTemp : ISQ::ThermodynamicTemperatureValue;
        in maxSafeTemp : ISQ::ThermodynamicTemperatureValue;
        out safeToOperate : Boolean;
    }
    
    action def ControlOvenCycle {
        in setpoint : ISQ::ThermodynamicTemperatureValue;
        in duration : ISQ::TimeValue;
        in currentTemp : ISQ::ThermodynamicTemperatureValue;
        in doorClosed : Boolean;
        out heaterCmd : Real;
        out fanCmd : Real;
        out phase : OperatingPhase;
        
        private attribute timer : ISQ::TimeValue;
        private attribute tolerance : ISQ::ThermodynamicTemperatureValue;
        
        first start;
        
        then action initializeIdle {
            assign phase := OperatingPhase::idle;
            assign heaterCmd := 0.0;
            assign fanCmd := 0.0;
            assign timer := 0.0 [s];
        }
        
        then merge awaitStart;
        
        then decide;
            if doorClosed then beginPreheat;
            if !doorClosed then awaitStart;
        
        action beginPreheat {
            assign phase := OperatingPhase::preheating;
            assign heaterCmd := 1.0;
            assign fanCmd := 1.0;
        }
        
        then merge checkPreheat;
        
        then decide;
            if currentTemp >= setpoint - tolerance then startMaintaining;
            if currentTemp < setpoint - tolerance and doorClosed then checkPreheat;
            if !doorClosed then initializeIdle;
        
        action startMaintaining {
            assign phase := OperatingPhase::maintaining;
        }
        
        then merge maintainLoop;
        
        then action regulateHeat : CalculateHeaterPower {
            in currentTemp;
            in setpoint;
            in tolerance;
            out powerCommand;
        }
        
        then assign heaterCmd := regulateHeat.powerCommand;
        then assign fanCmd := 1.0;
        
        then action trackTime : UpdateTimer {
            in deltaTime := 1.0 [s];
            in elapsed := timer;
            in duration;
            out newElapsed;
            out isComplete;
        }
        
        then assign timer := trackTime.newElapsed;
        
        then decide;
            if trackTime.isComplete then beginCooling;
            if !trackTime.isComplete and doorClosed then maintainLoop;
            if !doorClosed then initializeIdle;
        
        action beginCooling {
            assign phase := OperatingPhase::cooling;
            assign heaterCmd := 0.0;
            assign fanCmd := 0.5;
        }
        
        then merge coolLoop;
        
        then decide;
            if currentTemp <= 323.15 [K] then markComplete;
            if currentTemp > 323.15 [K] then coolLoop;
        
        action markComplete {
            assign phase := OperatingPhase::complete;
            assign heaterCmd := 0.0;
            assign fanCmd := 0.0;
        }
        
        then done;
    }
    
    action def OperateOven {
        in setpointTemp : ISQ::ThermodynamicTemperatureValue;
        in operatingDuration : ISQ::TimeValue;
        in maxSafeTemp : ISQ::ThermodynamicTemperatureValue;
        out finalTemperature : ISQ::ThermodynamicTemperatureValue;
        
        private attribute currentTemp : ISQ::ThermodynamicTemperatureValue;
        private attribute doorIsClosed : Boolean;
        private attribute heaterCommand : Real;
        private attribute fanCommand : Real;
        private attribute currentPhase : OperatingPhase;
        
        first start;
        
        then merge controlLoop;
        
        then action checkSafety : CheckSafety {
            in doorState;
            in currentTemp;
            in maxSafeTemp;
            out safeToOperate;
        }
        
        then decide;
            if !checkSafety.safeToOperate then emergencyShutdown;
            if checkSafety.safeToOperate then continueControl;
        
        action continueControl {
            action measureTemp : MeasureTemperature {
                in sensorSignal;
                out measuredTemp;
            }
            
            then assign currentTemp := measureTemp.measuredTemp;
            
            then action computeHeater : CalculateHeaterPower {
                in currentTemp;
                in setpoint := setpointTemp;
                in tolerance := 3.0 [K];
                out powerCommand;
            }
            
            then assign heaterCommand := computeHeater.powerCommand;
            
            then action computeFan : DetermineFanSpeed {
                in currentPhase;
                in currentTemp;
                out speedCommand;
            }
            
            then assign fanCommand := computeFan.speedCommand;
        }
        
        then decide;
            if currentPhase == OperatingPhase::complete then finish;
            if currentPhase != OperatingPhase::complete then controlLoop;
        
        action emergencyShutdown {
            assign heaterCommand := 0.0;
            assign fanCommand := 0.0;
            assign currentPhase := OperatingPhase::idle;
        }
        
        action finish {
            assign finalTemperature := currentTemp;
        }
        
        then done;
    }
    
    part def HotAirOven {
        port mainPower : ElectricalPowerPort;
        
        attribute targetTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute cycleTime : ISQ::TimeValue;
        attribute maximumTemperature : ISQ::ThermodynamicTemperatureValue;
        
        part chamber : OvenChamber {
            attribute :>> volume = 0.05 [m^3];
            attribute :>> insulationThickness = 0.05 [m];
        }
        
        part heater : HeatingElement {
            attribute :>> ratedPower = 2500.0 [W];
            attribute :>> maxTemperature = 573.15 [K];
        }
        
        part fan : CirculationFan {
            attribute :>> ratedSpeed = 1500.0;
        }
        
        part sensor : TemperatureSensor {
            attribute :>> accuracy = 1.0 [K];
            attribute :>> responseTime = 2.0 [s];
        }
        
        part door : DoorLatch {
            attribute :>> doorState = DoorState::closed;
            attribute :>> isLocked = false;
        }
        
        part controller : ControlUnit {
            attribute :>> setpointTemperature = 473.15 [K];
            attribute :>> operatingDuration = 3600.0 [s];
            attribute :>> currentPhase = OperatingPhase::idle;
            attribute :>> elapsedTime = 0.0 [s];
        }
        
        part ui : UserInterface {
            attribute :>> commandedSetpoint = 473.15 [K];
            attribute :>> commandedDuration = 3600.0 [s];
        }
        
        connect mainPower to heater.powerIn;
        connect mainPower to fan.powerIn;
        
        connect sensor.sense to controller.tempInput;
        connect controller.heaterControl to heater.control;
        connect controller.fanControl to fan.control;
        
        connect ui.commandedSetpoint to controller.setpointTemperature;
        connect ui.commandedDuration to controller.operatingDuration;
        
        satisfy primaryFunctionRequirement by controller, heater, fan, chamber;
        satisfy safetyRequirement by controller, door;
        satisfy performanceRequirement by heater, fan;
    }
    
    part ovenSystem : HotAirOven {
        attribute :>> targetTemperature = 473.15 [K];
        attribute :>> cycleTime = 3600.0 [s];
        attribute :>> maximumTemperature = 593.15 [K];
        
        perform action operate : OperateOven {
            in setpointTemp = ovenSystem.targetTemperature;
            in operatingDuration = ovenSystem.cycleTime;
            in maxSafeTemp = ovenSystem.maximumTemperature;
            out finalTemperature;
        }
    }
}
