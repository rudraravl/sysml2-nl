package SmartLaundrySystem {
    private import ScalarValues::*;

    item def Water;
    item def Detergent;
    item def Wastewater;
    item def Clothes;

    attribute def PowerValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def VolumeFlowRateValue :> Real;
    attribute def TimeValue :> Real;
    attribute def AngularVelocityValue :> Real;

    enum def CycleType {
        normal;
        delicate;
        heavyDuty;
    }
    enum def HeatLevel {
        low;
        medium;
        high;
    }

    attribute def StartCycle;
    attribute def StartWash;
    attribute def WaterLevelReached;
    attribute def WashPhaseComplete;
    attribute def RinsePhaseComplete;
    attribute def SpinPhaseComplete;
    attribute def WashComplete;
    attribute def StartDry;
    attribute def TargetMoistureReached;
    attribute def DryComplete;

    port def WaterInPort {
        in water : Water;
    }
    port def DrainPort {
        out wastewater : Wastewater;
    }
    port def ElectricalPort {
        in power : PowerValue;
    }
    port def ControlPort;

    part def Drum {
        attribute speed : AngularVelocityValue;
    }
    part def Motor {
        attribute powerOutput : PowerValue;
    }
    part def WaterHeater {
        attribute targetTemp : TemperatureValue;
    }
    part def DetergentDispenser {
        attribute detergentLevel : VolumeValue;
    }
    part def Pump {
        attribute flowRate : VolumeFlowRateValue;
    }
    part def HeatingElement {
        attribute powerOutput : PowerValue;
    }
    part def BlowerFan {
        attribute airflowRate : VolumeFlowRateValue;
    }
    part def MoistureSensor {
        attribute moistureLevel : Real;
    }
    part def TemperatureSensor {
        attribute temperature : TemperatureValue;
    }

    part def WashingMachine {
        port waterIn : WaterInPort;
        port drainOut : DrainPort;
        port electricalIn : ElectricalPort;
        port control : ControlPort;

        part drum : Drum;
        part motor : Motor;
        part waterHeater : WaterHeater;
        part detergentDispenser : DetergentDispenser;
        part pump : Pump;

        attribute selectedCycle : CycleType;
        attribute targetWaterTemp : TemperatureValue;
        attribute cycleDuration : TimeValue;

        action addDetergent;
        action fillWater;
        action agitate;
        action heatWater;
        action spinDrum;
        action drainWater;

        exhibit state washerStates {
            entry; then idle;
            state idle;
            accept StartWash 
                do addDetergent
                then filling;
            state filling {
                entry fillWater;
            }
            accept WaterLevelReached then washing;
            state washing {
                entry heatWater;
                do agitate;
            }
            accept WashPhaseComplete then rinsing;
            state rinsing {
                entry fillWater;
                do agitate;
                exit drainWater;
            }
            accept RinsePhaseComplete then spinning;
            state spinning {
                do spinDrum;
                exit drainWater;
            }
            accept SpinPhaseComplete 
                do send new WashComplete() to control
                then idle;
        }
    }

    part def ClothesDryer {
        port electricalIn : ElectricalPort;
        port control : ControlPort;

        part drum : Drum;
        part heatingElement : HeatingElement;
        part blowerFan : BlowerFan;
        part moistureSensor : MoistureSensor;
        part temperatureSensor : TemperatureSensor;

        attribute heatLevel : HeatLevel;
        attribute targetDryness : Real;

        action dryOperation {
            action generateHeat;
            action circulateAir;
            action tumble;
            action senseMoisture;
            action senseTemperature;
        }

        exhibit state dryerStates {
            entry; then idle;
            state idle;
            accept StartDry then drying;
            state drying {
                do dryOperation;
            }
            accept TargetMoistureReached 
                do send new DryComplete() to control
                then idle;
        }
    }

    part def CentralController {
        port controlWasher : ControlPort;
        port controlDryer : ControlPort;
        port electricalIn : ElectricalPort;

        attribute maxPower : PowerValue;
        attribute currentPower : PowerValue;

        action checkPowerLoad;
        action notifyUser;

        exhibit state controllerStates {
            entry; then standby;
            state standby;
            accept StartCycle 
                do send new StartWash() to controlWasher
                then managingWash;
            state managingWash {
                do checkPowerLoad;
            }
            accept WashComplete 
                do send new StartDry() to controlDryer
                then managingDry;
            state managingDry {
                do checkPowerLoad;
            }
            accept DryComplete 
                do notifyUser
                then standby;
        }
    }

    part def LaundrySystem {
        port waterIn : WaterInPort;
        port drainOut : DrainPort;
        port electricalIn : ElectricalPort;

        part controller : CentralController;
        part washer : WashingMachine;
        part dryer : ClothesDryer;

        connect waterIn to washer.waterIn;
        connect washer.drainOut to drainOut;
        connect electricalIn to controller.electricalIn;
        connect electricalIn to washer.electricalIn;
        connect electricalIn to dryer.electricalIn;
        connect controller.controlWasher to washer.control;
        connect controller.controlDryer to dryer.control;

        exhibit state systemStates {
            entry; then standby;
            state standby;
            accept StartCycle then washing;
            state washing;
            accept WashComplete then drying;
            state drying;
            accept DryComplete then standby;
        }
    }

    requirement def LaundryAutomationReq {
        doc /* The system shall automate the full laundry cycle from standby to washing to drying and back to standby. */
    }
    requirement def EnergyManagementReq {
        doc /* The controller shall manage high-power components to avoid overloading the home electrical circuit. */
        attribute maxPower : PowerValue;
        attribute totalPower : PowerValue;
        require constraint { totalPower <= maxPower }
    }
    requirement def DrynessControlReq {
        doc /* The dryer shall automatically end the cycle when the moisture sensor indicates the target dryness is reached. */
        attribute actualDryness : Real;
        attribute targetDryness : Real;
        require constraint { actualDryness <= targetDryness }
    }
    requirement def WashCycleControlReq {
        doc /* The washing machine shall precisely control water temperature, drum agitation speed, and cycle duration. */
        attribute actualTemp : TemperatureValue;
        attribute targetTemp : TemperatureValue;
        attribute maxTempVariance : TemperatureValue;
        require constraint { (actualTemp - targetTemp <= maxTempVariance) && (targetTemp - actualTemp <= maxTempVariance) }
    }
    requirement def DrumSpeedControlReq {
        doc /* The washing machine shall maintain drum speed within 5 percent of the target speed during agitation. */
        attribute actualSpeed : AngularVelocityValue;
        attribute targetSpeed : AngularVelocityValue;
        require constraint { (actualSpeed - targetSpeed) / targetSpeed <= 0.05 && (targetSpeed - actualSpeed) / targetSpeed <= 0.05 }
    }
    requirement def HeatLevelControlReq {
        doc /* The dryer shall regulate heat to low, medium, or high based on user selection. */
        attribute selectedHeat : HeatLevel;
        attribute actualHeat : HeatLevel;
        require constraint { selectedHeat == actualHeat }
    }
}
