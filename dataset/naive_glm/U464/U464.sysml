package AirliftPumpingSystem {
    imports ScalarValues::*;
    imports ISQ::*;

    // ---- Value types with units ----
    type PressureValue :> Real { unit 'Pa'; }
    type FlowRateValue :> Real { unit 'm3/s'; }
    type DensityValue :> Real { unit 'kg/m3'; }
    type LengthValue :> Real { unit 'm'; }
    type ElevationValue :> Real { unit 'm'; }
    type VolumeValue :> Real { unit 'm3'; }
    type VolumeFractionValue :> Real { unit '1'; }
    type TemperatureValue :> Real { unit 'K'; }

    // ---- Item definitions ----
    item def Air {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }

    item def Water {
        attribute density : DensityValue = 1000;
        attribute temperature : TemperatureValue;
    }

    item def AirWaterMixture {
        attribute airFraction : VolumeFractionValue;
        attribute mixtureDensity : DensityValue;
        attribute flowRate : FlowRateValue;
    }

    // ---- Port definitions ----
    port def AirPort {
        out item : Air;
        attribute pressure : PressureValue;
    }

    port def FluidPort {
        out item : Water;
        attribute flowRate : FlowRateValue;
    }

    port def MixturePort {
        out item : AirWaterMixture;
        attribute flowRate : FlowRateValue;
        attribute airFraction : VolumeFractionValue;
    }

    // ---- Requirements ----
    requirement def PumpingRequirement {
        doc "The system shall lift fluid from a lower source reservoir to a higher destination tank using buoyancy-driven airlift."
        attribute minLiftHeight : ElevationValue = 10;
        attribute targetFlowRate : FlowRateValue = 0.01;
        subject system : AirliftPumpingSystem;
        objective {
            system.liftHeight >= minLiftHeight and
            system.outFlowRate >= targetFlowRate
        }
    }

    requirement def PressureRegulationRequirement {
        doc "The pressure regulator shall maintain outlet pressure at the optimal setpoint for airlift pumping."
        attribute setpoint : PressureValue = 200000;
        attribute tolerance : PressureValue = 5000;
        subject regulator : PressureRegulator;
        objective {
            abs(regulator.outletPressure - setpoint) <= tolerance
        }
    }

    requirement def SeparationRequirement {
        doc "The separator shall vent air and discharge fluid with minimal residual air content."
        attribute maxResidualAirFraction : VolumeFractionValue = 0.02;
        subject separator : AirFluidSeparator;
        objective {
            separator.dischargedAirFraction <= maxResidualAirFraction
        }
    }

    requirement def FlowMonitoringRequirement {
        doc "The flow meter shall measure the discharged fluid flow rate for monitoring."
        attribute measurementError : FlowRateValue = 0.0005;
        subject meter : FlowMeter;
        objective {
            abs(meter.measuredFlowRate - meter.actualFlowRate) <= measurementError
        }
    }

    requirement def LifecycleRequirement {
        doc "The system shall operate through idle, starting, operating, shutdown, and fault states."
        subject system : AirliftPumpingSystem;
        objective {
            system.lifecycle.activeState in {'idle', 'starting', 'operating', 'shuttingDown', 'fault'}
        }
    }

    // ---- Part definitions ----
    part def AirCompressor {
        port airOut : AirPort;
        attribute generatedPressure : PressureValue = 300000;
        attribute intakePressure : PressureValue = 101325;
        attribute isRunning : Boolean = false;
        attribute ratedPower : Real = 1500;

        action def generateAir {
            in ambientAir : Air;
            out compressedAir : Air;
        }

        action generateAir {
            in ambientAir : Air = Air { pressure = intakePressure; };
            out compressedAir : Air = Air { pressure = generatedPressure; };
        }
    }

    part def PressureRegulator {
        port airIn : AirPort;
        port airOut : AirPort;
        attribute inletPressure : PressureValue;
        attribute outletPressure : PressureValue = 200000;
        attribute setpoint : PressureValue = 200000;

        action def regulate {
            in inputAir : Air;
            out regulatedAir : Air;
        }

        action regulate {
            in inputAir : Air;
            out regulatedAir : Air = Air { pressure = setpoint; };
        }
    }

    part def Riser {
        attribute length : LengthValue = 15;
        attribute submergenceDepth : LengthValue = 8;
        attribute liftHeight : ElevationValue = 7;
        attribute mixtureDensity : DensityValue;
        attribute ambientFluidDensity : DensityValue = 1000;
        port airInjection : AirPort;
        port fluidIntake : FluidPort;
        port mixtureOut : MixturePort;

        action def mixAndRise {
            in injectedAir : Air;
            in intakeFluid : Water;
            out mixture : AirWaterMixture;
        }

        action mixAndRise {
            in injectedAir : Air;
            in intakeFluid : Water;
            out mixture : AirWaterMixture = AirWaterMixture {
                mixtureDensity = ambientFluidDensity * (1 - 0.4);
                airFraction = 0.4;
            };
        }
    }

    part def AirliftPump {
        port airIn : AirPort;
        port mixtureOut : MixturePort;
        part riser : Riser;

        action def liftFluid {
            in air : Air;
            out mixture : AirWaterMixture;
        }

        action liftFluid {
            in air : Air;
            out mixture : AirWaterMixture;
        }
    }

    part def AirFluidSeparator {
        port mixtureIn : MixturePort;
        port airVent : AirPort;
        port fluidOut : FluidPort;
        attribute dischargedAirFraction : VolumeFractionValue = 0.01;
        attribute separationEfficiency : Real = 0.98;

        action def separate {
            in mixture : AirWaterMixture;
            out separatedAir : Air;
            out separatedFluid : Water;
        }

        action separate {
            in mixture : AirWaterMixture;
            out separatedAir : Air;
            out separatedFluid : Water;
        }
    }

    part def FlowMeter {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        attribute measuredFlowRate : FlowRateValue;
        attribute actualFlowRate : FlowRateValue;

        action def measure {
            in fluid : Water;
            out measuredFluid : Water;
        }

        action measure {
            in fluid : Water;
            out measuredFluid : Water;
        }
    }

    part def SourceReservoir {
        port fluidOut : FluidPort;
        attribute fluidLevel : ElevationValue = 0;
        attribute storedFluid : Water;
        attribute capacity : VolumeValue = 50;
    }

    part def DestinationTank {
        port fluidIn : FluidPort;
        attribute fluidLevel : ElevationValue;
        attribute capacity : VolumeValue = 5;
        attribute storedFluid : Water;
    }

    // ---- Main system ----
    part def AirliftPumpingSystem {
        attribute liftHeight : ElevationValue = 10;
        attribute outFlowRate : FlowRateValue;
        attribute systemPressure : PressureValue;
        port ventOut : AirPort;

        part compressor : AirCompressor;
        part regulator : PressureRegulator;
        part pump : AirliftPump;
        part separator : AirFluidSeparator;
        part meter : FlowMeter;
        part source : SourceReservoir;
        part destination : DestinationTank;

        // Connections
        connection compressor.airOut to regulator.airIn;
        connection regulator.airOut to pump.airIn;
        connection pump.airIn to pump.riser.airInjection;
        connection pump.riser.mixtureOut to pump.mixtureOut;
        connection pump.mixtureOut to separator.mixtureIn;
        connection separator.airVent to ventOut;
        connection separator.fluidOut to meter.fluidIn;
        connection meter.fluidOut to destination.fluidIn;
        connection source.fluidOut to pump.riser.fluidIntake;

        // Control signals / events
        attribute startCommand : Boolean = false;
        attribute stopCommand : Boolean = false;
        attribute pressureReached : Boolean = false;
        attribute shutdownComplete : Boolean = false;
        attribute startFailure : Boolean = false;
        attribute systemError : Boolean = false;
        attribute faultCleared : Boolean = false;
        attribute activeState : String = "idle";

        // State machine
        state Lifecycle {
            state idle {
                entry { activeState = "idle"; }
            }
            state starting {
                entry { activeState = "starting"; }
            }
            state operating {
                entry { activeState = "operating"; }
            }
            state shuttingDown {
                entry { activeState = "shuttingDown"; }
            }
            state fault {
                entry { activeState = "fault"; }
            }

            transition idle to starting when startCommand;
            transition starting to operating when pressureReached;
            transition operating to shuttingDown when stopCommand;
            transition shuttingDown to idle when shutdownComplete;
            transition starting to fault when startFailure;
            transition operating to fault when systemError;
            transition fault to idle when faultCleared;
        }

        exhibit Lifecycle;
    }

    // ---- Requirement satisfaction ----
    satisfy PumpingRequirement by AirliftPumpingSystem;
    satisfy PressureRegulationRequirement by PressureRegulator;
    satisfy SeparationRequirement by AirFluidSeparator;
    satisfy FlowMonitoringRequirement by FlowMeter;
    satisfy LifecycleRequirement by AirliftPumpingSystem;
}
