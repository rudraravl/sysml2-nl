package LiquidMetalThermalManagementSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value def TemperatureK :> Real { unit 'K'; }
    value def PowerW :> Real { unit 'W'; }
    value def MassFlowRateKgPerS :> Real { unit 'kg/s'; }
    value def PressurePa :> Real { unit 'Pa'; }
    value def VolumeM3 :> Real { unit 'm3'; }
    value def Fraction :> Real { unit '1'; }
    value def VoltageV :> Real { unit 'V'; }

    // ---- Items ----
    item def NaK {
        attribute density : Real = 850 [kg/m3];
        attribute specificHeat : Real = 1000 [J/(kg*K)];
        attribute thermalConductivity : Real = 22 [W/(m*K)];
        attribute meltingPoint : TemperatureK = 260 [K];
    }

    item def Heat;

    item def ControlSignal {
        attribute value : Fraction;
    }

    item def TemperatureReading {
        attribute value : TemperatureK;
    }

    // ---- Port definitions ----
    port def FluidPort {
        in item NaK;
        out item NaK;
        attribute flowRate : MassFlowRateKgPerS;
        attribute temperature : TemperatureK;
        attribute pressure : PressurePa;
    }

    port def HeatPort {
        out item Heat;
        attribute heatFlow : PowerW;
    }

    port def SignalOutPort {
        out item TemperatureReading;
    }

    port def ControlInPort {
        in item ControlSignal;
    }

    // ---- Component part definitions ----
    part def HeatSource {
        port heatOut : HeatPort;
        attribute nominalHeatGeneration : PowerW = 1500 [W];
        attribute peakHeatGeneration : PowerW = 3000 [W];
        attribute currentHeatGeneration : PowerW;
    }

    part def ColdPlate {
        port heatIn : HeatPort;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        attribute thermalResistance : Real = 0.01 [K/W];
        attribute channelVolume : VolumeM3 = 0.00005 [m3];
        attribute absorbedHeat : PowerW;
    }

    part def ElectromagneticPump {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port controlIn : ControlInPort;
        attribute maxFlowRate : MassFlowRateKgPerS = 0.6 [kg/s];
        attribute currentFlowRate : MassFlowRateKgPerS;
        attribute driveVoltage : VoltageV;
        attribute hasMovingParts : Boolean = false;
    }

    part def Radiator {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port ambientHeatOut : HeatPort;
        attribute finSurfaceArea : Real = 2.5 [m2];
        attribute heatTransferCoefficient : Real = 50 [W/(m2*K)];
        attribute ambientTemperature : TemperatureK = 300 [K];
        attribute dissipatedHeat : PowerW;
    }

    part def ExpansionTank {
        port fluidPort : FluidPort;
        attribute capacity : VolumeM3 = 0.002 [m3];
        attribute fillLevel : Fraction;
        attribute currentVolume : VolumeM3;
    }

    part def TemperatureSensor {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port signalOut : SignalOutPort;
        attribute measuredTemperature : TemperatureK;
        attribute samplingRate : Real = 10 [Hz];
    }

    part def SystemController {
        port tempSignalIn : SignalOutPort;
        port pumpControlOut : ControlInPort;
        attribute setpoint : TemperatureK = 340 [K];
        attribute highLoadThreshold : TemperatureK = 360 [K];
        attribute maxSafeTemperature : TemperatureK = 380 [K];
        attribute pumpSpeedCommand : Fraction;
        attribute proportionalGain : Real = 0.05;
        attribute integralGain : Real = 0.01;
        attribute integralError : Real = 0.0;

        action def computeControl {
            in measuredTemp : TemperatureK;
            out command : Fraction;
            // Proportional-integral control law
            attribute error : Real = setpoint - measuredTemp;
            attribute proportionalTerm : Real = proportionalGain * error;
            attribute integralTerm : Real = integralGain * (integralError + error);
            attribute rawCommand : Real = proportionalTerm + integralTerm;
        }
    }

    // ---- System assembly ----
    part def ThermalManagementSystem {
        part heatSource : HeatSource;
        part coldPlate : ColdPlate;
        part emPump : ElectromagneticPump;
        part radiator : Radiator;
        part expansionTank : ExpansionTank;
        part tempSensor : TemperatureSensor;
        part controller : SystemController;

        // Closed-loop fluid connections
        connection coldPlate.fluidOut to tempSensor.fluidIn;
        connection tempSensor.fluidOut to radiator.fluidIn;
        connection radiator.fluidOut to emPump.fluidIn;
        connection emPump.fluidOut to coldPlate.fluidIn;

        // Expansion tank tap
        connection expansionTank.fluidPort to emPump.fluidIn;

        // Heat path
        connection heatSource.heatOut to coldPlate.heatIn;
        connection radiator.ambientHeatOut to ambient;

        // Signal/control path
        connection tempSensor.signalOut to controller.tempSignalIn;
        connection controller.pumpControlOut to emPump.controlIn;

        // Ambient reference
        part ambient {
            port heatIn : HeatPort;
            attribute temperature : TemperatureK = 300 [K];
        }
        connection radiator.ambientHeatOut to ambient.heatIn;

        // ---- System state machine ----
        state systemStates {
            attribute startCommand : Boolean = false;
            attribute shutdownCommand : Boolean = false;
            attribute flowEstablished : Boolean = false;
            attribute currentCoolantTemp : TemperatureK = 300 [K];

            state standby {
                entry action { emPump.currentFlowRate = 0 [kg/s]; }
            }

            state startup {
                entry action { emPump.currentFlowRate = 0.1 [kg/s]; }
                do action { rampPumpFlow(); }
            }

            state normalOperation {
                do action { regulateTemperature(); }
            }

            state highLoad {
                entry action { emPump.currentFlowRate = emPump.maxFlowRate; }
                do action { regulateTemperature(); }
            }

            state emergency {
                entry action { emPump.currentFlowRate = emPump.maxFlowRate; }
                do action { alertOperator(); }
            }

            state controlledShutdown {
                entry action { emPump.currentFlowRate = 0.05 [kg/s]; }
                do action { gradualCoolDown(); }
            }

            transition standby to startup
                when startCommand;

            transition startup to normalOperation
                when flowEstablished;

            transition normalOperation to highLoad
                when currentCoolantTemp > controller.highLoadThreshold;

            transition highLoad to normalOperation
                when currentCoolantTemp < controller.setpoint + 5 [K];

            transition normalOperation to emergency
                when currentCoolantTemp > controller.maxSafeTemperature;

            transition highLoad to emergency
                when currentCoolantTemp > controller.maxSafeTemperature;

            transition emergency to controlledShutdown
                when currentCoolantTemp < controller.highLoadThreshold;

            transition normalOperation to controlledShutdown
                when shutdownCommand;

            transition highLoad to controlledShutdown
                when shutdownCommand;

            transition controlledShutdown to standby
                when emPump.currentFlowRate == 0 [kg/s];
        }

        action def rampPumpFlow {
            // Gradually increase pump flow to full operating rate
        }

        action def regulateTemperature {
            // Invoke controller.computeControl and adjust pump speed
        }

        action def alertOperator {
            // Emit high-temperature alarm signal
        }

        action def gradualCoolDown {
            // Reduce flow until safe, then stop
        }
    }

    // ---- Requirements ----
    requirement def CoolingPerformanceRequirement {
        subject system : ThermalManagementSystem;
        doc //
            The system shall maintain the coolant outlet temperature below 360 K
            when the heat source operates at nominal heat generation.
        //
    }

    requirement def PeakLoadRequirement {
        subject system : ThermalManagementSystem;
        doc //
            The system shall enter high-load mode and run the electromagnetic pump
            at full capacity when the coolant temperature exceeds 360 K.
        //
    }

    requirement def EmergencyProtectionRequirement {
        subject system : ThermalManagementSystem;
        doc //
            The system shall enter emergency state when the coolant temperature
            exceeds 380 K, and shall initiate a controlled shutdown thereafter.
        //
    }

    requirement def PumpReliabilityRequirement {
        subject pump : ElectromagneticPump;
        doc //
            The electromagnetic pump shall operate without moving parts and shall
            be capable of circulating NaK coolant continuously.
        //
    }

    requirement def ExpansionSafetyRequirement {
        subject tank : ExpansionTank;
        doc //
            The expansion tank shall accommodate volumetric expansion of NaK
            coolant across the full operating temperature range without
            exceeding the maximum allowable loop pressure.
        //
    }

    requirement def FeedbackControlRequirement {
        subject controller : SystemController;
        doc //
            The controller shall compare the measured coolant temperature to the
            setpoint and adjust the electromagnetic pump speed via a
            proportional-integral control law to maintain the target temperature.
        //
    }

    // ---- Requirement satisfaction ----
    satisfaction coolingSatisfaction : CoolingPerformanceRequirement {
        subject system : ThermalManagementSystem;
    }
    satisfaction peakLoadSatisfaction : PeakLoadRequirement {
        subject system : ThermalManagementSystem;
    }
    satisfaction emergencySatisfaction : EmergencyProtectionRequirement {
        subject system : ThermalManagementSystem;
    }
    satisfaction pumpReliabilitySatisfaction : PumpReliabilityRequirement {
        subject pump : ElectromagneticPump;
    }
    satisfaction expansionSafetySatisfaction : ExpansionSafetyRequirement {
        subject tank : ExpansionTank;
    }
    satisfaction feedbackControlSatisfaction : FeedbackControlRequirement {
        subject controller : SystemController;
    }
}
