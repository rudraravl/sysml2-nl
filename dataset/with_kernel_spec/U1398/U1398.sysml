package 'Industrial Evaporative Cooling Tower' {
    private import ScalarValues::*;

    package Definitions {
        private import ScalarValues::*;

        unit def degC;
        unit def percent;
        unit def m3ps;
        unit def rpm;

        value type TemperatureValue :> ScalarValues::Real { unit = degC; }
        value type Percentage :> ScalarValues::Real { unit = percent; }
        value type FlowRateValue :> ScalarValues::Real { unit = m3ps; }
        value type FanSpeedValue :> ScalarValues::Real { unit = rpm; }

        item def Water {
            attribute temperature : TemperatureValue;
            attribute flowRate : FlowRateValue;
        }
        item def AmbientAir {
            attribute temperature : TemperatureValue;
            attribute humidity : Percentage;
        }
        item def MoistAir {
            attribute temperature : TemperatureValue;
            attribute humidity : Percentage;
        }

        attribute def TemperatureSignal {
            attribute value : TemperatureValue;
        }
        attribute def FanSpeedCommand {
            attribute speed : Percentage;
        }
        attribute def StartCommand;
        attribute def StopCommand;
        attribute def EmergencyStopCommand;
        attribute def ResetCommand;

        part def ExternalIndustrialProcess {
            out item hotWater : Water;
            in item coldWater : Water;
        }

        action def 'Spray Water' {
            in waterIn : Water;
            out sprayOut : Water;
        }
        action def 'Evaporative Heat Transfer' {
            in waterIn : Water;
            in airIn : AmbientAir;
            out cooledWater : Water;
            out moistAir : MoistAir;
        }
        action def 'Draw Air' {
            in airIn : AmbientAir;
            in speedCmd : FanSpeedCommand;
            out exhaustAir : MoistAir;
        }
        action def 'Collect Water' {
            in waterIn : Water;
            out basinWater : Water;
        }
        action def 'Pump Water' {
            in waterIn : Water;
            out pumpedWater : Water;
        }
        action def 'Sense Temperature' {
            in water : Water;
            out reading : TemperatureSignal;
        }
        action def 'Adjust Fan Speed' {
            in currentTemp : TemperatureSignal;
            in setpoint : TemperatureValue;
            out cmd : FanSpeedCommand;
        }
        action def 'Cool Water';
        action def 'Init Systems';
        action def 'Ramp Down Fan';
        action def 'Cut Power';

        part def WaterDistributionSystem {
            in item hotWater : Water;
            out item distributedWater : Water;
            perform action 'spray water': 'Spray Water';
        }

        part def FillMedia {
            in item distributedWater : Water;
            in item ambientAir : AmbientAir;
            out item cooledWater : Water;
            out item moistAir : MoistAir;
            perform action 'heat transfer': 'Evaporative Heat Transfer';
        }

        part def InducedDraftFan {
            in item moistAir : MoistAir;
            in speedCmd : FanSpeedCommand;
            out item exhaustAir : MoistAir;
            perform action 'draw air': 'Draw Air';
        }

        part def ColdWaterBasin {
            in item cooledWater : Water;
            out item basinWater : Water;
            perform action 'collect water': 'Collect Water';
        }

        part def CirculationPump {
            in item basinWater : Water;
            out item coldWater : Water;
            perform action 'pump water': 'Pump Water';
        }

        part def TemperatureSensor {
            in item water : Water;
            out temp : TemperatureSignal;
            perform action 'sense temperature': 'Sense Temperature';
        }

        part def ControlSystem {
            in hotInletTemp : TemperatureSignal;
            in coldOutletTemp : TemperatureSignal;
            in startCmd : StartCommand;
            in stopCmd : StopCommand;
            in emergencyCmd : EmergencyStopCommand;
            in resetCmd : ResetCommand;
            out fanSpeedCmd : FanSpeedCommand;
            attribute setpoint : TemperatureValue = 30 [degC];
            attribute highTempThreshold : TemperatureValue = 35 [degC];
            attribute normalTempThreshold : TemperatureValue = 28 [degC];

            perform action 'adjust fan speed': 'Adjust Fan Speed';

            exhibit state 'control states' {
                entry action initial {}
                transition initial then idle;

                state idle;
                state startup;
                state 'normal operation';
                state 'high-load';
                state 'controlled shutdown';
                state 'emergency stop';

                transition 'idle_startup'
                    first idle
                    accept StartCommand
                    then startup;

                transition 'startup_normal'
                    first startup
                    then 'normal operation';

                transition 'normal_highload'
                    first 'normal operation'
                    if coldOutletTemp.value > highTempThreshold
                    then 'high-load';

                transition 'highload_normal'
                    first 'high-load'
                    if coldOutletTemp.value <= normalTempThreshold
                    then 'normal operation';

                transition 'normal_shutdown'
                    first 'normal operation'
                    accept StopCommand
                    then 'controlled shutdown';

                transition 'highload_shutdown'
                    first 'high-load'
                    accept StopCommand
                    then 'controlled shutdown';

                transition 'shutdown_idle'
                    first 'controlled shutdown'
                    then idle;

                transition 'normal_emergency'
                    first 'normal operation'
                    accept EmergencyStopCommand
                    then 'emergency stop';

                transition 'startup_emergency'
                    first startup
                    accept EmergencyStopCommand
                    then 'emergency stop';

                transition 'highload_emergency'
                    first 'high-load'
                    accept EmergencyStopCommand
                    then 'emergency stop';

                transition 'emergency_idle'
                    first 'emergency stop'
                    accept ResetCommand
                    then idle;
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part def CoolingTower {
            in item hotWater : Water;
            out item coldWater : Water;
            in item ambientAir : AmbientAir;
            out item exhaustAir : MoistAir;
            in startCmd : StartCommand;
            in stopCmd : StopCommand;
            in emergencyCmd : EmergencyStopCommand;
            in resetCmd : ResetCommand;

            part distribution : WaterDistributionSystem;
            part fill : FillMedia;
            part fan : InducedDraftFan;
            part basin : ColdWaterBasin;
            part pump : CirculationPump;
            part hotSensor : TemperatureSensor;
            part coldSensor : TemperatureSensor;
            part controller : ControlSystem;

            bind hotWater = distribution.hotWater;
            bind distribution.distributedWater = fill.distributedWater;
            bind fill.cooledWater = basin.cooledWater;
            bind basin.basinWater = pump.basinWater;
            bind pump.coldWater = coldWater;

            bind ambientAir = fill.ambientAir;
            bind fill.moistAir = fan.moistAir;
            bind fan.exhaustAir = exhaustAir;

            bind hotWater = hotSensor.water;
            bind pump.coldWater = coldSensor.water;

            bind hotSensor.temp = controller.hotInletTemp;
            bind coldSensor.temp = controller.coldOutletTemp;
            bind controller.fanSpeedCmd = fan.speedCmd;

            bind startCmd = controller.startCmd;
            bind stopCmd = controller.stopCmd;
            bind emergencyCmd = controller.emergencyCmd;
            bind resetCmd = controller.resetCmd;

            perform action 'cool water': 'Cool Water';
        }

        part 'Industrial Plant' {
            part process : ExternalIndustrialProcess;
            part 'Cooling Tower System' : CoolingTower;

            bind process.hotWater = 'Cooling Tower System'.hotWater;
            bind 'Cooling Tower System'.coldWater = process.coldWater;
        }
    }

    package Requirements {
        private import Definitions::*;
        private import Usages::*;

        requirement def CoolingTowerRequirements {
            subject coolingTower : CoolingTower;

            requirement 'Cooling Performance' {
                subject :>> coolingTower;
                doc
                /* The cooling tower shall reduce the temperature of hot water
                   from the industrial process to at most 30 degrees Celsius. */
            }

            requirement 'High Load Operation' {
                subject :>> coolingTower;
                doc
                /* The system shall transition to high-load mode if the outlet
                   temperature exceeds the high-temp threshold of 35 degrees Celsius. */
            }

            requirement 'Emergency Safety' {
                subject :>> coolingTower;
                doc
                /* The system shall enter emergency stop state upon receiving
                   an emergency stop command. */
            }

            requirement 'Circulation Continuity' {
                subject :>> coolingTower;
                doc
                /* The circulation pump shall continuously return cooled water
                   to the industrial process during normal operation. */
            }
        }
    }
}
