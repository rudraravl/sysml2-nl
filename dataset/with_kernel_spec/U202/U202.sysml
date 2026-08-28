package 'Industrial Dielectric Heating System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        attribute def StartCommand;
        attribute def ResetCommand;
        attribute def ShutdownSignal;

        item def RFEnergy {
            attribute frequency : FrequencyValue;
            attribute power : PowerValue;
        }
        item def CoolantFlow {
            attribute rate : VolumeFlowRateValue;
        }
        item def TemperatureReading {
            attribute value : TemperatureValue;
        }
        item def SafetyStatus {
            attribute doorClosed : Boolean;
            attribute eStopPressed : Boolean;
            attribute tempExceeded : Boolean;
        }

        action def 'Sense Temperature' {
            out temp : TemperatureReading;
        }
        action def 'Compute PID Output' {
            in target : TemperatureValue;
            in actual : TemperatureValue;
            out powerLevel : PowerValue;
        }
        action def 'Generate RF Power' {
            in powerLevel : PowerValue;
            out energy : RFEnergy;
        }
        action def 'Apply Electric Field' {
            in energy : RFEnergy;
        }
        action def 'Circulate Coolant' {
            out flow : CoolantFlow;
        }
        action def 'Monitor Safety' {
            in doorClosed : Boolean;
            in eStop : Boolean;
            in temp : TemperatureReading;
            in maxTemp : TemperatureValue;
            out status : SafetyStatus;
            out shutdown : ShutdownSignal;
        }
        action def 'Shutdown Generator';

        part def 'RF Power Generator' {
            attribute frequency : FrequencyValue = 27.12e6 [Hz];
            port powerCommandPort { in powerLevel : PowerValue; }
            port shutdownPort { in shutdown : ShutdownSignal; }
            port rfOutputPort { out energy : RFEnergy; }
            perform action 'generate rf power' : 'Generate RF Power';
            perform action 'shutdown generator' : 'Shutdown Generator';
        }
        part def 'Dielectric Applicator' {
            port rfInputPort { in energy : RFEnergy; }
            port doorStatusPort { out doorClosed : Boolean; }
            perform action 'apply electric field' : 'Apply Electric Field';
        }
        part def 'Fiber Optic Temperature Sensor' {
            port tempOutputPort { out temp : TemperatureReading; }
            perform action 'sense temperature' : 'Sense Temperature';
        }
        part def 'Heating Controller' {
            attribute targetTemp : TemperatureValue;
            port targetTempPort { in target : TemperatureValue; }
            port sensedTempPort { in sensed : TemperatureReading; }
            port powerCommandPort { out powerLevel : PowerValue; }
            perform action 'compute pid' : 'Compute PID Output';
        }
        part def 'Cooling System' {
            port coolantFlowPort { out flow : CoolantFlow; }
            perform action 'circulate coolant' : 'Circulate Coolant';
        }
        part def 'Safety System' {
            attribute maxSafeTemp : TemperatureValue = 500 [K];
            port doorStatusPort { in doorClosed : Boolean; }
            port eStopPort { in eStop : Boolean; }
            port tempInputPort { in temp : TemperatureReading; }
            port statusPort { out status : SafetyStatus; }
            port shutdownPort { out shutdown : ShutdownSignal; }
            perform action 'monitor safety' : 'Monitor Safety';
        }
        part def 'Emergency Stop Button' {
            port statusPort { out pressed : Boolean; }
        }
        part def 'User Interface' {
            port targetTempPort { out target : TemperatureValue; }
            port commandPort { out start : StartCommand; out reset : ResetCommand; }
        }

        part def 'Dielectric Heating System' {
            attribute targetTemp : TemperatureValue = 400 [K];
            part generator : 'RF Power Generator';
            part applicator : 'Dielectric Applicator';
            part sensor : 'Fiber Optic Temperature Sensor';
            part controller : 'Heating Controller';
            part coolingUnit : 'Cooling System';
            part safety : 'Safety System';
            part eStopButton : 'Emergency Stop Button';
            part userInterface : 'User Interface';
            exhibit state 'system states' : 'System States';
        }

        state def 'System States';

        requirement def 'RF Generation Requirement' {
            doc /* The RF Power Generator shall create high-power, high-frequency electromagnetic energy adjustable by command. */
        }
        requirement def 'Uniform Heating Requirement' {
            doc /* The Dielectric Applicator shall create a uniform electric field across the material for even heating. */
        }
        requirement def 'Temperature Sensing Requirement' {
            doc /* The Temperature Sensor shall use fiber optics to measure material temperature immune to electromagnetic fields. */
        }
        requirement def 'Control Requirement' {
            doc /* The Heating Controller shall use a PID algorithm to calculate power commands based on target and actual temperatures. */
        }
        requirement def 'Cooling Requirement' {
            doc /* The Cooling System shall circulate coolant to manage waste heat from the power generator. */
        }
        requirement def 'Safety Requirement' {
            doc /* The Safety System shall monitor door status, emergency stop, and temperature limits, shutting down the generator on violation. */
        }
    }

    package Usages {
        private import Definitions::*;

        part 'dielectric heating system' : 'Dielectric Heating System' {
            flow rfFlow of RFEnergy
                from generator.rfOutputPort.energy
                to applicator.rfInputPort.energy;
            flow commandFlow of PowerValue
                from controller.powerCommandPort.powerLevel
                to generator.powerCommandPort.powerLevel;
            flow sensedTempFlow of TemperatureReading
                from sensor.tempOutputPort.temp
                to controller.sensedTempPort.sensed;
            flow safetyTempFlow of TemperatureReading
                from sensor.tempOutputPort.temp
                to safety.tempInputPort.temp;
            flow doorStatusFlow of Boolean
                from applicator.doorStatusPort.doorClosed
                to safety.doorStatusPort.doorClosed;
            flow eStopFlow of Boolean
                from eStopButton.statusPort.pressed
                to safety.eStopPort.eStop;
            flow targetTempFlow of TemperatureValue
                from userInterface.targetTempPort.target
                to controller.targetTempPort.target;
            flow shutdownFlow of ShutdownSignal
                from safety.shutdownPort.shutdown
                to generator.shutdownPort.shutdown;

            state 'system states' : 'System States' {
                entry; then standby;

                state standby;
                accept StartCommand
                    then preheating;
                accept when not applicator.doorStatusPort.doorClosed
                    or eStopButton.statusPort.pressed
                    or sensor.tempOutputPort.temp.value > safety.maxSafeTemp
                    do send new ShutdownSignal() to generator
                    then fault;

                state preheating {
                    do generator.'generate rf power' { in powerLevel = 10 [kW]; }
                    do coolingUnit.'circulate coolant';
                }
                accept when sensor.tempOutputPort.temp.value >= 300 [K]
                    then 'active heating';
                accept when not applicator.doorStatusPort.doorClosed
                    or eStopButton.statusPort.pressed
                    or sensor.tempOutputPort.temp.value > safety.maxSafeTemp
                    do send new ShutdownSignal() to generator
                    then fault;

                state 'active heating' {
                    do controller.'compute pid' { in target = controller.targetTemp; in actual = sensor.tempOutputPort.temp.value; out powerLevel; }
                    do generator.'generate rf power' { in powerLevel = controller.'compute pid'.powerLevel; }
                    do coolingUnit.'circulate coolant';
                }
                accept when sensor.tempOutputPort.temp.value >= controller.targetTemp
                    then holding;
                accept when not applicator.doorStatusPort.doorClosed
                    or eStopButton.statusPort.pressed
                    or sensor.tempOutputPort.temp.value > safety.maxSafeTemp
                    do send new ShutdownSignal() to generator
                    then fault;

                state holding {
                    do controller.'compute pid' { in target = controller.targetTemp; in actual = sensor.tempOutputPort.temp.value; out powerLevel; }
                    do generator.'generate rf power' { in powerLevel = controller.'compute pid'.powerLevel; }
                    do coolingUnit.'circulate coolant';
                }
                accept after 3600 [s]
                    then cooling;
                accept when not applicator.doorStatusPort.doorClosed
                    or eStopButton.statusPort.pressed
                    or sensor.tempOutputPort.temp.value > safety.maxSafeTemp
                    do send new ShutdownSignal() to generator
                    then fault;

                state cooling {
                    do generator.'generate rf power' { in powerLevel = 0 [kW]; }
                    do coolingUnit.'circulate coolant';
                }
                accept when sensor.tempOutputPort.temp.value <= 300 [K]
                    then standby;
                accept when not applicator.doorStatusPort.doorClosed
                    or eStopButton.statusPort.pressed
                    or sensor.tempOutputPort.temp.value > safety.maxSafeTemp
                    do send new ShutdownSignal() to generator
                    then fault;

                state fault {
                    entry send new ShutdownSignal() to generator;
                }
                accept ResetCommand
                    then standby;
            }
        }

        requirement 'RF Generation Requirement' : 'RF Generation Requirement';
        requirement 'Uniform Heating Requirement' : 'Uniform Heating Requirement';
        requirement 'Temperature Sensing Requirement' : 'Temperature Sensing Requirement';
        requirement 'Control Requirement' : 'Control Requirement';
        requirement 'Cooling Requirement' : 'Cooling Requirement';
        requirement 'Safety Requirement' : 'Safety Requirement';
    }
}
