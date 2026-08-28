package NanomaterialSensorSystem {
    import ScalarValues::*;

    // ===== Units =====
    unit nm;
    unit ppm;
    unit ohm;
    unit V;
    unit s;
    unit A;

    // ===== Value Types =====
    value type Concentration :> Real {
        unit ppm;
    }

    value type ElectricalResistance :> Real {
        unit ohm;
    }

    value type Voltage :> Real {
        unit V;
    }

    value type ParticleSize :> Real {
        unit nm;
    }

    value type ResponseTime :> Real {
        unit s;
    }

    value type Current :> Real {
        unit A;
    }

    // ===== Item Types =====
    item def TargetGas {
        attribute name : String;
        attribute concentration : Concentration;
    }

    item def ElectricalSignal {
        attribute resistance : ElectricalResistance;
        attribute voltage : Voltage;
    }

    item def ProcessedSignal {
        attribute concentration : Concentration;
        attribute signalQuality : Real;
        attribute timestamp : Real;
    }

    item def PowerSupply {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    // ===== Port Definitions =====
    port def GasPort {
        out item gas : TargetGas;
    }

    port def SignalPort {
        out item signal : ElectricalSignal;
    }

    port def DataPort {
        out item data : ProcessedSignal;
    }

    port def PowerPort {
        out item power : PowerSupply;
    }

    // ===== State Machine Definition =====
    state def SensingStates {
        entry; then baseline;

        state baseline {
            entry {
                /* Sensor in clean air; resistance at baseline value */
            }
            do {
                /* Monitor gasInput for incoming target gas */
            }
        }

        state adsorbing {
            entry {
                /* Gas molecules adsorbing to nanoparticle surface */
                /* Resistance deviates from baseline proportionally to concentration */
            }
            do {
                /* Accumulate gas molecules on nanoparticle surface */
            }
        }

        state purging {
            entry {
                /* Clean air purge initiated */
                /* Gas molecules desorbing from surface */
            }
            do {
                /* Resistance returning toward baseline */
            }
        }

        transition baseline to adsorbing
            when gasInput.gas.concentration > 0 [ppm];

        transition adsorbing to purging
            when currentResistance != baselineResistance;

        transition purging to baseline
            when currentResistance == baselineResistance;
    }

    // ===== Action Definitions =====
    action def ProcessSignalAction {
        in rawSignal : ElectricalSignal;
        out processed : ProcessedSignal;

        action amplify {
            in input : ElectricalSignal;
            out output : ElectricalSignal;
        }

        action filter {
            in input : ElectricalSignal;
            out output : ElectricalSignal;
        }

        action calculateConcentration {
            in input : ElectricalSignal;
            out output : ProcessedSignal;
        }

        flow rawSignal -> amplify.input;
        flow amplify.output -> filter.input;
        flow filter.output -> calculateConcentration.input;
        flow calculateConcentration.output -> processed;
    }

    action def RegulatePowerAction {
        in rawVoltage : Voltage;
        out regulated : PowerSupply;

        action stepDown {
            in input : Voltage;
            out output : PowerSupply;
        }

        action stabilize {
            in input : PowerSupply;
            out output : PowerSupply;
        }

        action protect {
            in input : PowerSupply;
            out output : PowerSupply;
        }

        flow rawVoltage -> stepDown.input;
        flow stepDown.output -> stabilize.input;
        flow stabilize.output -> protect.input;
        flow protect.output -> regulated;
    }

    // ===== Part: Nanoparticle Layer =====
    part def NanoparticleLayer {
        attribute particleSize : ParticleSize = 30 [nm];
        attribute minParticleSize : ParticleSize = 10 [nm];
        attribute maxParticleSize : ParticleSize = 50 [nm];
        attribute baselineResistance : ElectricalResistance = 1000 [ohm];
        attribute currentResistance : ElectricalResistance = 1000 [ohm];
        attribute sensitivityFactor : Real = 0.5;
        attribute activeSurfaceArea : Real = 1000;

        port gasInput : ~GasPort;
        port signalOutput : SignalPort;
        port powerInput : ~PowerPort;

        exhibit sensingBehavior : SensingStates;
    }

    // ===== Part: Signal Processor =====
    part def SignalProcessor {
        attribute amplificationFactor : Real = 100;
        attribute filterCutoffFrequency : Real = 1000;
        attribute calibrationFactor : Real = 1.0;
        attribute noiseFloor : Real = 0.01;

        port signalInput : ~SignalPort;
        port dataOutput : DataPort;
        port powerInput : ~PowerPort;

        perform processSignal : ProcessSignalAction;
    }

    // ===== Part: Power Management Module =====
    part def PowerManagementModule {
        attribute inputVoltage : Voltage = 12 [V];
        attribute outputVoltage : Voltage = 3.3 [V];
        attribute maxOutputCurrent : Current = 0.5 [A];
        attribute efficiency : Real = 0.85;
        attribute thermalShutdownThreshold : Real = 85;

        port powerInput : ~PowerPort;
        port powerOutput1 : PowerPort;
        port powerOutput2 : PowerPort;

        perform regulatePower : RegulatePowerAction;
    }

    // ===== Top-Level System =====
    part def NanomaterialSensorSystem {
        attribute systemId : String;
        attribute targetGasName : String = "CO2";
        attribute operatingTemperature : Real = 25;
        attribute maxResponseTime : ResponseTime = 30 [s];
        attribute minDetectionLimit : Concentration = 1 [ppm];

        port gasInput : GasPort;
        port dataOutput : DataPort;
        port powerInput : PowerPort;

        part nanoparticleLayer : NanoparticleLayer {
            port gasInput : ~GasPort;
            port signalOutput : SignalPort;
            port powerInput : ~PowerPort;
        }

        part signalProcessor : SignalProcessor {
            port signalInput : ~SignalPort;
            port dataOutput : DataPort;
            port powerInput : ~PowerPort;
        }

        part powerModule : PowerManagementModule {
            port powerInput : ~PowerPort;
            port powerOutput1 : PowerPort;
            port powerOutput2 : PowerPort;
        }

        connection gasInput to nanoparticleLayer.gasInput;
        connection nanoparticleLayer.signalOutput to signalProcessor.signalInput;
        connection signalProcessor.dataOutput to dataOutput;
        connection powerInput to powerModule.powerInput;
        connection powerModule.powerOutput1 to nanoparticleLayer.powerInput;
        connection powerModule.powerOutput2 to signalProcessor.powerInput;
    }

    // ===== Requirements =====
    requirement def DetectionSensitivityReq {
        subject sensor : NanomaterialSensorSystem;
        attribute minDetectableConcentration : Concentration = 1 [ppm];
        objective {
            doc /* The sensor shall detect gas concentrations as low as 1 ppm. */;
        }
    }

    requirement def ResponseTimeRequirement {
        subject sensor : NanomaterialSensorSystem;
        attribute maxResponseTime : ResponseTime = 30 [s];
        objective {
            doc /* The sensor shall provide a response within 30 seconds of exposure. */;
        }
    }

    requirement def PowerStabilityRequirement {
        subject powerModule : PowerManagementModule;
        attribute maxOutputVoltage : Voltage = 5 [V];
        objective {
            doc /* The power module shall output a stable voltage under 5V to safely power sensitive components. */;
        }
    }

    requirement def ParticleSizeRangeRequirement {
        subject layer : NanoparticleLayer;
        attribute minSize : ParticleSize = 10 [nm];
        attribute maxSize : ParticleSize = 50 [nm];
        objective {
            doc /* Nanoparticle size shall be between 10 and 50 nm to maximize surface area for gas adsorption. */;
        }
    }

    requirement def BaselineResistanceRequirement {
        subject layer : NanoparticleLayer;
        attribute baselineResistance : ElectricalResistance = 1000 [ohm];
        objective {
            doc /* The nanoparticle layer shall maintain a defined baseline electrical resistance in clean air. */;
        }
    }

    requirement def SignalProcessingRequirement {
        subject processor : SignalProcessor;
        attribute amplificationFactor : Real = 100;
        objective {
            doc /* The signal processor shall amplify and filter raw electrical signals to calculate gas concentration in ppm. */;
        }
    }

    requirement def SensingCycleRequirement {
        subject sensor : NanomaterialSensorSystem;
        objective {
            doc /* The sensor shall cycle through baseline, adsorbing, and purging states to detect and recover from gas exposure. */;
        }
    }
}
