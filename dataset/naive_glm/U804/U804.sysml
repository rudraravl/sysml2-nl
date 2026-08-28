package IndustrialSafetySystem {
    import ScalarValues::*;
    import ISQ::*;

    value def Voltage :> Real { unit "V"; }
    value def Resistance :> Real { unit "ohm"; }
    value def Temperature :> Real { unit "degC"; }
    value def Concentration :> Real { unit "%LEL"; }
    value def Current :> Real { unit "A"; }

    item def CombustibleGas;
    item def ElectricalPower;
    item def AlarmSignal;

    requirement def CombustibleGasDetectionReq {
        doc "The system shall detect and monitor combustible gases to prevent explosions."
    }
    requirement def PellistorOperationReq {
        doc "The Pellistor sensor shall use a catalytic bead and a compensation bead in a Wheatstone bridge configuration."
    }
    requirement def SignalConditioningReq {
        doc "The signal conditioner shall amplify and filter the raw voltage signal."
    }
    requirement def ConcentrationCalculationReq {
        doc "The concentration calculator shall convert conditioned voltage to %LEL."
    }
    requirement def AlarmControlReq {
        doc "The alarm controller shall monitor concentration and trigger alarms based on thresholds."
    }

    port def PowerPort {
        out power : ElectricalPower;
    }
    port def VoltagePort {
        out voltage : Voltage;
    }
    port def ConcentrationPort {
        out concentration : Concentration;
    }
    port def AlarmPort {
        out alarm : AlarmSignal;
    }

    part def PowerModule {
        port powerOut : PowerPort;
        attribute outputVoltage : Voltage = 5.0;
    }

    part def CatalyticBead {
        attribute resistance : Resistance;
        attribute temperature : Temperature;
        port powerIn : PowerPort;
        port gasIn;
    }

    part def CompensationBead {
        attribute resistance : Resistance;
        attribute temperature : Temperature;
        port powerIn : PowerPort;
    }

    part def WheatstoneBridge {
        port powerIn : PowerPort;
        port voltageOut : VoltagePort;
        
        part catalyticBead : CatalyticBead;
        part compensationBead : CompensationBead;
        
        connection powerToCatalytic : powerIn to catalyticBead.powerIn;
        connection powerToCompensation : powerIn to compensationBead.powerIn;
        
        action calculateBridgeVoltage {
            in catalyticResistance : Resistance;
            in compensationResistance : Resistance;
            out voltage : Voltage;
        }
    }

    part def PellistorSensor {
        satisfy PellistorOperationReq;
        port powerIn : PowerPort;
        port voltageOut : VoltagePort;
        
        part bridge : WheatstoneBridge;
        
        connection powerToBridge : powerIn to bridge.powerIn;
        connection voltageFromBridge : bridge.voltageOut to voltageOut;
    }

    part def SignalConditioner {
        satisfy SignalConditioningReq;
        port powerIn : PowerPort;
        port voltageIn : VoltagePort;
        port voltageOut : VoltagePort;
        
        action conditionSignal {
            in rawVoltage : Voltage;
            out conditionedVoltage : Voltage;
        }
    }

    part def ConcentrationCalculator {
        satisfy ConcentrationCalculationReq;
        port powerIn : PowerPort;
        port voltageIn : VoltagePort;
        port concentrationOut : ConcentrationPort;
        
        attribute calibrationFactor : Real = 1.0;
        
        action calculateConcentration {
            in voltage : Voltage;
            out concentration : Concentration;
        }
    }

    part def AlarmController {
        satisfy AlarmControlReq;
        port powerIn : PowerPort;
        port concentrationIn : ConcentrationPort;
        port alarmOut : AlarmPort;
        
        attribute warningThreshold : Concentration = 10.0;
        attribute alarmThreshold : Concentration = 25.0;
        attribute currentConcentration : Concentration;
        
        state def ControllerStates {
            state Normal;
            state Warning;
            state Alarm;
            
            transition Normal to Warning 
                if currentConcentration > warningThreshold;
            transition Warning to Alarm 
                if currentConcentration > alarmThreshold;
            transition Warning to Normal 
                if currentConcentration <= warningThreshold;
            transition Alarm to Warning 
                if currentConcentration <= alarmThreshold;
        }
        
        exhibit state ControllerStates;
    }

    part def IndustrialSafetySystem {
        satisfy CombustibleGasDetectionReq;
        
        part powerModule : PowerModule;
        part sensor : PellistorSensor;
        part conditioner : SignalConditioner;
        part calculator : ConcentrationCalculator;
        part alarmController : AlarmController;
        
        connection powerToSensor : powerModule.powerOut to sensor.powerIn;
        connection powerToConditioner : powerModule.powerOut to conditioner.powerIn;
        connection powerToCalculator : powerModule.powerOut to calculator.powerIn;
        connection powerToAlarm : powerModule.powerOut to alarmController.powerIn;
        
        connection sensorToConditioner : sensor.voltageOut to conditioner.voltageIn;
        connection conditionerToCalculator : conditioner.voltageOut to calculator.voltageIn;
        connection calculatorToAlarm : calculator.concentrationOut to alarmController.concentrationIn;
    }
}
