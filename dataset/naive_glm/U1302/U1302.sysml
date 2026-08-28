package TemperatureControlSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def Voltage :> Real {
        unit 'V';
    }
    value def Current :> Real {
        unit 'A';
    }
    value def Power :> Real {
        unit 'W';
    }
    value def TemperatureValue :> Real {
        unit 'degC';
    }
    value def AnalogSignal :> Real {
        unit 'V';
    }
    value def DigitalReading :> Integer;
    value def ControlSignal :> String;

    // ===== Items =====
    item def AmbientAir;
    item def ThermalEnergy;
    item def PowerLossEvent;
    item def CriticalErrorEvent;

    // ===== Interfaces / Port Definitions =====
    interface def PowerInterface {
        end supplier : Voltage;
        end current : Current;
    }
    interface def AnalogTempInterface {
        end voltageSignal : AnalogSignal;
    }
    interface def DigitalControlInterface {
        end command : ControlSignal;
    }
    interface def ThermalInterface {
        end heat : ThermalEnergy;
    }

    port def PowerPort :> PowerInterface;
    port def AnalogTempPort :> AnalogTempInterface;
    port def DigitalControlPort :> DigitalControlInterface;
    port def ThermalPort :> ThermalInterface;

    // ===== Requirements =====
    requirement def TemperatureStabilityRequirement {
        doc /* The system shall maintain ambient temperature within +/- 1 degC of the target temperature. */
        attribute targetTemperature : TemperatureValue = 25 [degC];
        attribute tolerance : TemperatureValue = 1 [degC];
        subject : TemperatureControlSystem;
        require constraint { abs(subject.measuredTemperature - targetTemperature) <= tolerance }
    }

    requirement def ContinuousMonitoringRequirement {
        doc /* The system shall continuously monitor ambient temperature using two sensors. */
        subject : TemperatureControlSystem;
        require constraint { subject.sensorCount == 2 }
    }

    requirement def PowerRobustnessRequirement {
        doc /* The microcontroller shall enter sleep mode on power loss and recover on power restoration. */
        subject : Microcontroller;
        require constraint { subject.canRecoverFromPowerLoss == true }
    }

    requirement def ErrorHandlingRequirement {
        doc /* The microcontroller shall execute a shutdown and recovery process on critical errors. */
        subject : Microcontroller;
        require constraint { subject.hasErrorRecovery == true }
    }

    // ===== Part Definitions =====
    part def PowerSupply {
        attribute outputVoltage : Voltage = 5 [V];
        attribute outputCurrent : Current = 2 [A];
        attribute outputPower : Power = 10 [W];
        port powerOut : PowerPort;
    }

    part def TemperatureSensor {
        attribute sensorId : String;
        attribute minRange : TemperatureValue = -20 [degC];
        attribute maxRange : TemperatureValue = 80 [degC];
        attribute sensitivity : Real = 0.01 [V/degC];
        port powerIn : PowerPort;
        port analogOut : AnalogTempPort;
        attribute measuredVoltage : AnalogSignal = 0 [V];
        action def senseTemperature {
            in ambient : AmbientAir;
            out signal : AnalogSignal;
        }
        perform senseTemperature;
    }

    part def HeatingElement {
        attribute maxPower : Power = 50 [W];
        attribute isActive : Boolean = false;
        port powerIn : PowerPort;
        port controlIn : DigitalControlPort;
        port heatOut : ThermalPort;
        action def generateHeat {
            in command : ControlSignal;
            out heat : ThermalEnergy;
        }
        perform generateHeat;
    }

    part def ADC {
        attribute resolution : DigitalReading = 12;
        attribute referenceVoltage : Voltage = 3.3 [V];
        port analogIn : AnalogTempPort[2];
        port digitalOut : DigitalControlPort[2];
        action def convert {
            in analog : AnalogSignal;
            out digital : DigitalReading;
        }
        perform convert;
    }

    part def Microcontroller {
        attribute targetTemperature : TemperatureValue = 25 [degC];
        attribute tolerance : TemperatureValue = 1 [degC];
        attribute canRecoverFromPowerLoss : Boolean = true;
        attribute hasErrorRecovery : Boolean = true;
        attribute measuredTemperature : TemperatureValue = 25 [degC];
        attribute sensorCount : Integer = 2;
        port powerIn : PowerPort;
        port adcDigitalIn : DigitalControlPort[2];
        port heaterControlOut : DigitalControlPort;
        part adc : ADC;
        state def MicrocontrollerStates {
            entry; then Active;
            state Active {
                entry; then Running;
                state Running;
                transition Running_to_Heating
                    first Running
                    if measuredTemperature < (targetTemperature - tolerance)
                    then Heating;
                transition Heating_to_Running
                    first Heating
                    if measuredTemperature >= targetTemperature
                    then Running;
                state Heating;
                transition Running_to_Sleep
                    first Running
                    if powerLossDetected
                    then Sleep;
                transition Heating_to_Sleep
                    first Heating
                    if powerLossDetected
                    then Sleep;
            }
            state Sleep {
                entry action { /* enter low-power mode */ }
                transition Sleep_to_Active
                    first Sleep
                    if powerRestored
                    then Active;
            }
            state ShutdownRecovery {
                entry action { /* critical error handling */ }
                transition ShutdownRecovery_to_Active
                    first ShutdownRecovery
                    if errorResolved
                    then Active;
            }
            transition Active_to_ShutdownRecovery
                first Active
                if criticalErrorDetected
                then ShutdownRecovery;
        }
        attribute powerLossDetected : Boolean = false;
        attribute powerRestored : Boolean = false;
        attribute criticalErrorDetected : Boolean = false;
        attribute errorResolved : Boolean = false;
        perform MicrocontrollerStates;
        action def ControlLoop {
            in digitalReadings : DigitalReading[2];
            out heaterCommand : ControlSignal;
            action readSensors;
            action computeAverageTemperature {
                in readings : DigitalReading[2];
                out avgTemp : TemperatureValue;
            }
            action compareWithTarget {
                in currentTemp : TemperatureValue;
                in target : TemperatureValue;
                out command : ControlSignal;
            }
            action sendControlSignal {
                in command : ControlSignal;
            }
            flow readSensors.digitalReadings -> computeAverageTemperature.readings;
            flow computeAverageTemperature.avgTemp -> compareWithTarget.currentTemp;
            flow compareWithTarget.command -> sendControlSignal.command;
        }
        perform ControlLoop;
    }

    part def TemperatureControlSystem {
        attribute measuredTemperature : TemperatureValue = 25 [degC];
        attribute sensorCount : Integer = 2;
        part powerSupply : PowerSupply;
        part microcontroller : Microcontroller;
        part sensor1 : TemperatureSensor {
            attribute sensorId = "S1";
        }
        part sensor2 : TemperatureSensor {
            attribute sensorId = "S2";
        }
        part heater : HeatingElement;
        item ambientAir : AmbientAir;
        item thermalEnergy : ThermalEnergy;
        satisfy TemperatureStabilityRequirement by microcontroller;
        satisfy ContinuousMonitoringRequirement by microcontroller;
        satisfy PowerRobustnessRequirement by microcontroller;
        satisfy ErrorHandlingRequirement by microcontroller;
        connection powerSupplyToMicrocontroller : PowerInterface connect powerSupply.powerOut to microcontroller.powerIn;
        connection powerSupplyToSensor1 : PowerInterface connect powerSupply.powerOut to sensor1.powerIn;
        connection powerSupplyToSensor2 : PowerInterface connect powerSupply.powerOut to sensor2.powerIn;
        connection powerSupplyToHeater : PowerInterface connect powerSupply.powerOut to heater.powerIn;
        connection sensor1ToADC : AnalogTempInterface connect sensor1.analogOut to microcontroller.adc.analogIn[1];
        connection sensor2ToADC : AnalogTempInterface connect sensor2.analogOut to microcontroller.adc.analogIn[2];
        connection adcToMicrocontroller1 : DigitalControlInterface connect microcontroller.adc.digitalOut[1] to microcontroller.adcDigitalIn[1];
        connection adcToMicrocontroller2 : DigitalControlInterface connect microcontroller.adc.digitalOut[2] to microcontroller.adcDigitalIn[2];
        connection microcontrollerToHeater : DigitalControlInterface connect microcontroller.heaterControlOut to heater.controlIn;
        connection heaterToEnvironment : ThermalInterface connect heater.heatOut to ambientAir;
    }
}
