package OlfactometerSystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    // ---- Unit Definitions ----
    unit L_per_min { def :> Real; }
    unit ppm { def :> Real; }
    unit percent { def :> Real; }
    unit kPa { def :> Real; }
    unit mL { def :> Real; }
    unit mg { def :> Real; }

    // ---- Value Types ----
    attribute def FlowRate :> Real { unit L_per_min; }
    attribute def Concentration :> Real { unit ppm; }
    attribute def TempCelsius :> Real { unit 'degC'; }
    attribute def RelativeHumidity :> Real { unit percent; }
    attribute def Pressure :> Real { unit kPa; }
    attribute def Volume :> Real { unit mL; }
    attribute def Mass :> Real { unit mg; }
    attribute def Duration :> Real { unit s; }

    // ---- Item Definitions ----
    item def CleanAir {
        attribute temperature : TempCelsius;
        attribute humidity : RelativeHumidity;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    item def LiquidOdorant {
        attribute name : String;
        attribute vaporPressure : Pressure;
        attribute density : Real;
        attribute purity : Real;
    }

    item def OdorantVapor {
        attribute odorantId : Integer;
        attribute concentration : Concentration;
        attribute flowRate : FlowRate;
        attribute temperature : TempCelsius;
    }

    item def ScentedAir {
        attribute odorantId : Integer;
        attribute concentration : Concentration;
        attribute temperature : TempCelsius;
        attribute humidity : RelativeHumidity;
        attribute flowRate : FlowRate;
    }

    // ---- Port Definitions ----
    port def AirFlowPort {
        out item air : CleanAir;
    }

    port def VaporFlowPort {
        out item vapor : OdorantVapor;
    }

    port def ScentedAirPort {
        out item scentedAir : ScentedAir;
    }

    port def FlowControlPort {
        in attribute setpoint : FlowRate;
        out attribute measuredFlow : FlowRate;
        out attribute status : String;
    }

    port def ConditioningControlPort {
        in attribute targetTemp : TempCelsius;
        in attribute targetHumidity : RelativeHumidity;
        out attribute measuredTemp : TempCelsius;
        out attribute measuredHumidity : RelativeHumidity;
    }

    port def ConcentrationFeedbackPort {
        out attribute measuredConcentration : Concentration;
        out attribute sensorStatus : String;
    }

    port def OperatorCommandPort {
        in attribute protocolId : Integer;
        in attribute channel : Integer;
        in attribute targetConcentration : Concentration;
        in attribute stimulusDuration : Duration;
        in attribute purgeDuration : Duration;
        out attribute systemStatus : String;
    }

    // ---- Part Definitions ----
    part def CleanAirSupply {
        port airOut : AirFlowPort;
        attribute outputPressure : Pressure = 101.3;
        attribute maxFlowRate : FlowRate = 20.0;
        attribute filterEfficiency : Real = 0.9999;
    }

    part def HumidityController {
        port airIn : AirFlowPort;
        port airOut : AirFlowPort;
        port controlIn : ConditioningControlPort;
        attribute targetHumidity : RelativeHumidity;
        attribute currentHumidity : RelativeHumidity;
        attribute humidifierCapacity : Volume;
        attribute responseTime : Duration = 2.0;
    }

    part def TemperatureController {
        port airIn : AirFlowPort;
        port airOut : AirFlowPort;
        port controlIn : ConditioningControlPort;
        attribute targetTemperature : TempCelsius;
        attribute currentTemperature : TempCelsius;
        attribute heaterPower : Real;
        attribute responseTime : Duration = 5.0;
    }

    part def OdorantReservoir {
        attribute reservoirId : Integer;
        attribute odorant : LiquidOdorant;
        attribute fillLevel : Volume;
        attribute maxCapacity : Volume = 50.0;
        attribute temperature : TempCelsius;
        port vaporOut : VaporFlowPort;
    }

    part def MassFlowController {
        port controlIn : FlowControlPort;
        port flowIn : AirFlowPort;
        port flowOut : AirFlowPort;
        attribute maxFlowRate : FlowRate;
        attribute currentFlowRate : FlowRate;
        attribute accuracy : Real = 0.01;
        attribute responseTime : Duration = 0.5;
    }

    part def OdorantMassFlowController {
        port controlIn : FlowControlPort;
        port vaporIn : VaporFlowPort;
        port vaporOut : VaporFlowPort;
        attribute maxFlowRate : FlowRate;
        attribute currentFlowRate : FlowRate;
        attribute accuracy : Real = 0.005;
        attribute responseTime : Duration = 0.3;
    }

    part def MixingManifold {
        port carrierIn : AirFlowPort;
        port vaporIn[1..4] : VaporFlowPort;
        port mixedOut : ScentedAirPort;
        attribute mixingVolume : Volume = 5.0;
        attribute mixingEfficiency : Real = 0.98;
    }

    part def ConcentrationSensor {
        port sampleIn : ScentedAirPort;
        port feedbackOut : ConcentrationFeedbackPort;
        attribute measuredConcentration : Concentration;
        attribute responseTime : Duration = 0.2;
        attribute accuracy : Real = 0.02;
        attribute detectionLimit : Concentration = 0.01;
    }

    part def ControlComputer {
        port operatorCmd : OperatorCommandPort;
        port feedbackIn : ConcentrationFeedbackPort;
        port carrierMfcControl : FlowControlPort;
        port odorantMfcControl[1..4] : FlowControlPort;
        port conditioningControl : ConditioningControlPort;
        attribute targetConcentration : Concentration;
        attribute activeChannel : Integer;
        attribute stimulusDuration : Duration;
        attribute purgeDuration : Duration;
        attribute stabilizationTime : Duration = 3.0;
        attribute protocolRunning : Boolean = false;
        attribute pidGainProportional : Real = 2.0;
        attribute pidGainIntegral : Real = 0.5;
        attribute pidGainDerivative : Real = 0.1;
        attribute integralError : Real = 0.0;
        attribute previousError : Real = 0.0;
    }

    part def StimulusProtocol {
        attribute protocolId : Integer;
        attribute channel : Integer;
        attribute targetConcentration : Concentration;
        attribute duration : Duration;
        attribute purgeDuration : Duration;
        attribute stabilizationTime : Duration;
        attribute carrierFlowRate : FlowRate;
        attribute interTrialInterval : Duration;
    }

    // ---- Main System ----
    part def Olfactometer {
        port operatorInterface : OperatorCommandPort;
        port outputPort : ScentedAirPort;

        part cleanAirSupply : CleanAirSupply;
        part humidityController : HumidityController;
        part temperatureController : TemperatureController;
        part reservoirs[1..4] : OdorantReservoir;
        part carrierMFC : MassFlowController;
        part odorantMFCs[1..4] : OdorantMassFlowController;
        part mixingManifold : MixingManifold;
        part concentrationSensor : ConcentrationSensor;
        part controlComputer : ControlComputer;

        // Air pathway connections
        connection cleanAirToHumidity connect cleanAirSupply.airOut to humidityController.airIn;
        connection humidityToTemperature connect humidityController.airOut to temperatureController.airIn;
        connection tempToCarrierMFC connect temperatureController.airOut to carrierMFC.flowIn;
        connection carrierMFCtoManifold connect carrierMFC.flowOut to mixingManifold.carrierIn;

        // Odorant pathway connections
        connection reservoirToMFC[1..4] connect reservoirs.vaporOut to odorantMFCs.vaporIn;
        connection mfcToManifold[1..4] connect odorantMFCs.vaporOut to mixingManifold.vaporIn;

        // Output connections
        connection manifoldToSensor connect mixingManifold.mixedOut to concentrationSensor.sampleIn;
        connection manifoldToOutput connect mixingManifold.mixedOut to outputPort;

        // Feedback connections
        connection sensorToComputer connect concentrationSensor.feedbackOut to controlComputer.feedbackIn;

        // Control connections
        connection computerToCarrierMFC connect controlComputer.carrierMfcControl to carrierMFC.controlIn;
        connection computerToOdorantMFC[1..4] connect controlComputer.odorantMfcControl to odorantMFCs.controlIn;
        connection computerToConditioning connect controlComputer.conditioningControl to humidityController.controlIn;
        connection computerToConditioning2 connect controlComputer.conditioningControl to temperatureController.controlIn;

        // Operator interface
        connection operatorToComputer connect operatorInterface to controlComputer.operatorCmd;

        // State machine behavior
        behavior stateMachine OlfactometerOperation {
            attribute currentProtocol : StimulusProtocol;
            attribute elapsedTime : Duration;
            attribute purgeElapsedTime : Duration;
            attribute stabilizeElapsedTime : Duration;

            state Idle {
                entry action {
                    controlComputer.protocolRunning = false;
                    operatorInterface.systemStatus = "Idle";
                    carrierMFC.controlIn.setpoint = 5.0;
                    odorantMFCs.controlIn.setpoint = 0.0;
                }
            }

            state Stabilizing {
                entry action {
                    controlComputer.protocolRunning = true;
                    operatorInterface.systemStatus = "Stabilizing";
                    carrierMFC.controlIn.setpoint = currentProtocol.carrierFlowRate;
                    odorantMFCs[currentProtocol.channel].controlIn.setpoint = 0.0;
                    stabilizeElapsedTime = 0.0;
                }
                do action {
                    stabilizeElapsedTime = stabilizeElapsedTime + 0.1;
                }
            }

            state Delivering {
                entry action {
                    operatorInterface.systemStatus = "Delivering";
                    odorantMFCs[currentProtocol.channel].controlIn.setpoint = currentProtocol.targetConcentration;
                    elapsedTime = 0.0;
                }
                do action {
                    // Closed-loop feedback control
                    attribute error : Real;
                    attribute derivativeError : Real;
                    attribute correction : Real;
                    error = currentProtocol.targetConcentration - concentrationSensor.feedbackOut.measuredConcentration;
                    controlComputer.integralError = controlComputer.integralError + error;
                    derivativeError = error - controlComputer.previousError;
                    correction = controlComputer.pidGainProportional * error
                        + controlComputer.pidGainIntegral * controlComputer.integralError
                        + controlComputer.pidGainDerivative * derivativeError;
                    odorantMFCs[currentProtocol.channel].controlIn.setpoint =
                        odorantMFCs[currentProtocol.channel].controlIn.setpoint + correction;
                    controlComputer.previousError = error;
                    elapsedTime = elapsedTime + 0.1;
                }
            }

            state Purging {
                entry action {
                    operatorInterface.systemStatus = "Purging";
                    odorantMFCs.controlIn.setpoint = 0.0;
                    carrierMFC.controlIn.setpoint = currentProtocol.carrierFlowRate * 2.0;
                    purgeElapsedTime = 0.0;
                }
                do action {
                    purgeElapsedTime = purgeElapsedTime + 0.1;
                }
            }

            transition T1 first Idle then Stabilizing
                when operatorInterface.protocolId > 0;

            transition T2 first Stabilizing then Delivering
                when stabilizeElapsedTime >= currentProtocol.stabilizationTime
                    and abs(carrierMFC.controlIn.measuredFlow - carrierMFC.controlIn.setpoint)
                        / carrierMFC.controlIn.setpoint <= carrierMFC.accuracy;

            transition T3 first Delivering then Purging
                when elapsedTime >= currentProtocol.duration;

            transition T4 first Purging then Idle
                when purgeElapsedTime >= currentProtocol.purgeDuration
                    and concentrationSensor.feedbackOut.measuredConcentration
                        <= concentrationSensor.detectionLimit;
        }
    }

    // ---- Requirements ----
    requirement def ConcentrationAccuracyReq {
        attribute targetConcentration : Concentration;
        attribute measuredConcentration : Concentration;
        constraint {
            abs(measuredConcentration - targetConcentration) / targetConcentration <= 0.05
        }
    }

    requirement def FlowStabilityReq {
        attribute setpoint : FlowRate;
        attribute measured : FlowRate;
        constraint {
            abs(measured - setpoint) / setpoint <= 0.01
        }
    }

    requirement def TemperatureStabilityReq {
        attribute target : TempCelsius;
        attribute measured : TempCelsius;
        constraint {
            abs(measured - target) <= 0.5
        }
    }

    requirement def HumidityStabilityReq {
        attribute target : RelativeHumidity;
        attribute measured : RelativeHumidity;
        constraint {
            abs(measured - target) <= 2.0
        }
    }

    requirement def PurgeEffectivenessReq {
        attribute residualConcentration : Concentration;
        constraint {
            residualConcentration <= 0.01
        }
    }

    requirement def StimulusRepeatabilityReq {
        attribute trial1Concentration : Concentration;
        attribute trial2Concentration : Concentration;
        constraint {
            abs(trial1Concentration - trial2Concentration) / trial1Concentration <= 0.03
        }
    }

    requirement def ResponseTimeReq {
        attribute maxResponseTime : Duration = 1.0;
        attribute actualResponseTime : Duration;
        constraint {
            actualResponseTime <= maxResponseTime
        }
    }

    requirement def FourChannelCapacityReq {
        attribute numChannels : Integer = 4;
        constraint {
            numChannels >= 4
        }
    }

    requirement def OlfactometerSystemRequirements {
        requirement concentrationAccuracy : ConcentrationAccuracyReq {
            doc "The delivered concentration shall be within 5% of the target concentration.";
        }
        requirement flowStability : FlowStabilityReq {
            doc "Mass flow controllers shall maintain flow within 1% of setpoint.";
        }
        requirement temperatureStability : TemperatureStabilityReq {
            doc "Carrier air temperature shall be stable within 0.5 degrees Celsius.";
        }
        requirement humidityStability : HumidityStabilityReq {
            doc "Carrier air humidity shall be stable within 2% relative humidity.";
        }
        requirement purgeEffectiveness : PurgeEffectivenessReq {
            doc "Residual odorant concentration after purge shall not exceed 0.01 ppm.";
        }
        requirement stimulusRepeatability : StimulusRepeatabilityReq {
            doc "Repeated stimulus delivery shall be repeatable within 3%.";
        }
        requirement responseTime : ResponseTimeReq {
            doc "System response time shall not exceed 1 second.";
        }
        requirement channelCapacity : FourChannelCapacityReq {
            doc "System shall support at least 4 independent odorant channels.";
        }
    }

    // ---- Verification ----
    verification def VerifyConcentrationAccuracy {
        subject : Olfactometer;
        objective : ConcentrationAccuracyReq;
        method {
            // Deliver known concentration and measure with reference sensor
        }
    }

    verification def VerifyPurgeEffectiveness {
        subject : Olfactometer;
        objective : PurgeEffectivenessReq;
        method {
            // Deliver stimulus, purge, and measure residual concentration
        }
    }

    verification def VerifyRepeatability {
        subject : Olfactometer;
        objective : StimulusRepeatabilityReq;
        method {
            // Deliver same protocol 10 times and compare concentrations
        }
    }
}
