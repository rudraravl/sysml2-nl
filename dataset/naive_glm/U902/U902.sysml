package SQUIDMagnetometer {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    attribute def MagneticFlux :> Real { unit 'Wb'; }
    attribute def MagneticFluxDensity :> Real { unit 'T'; }
    attribute def Voltage :> Real { unit 'V'; }
    attribute def Current :> Real { unit 'A'; }
    attribute def Temperature :> Real { unit 'K'; }
    attribute def Resistance :> Real { unit 'Ω'; }
    attribute def Inductance :> Real { unit 'H'; }
    attribute def Capacitance :> Real { unit 'F'; }
    attribute def Frequency :> Real { unit 'Hz'; }
    attribute def Power :> Real { unit 'W'; }
    attribute def Dimensionless :> Real { }

    // ===== Item Types =====
    item def MagneticField {
        attribute fluxDensity : MagneticFluxDensity;
        attribute direction : Angle;
    }
    item def FluxQuantum {
        attribute value : MagneticFlux = 2.067833848e-15 [Wb];
    }
    item def ElectricalSignal {
        attribute voltage : Voltage;
        attribute frequency : Frequency;
    }
    item def DigitalData {
        attribute fieldStrength : MagneticFluxDensity;
        attribute timestamp : Time;
        attribute quality : Dimensionless;
    }
    item def Coolant {
        attribute temperature : Temperature;
        attribute flowRate : VolumeFlowRate;
    }
    item def ThermalEnergy {
        attribute temperature : Temperature;
    }

    // ===== Port Definitions =====
    port def MagneticPort {
        out field : MagneticField;
    }
    port def FluxPort {
        out flux : MagneticFlux;
    }
    port def ElectricalPort {
        out signal : ElectricalSignal;
        in bias : Current;
    }
    port def ThermalPort {
        out thermal : ThermalEnergy;
    }
    port def DataPort {
        out data : DigitalData;
    }
    port def ControlPort {
        in command : String;
        out status : String;
    }

    // ===== Requirements =====
    requirement def SuperconductivityRequirement {
        subject sensorTemp : Temperature;
        require sensorTemp <= 4.2 [K];
    }

    requirement def SensitivityRequirement {
        subject minField : MagneticFluxDensity;
        require minField <= 1e-15 [T];
    }

    requirement def ShieldingRequirement {
        subject attenuation : Dimensionless;
        require attenuation >= 1000.0;
    }

    requirement def BiasStabilityRequirement {
        subject biasCurrent : Current;
        require biasCurrent == 20e-6 [A] :± 0.1e-6 [A];
    }

    requirement def OperatingTemperatureRequirement {
        subject opTemp : Temperature;
        require opTemp >= 4.0 [K] and opTemp <= 4.4 [K];
    }

    // ===== Parts =====

    part def JosephsonJunction {
        attribute criticalCurrent : Current = 2.5e-6 [A];
        attribute resistance : Resistance = 1.0 [Ω];
        attribute capacitance : Capacitance = 1e-12 [F];
        port in biasInput : Current;
        port out voltageOutput : Voltage;
        port in thermalInput : ThermalEnergy;

        action tunnelElectronPairs : Action {
            in bias : Current;
            in flux : MagneticFlux;
            out voltage : Voltage;
        }
    }

    part def SuperconductingLoop {
        attribute loopInductance : Inductance = 100e-12 [H];
        attribute loopArea : Area = 1e-8 [m^2];
        attribute operatingTemp : Temperature;
        port in thermalInput : ThermalEnergy;
        port in fluxInput : MagneticFlux;
        port out voltageOutput : Voltage;
        port in biasInput : Current;

        part junction1 : JosephsonJunction {
            redefines criticalCurrent = 2.5e-6 [A];
        }
        part junction2 : JosephsonJunction {
            redefines criticalCurrent = 2.5e-6 [A];
        }

        action induceScreeningCurrent : Action {
            in flux : MagneticFlux;
            out screeningCurrent : Current;
        }

        action generateVoltage : Action {
            in screeningCurrent : Current;
            in bias : Current;
            out voltage : Voltage;
        }
    }

    part def SQUIDSensor {
        attribute sensitivity : MagneticFluxDensity = 1e-15 [T];
        attribute operatingTemp : Temperature;
        port in thermalInput : ThermalEnergy;
        port in fluxInput : MagneticFlux;
        port in biasInput : Current;
        port out signalOutput : ElectricalSignal;

        part loop : SuperconductingLoop {
            redefines loopInductance = 100e-12 [H];
        }

        satisfy SuperconductivityRequirement {
            subject = operatingTemp;
        }
        satisfy SensitivityRequirement {
            subject = sensitivity;
        }
    }

    part def CryogenicSystem {
        attribute targetTemp : Temperature = 4.2 [K];
        attribute currentTemp : Temperature;
        attribute coolingPower : Power = 1.0 [W];
        attribute coolantFlowRate : VolumeFlowRate;
        port out thermalOutput : ThermalEnergy;
        port in controlInput : ControlPort;

        part coolantReservoir {
            attribute capacity : Volume = 100e-3 [m^3];
            attribute fillLevel : Real;
        }

        part compressor {
            attribute power : Power = 100.0 [W];
        }

        part temperatureSensor {
            attribute measuredTemp : Temperature;
        }

        action coolDown : Action {
            in initialTemp : Temperature;
            out finalTemp : Temperature;
        }

        action maintainTemperature : Action {
            in setpoint : Temperature;
            out actual : Temperature;
        }

        satisfy OperatingTemperatureRequirement {
            subject = currentTemp;
        }
    }

    part def MagneticShield {
        attribute attenuationFactor : Dimensionless = 10000.0;
        attribute layers : Integer = 3;
        attribute material : String = "MuMetal";
        port in externalField : MagneticField;
        port out attenuatedField : MagneticField;

        action attenuateField : Action {
            in inputField : MagneticField;
            out outputField : MagneticField;
        }

        satisfy ShieldingRequirement {
            subject = attenuationFactor;
        }
    }

    part def FluxTransformer {
        attribute pickupCoilArea : Area = 1e-4 [m^2];
        attribute pickupCoilTurns : Integer = 100;
        attribute couplingCoefficient : Dimensionless = 0.95;
        port in externalField : MagneticField;
        port out fluxOutput : MagneticFlux;

        part pickupCoil {
            attribute area : Area = 1e-4 [m^2];
            attribute turns : Integer = 100;
            attribute inductance : Inductance = 1e-6 [H];
        }

        part inputCoil {
            attribute turns : Integer = 10;
            attribute inductance : Inductance = 1e-9 [H];
        }

        action gatherField : Action {
            in field : MagneticField;
            out flux : MagneticFlux;
        }

        action transferFlux : Action {
            in flux : MagneticFlux;
            out coupledFlux : MagneticFlux;
        }
    }

    part def BiasCurrentSource {
        attribute outputCurrent : Current = 20e-6 [A];
        attribute stability : Dimensionless = 1e-6;
        attribute voltageCompliance : Voltage = 5.0 [V];
        port out biasOutput : Current;
        port in controlInput : ControlPort;

        action generateBiasCurrent : Action {
            out bias : Current;
        }

        satisfy BiasStabilityRequirement {
            subject = outputCurrent;
        }
    }

    part def ReadoutElectronics {
        attribute gain : Dimensionless = 10000.0;
        attribute bandwidth : Frequency = 100e3 [Hz];
        attribute noiseFloor : Voltage = 1e-9 [V];
        attribute resolution : Integer = 24;
        port in signalInput : ElectricalSignal;
        port out dataOutput : DigitalData;
        port in controlInput : ControlPort;

        part preamplifier {
            attribute gain : Dimensionless = 1000.0;
            attribute noise : Voltage = 0.5e-9 [V];
        }

        part filter {
            attribute cutoffLow : Frequency = 1.0 [Hz];
            attribute cutoffHigh : Frequency = 10e3 [Hz];
            attribute order : Integer = 4;
        }

        part adc {
            attribute resolution : Integer = 24;
            attribute sampleRate : Frequency = 100e3 [Hz];
        }

        action amplifySignal : Action {
            in signal : ElectricalSignal;
            out amplified : ElectricalSignal;
        }

        action filterNoise : Action {
            in signal : ElectricalSignal;
            out filtered : ElectricalSignal;
        }

        action digitize : Action {
            in signal : ElectricalSignal;
            out data : DigitalData;
        }
    }

    part def Controller {
        attribute state : String;
        port out controlOutput : ControlPort;
        port in statusInput : ControlPort;

        action manageOperation : Action {
            in status : String;
            out command : String;
        }
    }

    // ===== Top-level System =====
    part def SQUIDMagnetometerSystem {
        attribute systemID : String = "SQUID-MAG-001";
        attribute manufacturer : String = "Quantum Instruments";
        attribute maxFieldRange : MagneticFluxDensity = 1e-9 [T];

        port in externalMagneticField : MagneticPort;
        port out measurementData : DataPort;
        port in systemControl : ControlPort;

        part shield : MagneticShield {
            redefines attenuationFactor = 10000.0;
            redefines layers = 3;
        }

        part fluxTransformer : FluxTransformer {
            redefines pickupCoilArea = 1e-4 [m^2];
            redefines couplingCoefficient = 0.95;
        }

        part squidSensor : SQUIDSensor {
            redefines sensitivity = 1e-15 [T];
        }

        part cryogenicSystem : CryogenicSystem {
            redefines targetTemp = 4.2 [K];
            redefines coolingPower = 1.0 [W];
        }

        part biasSource : BiasCurrentSource {
            redefines outputCurrent = 20e-6 [A];
        }

        part readout : ReadoutElectronics {
            redefines gain = 10000.0;
            redefines bandwidth = 100e3 [Hz];
        }

        part controller : Controller;

        // Connections
        connection externalFieldToShield : MagneticPort = systemControl::command > shield.externalField;
        connection shieldToTransformer : MagneticPort = shield.attenuatedField > fluxTransformer.externalField;
        connection transformerToSensor : FluxPort = fluxTransformer.fluxOutput > squidSensor.fluxInput;
        connection cryoToSensor : ThermalPort = cryogenicSystem.thermalOutput > squidSensor.thermalInput;
        connection cryoToTransformer : ThermalPort = cryogenicSystem.thermalOutput > fluxTransformer.thermalInput;
        connection biasToSensor : ElectricalPort = biasSource.biasOutput > squidSensor.biasInput;
        connection sensorToReadout : ElectricalPort = squidSensor.signalOutput > readout.signalInput;
        connection readoutToOutput : DataPort = readout.dataOutput > measurementData.data;
        connection controllerToCryo : ControlPort = controller.controlOutput > cryogenicSystem.controlInput;
        connection controllerToBias : ControlPort = controller.controlOutput > biasSource.controlInput;
        connection controllerToReadout : ControlPort = controller.controlOutput > readout.controlInput;

        // ===== State Machine =====
        state def SQUIDOperatingStates {
            entry action assignInitial {
                controller.state = "Idle";
            }

            state Idle {
                entry action enterIdle {
                    controller.state = "Idle";
                    cryogenicSystem.currentTemp = 300.0 [K];
                }
                do action waitForStart {
                    controller.manageOperation();
                }
            }

            state Cooldown {
                entry action enterCooldown {
                    controller.state = "Cooldown";
                    cryogenicSystem.coolDown();
                }
                do action cooling {
                    cryogenicSystem.maintainTemperature();
                }
            }

            state Stabilizing {
                entry action enterStabilizing {
                    controller.state = "Stabilizing";
                }
                do action stabilize {
                    cryogenicSystem.maintainTemperature();
                }
            }

            state Biasing {
                entry action enterBiasing {
                    controller.state = "Biasing";
                    biasSource.generateBiasCurrent();
                }
                do action tuneBias {
                    biasSource.generateBiasCurrent();
                }
            }

            state Measuring {
                entry action enterMeasuring {
                    controller.state = "Measuring";
                }
                do action measure {
                    fluxTransformer.gatherField();
                    fluxTransformer.transferFlux();
                    squidSensor.loop.induceScreeningCurrent();
                    squidSensor.loop.generateVoltage();
                    readout.amplifySignal();
                    readout.filterNoise();
                    readout.digitize();
                }
            }

            state Fault {
                entry action enterFault {
                    controller.state = "Fault";
                }
                do action handleFault {
                    controller.manageOperation();
                }
            }

            transition IdleToCooldown first Idle then Cooldown
                when systemControl::command == "Start"
            accept "Start";

            transition CooldownToStabilizing then Stabilizing
                when cryogenicSystem.currentTemp <= 4.4 [K]
            accept "TemperatureReached";

            transition StabilizingToBiasing then Biasing
                when cryogenicSystem.currentTemp >= 4.0 [K] and cryogenicSystem.currentTemp <= 4.4 [K]
            accept "Stable";

            transition BiasingToMeasuring then Measuring
                when biasSource.outputCurrent == 20e-6 [A]
            accept "BiasSet";

            transition MeasuringToIdle then Idle
                accept "Stop";

            transition AnyToFault then Fault
                when cryogenicSystem.currentTemp > 5.0 [K] or biasSource.outputCurrent != 20e-6 [A]
            accept "Error";

            transition FaultToIdle then Idle
                accept "Reset";
        }

        part operatingStateMachine : SQUIDOperatingStates;
    }
}
