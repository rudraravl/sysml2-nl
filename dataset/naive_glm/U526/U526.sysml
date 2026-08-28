package FluidInjectionSystem {
    import ISQ::*;
    import ISQVolume::*;
    import ISQPressure::*;
    import ISQTime::*;
    import ISQFrequency::*;
    import ISQMass::*;
    import ISQThermodynamicTemperature::*;
    import ISQAngle::*;

    // ---------- Item & Value Types ----------
    item def InjectionFluid {
        attribute density : MassDensityValue;
        attribute viscosity : Real; // Pa*s
        attribute cetaneNumber : Real;
    }

    item def FluidFlow {
        ref item fluid : InjectionFluid;
        attribute flowRate : VolumeFlowRateValue;
        attribute pressure : PressureValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }

    item def SprayPattern {
        attribute coneAngle : PlaneAngleValue = 45 [deg];
        attribute dropletSauterMeanDiameter : LengthValue;
        attribute uniformityIndex : Real;
    }

    value type VolumeFlowRateValue :> Real { unit : VolumeFlowRateUnit; }
    value type PressureValue :> Real { unit : PressureUnit; }
    value type ThermodynamicTemperatureValue :> Real { unit : ThermodynamicTemperatureUnit; }
    value type DurationValue :> Real { unit : TimeUnit; }
    value type VolumeValue :> Real { unit : VolumeUnit; }
    value type PlaneAngleValue :> Real { unit : PlaneAngleUnit; }
    value type FrequencyValue :> Real { unit : FrequencyUnit; }

    // ---------- Port Definitions ----------
    port def FluidPort {
        out item supply : FluidFlow;
        in item return : FluidFlow;
    }

    port def CommandPort {
        out item command : InjectionCommand;
    }

    port def FeedbackPort {
        out item measurement : FlowMeasurement;
    }

    // ---------- Signal Items ----------
    item def InjectionCommand {
        attribute injectionDuration : DurationValue;
        attribute targetVolume : VolumeValue;
        attribute injectionTiming : DurationValue;
        attribute sequenceId : Integer;
    }

    item def FlowMeasurement {
        attribute measuredFlowRate : VolumeFlowRateValue;
        attribute accumulatedVolume : VolumeValue;
        attribute linePressure : PressureValue;
        attribute fluidTemperature : ThermodynamicTemperatureValue;
        attribute timestamp : DurationValue;
    }

    // ---------- Component Parts ----------
    part def FluidReservoir {
        attribute initialPressure : PressureValue = 5 [bar];
        attribute capacity : VolumeValue = 50 [L];
        attribute currentVolume : VolumeValue;
        attribute fluidTemperature : ThermodynamicTemperatureValue = 25 [degC];
        port fluidOut : FluidPort;
        
        private attribute minOperatingVolume : VolumeValue = 5 [L];
        
        action def supplyFluid {
            in item request : InjectionCommand;
            out item flow : FluidFlow;
        }
    }

    part def PressureRegulator {
        attribute regulatedPressure : PressureValue = 3 [bar] :>> setpoint;
        attribute regulationAccuracy : PressureValue = 0.05 [bar];
        attribute maxFlowCapacity : VolumeFlowRateValue = 500 [mL/min];
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        
        private attribute setpoint : PressureValue;
        private attribute measuredPressure : PressureValue;
        
        action def regulatePressure {
            in item inputFlow : FluidFlow;
            out item outputFlow : FluidFlow;
            
            // Pressure regulation control logic
            if measuredPressure > setpoint + regulationAccuracy {
                // Reduce flow to lower pressure
            } else if measuredPressure < setpoint - regulationAccuracy {
                // Increase flow to raise pressure
            }
        }
    }

    part def InjectionController {
        attribute clockFrequency : FrequencyValue = 20 [MHz];
        attribute minInjectionDuration : DurationValue = 0.5 [ms];
        attribute maxInjectionDuration : DurationValue = 10 [ms];
        attribute calculationLatency : DurationValue = 0.1 [ms];
        attribute targetVolume : VolumeValue;
        attribute pressureCompensationFactor : Real = 1.0;
        
        port commandOut : CommandPort;
        port feedbackIn : FeedbackPort;
        
        private attribute learnedCorrectionFactor : Real = 1.0;
        private attribute injectionCount : Integer = 0;
        
        action def calculateInjectionParameters {
            in attribute desiredVolume : VolumeValue;
            in attribute currentPressure : PressureValue;
            in attribute lastMeasurement : FlowMeasurement;
            out item command : InjectionCommand;
            
            // Calculate base duration from target volume and expected flow rate
            private attribute expectedFlowRate : VolumeFlowRateValue = 100 [mL/min];
            private attribute baseDuration : DurationValue = desiredVolume / expectedFlowRate;
            private attribute compensatedDuration : DurationValue = baseDuration * pressureCompensationFactor * learnedCorrectionFactor;
            
            // Apply learned correction from feedback
            if lastMeasurement.accumulatedVolume > 0 {
                learnedCorrectionFactor = desiredVolume / lastMeasurement.accumulatedVolume;
            }
        }
        
        action def processFeedback {
            in item measurement : FlowMeasurement;
            // Update correction factors for future injections
        }
    }

    part def InjectorValve {
        attribute responseTime : DurationValue = 0.2 [ms];
        attribute maxOperatingPressure : PressureValue = 10 [bar];
        attribute orificeDiameter : LengthValue = 0.2 [mm];
        attribute flowCoefficient : Real = 0.7;
        attribute cycleCount : Integer = 0;
        attribute maxCycles : Integer = 10000000;
        
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port commandIn : CommandPort;
        
        state injectionCycle {
            entry action { cycleCount = cycleCount + 1; }
            
            state idle;
            state priming;
            state injecting;
            state purging;
            
            transition idle_to_priming 
                first idle 
                accept command : InjectionCommand 
                then priming {
                    action primingAction {
                        // Prepare valve for injection
                    }
                }
            
            transition priming_to_injecting
                first priming
                after responseTime
                then injecting {
                    action injectionAction {
                        // Valve fully open, delivering fluid
                    }
                }
            
            transition injecting_to_purging
                first injecting
                after command.injectionDuration
                then purging {
                    action purgeAction {
                        // Close valve and clear residual pressure
                    }
                }
            
            transition purging_to_idle
                first purging
                after 0.3 [ms]
                then idle;
        }
    }

    part def FlowMeter {
        attribute measurementRange : VolumeFlowRateValue = 0 to 500 [mL/min];
        attribute accuracy : Real = 0.5; // ±0.5% of reading
        attribute samplingRate : FrequencyValue = 1000 [Hz];
        attribute pressureDrop : PressureValue = 0.01 [bar];
        
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port measurementOut : FeedbackPort;
        
        private attribute accumulatedVolume : VolumeValue = 0 [mL];
        
        action def measureFlow {
            in item inputFlow : FluidFlow;
            out item measurement : FlowMeasurement;
            
            // Accumulate volume for totalization
            accumulatedVolume = accumulatedVolume + (inputFlow.flowRate / samplingRate);
        }
    }

    part def DeliveryNozzle {
        attribute sprayConeAngle : PlaneAngleValue = 45 [deg];
        attribute orificeDiameter : LengthValue = 0.15 [mm];
        attribute atomizationQuality : Real;
        attribute maxFlowRate : VolumeFlowRateValue = 200 [mL/min];
        
        port fluidIn : FluidPort;
        port sprayOut : FluidPort;
        
        action def atomizeFluid {
            in item inputFlow : FluidFlow;
            out item spray : FluidFlow;
            out item pattern : SprayPattern;
            
            // Convert pressurized fluid to atomized spray
            private attribute velocity : Real; // m/s
            private attribute reynoldsNumber : Real;
        }
    }

    // ---------- System Assembly ----------
    part def FluidInjectionSystem {
        attribute systemPressure : PressureValue = 3 [bar];
        attribute operatingTemperatureRange : ThermodynamicTemperatureValue = -40 to 120 [degC];
        attribute accuracyClass : Real = 0.5; // ±0.5% accuracy
        attribute designLife : Integer = 10000000; // 10 million cycles
        
        port systemFluidIn : FluidPort;
        port systemSprayOut : FluidPort;
        
        part reservoir : FluidReservoir {
            port fluidOut : FluidPort;
        }
        
        part regulator : PressureRegulator {
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
        }
        
        part controller : InjectionController {
            port commandOut : CommandPort;
            port feedbackIn : FeedbackPort;
        }
        
        part valve : InjectorValve {
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
            port commandIn : CommandPort;
        }
        
        part flowMeter : FlowMeter {
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
            port measurementOut : FeedbackPort;
        }
        
        part nozzle : DeliveryNozzle {
            port fluidIn : FluidPort;
            port sprayOut : FluidPort;
        }
        
        // Connections
        connection reservoirToRegulator : FluidPort 
            connect reservoir.fluidOut to regulator.fluidIn;
        
        connection regulatorToValve : FluidPort 
            connect regulator.fluidOut to valve.fluidIn;
        
        connection valveToFlowMeter : FluidPort 
            connect valve.fluidOut to flowMeter.fluidIn;
        
        connection flowMeterToNozzle : FluidPort 
            connect flowMeter.fluidOut to nozzle.fluidIn;
        
        connection controllerToValve : CommandPort 
            connect controller.commandOut to valve.commandIn;
        
        connection flowMeterToController : FeedbackPort 
            connect flowMeter.measurementOut to controller.feedbackIn;
        
        // System-level behavior
        action def performInjectionCycle {
            in attribute targetVolume : VolumeValue;
            
            // Controller calculates injection parameters
            action calculateParameters : controller.calculateInjectionParameters {
                in attribute desiredVolume = targetVolume;
                in attribute currentPressure = systemPressure;
            }
            
            // Valve executes injection cycle
            action executeInjection : valve.injectionCycle;
            
            // Flow meter provides feedback
            action measureFlow : flowMeter.measureFlow;
            
            // Nozzle atomizes and delivers
            action atomize : nozzle.atomizeFluid;
        }
    }

    // ---------- Requirements ----------
    requirement def InjectionAccuracyRequirement {
        doc "The system shall deliver fluid with ±0.5% accuracy of target volume";
        attribute targetAccuracy : Real = 0.5; // percent
        attribute targetVolume : VolumeValue;
        attribute actualVolume : VolumeValue;
        
        require constraint { 
            abs(actualVolume - targetVolume) / targetVolume * 100 <= targetAccuracy 
        }
    }

    requirement def ResponseTimeRequirement {
        doc "The injector valve shall respond to command within 0.2 ms";
        attribute maxResponseTime : DurationValue = 0.2 [ms];
        attribute actualResponseTime : DurationValue;
        
        require constraint { actualResponseTime <= maxResponseTime }
    }

    requirement def PressureRegulationRequirement {
        doc "The pressure regulator shall maintain output pressure within ±0.05 bar of setpoint";
        attribute setpoint : PressureValue = 3 [bar];
        attribute tolerance : PressureValue = 0.05 [bar];
        attribute actualPressure : PressureValue;
        
        require constraint { 
            abs(actualPressure - setpoint) <= tolerance 
        }
    }

    requirement def AtomizationRequirement {
        doc "The nozzle shall produce a 45-degree cone spray pattern";
        attribute requiredConeAngle : PlaneAngleValue = 45 [deg];
        attribute angleTolerance : PlaneAngleValue = 2 [deg];
        attribute actualConeAngle : PlaneAngleValue;
        
        require constraint { 
            abs(actualConeAngle - requiredConeAngle) <= angleTolerance 
        }
    }

    requirement def ReliabilityRequirement {
        doc "The system shall complete 10 million injection cycles without failure";
        attribute requiredCycles : Integer = 10000000;
        attribute actualCycles : Integer;
        
        require constraint { actualCycles >= requiredCycles }
    }

    requirement def SafetyRequirement {
        doc "The system shall operate within specified pressure and temperature limits";
        attribute maxPressure : PressureValue = 10 [bar];
        attribute minTemperature : ThermodynamicTemperatureValue = -40 [degC];
        attribute maxTemperature : ThermodynamicTemperatureValue = 120 [degC];
        attribute actualPressure : PressureValue;
        attribute actualTemperature : ThermodynamicTemperatureValue;
        
        require constraint { 
            actualPressure <= maxPressure and
            actualTemperature >= minTemperature and
            actualTemperature <= maxTemperature
        }
    }

    requirement def SystemRequirementsPackage {
        requirement injectionAccuracy : InjectionAccuracyRequirement;
        requirement responseTime : ResponseTimeRequirement;
        requirement pressureRegulation : PressureRegulationRequirement;
        requirement atomization : AtomizationRequirement;
        requirement reliability : ReliabilityRequirement;
        requirement safety : SafetyRequirement;
    }
}
