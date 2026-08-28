package TGuardSystem {
    import ScalarValues::*;

    package Units {
        unit kelvin;
        unit pascal;
        unit cubicMetrePerSecond;
    }

    package Values {
        import Units::*;

        value def Temperature :> Real {
            unit kelvin;
        }
        value def Pressure :> Real {
            unit pascal;
        }
        value def FlowRate :> Real {
            unit cubicMetrePerSecond;
        }
        value def Aperture :> Real {
            doc /* Valve opening fraction, 0.0 closed, 1.0 fully open. */;
        }
    }

    package Items {
        import Values::*;

        item def TemperatureReading {
            value temperatureValue : Temperature;
        }
        item def PressureReading {
            value pressureValue : Pressure;
        }
        item def ValveCommand {
            value apertureCommand : Aperture;
        }
    }

    package Ports {
        import Items::*;

        port def TemperatureOut {
            out tempStream : TemperatureReading;
        }
        port def TemperatureIn {
            in tempStream : TemperatureReading;
        }
        port def PressureOut {
            out pressStream : PressureReading;
        }
        port def PressureIn {
            in pressStream : PressureReading;
        }
        port def CommandOut {
            out cmdStream : ValveCommand;
        }
        port def CommandIn {
            in cmdStream : ValveCommand;
        }
    }

    package Components {
        import Ports::*;
        import Items::*;
        import Values::*;

        part def TemperatureSensor {
            port tempOut : TemperatureOut;
            attribute measuredTemperature : Temperature;
            attribute samplingPeriod : Real = 0.2;
            attribute operationalMin : Temperature = 273 [kelvin];
            attribute operationalMax : Temperature = 450 [kelvin];

            action sample {
                out reading : TemperatureReading;
                do {
                    reading := TemperatureReading(temperatureValue = measuredTemperature);
                }
            }
        }

        part def PressureSensor {
            port pressOut : PressureOut;
            attribute measuredPressure : Pressure;
            attribute samplingPeriod : Real = 0.2;
            attribute operationalMin : Pressure = 50000 [pascal];
            attribute operationalMax : Pressure = 300000 [pascal];

            action sample {
                out reading : PressureReading;
                do {
                    reading := PressureReading(pressureValue = measuredPressure);
                }
            }
        }

        part def ProtectionController {
            port tempIn : TemperatureIn;
            port pressIn : PressureIn;
            port cmdOut : CommandOut;

            attribute tempWarnThreshold : Temperature = 320 [kelvin];
            attribute tempCritThreshold : Temperature = 340 [kelvin];
            attribute tempEmergThreshold : Temperature = 350 [kelvin];
            attribute pressWarnThreshold : Pressure = 150000 [pascal];
            attribute pressCritThreshold : Pressure = 180000 [pascal];
            attribute pressEmergThreshold : Pressure = 200000 [pascal];

            attribute currentTemp : Temperature;
            attribute currentPress : Pressure;
            attribute commandedAperture : Aperture;
            attribute operationalState : String;

            state machine controllerStateBehavior {
                state Normal {
                    entry { commandedAperture := 1.0; operationalState := "normal"; }
                }
                state Elevated {
                    entry { commandedAperture := 0.6; operationalState := "elevated"; }
                }
                state Critical {
                    entry { commandedAperture := 0.3; operationalState := "critical"; }
                }
                state Emergency {
                    entry { commandedAperture := 0.0; operationalState := "emergency"; }
                }

                transition Normal -> Elevated when (currentTemp >= tempWarnThreshold) or (currentPress >= pressWarnThreshold);
                transition Normal -> Critical when (currentTemp >= tempCritThreshold) or (currentPress >= pressCritThreshold);
                transition Normal -> Emergency when (currentTemp >= tempEmergThreshold) or (currentPress >= pressEmergThreshold);
                transition Elevated -> Critical when (currentTemp >= tempCritThreshold) or (currentPress >= pressCritThreshold);
                transition Elevated -> Emergency when (currentTemp >= tempEmergThreshold) or (currentPress >= pressEmergThreshold);
                transition Critical -> Emergency when (currentTemp >= tempEmergThreshold) or (currentPress >= pressEmergThreshold);
                transition Critical -> Elevated when (currentTemp < tempCritThreshold) and (currentPress < pressCritThreshold);
                transition Elevated -> Normal when (currentTemp < tempWarnThreshold) and (currentPress < pressWarnThreshold);
                transition Critical -> Normal when (currentTemp < tempWarnThreshold) and (currentPress < pressWarnThreshold);
            }

            action monitor {
                in temp : TemperatureReading;
                in press : PressureReading;
                out cmd : ValveCommand;
                do {
                    currentTemp := temp.temperatureValue;
                    currentPress := press.pressureValue;
                    cmd := ValveCommand(apertureCommand = commandedAperture);
                }
            }
        }

        part def ControlValve {
            port cmdIn : CommandIn;
            attribute currentAperture : Aperture;
            attribute flowRate : FlowRate;
            attribute maxFlowRate : FlowRate = 0.1 [cubicMetrePerSecond];
            attribute actuationTime : Real = 0.1;

            action actuate {
                in command : ValveCommand;
                do {
                    currentAperture := command.apertureCommand;
                    flowRate := maxFlowRate * currentAperture;
                }
            }
        }
    }

    package Assembly {
        import Components::*;

        part def TGuard {
            part temperatureSensor : TemperatureSensor;
            part pressureSensor : PressureSensor;
            part controller : ProtectionController;
            part valve : ControlValve;

            connect temperatureSensor.tempOut to controller.tempIn;
            connect pressureSensor.pressOut to controller.pressIn;
            connect controller.cmdOut to valve.cmdIn;
        }
    }

    package Requirements {
        import Assembly::*;
        import Values::*;

        requirement def ContinuousMonitoring {
            subject tguard : TGuard;
            doc /* The TGuard system shall continuously monitor the fluid line temperature and pressure. */;
            require tguard.temperatureSensor.measuredTemperature updates regularly and tguard.pressureSensor.measuredPressure updates regularly;
        }

        requirement def AutonomousOperation {
            subject tguard : TGuard;
            doc /* The TGuard shall operate autonomously, requiring no manual intervention. */;
        }

        requirement def NormalValveAperture {
            subject tguard : TGuard;
            doc /* In the normal operational state, the control valve shall remain fully open (aperture = 1.0). */;
            require {
                when tguard.controller.operationalState == "normal"
                that tguard.valve.currentAperture == 1.0;
            }
        }

        requirement def ElevatedValveAperture {
            subject tguard : TGuard;
            doc /* In the elevated operational state, the control valve shall be partially closed (aperture = 0.6). */;
            require {
                when tguard.controller.operationalState == "elevated"
                that tguard.valve.currentAperture == 0.6;
            }
        }

        requirement def CriticalValveAperture {
            subject tguard : TGuard;
            doc /* In the critical operational state, the control valve shall be mostly closed (aperture = 0.3). */;
            require {
                when tguard.controller.operationalState == "critical"
                that tguard.valve.currentAperture == 0.3;
            }
        }

        requirement def EmergencyShutdown {
            subject tguard : TGuard;
            doc /* In the emergency operational state, the control valve shall be fully closed (aperture = 0.0), halting fluid flow. */;
            require {
                when tguard.controller.operationalState == "emergency"
                that tguard.valve.currentAperture == 0.0 and tguard.valve.flowRate == 0.0 [cubicMetrePerSecond];
            }
        }

        requirement def SensorSamplingRate {
            subject tguard : TGuard;
            attribute minSamplingRate : Real = 5.0;
            doc /* The TGuard system shall sample sensor readings at least 5 times per second. */;
            require (1.0 / tguard.temperatureSensor.samplingPeriod) >= minSamplingRate and (1.0 / tguard.pressureSensor.samplingPeriod) >= minSamplingRate;
        }
    }
}
