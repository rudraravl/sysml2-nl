package CryogenicCoolingSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQThermodynamics::*;

    value type TemperatureKelvin > Real { unit "K"; }
    value type PressureBar > Real { unit "bar"; }
    value type VolumeLiter > Real { unit "L"; }
    value type FlowRateLiterPerMin > Real { unit "L/min"; }
    value type ValvePosition > Real { min 0; max 1; }

    item def LiquidNitrogen;
    item def NitrogenGas;

    port def LN2FlowPort {
        out item liquidNitrogen : LiquidNitrogen;
    }
    port def GasFlowPort {
        out item nitrogenGas : NitrogenGas;
    }
    port def ControlSignalPort {
        in attribute value : Real;
    }
    port def SensorSignalPort {
        out attribute value : Real;
    }

    requirement def CoolingRequirement {
        subject target : ThermalLoad;
        objective {
            doc /* The system shall maintain the target temperature at 90 K with a stability of ±1.5 K. */
            require target.actualTemp.value >= 88.5 and target.actualTemp.value <= 91.5
        }
    }

    requirement def SafetyRequirement {
        subject dewar : StorageDewar;
        objective {
            doc /* The system shall vent excess pressure if dewar pressure exceeds 2.5 bar. */
            require dewar.currentPressure.value > 2.5 implies dewar.safetyReliefValve.isOpen == true
        }
    }

    requirement def LowLevelAlarmRequirement {
        subject dewar : StorageDewar;
        objective {
            doc /* The system shall trigger an alarm if LN2 level drops below 20 L. */
            require dewar.currentLevel.value < 20 implies alarmActive == true
        }
    }

    part def ThermalLoad {
        attribute actualTemp : TemperatureKelvin;
        port tempSensorPort : SensorSignalPort;
        port thermalInterface;
    }

    part def StorageDewar {
        attribute capacity : VolumeLiter = 150;
        attribute currentLevel : VolumeLiter;
        attribute currentPressure : PressureBar;
        
        port ln2Supply : LN2FlowPort;
        port gasVent : GasFlowPort;
        
        part safetyReliefValve {
            attribute isOpen : Boolean;
        }
    }

    part def CryogenicSupplyValve {
        attribute position : ValvePosition;
        port ln2In : LN2FlowPort;
        port ln2Out : LN2FlowPort;
        port controlInput : ControlSignalPort;
    }

    part def CryogenicHeatExchanger {
        port ln2In : LN2FlowPort;
        port gasOut : GasFlowPort;
        port thermalInterface;
    }

    part def GasVentSystem {
        port gasIn : GasFlowPort;
        port gasExhaust : GasFlowPort;
    }

    part def TemperatureController {
        attribute targetTemp : TemperatureKelvin = 90.0;
        attribute kp : Real = 1.0;
        attribute ki : Real = 0.1;
        attribute kd : Real = 0.01;
        
        port tempSensorInput : SensorSignalPort;
        port valveControlOutput : ControlSignalPort;
        
        action computePID {
            in actualTemp : TemperatureKelvin;
            in targetTemp : TemperatureKelvin;
            out valvePosition : ValvePosition;
        }
    }

    part def PressureSensor {
        port pressureOutput : SensorSignalPort;
    }

    part def LevelSensor {
        port levelOutput : SensorSignalPort;
    }

    part def CryoCoolingSystem {
        part thermalLoad : ThermalLoad;
        part dewar : StorageDewar;
        part supplyValve : CryogenicSupplyValve;
        part heatExchanger : CryogenicHeatExchanger;
        part gasVent : GasVentSystem;
        part controller : TemperatureController;
        part pressureSensor : PressureSensor;
        part levelSensor : LevelSensor;
        
        attribute alarmActive : Boolean;
        
        satisfy CoolingRequirement {
            subject thermalLoad;
        }
        satisfy SafetyRequirement {
            subject dewar;
        }
        satisfy LowLevelAlarmRequirement {
            subject dewar;
        }

        connection ln2DewarToValve connect dewar.ln2Supply to supplyValve.ln2In;
        connection ln2ValveToHE connect supplyValve.ln2Out to heatExchanger.ln2In;
        connection gasHEToVent connect heatExchanger.gasOut to gasVent.gasIn;
        connection tempSensorToController connect thermalLoad.tempSensorPort to controller.tempSensorInput;
        connection controllerToValve connect controller.valveControlOutput to supplyValve.controlInput;
        
        connection thermalInterface connect heatExchanger.thermalInterface to thermalLoad.thermalInterface;

        state CoolingSystemBehavior {
            state Initialization;
            state Precooling;
            state SteadyStateOperation;
            state EmergencyShutdown;
            
            transition init to Initialization;
            transition Initialization to Precooling when thermalLoad.actualTemp.value > 90.0;
            transition Precooling to SteadyStateOperation when thermalLoad.actualTemp.value <= 90.0;
            transition SteadyStateOperation to Precooling when thermalLoad.actualTemp.value > 91.5;
            transition SteadyStateOperation to EmergencyShutdown when dewar.currentLevel.value < 10.0 or dewar.currentPressure.value > 3.0;
        }
    }
}
