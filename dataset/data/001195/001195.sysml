package 'Pitometer Log System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def PressureDifferenceValue :> PressureValue;
    attribute def WaterDensityValue :> MassDensityValue;
    attribute def CalibrationFactorValue :> Real;

    item def PressureData {
        attribute dynamicPressure : PressureValue;
        attribute staticPressure : PressureValue;
        attribute timestamp : TimeValue;
    }

    item def VelocityData {
        attribute speed : SpeedValue;
        attribute timestamp : TimeValue;
    }

    item def DistanceData {
        attribute totalDistance : LengthValue;
        attribute timestamp : TimeValue;
    }

    port def PressureInputPort {
        in item pressureSignal : PressureData;
    }

    port def VelocityOutputPort {
        out item velocitySignal : VelocityData;
    }

    port def DistanceOutputPort {
        out item distanceSignal : DistanceData;
    }

    part def PitotTube {
        doc /* Hydrodynamic sensor extending through hull to measure water flow pressure. */
        
        port dynamicPort : PressureInputPort;
        port staticPort : PressureInputPort;
        port differentialOut : PressureInputPort;

        attribute tubeLength : LengthValue;
        attribute mountingDepth : LengthValue;
    }

    part def PressureTransducer {
        doc /* Converts differential pressure to electrical signal. */
        
        port pressureIn : PressureInputPort;
        port pressureOut : PressureInputPort;

        attribute sensitivity : PressureDifferenceValue;
        attribute accuracy : Real;

        action convertPressure {
            in rawPressure : PressureData;
            out calibratedPressure : PressureData;
        }
    }

    part def VelocityComputer {
        doc /* Calculates vessel speed through water from pressure differential. */
        
        port pressureIn : PressureInputPort;
        port velocityOut : VelocityOutputPort;

        attribute waterDensity : WaterDensityValue := 1025.0 [kg/m^3];
        attribute calibrationFactor : CalibrationFactorValue := 1.0;

        action calculateVelocity {
            in pressureInput : PressureData;
            out velocityOutput : VelocityData;

            action computeSpeed {
                in pressureDiff : PressureDifferenceValue;
                in density : WaterDensityValue;
                in calibration : CalibrationFactorValue;
                out speed : SpeedValue;
            }

            first start;
            then action extractDifferential {
                in pressure = pressureInput;
                out differential : PressureDifferenceValue;
            }
            then action applyBernoulli : computeSpeed {
                in pressureDiff = extractDifferential.differential;
                in density = waterDensity;
                in calibration = calibrationFactor;
                out speed;
            }
            then action packageOutput {
                in speed = applyBernoulli.speed;
                in time = pressureInput.timestamp;
                out result = velocityOutput;
            }
            then done;
        }
    }

    part def DistanceIntegrator {
        doc /* Integrates velocity over time to compute total distance traveled. */
        
        port velocityIn : VelocityOutputPort;
        port distanceOut : DistanceOutputPort;

        attribute accumulatedDistance : LengthValue := 0.0 [m];
        attribute updateInterval : TimeValue := 0.1 [s];
        attribute lastUpdateTime : TimeValue := 0.0 [s];

        action integrateDistance {
            in velocityInput : VelocityData;
            out distanceOutput : DistanceData;

            private attribute currentDistance := accumulatedDistance;
            private attribute previousTime := lastUpdateTime;

            action computeIncrement {
                in velocity : SpeedValue;
                in deltaTime : TimeValue;
                out increment : LengthValue;
            }

            action updateAccumulator {
                in increment : LengthValue;
                in current : LengthValue;
                out updated : LengthValue;
            }

            first start;
            then action calculateDeltaTime {
                in currentTime = velocityInput.timestamp;
                in lastTime = previousTime;
                out deltaT : TimeValue;
            }
            then action calculateIncrement : computeIncrement {
                in velocity = velocityInput.speed;
                in deltaTime = calculateDeltaTime.deltaT;
                out increment;
            }
            then action updateTotal : updateAccumulator {
                in increment = calculateIncrement.increment;
                in current = currentDistance;
                out updated;
            }
            then assign currentDistance := updateTotal.updated;
            then assign previousTime := velocityInput.timestamp;
            then action createOutput {
                in distance = currentDistance;
                in time = velocityInput.timestamp;
                out result = distanceOutput;
            }
            then done;
        }
    }

    part def DisplayUnit {
        doc /* Displays current speed and accumulated distance to operator. */
        
        port velocityIn : VelocityOutputPort;
        port distanceIn : DistanceOutputPort;

        attribute displayedSpeed : SpeedValue;
        attribute displayedDistance : LengthValue;
        attribute updateRate : Real := 1.0;

        action updateDisplay {
            in velocityData : VelocityData;
            in distanceData : DistanceData;

            action refreshSpeedDisplay {
                in speed : SpeedValue;
            }

            action refreshDistanceDisplay {
                in distance : LengthValue;
            }
        }
    }

    part def PitometerLog {
        doc /* 
            A Pitometer log is a marine navigation instrument that measures 
            a vessel's speed through water and total distance traveled. 
            It operates by sensing the differential pressure between dynamic 
            and static water pressure at the hull, converting this pressure 
            difference to velocity using Bernoulli's principle, and continuously 
            integrating velocity over time to determine cumulative distance.
            The system provides real-time speed and distance information 
            essential for marine navigation and voyage planning.
        */

        part pitotTube : PitotTube {
            port redefines dynamicPort;
            port redefines staticPort;
            port redefines differentialOut;
        }

        part transducer : PressureTransducer {
            port redefines pressureIn;
            port redefines pressureOut;
        }

        part velocityComputer : VelocityComputer {
            port redefines pressureIn;
            port redefines velocityOut;
        }

        part distanceIntegrator : DistanceIntegrator {
            port redefines velocityIn;
            port redefines distanceOut;
        }

        part display : DisplayUnit {
            port redefines velocityIn;
            port redefines distanceIn;
        }

        connection tubeToTransducer 
            connect pitotTube.differentialOut to transducer.pressureIn;

        connection transducerToComputer 
            connect transducer.pressureOut to velocityComputer.pressureIn;

        connection computerToIntegrator 
            connect velocityComputer.velocityOut to distanceIntegrator.velocityIn;

        connection integratorToDisplay 
            connect distanceIntegrator.distanceOut to display.distanceIn;

        connection computerToDisplay 
            connect velocityComputer.velocityOut to display.velocityIn;

        perform action measureAndLog {
            first start;
            then merge continuousMeasurement;

            action sensePressure {
                out pressureData : PressureData;
            }

            then action computeVelocity {
                in pressureData = sensePressure.pressureData;
                out velocityData : VelocityData;
            }

            then action integrateToDistance {
                in velocityData = computeVelocity.velocityData;
                out distanceData : DistanceData;
            }

            then action updateDisplays {
                in velocityData = computeVelocity.velocityData;
                in distanceData = integrateToDistance.distanceData;
            }

            then continuousMeasurement;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* 
            The Pitometer Log shall continuously measure and display 
            the vessel's speed through water and total distance traveled.
        */

        subject pitometerSystem : PitometerLog;

        require constraint continuousMeasurement {
            doc /* System shall provide continuous real-time measurements. */
        }

        require constraint accurateSpeed {
            doc /* Speed measurement shall be accurate within ±2% of actual speed. */
        }

        require constraint accurateDistance {
            doc /* Distance measurement shall be accurate within ±1% of actual distance. */
        }
    }

    requirement def PressureSensingRequirement {
        doc /* 
            The pressure sensing subsystem shall accurately measure 
            differential pressure across the specified operating range.
        */

        subject sensor : PitotTube;

        require constraint operatingRange {
            doc /* Shall operate over speed range 0 to 40 knots. */
        }

        require constraint pressureAccuracy {
            doc /* Pressure measurement accuracy shall be ±0.5% of reading. */
        }
    }

    requirement def VelocityComputationRequirement {
        doc /* 
            The velocity computer shall convert pressure differential 
            to speed using validated hydrodynamic principles.
        */

        subject computer : VelocityComputer;

        require constraint bernoulliApplication {
            doc /* Shall apply Bernoulli equation: v = sqrt(2*ΔP/ρ). */
        }

        require constraint calibrationSupport {
            doc /* Shall support field calibration adjustment. */
        }
    }

    requirement def IntegrationRequirement {
        doc /* 
            The distance integrator shall accurately accumulate 
            distance over extended operation periods.
        */

        subject integrator : DistanceIntegrator;

        require constraint integrationRate {
            doc /* Integration update rate shall be at least 10 Hz. */
        }

        require constraint numericalStability {
            doc /* Integration algorithm shall maintain stability over 1000+ hours. */
        }

        require constraint resetCapability {
            doc /* Shall support manual reset of accumulated distance. */
        }
    }

    requirement systemRequirements {
        doc /* Top-level requirements for Pitometer Log system. */

        require primaryFunction : PrimaryFunctionRequirement;
        require pressureSensing : PressureSensingRequirement;
        require velocityComputation : VelocityComputationRequirement;
        require distanceIntegration : IntegrationRequirement;

        satisfy primaryFunction by pitometerLogInstance.measureAndLog;
    }

    action def CalibrateSystem {
        in knownSpeed : SpeedValue;
        in measuredSpeed : SpeedValue;
        out newCalibrationFactor : CalibrationFactorValue;

        action calculateCalibrationFactor {
            in known : SpeedValue;
            in measured : SpeedValue;
            out factor : CalibrationFactorValue;
        }

        action applyCalibrationFactor {
            in factor : CalibrationFactorValue;
        }

        first start;
        then action compute : calculateCalibrationFactor {
            in known = knownSpeed;
            in measured = measuredSpeed;
            out factor;
        }
        then action apply : applyCalibrationFactor {
            in factor = compute.factor;
        }
        then assign newCalibrationFactor := compute.factor;
        then done;
    }

    part pitometerLogInstance : PitometerLog {
        attribute operationalStatus : String := "Offline";
        attribute calibrationDate : TimeValue;
        attribute totalOperatingHours : TimeValue := 0.0 [s];

        perform action operateSystem {
            first start;

            action powerOn {
                out status : String;
            }

            then action runDiagnostics {
                out diagnosticResult : Boolean;
            }

            then decide;
                if runDiagnostics.diagnosticResult then calibrateIfNeeded;
                else handleFault;

            action calibrateIfNeeded : CalibrateSystem {
                in knownSpeed;
                in measuredSpeed;
                out newCalibrationFactor;
            }

            then action normalOperation references measureAndLog;

            action handleFault {
                out faultCode : String;
            }

            then done;
        }
    }
}
