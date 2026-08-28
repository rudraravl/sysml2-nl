package 'Liquid Nitrogen Cryogenic Cooling System' {
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def TempK :> Real;
    attribute def PressPa :> Real;
    attribute def VolL :> Real;
    attribute def ValveOpeningPct :> Real;

    item def LN2;
    item def NitrogenGas;
    item def InitializationComplete;

    item def TemperatureReading {
        attribute value : TempK;
    }
    item def PressureReading {
        attribute value : PressPa;
    }
    item def LevelReading {
        attribute value : VolL;
    }
    item def ValveCommand {
        attribute opening : ValveOpeningPct;
    }
    item def RefillAlarm;

    action def InitializeSystem {
        language "Alf"
        /*
         * Perform startup self-checks on all sensors, valves, and controller.
         * Emit InitializationComplete when all checks pass.
         */
    }

    action def PrecoolThermalLoad {
        language "Alf"
        /*
         * Open the cryogenic supply valve to maximum LN2 flow
         * to rapidly bring the thermal load temperature down to 90 K.
         */
    }

    action def RegulateTemperature {
        in sensorReading : TemperatureReading;
        in targetTemp : TempK;
        out valveCommand : ValveCommand;
        language "Alf"
        /*
         * error = targetTemp - sensorReading.value;
         * integral = integral + error * dt;
         * derivative = (error - previousError) / dt;
         * opening = clamp(Kp * error + Ki * integral + Kd * derivative, 0, 100);
         * valveCommand = new ValveCommand(opening);
         */
    }

    action def OpenReliefValve {
        language "Alf"
        /*
         * Command the safety relief valve to open and vent excess nitrogen gas.
         */
    }

    state def CryogenicSystemStates;
    state def ReliefValveStates;

    part def TemperatureSensor {
        port sensedOut {
            out reading : TemperatureReading;
        }
    }

    part def PressureSensor {
        port pressureOut {
            out reading : PressureReading;
        }
    }

    part def LevelSensor {
        port levelOut {
            out reading : LevelReading;
        }
    }

    part def SafetyReliefValve {
        port pressureIn {
            in pressure : PressureReading;
        }
        port gasOut {
            out gas : NitrogenGas;
        }
        exhibit state reliefStates : ReliefValveStates {
            entry; then closed;
            state closed;
            transition closed_to_open
                first closed
                accept PressureReading
                if pressureIn.pressure.value > 100000.0
                then open;
            state open;
            transition open_to_closed
                first open
                accept PressureReading
                if pressureIn.pressure.value <= 100000.0
                then closed;
        }
    }

    part def ThermalLoad {
        part tempSensor : TemperatureSensor;
    }

    part def StorageDewar {
        attribute capacity : VolL = 150.0;
        part pressSensor : PressureSensor;
        part levelSensor : LevelSensor;
        part reliefValve : SafetyReliefValve;
        port ln2Out {
            out liquid : LN2;
        }
        flow pressureToReliefFlow of PressureReading
            from pressSensor.pressureOut.reading
            to reliefValve.pressureIn.pressure;
    }

    part def CryogenicSupplyValve {
        port cmdIn {
            in cmd : ValveCommand;
        }
        port ln2In {
            in liquid : LN2;
        }
        port ln2Out {
            out liquid : LN2;
        }
    }

    part def CryogenicHeatExchanger {
        port ln2In {
            in liquid : LN2;
        }
        port gasOut {
            out gas : NitrogenGas;
        }
    }

    part def ReturnValve {
        port gasIn {
            in gas : NitrogenGas;
        }
        port gasOut {
            out gas : NitrogenGas;
        }
    }

    part def GasVentSystem {
        port gasIn {
            in gas : NitrogenGas;
        }
        port reliefGasIn {
            in gas : NitrogenGas;
        }
    }

    part def OperatorAlarm {
        port alarmIn {
            in alarm : RefillAlarm;
        }
    }

    part def TemperatureController {
        attribute targetTemp : TempK = 90.0;
        attribute stability : TempK = 1.5;
        port tempIn {
            in temp : TemperatureReading;
        }
        port levelIn {
            in level : LevelReading;
        }
        port pressureIn {
            in pressure : PressureReading;
        }
        port valveCmdOut {
            out cmd : ValveCommand;
        }
        port alarmOut {
            out alarm : RefillAlarm;
        }
    }

    part def CryogenicCoolingSystem {
        attribute targetTemperature : TempK = 90.0;
        attribute maxPressure : PressPa = 100000.0;
        attribute lowLevelThreshold : VolL = 20.0;

        part thermalLoad : ThermalLoad;
        part dewar : StorageDewar;
        part supplyValve : CryogenicSupplyValve;
        part heatExchanger : CryogenicHeatExchanger;
        part returnValve : ReturnValve;
        part ventSystem : GasVentSystem;
        part controller : TemperatureController;
        part operatorAlarm : OperatorAlarm;

        flow ln2SupplyFlow of LN2
            from dewar.ln2Out.liquid
            to supplyValve.ln2In.liquid;
        flow ln2ToHxFlow of LN2
            from supplyValve.ln2Out.liquid
            to heatExchanger.ln2In.liquid;
        flow gasToReturnFlow of NitrogenGas
            from heatExchanger.gasOut.gas
            to returnValve.gasIn.gas;
        flow gasVentFlow of NitrogenGas
            from returnValve.gasOut.gas
            to ventSystem.gasIn.gas;
        flow reliefGasFlow of NitrogenGas
            from dewar.reliefValve.gasOut.gas
            to ventSystem.reliefGasIn.gas;

        flow tempReadingFlow of TemperatureReading
            from thermalLoad.tempSensor.sensedOut.reading
            to controller.tempIn.temp;
        flow levelReadingFlow of LevelReading
            from dewar.levelSensor.levelOut.reading
            to controller.levelIn.level;
        flow pressureReadingFlow of PressureReading
            from dewar.pressSensor.pressureOut.reading
            to controller.pressureIn.pressure;

        flow valveCmdFlow of ValveCommand
            from controller.valveCmdOut.cmd
            to supplyValve.cmdIn.cmd;

        flow alarmFlow of RefillAlarm
            from controller.alarmOut.alarm
            to operatorAlarm.alarmIn.alarm;

        exhibit state systemStates : CryogenicSystemStates {
            entry; then initialization;

            state initialization {
                entry action InitializeSystem;
            }

            transition init_to_precooling
                first initialization
                accept InitializationComplete
                then precooling;

            state precooling {
                entry action PrecoolThermalLoad;
            }

            transition precool_to_steady
                first precooling
                accept TemperatureReading
                if thermalLoad.tempSensor.sensedOut.reading.value <= targetTemperature
                then steadyState;

            state steadyState {
                do action regulate : RegulateTemperature {
                    in sensorReading = thermalLoad.tempSensor.sensedOut.reading;
                    in targetTemp = targetTemperature;
                    out valveCommand = controller.valveCmdOut.cmd;
                }
            }

            state lowLevelAlarm;
            state overPressureVent {
                entry action openRelief : OpenReliefValve;
            }

            transition steady_to_lowLevel
                first steadyState
                accept LevelReading
                if dewar.levelSensor.levelOut.reading.value <= lowLevelThreshold
                do send new RefillAlarm() to operatorAlarm
                then lowLevelAlarm;

            transition lowLevel_to_steady
                first lowLevelAlarm
                accept LevelReading
                if dewar.levelSensor.levelOut.reading.value > lowLevelThreshold
                then steadyState;

            transition steady_to_overPressure
                first steadyState
                accept PressureReading
                if dewar.pressSensor.pressureOut.reading.value > maxPressure
                then overPressureVent;

            transition overPressure_to_steady
                first overPressureVent
                accept PressureReading
                if dewar.pressSensor.pressureOut.reading.value <= maxPressure
                then steadyState;
        }
    }

    requirement def 'Stable Cryogenic Temperature' {
        doc /* The system shall maintain the thermal load at 90 K with stability within ±1.5 K during steady-state operation. */
        attribute targetTemp : TempK = 90.0;
        attribute stability : TempK = 1.5;
    }

    requirement def 'Overpressure Protection' {
        doc /* The system shall automatically vent nitrogen gas when dewar pressure exceeds 100000 Pa. */
    }

    requirement def 'Low Level Alarm' {
        doc /* The system shall notify the operator when the LN2 level falls below 20 liters. */
    }

    requirement def 'Cryogenic Cooling Capacity' {
        doc /* The storage dewar shall hold a minimum of 150 liters of liquid nitrogen. */
    }
}
