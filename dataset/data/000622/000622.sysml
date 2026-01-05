package HeineOptotechnikMedicalIlluminationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def LuminousIntensityValue :> ISQ::LuminousIntensityValue;
    attribute def IlluminanceValue :> ISQ::IlluminanceValue;
    attribute def ColorTemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def BatteryChargeValue :> Real;
    attribute def VoltageValue :> ISQ::VoltageValue;
    attribute def CurrentValue :> ISQ::ElectricCurrentValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def MassValue :> ISQ::MassValue;
    attribute def AngleValue :> ISQ::AngleValue;
    
    enum def IntensityLevel {
        off;
        low;
        medium;
        high;
        maximum;
    }
    
    enum def SystemStatus {
        operational;
        lowBattery;
        overheating;
        fault;
    }
    
    item def LightBeam {
        attribute intensity : IlluminanceValue;
        attribute colorTemp : ColorTemperatureValue;
        attribute beamAngle : AngleValue;
    }
    
    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    port def PowerPort {
        out power : ElectricalPower;
    }
    
    port def LightPort {
        out lightBeam : LightBeam;
    }
    
    port def ControlPort {
        in intensityCommand : IntensityLevel;
        out statusFeedback : SystemStatus;
    }
    
    part def LEDIlluminationModule {
        attribute nominalIntensity : LuminousIntensityValue;
        attribute colorTemperature : ColorTemperatureValue;
        attribute currentLevel : IntensityLevel;
        attribute powerConsumption : PowerValue;
        
        port powerIn : ~PowerPort;
        port lightOut : LightPort;
        port control : ControlPort;
    }
    
    part def FiberOpticLightGuide {
        attribute transmissionEfficiency : Real;
        attribute length : ISQ::LengthValue;
        attribute outputAngle : AngleValue;
        
        port lightIn : ~LightPort;
        port lightOut : LightPort;
    }
    
    part def RechargeableBatteryPack {
        attribute capacity : Real;
        attribute currentCharge : BatteryChargeValue;
        attribute voltage : VoltageValue;
        attribute mass : MassValue;
        
        port powerOut : PowerPort;
    }
    
    part def PowerManagementUnit {
        attribute efficiency : Real;
        attribute outputVoltage : VoltageValue;
        
        port batteryIn : ~PowerPort;
        port powerOut : PowerPort;
        port control : ControlPort;
    }
    
    part def TemperatureSensor {
        attribute currentTemp : ISQ::ThermodynamicTemperatureValue;
        attribute threshold : ISQ::ThermodynamicTemperatureValue;
        
        port sensorOut;
    }
    
    part def UserControlInterface {
        attribute selectedIntensity : IntensityLevel;
        
        port controlOut : ControlPort;
    }
    
    part def OpticalHeadpiece {
        attribute focusRange : ISQ::LengthValue;
        attribute beamDiameter : ISQ::LengthValue;
        attribute mass : MassValue;
        
        port lightIn : ~LightPort;
        port lightOut : LightPort;
    }
    
    action def InitializeSystem {
        out systemReady : Boolean;
    }
    
    action def SetIntensity {
        in targetLevel : IntensityLevel;
        out actualIntensity : LuminousIntensityValue;
    }
    
    action def MonitorBattery {
        out chargeLevel : BatteryChargeValue;
        out status : SystemStatus;
    }
    
    action def MonitorTemperature {
        out temperature : ISQ::ThermodynamicTemperatureValue;
        out thermalStatus : SystemStatus;
    }
    
    action def ProvideIllumination {
        in targetArea;
        out illuminatedField : LightBeam;
    }
    
    action def PerformSafetyCheck {
        in batteryStatus : SystemStatus;
        in thermalStatus : SystemStatus;
        out overallStatus : SystemStatus;
    }
    
    action def OperateMedicalIllumination {
        first start;
        then action initialize : InitializeSystem;
        then merge continuousOperation;
        
        action monitorBattery : MonitorBattery {
            out batteryCharge : BatteryChargeValue;
            out batteryStatus : SystemStatus;
        }
        
        action monitorTemp : MonitorTemperature {
            out currentTemp : ISQ::ThermodynamicTemperatureValue;
            out tempStatus : SystemStatus;
        }
        
        action safetyCheck : PerformSafetyCheck {
            in batteryStatus = monitorBattery.batteryStatus;
            in thermalStatus = monitorTemp.tempStatus;
            out systemStatus : SystemStatus;
        }
        
        then decide;
            if safetyCheck.systemStatus == SystemStatus::operational then illuminate;
            if safetyCheck.systemStatus == SystemStatus::lowBattery then reducePower;
            if safetyCheck.systemStatus == SystemStatus::overheating then cooldown;
            if safetyCheck.systemStatus == SystemStatus::fault then shutdown;
        
        action illuminate : ProvideIllumination {
            out field : LightBeam;
        }
        then continuousOperation;
        
        action reducePower : SetIntensity {
            in targetLevel = IntensityLevel::low;
            out intensity : LuminousIntensityValue;
        }
        then continuousOperation;
        
        action cooldown;
        then continuousOperation;
        
        action shutdown;
        then done;
    }
    
    part def HeineIlluminationSystem {
        attribute totalMass : MassValue;
        attribute operatingTime : ISQ::DurationValue;
        attribute currentIntensity : IntensityLevel;
        
        perform action operation : OperateMedicalIllumination;
        
        part ledModule : LEDIlluminationModule {
            attribute :>> nominalIntensity = 50000.0 [cd];
            attribute :>> colorTemperature = 4500.0 [K];
            attribute :>> currentLevel : IntensityLevel;
            attribute :>> powerConsumption : PowerValue;
            
            perform operation.illuminate;
        }
        
        part fiberGuide : FiberOpticLightGuide {
            attribute :>> transmissionEfficiency = 0.95;
            attribute :>> length = 1.5 [m];
            attribute :>> outputAngle = 60.0 [deg];
        }
        
        part battery : RechargeableBatteryPack {
            attribute :>> capacity = 5200.0;
            attribute :>> currentCharge : BatteryChargeValue;
            attribute :>> voltage = 7.4 [V];
            attribute :>> mass = 180.0 [g];
            
            perform operation.monitorBattery;
        }
        
        part powerMgmt : PowerManagementUnit {
            attribute :>> efficiency = 0.92;
            attribute :>> outputVoltage = 5.0 [V];
            
            perform operation.safetyCheck;
        }
        
        part tempSensor : TemperatureSensor {
            attribute :>> currentTemp : ISQ::ThermodynamicTemperatureValue;
            attribute :>> threshold = 333.15 [K];
            
            perform operation.monitorTemp;
        }
        
        part userControl : UserControlInterface {
            attribute :>> selectedIntensity : IntensityLevel;
        }
        
        part headpiece : OpticalHeadpiece {
            attribute :>> focusRange = 0.35 [m];
            attribute :>> beamDiameter = 0.08 [m];
            attribute :>> mass = 95.0 [g];
        }
        
        connection batteryToPower connect battery.powerOut to powerMgmt.batteryIn;
        connection powerToLED connect powerMgmt.powerOut to ledModule.powerIn;
        connection ledToFiber connect ledModule.lightOut to fiberGuide.lightIn;
        connection fiberToHead connect fiberGuide.lightOut to headpiece.lightIn;
        connection controlToLED connect userControl.controlOut to ledModule.control;
        connection controlToPower connect userControl.controlOut to powerMgmt.control;
    }
    
    requirement <'REQ-HEINE-1000'> primaryFunction {
        doc /* 
         * The Heine Optotechnik medical illumination system shall provide 
         * high-quality, adjustable illumination for medical examination and 
         * surgical procedures, enabling precise visualization of anatomical 
         * structures and pathological conditions.
         */
        subject system : HeineIlluminationSystem;
    }
    
    requirement <'REQ-HEINE-1001'> illuminationQuality {
        doc /* 
         * The system shall provide illumination with color temperature 
         * between 4000K and 5000K to ensure accurate tissue color rendition.
         */
        subject led :>> heineSystem.ledModule;
        
        assert constraint {
            led.colorTemperature >= 4000.0 [K] and
            led.colorTemperature <= 5000.0 [K]
        }
    }
    
    requirement <'REQ-HEINE-1002'> intensityRange {
        doc /* 
         * The system shall provide adjustable luminous intensity from 
         * 10,000 cd to at least 50,000 cd.
         */
        subject led :>> heineSystem.ledModule;
        
        assert constraint {
            led.nominalIntensity >= 50000.0 [cd]
        }
    }
    
    requirement <'REQ-HEINE-1003'> operatingDuration {
        doc /* 
         * The system shall operate continuously for at least 4 hours 
         * on a single battery charge at medium intensity setting.
         */
        subject system :>> heineSystem;
        
        assert constraint {
            system.operatingTime >= 4.0 [h]
        }
    }
    
    requirement <'REQ-HEINE-1004'> portabilityMass {
        doc /* 
         * The total mass of the portable system shall not exceed 350 grams 
         * to ensure user comfort during extended procedures.
         */
        subject system :>> heineSystem;
        
        assert constraint {
            system.totalMass <= 350.0 [g]
        }
    }
    
    requirement <'REQ-HEINE-1005'> batteryManagement {
        doc /* 
         * The system shall monitor battery charge level and provide 
         * indication when charge drops below 20% capacity.
         */
        subject battery :>> heineSystem.battery;
        
        assert constraint {
            battery.currentCharge < 20.0 implies
            heineSystem.powerMgmt.control.statusFeedback == SystemStatus::lowBattery
        }
    }
    
    requirement <'REQ-HEINE-1006'> thermalProtection {
        doc /* 
         * The system shall monitor operating temperature and reduce power 
         * or shutdown if temperature exceeds 60°C to prevent thermal damage.
         */
        subject sensor :>> heineSystem.tempSensor;
        
        assert constraint {
            sensor.currentTemp > 333.15 [K] implies
            heineSystem.currentIntensity == IntensityLevel::low or
            heineSystem.currentIntensity == IntensityLevel::off
        }
    }
    
    requirement <'REQ-HEINE-1007'> fiberOpticEfficiency {
        doc /* 
         * The fiber optic light guide shall maintain at least 90% 
         * transmission efficiency to minimize light loss.
         */
        subject fiber :>> heineSystem.fiberGuide;
        
        assert constraint {
            fiber.transmissionEfficiency >= 0.90
        }
    }
    
    part heineSystem : HeineIlluminationSystem {
        attribute :>> totalMass = battery.mass + headpiece.mass + 75.0 [g];
        attribute :>> operatingTime = 4.5 [h];
    }
    
    satisfy primaryFunction by heineSystem;
    satisfy illuminationQuality by heineSystem.ledModule;
    satisfy intensityRange by heineSystem.ledModule;
    satisfy operatingDuration by heineSystem;
    satisfy portabilityMass by heineSystem;
    satisfy batteryManagement by heineSystem.battery;
    satisfy thermalProtection by heineSystem.tempSensor;
    satisfy fiberOpticEfficiency by heineSystem.fiberGuide;
}
