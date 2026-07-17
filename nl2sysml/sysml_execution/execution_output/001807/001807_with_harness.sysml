package LiquidMetalCoolingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def LiquidMetalProperties {
        attribute meltingPoint : TemperatureValue;
        attribute boilingPoint : TemperatureValue;
        attribute thermalConductivity : Real;
        attribute density : DensityValue;
        attribute viscosity : Real;
    }

    attribute def SodiumPotassiumAlloy :> LiquidMetalProperties {
        attribute :>> meltingPoint = -12.6 [SI::K];
        attribute :>> boilingPoint = 1058.15 [SI::K];
        attribute :>> thermalConductivity = 24.4;
        attribute :>> density = 866.0 [SI::kg/SI::m^3];
        attribute :>> viscosity = 0.00068;
    }

    item def LiquidMetalCoolant {
        attribute properties : LiquidMetalProperties;
        attribute currentTemperature : TemperatureValue;
        attribute flowRate : VolumeFlowRateValue;
        attribute pressure : PressureValue;
    }

    item def ThermalLoad {
        attribute heatGenerated : PowerValue;
    }

    item def ControlSignal {
        attribute pumpSpeed : Real;
        attribute targetTemperature : TemperatureValue;
    }

    port def CoolantPort {
        attribute temperature : TemperatureValue;
        attribute flowRate : VolumeFlowRateValue;
        attribute pressure : PressureValue;
    }

    port def ThermalPort {
        attribute heatTransferRate : PowerValue;
        attribute surfaceTemperature : TemperatureValue;
    }

    port def ControlPort {
        attribute commandSignal : Real;
    }

    part def HeatSource {
        doc /* Component generating thermal energy requiring cooling */
        port thermalOutput : ThermalPort;
        attribute powerOutput : PowerValue;
        attribute operatingTemperature : TemperatureValue;
    }

    part def ElectromagneticPump {
        doc /* Pump using electromagnetic forces to circulate liquid metal without mechanical contact */
        port coolantInlet : CoolantPort;
        port coolantOutlet : CoolantPort;
        port controlInput : ControlPort;
        attribute pumpSpeed : Real;
        attribute maxFlowRate : VolumeFlowRateValue;
        attribute powerConsumption : PowerValue;
        perform action pumpCoolant;
    }

    part def ColdPlate {
        doc /* Heat exchanger interface between heat source and liquid metal */
        port thermalInput : ThermalPort;
        port coolantInlet : CoolantPort;
        port coolantOutlet : CoolantPort;
        attribute heatTransferCoefficient : Real;
        attribute surfaceArea : AreaValue;
        perform action absorbHeat;
    }

    part def Radiator {
        doc /* Heat dissipation component transferring heat to ambient environment */
        port coolantInlet : CoolantPort;
        port coolantOutlet : CoolantPort;
        port ambientInterface : ThermalPort;
        attribute coolingCapacity : PowerValue;
        attribute finEfficiency : Real;
        perform action dissipateHeat;
    }

    part def ExpansionTank {
        doc /* Reservoir accommodating thermal expansion of liquid metal */
        port coolantInterface : CoolantPort;
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        attribute maxPressure : PressureValue;
    }

    part def TemperatureSensor {
        port coolantMonitor : CoolantPort;
        port sensorOutput : ControlPort;
        attribute measuredTemperature : TemperatureValue;
        attribute accuracy : Real;
        perform action measureTemperature;
    }

    part def SystemController {
        doc /* Control unit managing pump speed based on thermal feedback */
        port temperatureInput : ControlPort;
        port pumpControl : ControlPort;
        attribute targetTemperature : TemperatureValue;
        attribute controlGain : Real;
        perform action regulateFlow;
    }

    action def MonitorTemperature {
        in coolantTemp : TemperatureValue;
        in targetTemp : TemperatureValue;
        out temperatureError : TemperatureValue;
        out requiresAdjustment : Boolean;
    }

    action def CalculatePumpSpeed {
        in temperatureError : TemperatureValue;
        in currentSpeed : Real;
        in controlGain : Real;
        out newSpeed : Real;
    }

    action def CirculateCoolant {
        in pumpSpeed : Real;
        in coolantProperties : LiquidMetalProperties;
        out flowRate : VolumeFlowRateValue;
    }

    action def TransferHeat {
        in sourceTemp : TemperatureValue;
        in coolantTemp : TemperatureValue;
        in flowRate : VolumeFlowRateValue;
        out heatTransferred : PowerValue;
        out coolantTempOut : TemperatureValue;
    }

    action def ThermalRegulationCycle {
        doc /* Continuous thermal management cycle */
        private attribute currentSpeed : Real;
        in coolantTemp : TemperatureValue;
        in targetTemp : TemperatureValue;
        in controlGain : Real;
        
        first start;
        then merge continuousOperation;
        
        then action monitor : MonitorTemperature {
            in coolantTemp = coolantTemp;
            in targetTemp = targetTemp;
            out temperatureError;
            out requiresAdjustment;
        }
        
        then decide;
            if monitor.requiresAdjustment then adjustFlow;
            else maintainFlow;
        
        action adjustFlow : CalculatePumpSpeed {
            in temperatureError = monitor.temperatureError;
            in currentSpeed = currentSpeed;
            in controlGain = controlGain;
            out newSpeed;
        }
        then assign currentSpeed := adjustFlow.newSpeed;
        then continuousOperation;
        
        action maintainFlow;
        then continuousOperation;
    }

    state def CoolingSystemState {
        entry; then standby;
        
        state standby {
            doc /* System idle, coolant at ambient temperature */
        }
        accept at standby then startup
            when StartupCommand;
        
        state startup {
            doc /* Initial circulation and temperature stabilization */
            entry assign pumpSpeed := 0.3;
        }
        transition startup to normalOperation
            when coolantCirculating;
        
        state normalOperation {
            doc /* Active thermal management with feedback control */
            do action thermalControl : ThermalRegulationCycle;
        }
        transition normalOperation to highLoad
            when heatLoadExceeds80Percent;
        transition normalOperation to shutdown
            when ShutdownCommand;
        
        state highLoad {
            doc /* Maximum cooling capacity operation */
            entry assign pumpSpeed := 1.0;
        }
        transition highLoad to normalOperation
            when heatLoadBelow70Percent;
        transition highLoad to emergency
            when temperatureExceedsLimit;
        
        state emergency {
            doc /* Emergency cooling and system protection */
            entry assign pumpSpeed := 1.0;
        }
        transition emergency to shutdown
            when systemSafe;
        
        state shutdown {
            doc /* Controlled system shutdown */
            entry assign pumpSpeed := 0.0;
        }
        transition shutdown to standby
            when coolantAtAmbient;
        
        attribute pumpSpeed : Real;
        event StartupCommand;
        event ShutdownCommand;
        event coolantCirculating;
        event heatLoadExceeds80Percent;
        event heatLoadBelow70Percent;
        event temperatureExceedsLimit;
        event systemSafe;
        event coolantAtAmbient;
    }

    requirement def <'LMC-001'> OperatingTemperatureRange {
        doc /* The liquid metal cooling system shall maintain coolant temperature 
               between 323K and 673K during normal operation. */
        subject coolingSystem : LiquidMetalThermalManagementSystem;
        require constraint {
            coolingSystem.coldPlate.coolantOutlet.temperature >= 323.15 [SI::K] and
            coolingSystem.coldPlate.coolantOutlet.temperature <= 673.15 [SI::K]
        }
    }

    requirement def <'LMC-002'> HeatRemovalCapacity {
        doc /* The system shall remove minimum 10 kW of thermal energy 
               from the heat source continuously. */
        subject coolingSystem : LiquidMetalThermalManagementSystem;
        require constraint {
            coolingSystem.radiator.coolingCapacity >= 10000.0 [SI::W]
        }
    }

    requirement def <'LMC-003'> FlowRateStability {
        doc /* The electromagnetic pump shall maintain flow rate within 
               ±5% of commanded value. */
        subject pump : ElectromagneticPump;
        require constraint {
            pump.coolantOutlet.flowRate >= 0.95 * pump.maxFlowRate and
            pump.coolantOutlet.flowRate <= 1.05 * pump.maxFlowRate
        }
    }

    requirement def <'LMC-004'> SystemSafety {
        doc /* The system shall prevent coolant temperature from exceeding 
               boiling point to ensure safe operation. */
        subject coolingSystem : LiquidMetalThermalManagementSystem;
        require constraint {
            coolingSystem.coldPlate.coolantOutlet.temperature < 1000.0 [SI::K]
        }
    }

    requirement def <'LMC-005'> ResponseTime {
        doc /* The control system shall respond to temperature changes 
               within 2 seconds. */
        subject controller : SystemController;
    }

    requirement systemRequirements {
        doc /* Top-level requirements for liquid metal cooling system */
        require <'LMC-001'> OperatingTemperatureRange;
        require <'LMC-002'> HeatRemovalCapacity;
        require <'LMC-003'> FlowRateStability;
        require <'LMC-004'> SystemSafety;
        require <'LMC-005'> ResponseTime;
    }

    connection def CoolantConnection {
        end source : CoolantPort;
        end target : CoolantPort;
    }

    connection def ThermalConnection {
        end source : ThermalPort;
        end target : ThermalPort;
    }

    connection def ControlConnection {
        end source : ControlPort;
        end target : ControlPort;
    }

    part def LiquidMetalThermalManagementSystem {
        doc /* A high-performance thermal management system utilizing liquid metal coolant 
               for efficient heat transfer. Primary function: Continuously circulate liquid 
               metal coolant through a closed loop to absorb thermal energy from a high-power 
               heat source, transport it via electromagnetic pumping, and dissipate it to the 
               ambient environment through a radiator, while maintaining precise temperature 
               control through automated feedback regulation. */

        attribute systemOperatingTemp : TemperatureValue = 473.15 [SI::K];
        attribute maxThermalLoad : PowerValue = 15000.0 [SI::W];
        attribute coolantVolume : VolumeValue = 5.0 [SI::L];

        part heatSource : HeatSource {
            attribute :>> powerOutput = 12000.0 [SI::W];
            attribute :>> operatingTemperature = 623.15 [SI::K];
        }

        part coldPlate : ColdPlate {
            attribute :>> heatTransferCoefficient = 5000.0;
            attribute :>> surfaceArea = 0.04 [SI::m^2];
        }

        part pump : ElectromagneticPump {
            attribute :>> pumpSpeed = 0.7;
            attribute :>> maxFlowRate = 15.0 [SI::L/SI::min];
            attribute :>> powerConsumption = 500.0 [SI::W];
        }

        part radiator : Radiator {
            attribute :>> coolingCapacity = 15000.0 [SI::W];
            attribute :>> finEfficiency = 0.85;
        }

        part expansionTank : ExpansionTank {
            attribute :>> capacity = 8.0 [SI::L];
            attribute :>> currentLevel = 5.0 [SI::L];
            attribute :>> maxPressure = 200000.0 [SI::Pa];
        }

        part temperatureSensor : TemperatureSensor {
            attribute :>> measuredTemperature = 473.15 [SI::K];
            attribute :>> accuracy = 0.98;
        }

        part controller : SystemController {
            attribute :>> targetTemperature = 473.15 [SI::K];
            attribute :>> controlGain = 0.05;
        }

        item coolant : LiquidMetalCoolant {
            attribute :>> properties : SodiumPotassiumAlloy;
            attribute :>> currentTemperature = 473.15 [SI::K];
            attribute :>> flowRate = 10.0 [SI::L/SI::min];
            attribute :>> pressure = 150000.0 [SI::Pa];
        }

        connection heatSourceToColdPlate : ThermalConnection
            connect heatSource.thermalOutput to coldPlate.thermalInput;

        connection pumpToColdPlate : CoolantConnection
            connect pump.coolantOutlet to coldPlate.coolantInlet;

        connection coldPlateToRadiator : CoolantConnection
            connect coldPlate.coolantOutlet to radiator.coolantInlet;

        connection radiatorToExpansion : CoolantConnection
            connect radiator.coolantOutlet to expansionTank.coolantInterface;

        connection expansionToPump : CoolantConnection
            connect expansionTank.coolantInterface to pump.coolantInlet;

        connection sensorMonitoring : CoolantConnection
            connect coldPlate.coolantOutlet to temperatureSensor.coolantMonitor;

        connection sensorToController : ControlConnection
            connect temperatureSensor.sensorOutput to controller.temperatureInput;

        connection controllerToPump : ControlConnection
            connect controller.pumpControl to pump.controlInput;

        perform action systemOperation : ThermalRegulationCycle {
            in coolantTemp = temperatureSensor.measuredTemperature;
            in targetTemp = controller.targetTemperature;
            in controlGain = controller.controlGain;
        }

        exhibit state systemBehavior : CoolingSystemState {
            :>> pumpSpeed = pump.pumpSpeed;
        }

        satisfy systemRequirements;
    }

    part liquidMetalSystem : LiquidMetalThermalManagementSystem;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import LiquidMetalCoolingSystem::*;

    part testSubject : LiquidMetalThermalManagementSystem {
        exhibit state systemBehavior : CoolingSystemState;
    }

    action orchestrator {
        attribute testTemperatureError : TemperatureValue;
        action adjustFlowProbe : CalculatePumpSpeed {
            in temperatureError = testTemperatureError;
            in currentSpeed = 0.0;
            in controlGain = 0.0;
        }
        first adjustFlowProbe;
    }
}
