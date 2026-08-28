package ResidentialElectricWaterHeater {
    private import ScalarValues::*;

    package Definitions {
        item def ColdWater;
        item def HotWater;

        attribute def Temperature :> Real;
        attribute def Pressure :> Real;
        attribute def Power :> Real;
        attribute def Volume :> Real;

        attribute def HeaterOnCmd;
        attribute def HeaterOffCmd;
        attribute def PumpOnCmd;
        attribute def PumpOffCmd;
        attribute def OverTempAlert;

        port def WaterInPort { in coldWater : ColdWater; }
        port def WaterOutPort { out hotWater : HotWater; }
        port def RecirculationInPort { in returnWater : HotWater; }
        port def RecirculationOutPort { out supplyWater : HotWater; }
        port def TempSenseOutPort { out temperature : Temperature; }
        port def TempSenseInPort { in temperature : Temperature; }
        port def HeaterCmdOutPort { out onCmd : HeaterOnCmd; out offCmd : HeaterOffCmd; }
        port def HeaterCmdInPort { in onCmd : HeaterOnCmd; in offCmd : HeaterOffCmd; }
        port def PumpCmdOutPort { out onCmd : PumpOnCmd; out offCmd : PumpOffCmd; }
        port def PumpCmdInPort { in onCmd : PumpOnCmd; in offCmd : PumpOffCmd; }
        port def PressureOutPort { out pressure : Pressure; }
        port def PressureInPort { in pressure : Pressure; }
        port def PowerInPort { in power : Power; }
        port def ThermalOutPort { out thermalPower : Power; }
        port def ThermalInPort { in thermalPower : Power; }
        port def AlertOutPort { out alert : OverTempAlert; }

        state def ControlUnitStates;
        state def SafetyValveStates;

        part def WaterTank {
            attribute capacity : Volume = 200;
            attribute insulationRating : Real = 0.95;
            port waterIn : WaterInPort;
            port waterOut : WaterOutPort;
            port recircIn : RecirculationInPort;
            port recircOut : RecirculationOutPort;
            port pressurePort : PressureOutPort;
            port thermalIn : ThermalInPort;
        }

        part def HeatingElement {
            attribute powerRating : Power;
            port powerPort : PowerInPort;
            port controlPort : HeaterCmdInPort;
            port thermalPort : ThermalOutPort;
            exhibit state heaterStates {
                entry; then off;
                state off;
                accept HeaterOnCmd
                    then on;
                state on;
                accept HeaterOffCmd
                    then off;
            }
        }

        part def ControlUnit {
            attribute targetTemp : Temperature = 60;
            attribute hysteresis : Temperature = 2;
            attribute maxSafeTemp : Temperature = 85;
            port tempInput : TempSenseInPort;
            port primaryHeaterControl : HeaterCmdOutPort;
            port secondaryHeaterControl : HeaterCmdOutPort;
            port pumpControl : PumpCmdOutPort;
            port alertPort : AlertOutPort;

            exhibit state controlStates : ControlUnitStates parallel {
                state operationalStates {
                    entry; then standby;
                    state standby;
                    accept when tempInput.temperature < targetTemp - hysteresis
                        do action {
                            send new HeaterOnCmd() to primaryHeaterControl;
                            send new HeaterOnCmd() to secondaryHeaterControl;
                            send new PumpOnCmd() to pumpControl;
                        }
                        then heating;
                    state heating;
                    accept when tempInput.temperature >= targetTemp
                        do action {
                            send new HeaterOffCmd() to primaryHeaterControl;
                            send new HeaterOffCmd() to secondaryHeaterControl;
                        }
                        then maintaining;
                    state maintaining {
                        do action {
                            send new HeaterOnCmd() to secondaryHeaterControl;
                        }
                    }
                    accept when tempInput.temperature < targetTemp - hysteresis
                        then heating;
                }
                state safetyStates {
                    entry; then normal;
                    state normal;
                    accept when tempInput.temperature > maxSafeTemp
                        do action {
                            send new OverTempAlert() to alertPort;
                            send new HeaterOffCmd() to primaryHeaterControl;
                            send new HeaterOffCmd() to secondaryHeaterControl;
                        }
                        then emergencyShutdown;
                    state emergencyShutdown;
                    accept when tempInput.temperature < 70
                        then normal;
                }
            }
        }

        part def TemperatureSensor {
            port tempOut : TempSenseOutPort;
        }

        part def CirculationPump {
            port controlPort : PumpCmdInPort;
            port waterIn : RecirculationInPort;
            port waterOut : RecirculationOutPort;
            exhibit state pumpStates {
                entry; then stopped;
                state stopped;
                accept PumpOnCmd
                    then running;
                state running;
                accept PumpOffCmd
                    then stopped;
            }
        }

        part def SafetyValve {
            attribute maxSafePressure : Pressure = 600000;
            port pressureIn : PressureInPort;
            port ventPort : WaterOutPort;
            exhibit state valveStates : SafetyValveStates {
                entry; then closed;
                state closed;
                accept when pressureIn.pressure > maxSafePressure
                    then open;
                state open;
                accept when pressureIn.pressure < maxSafePressure
                    then closed;
            }
        }

        part def WaterHeaterSystem {
            part tank : WaterTank;
            part primaryHeater : HeatingElement {
                attribute powerRating = 4500;
            }
            part secondaryHeater : HeatingElement {
                attribute powerRating = 2000;
            }
            part controlUnit : ControlUnit;
            part tempSensor : TemperatureSensor;
            part circPump : CirculationPump;
            part safetyValve : SafetyValve;

            flow tempFlow of Temperature
                from tempSensor.tempOut.temperature to controlUnit.tempInput.temperature;
            flow primaryOnCmdFlow of HeaterOnCmd
                from controlUnit.primaryHeaterControl.onCmd to primaryHeater.controlPort.onCmd;
            flow primaryOffCmdFlow of HeaterOffCmd
                from controlUnit.primaryHeaterControl.offCmd to primaryHeater.controlPort.offCmd;
            flow secondaryOnCmdFlow of HeaterOnCmd
                from controlUnit.secondaryHeaterControl.onCmd to secondaryHeater.controlPort.onCmd;
            flow secondaryOffCmdFlow of HeaterOffCmd
                from controlUnit.secondaryHeaterControl.offCmd to secondaryHeater.controlPort.offCmd;
            flow pumpOnCmdFlow of PumpOnCmd
                from controlUnit.pumpControl.onCmd to circPump.controlPort.onCmd;
            flow pumpOffCmdFlow of PumpOffCmd
                from controlUnit.pumpControl.offCmd to circPump.controlPort.offCmd;
            flow primaryThermalFlow of Power
                from primaryHeater.thermalPort.thermalPower to tank.thermalIn.thermalPower;
            flow secondaryThermalFlow of Power
                from secondaryHeater.thermalPort.thermalPower to tank.thermalIn.thermalPower;
            flow pressureFlow of Pressure
                from tank.pressurePort.pressure to safetyValve.pressureIn.pressure;
            flow recircFlow of HotWater
                from tank.recircOut.supplyWater to circPump.waterIn.returnWater;
            flow returnFlow of HotWater
                from circPump.waterOut.supplyWater to tank.recircIn.returnWater;
        }

        requirement def HeatingReqDef {
            doc /* The system shall heat water using a 4500W primary and 2000W secondary heater. */
            attribute primaryPower : Power = 4500;
            attribute secondaryPower : Power = 2000;
            require constraint { primaryPower == 4500 and secondaryPower == 2000 }
        }
        requirement def TemperatureMaintenanceReqDef {
            doc /* The system shall maintain water temperature at the target 60C. */
            attribute currentTemp : Temperature;
            attribute targetTemp : Temperature = 60;
            attribute hysteresis : Temperature = 2;
            require constraint { abs(currentTemp - targetTemp) <= hysteresis }
        }
        requirement def OverTempSafetyReqDef {
            doc /* The system shall shut down heaters if water temperature exceeds 85C. */
            attribute maxSafeTemp : Temperature = 85;
            attribute actualTemp : Temperature;
            require constraint { actualTemp < maxSafeTemp }
        }
        requirement def PressureSafetyReqDef {
            doc /* A mechanical safety valve shall release pressure if it exceeds 600 kPa. */
            attribute maxSafePressure : Pressure = 600000;
            attribute actualPressure : Pressure;
            require constraint { actualPressure <= maxSafePressure }
        }
        requirement def TankCapacityReqDef {
            doc /* The insulated tank shall store 200 liters of water. */
            attribute tankCapacity : Volume = 200;
            attribute actualCapacity : Volume;
            require constraint { actualCapacity >= tankCapacity }
        }
        requirement def EnergyEfficiencyReqDef {
            doc /* The system shall minimize energy loss through tank insulation. */
            attribute insulationRating : Real = 0.95;
            require constraint { insulationRating >= 0.90 }
        }
    }

    package Usages {
        private import Definitions::*;

        part waterHeater : WaterHeaterSystem {
            requirement heatingReq : HeatingReqDef;
            requirement tempMaintenanceReq : TemperatureMaintenanceReqDef;
            requirement overTempSafetyReq : OverTempSafetyReqDef;
            requirement pressureSafetyReq : PressureSafetyReqDef;
            requirement tankCapacityReq : TankCapacityReqDef;
            requirement energyEfficiencyReq : EnergyEfficiencyReqDef;
        }
    }
}
